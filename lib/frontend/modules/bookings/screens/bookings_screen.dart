import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/frontend/shared/providers/auth_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/booking_provider.dart';
import 'package:tanodmobile/frontend/shared/widgets/app_toast.dart';
import 'package:tanodmobile/models/domain/booking.dart';

bool _isSameDay(DateTime a, DateTime? b) =>
    b != null && a.year == b.year && a.month == b.month && a.day == b.day;

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final ScrollController _listScrollController = ScrollController();

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  int? _selectedTractorId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final provider = context.read<BookingProvider>();
    provider.fetchBookings();
    provider.fetchTractors();

    // FCA role: fetch farmers list for booking on behalf
    final roles = context.read<AuthProvider>().session?.roles ?? [];
    if (roles.contains('fca')) {
      provider.fetchFarmers();
    }

    _listScrollController.addListener(() {
      if (_listScrollController.position.pixels >=
          _listScrollController.position.maxScrollExtent - 200) {
        context.read<BookingProvider>().fetchMore();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  List<Booking> _filterBookings(List<Booking> bookings) {
    var filtered = bookings;
    if (_selectedTractorId != null) {
      filtered = filtered
          .where((b) => b.tractorId == _selectedTractorId)
          .toList();
    }
    return filtered;
  }

  List<Booking> _getEventsForDay(
      DateTime day, Map<DateTime, List<Booking>> byDate) {
    final key = DateTime(day.year, day.month, day.day);
    final events = byDate[key] ?? [];
    if (_selectedTractorId == null) return events;
    return events.where((b) => b.tractorId == _selectedTractorId).toList();
  }

  void _showCreateBookingSheet() {
    final provider = context.read<BookingProvider>();
    final roles = context.read<AuthProvider>().session?.roles ?? [];
    final isFca = roles.contains('fca');

    if (provider.tractors.isEmpty) {
      AppToast.warning('No tractors available');
      return;
    }

    int? tractorId;
    int? farmerId;
    DateTime fromDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay fromTime = const TimeOfDay(hour: 8, minute: 0);
    DateTime toDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay toTime = const TimeOfDay(hour: 17, minute: 0);
    final purposeController = TextEditingController();
    final areaController = TextEditingController();
    final notesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.mutedInk.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'New Booking',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Farmer dropdown (FCA only)
                    if (isFca) ...[
                      _buildLabel('Farmer'),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppColors.mutedInk.withValues(alpha: 0.2),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: farmerId,
                            isExpanded: true,
                            hint: const Text('Select farmer'),
                            items: provider.farmers.map((f) {
                              final id = f['id'] as int;
                              final name = f['name']?.toString() ?? '';
                              return DropdownMenuItem(
                                value: id,
                                child: Text(name),
                              );
                            }).toList(),
                            onChanged: (val) =>
                                setSheetState(() => farmerId = val),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Tractor dropdown
                    _buildLabel('Tractor'),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.mutedInk.withValues(alpha: 0.2),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: tractorId,
                          isExpanded: true,
                          hint: const Text('Select tractor'),
                          items: provider.tractors.map((t) {
                            final id = t['id'] as int;
                            final plate = t['no_plate']?.toString() ?? '';
                            final brand = t['brand']?.toString() ?? '';
                            return DropdownMenuItem(
                              value: id,
                              child: Text('$plate - $brand'),
                            );
                          }).toList(),
                          onChanged: (val) =>
                              setSheetState(() => tractorId = val),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // From - Date & Time
                    _buildLabel('From'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _DatePickerField(
                            date: fromDate,
                            onPick: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: fromDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setSheetState(() {
                                  fromDate = picked;
                                  if (toDate.isBefore(fromDate)) {
                                    toDate = fromDate;
                                  }
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        _TimePickerField(
                          time: fromTime,
                          onPick: () async {
                            final picked = await showTimePicker(
                              context: ctx,
                              initialTime: fromTime,
                            );
                            if (picked != null) {
                              setSheetState(() => fromTime = picked);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // To - Date & Time
                    _buildLabel('To'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _DatePickerField(
                            date: toDate,
                            onPick: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: toDate.isBefore(fromDate)
                                    ? fromDate
                                    : toDate,
                                firstDate: fromDate,
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setSheetState(() => toDate = picked);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        _TimePickerField(
                          time: toTime,
                          onPick: () async {
                            final picked = await showTimePicker(
                              context: ctx,
                              initialTime: toTime,
                            );
                            if (picked != null) {
                              setSheetState(() => toTime = picked);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Purpose
                    _buildLabel('Purpose'),
                    const SizedBox(height: 6),
                    _buildTextField(purposeController, 'e.g. Land preparation'),
                    const SizedBox(height: 14),

                    // Farm area
                    _buildLabel('Farm Area (hectares)'),
                    const SizedBox(height: 6),
                    _buildTextField(areaController, 'e.g. 2.5',
                        keyboard: TextInputType.number),
                    const SizedBox(height: 14),

                    // Notes
                    _buildLabel('Notes (optional)'),
                    const SizedBox(height: 6),
                    _buildTextField(notesController, 'Additional details...',
                        maxLines: 3),
                    const SizedBox(height: 20),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          if (tractorId == null) {
                            AppToast.warning('Please select a tractor');
                            return;
                          }
                          if (isFca && farmerId == null) {
                            AppToast.warning('Please select a farmer');
                            return;
                          }
                          if (purposeController.text.trim().isEmpty) {
                            AppToast.warning('Please enter a purpose');
                            return;
                          }

                          final dateFmt = DateFormat('yyyy-MM-dd');
                          final timeFmt = DateFormat('HH:mm');
                          final fromDateTime = DateTime(
                            fromDate.year,
                            fromDate.month,
                            fromDate.day,
                            fromTime.hour,
                            fromTime.minute,
                          );
                          final toDateTime = DateTime(
                            toDate.year,
                            toDate.month,
                            toDate.day,
                            toTime.hour,
                            toTime.minute,
                          );

                          if (toDateTime.isBefore(fromDateTime)) {
                            AppToast.warning('End date/time must be after start');
                            return;
                          }

                          final area =
                              double.tryParse(areaController.text.trim());
                          final notes = notesController.text.trim().isEmpty
                              ? null
                              : notesController.text.trim();

                          final success = await provider.createBooking(
                            tractorId: tractorId!,
                            bookingDate: dateFmt.format(fromDate),
                            startDate: dateFmt.format(fromDate),
                            endDate: dateFmt.format(toDate),
                            startTime: timeFmt.format(fromDateTime),
                            endTime: timeFmt.format(toDateTime),
                            purpose: purposeController.text.trim(),
                            farmerId: farmerId,
                            farmAreaHectares: area,
                            notes: notes,
                          );

                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                            if (success) {
                              AppToast.success('Booking created!');
                            } else {
                              AppToast.error('Failed to create booking');
                            }
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.forest,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Create Booking',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditBookingSheet(Booking booking) {
    final provider = context.read<BookingProvider>();
    final roles = context.read<AuthProvider>().session?.roles ?? [];
    final isFca = roles.contains('fca');
    final isAdmin = roles.contains('super-admin') || roles.contains('sub-admin');
    final isFarmer = !isFca && !isAdmin;

    int? tractorId = booking.tractorId;
    DateTime fromDate = booking.startDate ?? booking.bookingDate;
    DateTime toDate = booking.endDate ?? booking.bookingDate;
    TimeOfDay fromTime = _parseTime(booking.startTime) ??
        const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay toTime = _parseTime(booking.endTime) ??
        const TimeOfDay(hour: 17, minute: 0);
    final purposeController = TextEditingController(text: booking.purpose ?? '');
    final areaController = TextEditingController(
      text: booking.farmAreaHectares?.toString() ?? '',
    );
    final notesController = TextEditingController(text: booking.notes ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.mutedInk.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Edit Booking',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    if (isFarmer) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                size: 18,
                                color: AppColors.gold.withValues(alpha: 0.8)),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Editing will reset status to pending for re-approval.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.ink,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),

                    // Tractor dropdown
                    _buildLabel('Tractor'),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.mutedInk.withValues(alpha: 0.2),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: tractorId,
                          isExpanded: true,
                          hint: const Text('Select tractor'),
                          items: provider.tractors.map((t) {
                            final id = t['id'] as int;
                            final plate = t['no_plate']?.toString() ?? '';
                            final brand = t['brand']?.toString() ?? '';
                            return DropdownMenuItem(
                              value: id,
                              child: Text('$plate - $brand'),
                            );
                          }).toList(),
                          onChanged: (val) =>
                              setSheetState(() => tractorId = val),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // From - Date & Time
                    _buildLabel('From'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _DatePickerField(
                            date: fromDate,
                            onPick: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: fromDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setSheetState(() {
                                  fromDate = picked;
                                  if (toDate.isBefore(fromDate)) {
                                    toDate = fromDate;
                                  }
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        _TimePickerField(
                          time: fromTime,
                          onPick: () async {
                            final picked = await showTimePicker(
                              context: ctx,
                              initialTime: fromTime,
                            );
                            if (picked != null) {
                              setSheetState(() => fromTime = picked);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // To - Date & Time
                    _buildLabel('To'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _DatePickerField(
                            date: toDate,
                            onPick: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: toDate.isBefore(fromDate)
                                    ? fromDate
                                    : toDate,
                                firstDate: fromDate,
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setSheetState(() => toDate = picked);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        _TimePickerField(
                          time: toTime,
                          onPick: () async {
                            final picked = await showTimePicker(
                              context: ctx,
                              initialTime: toTime,
                            );
                            if (picked != null) {
                              setSheetState(() => toTime = picked);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Purpose
                    _buildLabel('Purpose'),
                    const SizedBox(height: 6),
                    _buildTextField(purposeController, 'e.g. Land preparation'),
                    const SizedBox(height: 14),

                    // Farm area
                    _buildLabel('Farm Area (hectares)'),
                    const SizedBox(height: 6),
                    _buildTextField(areaController, 'e.g. 2.5',
                        keyboard: TextInputType.number),
                    const SizedBox(height: 14),

                    // Notes
                    _buildLabel('Notes (optional)'),
                    const SizedBox(height: 6),
                    _buildTextField(notesController, 'Additional details...',
                        maxLines: 3),
                    const SizedBox(height: 20),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          if (tractorId == null) {
                            AppToast.warning('Please select a tractor');
                            return;
                          }
                          if (purposeController.text.trim().isEmpty) {
                            AppToast.warning('Please enter a purpose');
                            return;
                          }

                          final dateFmt = DateFormat('yyyy-MM-dd');
                          final timeFmt = DateFormat('HH:mm');
                          final fromDateTime = DateTime(
                            fromDate.year,
                            fromDate.month,
                            fromDate.day,
                            fromTime.hour,
                            fromTime.minute,
                          );
                          final toDateTime = DateTime(
                            toDate.year,
                            toDate.month,
                            toDate.day,
                            toTime.hour,
                            toTime.minute,
                          );

                          if (toDateTime.isBefore(fromDateTime)) {
                            AppToast.warning(
                                'End date/time must be after start');
                            return;
                          }

                          final area =
                              double.tryParse(areaController.text.trim());
                          final notes = notesController.text.trim().isEmpty
                              ? null
                              : notesController.text.trim();

                          final success = await provider.updateBooking(
                            bookingId: booking.id,
                            tractorId: tractorId,
                            bookingDate: dateFmt.format(fromDate),
                            startDate: dateFmt.format(fromDate),
                            endDate: dateFmt.format(toDate),
                            startTime: timeFmt.format(fromDateTime),
                            endTime: timeFmt.format(toDateTime),
                            purpose: purposeController.text.trim(),
                            farmAreaHectares: area,
                            notes: notes,
                          );

                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                            if (success) {
                              AppToast.success('Booking updated!');
                            } else {
                              AppToast.error('Failed to update booking');
                            }
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.forest,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Update Booking',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  TimeOfDay? _parseTime(String? time) {
    if (time == null) return null;
    final parts = time.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint,
      {TextInputType? keyboard, int maxLines = 1}) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: AppColors.mutedInk.withValues(alpha: 0.5),
          fontSize: 14,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: AppColors.mutedInk.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: AppColors.mutedInk.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.forest),
        ),
      ),
    );
  }

  Widget _buildCalendarTab(BookingProvider provider) {
    final byDate = provider.bookingsByDate;
    final daysInMonth = DateUtils.getDaysInMonth(
        _focusedDay.year, _focusedDay.month);
    final firstOfMonth =
        DateTime(_focusedDay.year, _focusedDay.month, 1);
    // Monday = 1, Sunday = 7
    final startWeekday = firstOfMonth.weekday; // 1=Mon
    final totalCells = ((startWeekday - 1) + daysInMonth + 6) ~/ 7 * 7;

    return Column(
      children: [
        // Month header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded,
                    color: AppColors.forest),
                onPressed: () {
                  setState(() {
                    _focusedDay = DateTime(
                        _focusedDay.year, _focusedDay.month - 1);
                  });
                },
              ),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  setState(() => _focusedDay = DateTime.now());
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    'Today',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.forest,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded,
                    color: AppColors.forest),
                onPressed: () {
                  setState(() {
                    _focusedDay = DateTime(
                        _focusedDay.year, _focusedDay.month + 1);
                  });
                },
              ),
              const Spacer(),
              Text(
                DateFormat('MMMM yyyy').format(_focusedDay),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),

        // Weekday headers
        Container(
          color: Colors.white,
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.mutedInk.withValues(alpha: 0.6),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),

        // Calendar grid
        Expanded(
          child: Container(
            color: Colors.white,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final rows = totalCells ~/ 7;
                final cellHeight = constraints.maxHeight / rows;
                final cellWidth = constraints.maxWidth / 7;
                const dayNumberHeight = 28.0;
                const barHeight = 18.0;
                const barGap = 1.0;
                final maxLanes =
                    ((cellHeight - dayNumberHeight - 2) / (barHeight + barGap))
                        .floor()
                        .clamp(0, 4);

                // Collect all bookings visible this month
                final allBookings = <Booking>{};
                for (final entry in byDate.entries) {
                  allBookings.addAll(entry.value);
                }

                return Column(
                  children: List.generate(rows, (row) {
                    // Dates for this week row
                    final rowDates = List.generate(7, (col) {
                      final cellIndex = row * 7 + col;
                      final dayOffset = cellIndex - (startWeekday - 1);
                      return DateTime(
                        _focusedDay.year,
                        _focusedDay.month,
                        dayOffset + 1,
                      );
                    });

                    final rowStart = DateTime(
                      rowDates.first.year,
                      rowDates.first.month,
                      rowDates.first.day,
                    );
                    final rowEnd = DateTime(
                      rowDates.last.year,
                      rowDates.last.month,
                      rowDates.last.day,
                    );

                    // Find bookings that overlap with this week row
                    final rowEvents = <_RowEvent>[];
                    final seen = <int>{};
                    for (final b in allBookings) {
                      if (seen.contains(b.id)) continue;

                      final bStart = b.startDate ?? b.bookingDate;
                      final bEnd = b.endDate ?? bStart;
                      final bs = DateTime(bStart.year, bStart.month, bStart.day);
                      final be = DateTime(bEnd.year, bEnd.month, bEnd.day);

                      // Check overlap
                      if (be.isBefore(rowStart) || bs.isAfter(rowEnd)) continue;

                      // Apply tractor filter
                      if (_selectedTractorId != null &&
                          b.tractorId != _selectedTractorId) {
                        continue;
                      }

                      seen.add(b.id);

                      // Clamp to row bounds
                      final clampedStart = bs.isBefore(rowStart) ? rowStart : bs;
                      final clampedEnd = be.isAfter(rowEnd) ? rowEnd : be;

                      final startCol =
                          clampedStart.difference(rowStart).inDays.clamp(0, 6);
                      final endCol =
                          clampedEnd.difference(rowStart).inDays.clamp(0, 6);

                      rowEvents.add(_RowEvent(
                        booking: b,
                        startCol: startCol,
                        endCol: endCol,
                        isStart: !bs.isBefore(rowStart),
                        isEnd: !be.isAfter(rowEnd),
                      ));
                    }

                    // Sort by startCol, then longer spans first
                    rowEvents.sort((a, b) {
                      final c = a.startCol.compareTo(b.startCol);
                      if (c != 0) return c;
                      return (b.endCol - b.startCol)
                          .compareTo(a.endCol - a.startCol);
                    });

                    // Lane assignment
                    final lanes = <Set<int>>[];
                    final laneAssignments = <int>[];
                    for (final e in rowEvents) {
                      final cols = Set<int>.from(List.generate(
                        e.endCol - e.startCol + 1,
                        (i) => e.startCol + i,
                      ));
                      int assignedLane = -1;
                      for (int i = 0; i < lanes.length; i++) {
                        if (lanes[i].intersection(cols).isEmpty) {
                          assignedLane = i;
                          break;
                        }
                      }
                      if (assignedLane == -1) {
                        assignedLane = lanes.length;
                        lanes.add(<int>{});
                      }
                      lanes[assignedLane].addAll(cols);
                      laneAssignments.add(assignedLane);
                    }

                    // Count overflow per cell
                    final overflowCounts = List.filled(7, 0);
                    for (int i = 0; i < rowEvents.length; i++) {
                      if (laneAssignments[i] >= maxLanes) {
                        for (int c = rowEvents[i].startCol;
                            c <= rowEvents[i].endCol;
                            c++) {
                          overflowCounts[c]++;
                        }
                      }
                    }

                    return SizedBox(
                      height: cellHeight,
                      child: Stack(
                        children: [
                          // Day number cells (background)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: List.generate(7, (col) {
                              final cellIndex = row * 7 + col;
                              final dayOffset = cellIndex - (startWeekday - 1);
                              final isCurrentMonth = dayOffset >= 0 &&
                                  dayOffset < daysInMonth;
                              final cellDate = rowDates[col];
                              final isToday = isCurrentMonth &&
                                  _isSameDay(cellDate, DateTime.now());
                              final isSelected = isCurrentMonth &&
                                  _selectedDay != null &&
                                  _isSameDay(cellDate, _selectedDay);

                              final dayEvents = isCurrentMonth
                                  ? _getEventsForDay(cellDate, byDate)
                                  : <Booking>[];

                              return Expanded(
                                child: GestureDetector(
                                  onTap: isCurrentMonth
                                      ? () {
                                          setState(() {
                                            _selectedDay = cellDate;
                                          });
                                          if (dayEvents.isNotEmpty) {
                                            _showDayBookings(
                                                cellDate, dayEvents);
                                          }
                                        }
                                      : null,
                                  child: Container(
                                    height: cellHeight,
                                    decoration: BoxDecoration(
                                      border: Border(
                                        top: BorderSide(
                                          color: AppColors.mutedInk
                                              .withValues(alpha: 0.08),
                                        ),
                                        right: col < 6
                                            ? BorderSide(
                                                color: AppColors.mutedInk
                                                    .withValues(alpha: 0.08),
                                              )
                                            : BorderSide.none,
                                      ),
                                      color: isSelected
                                          ? AppColors.forest
                                              .withValues(alpha: 0.06)
                                          : null,
                                    ),
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Column(
                                      children: [
                                        // Day number
                                        Container(
                                          width: 24,
                                          height: 24,
                                          alignment: Alignment.center,
                                          decoration: isToday
                                              ? const BoxDecoration(
                                                  color: AppColors.forest,
                                                  shape: BoxShape.circle,
                                                )
                                              : null,
                                          child: Text(
                                            cellDate.day.toString(),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: isToday
                                                  ? FontWeight.w800
                                                  : FontWeight.w500,
                                              color: isToday
                                                  ? Colors.white
                                                  : (isCurrentMonth
                                                      ? AppColors.ink
                                                      : AppColors.mutedInk
                                                          .withValues(
                                                              alpha: 0.3)),
                                            ),
                                          ),
                                        ),
                                        // Overflow indicator
                                        if (overflowCounts[col] > 0)
                                          Padding(
                                            padding: EdgeInsets.only(
                                              top: maxLanes *
                                                      (barHeight + barGap) +
                                                  2,
                                            ),
                                            child: Text(
                                              '+${overflowCounts[col]}',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.mutedInk
                                                    .withValues(alpha: 0.6),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                          // Spanning event bars
                          ...List.generate(rowEvents.length, (i) {
                            final e = rowEvents[i];
                            final lane = laneAssignments[i];
                            if (lane >= maxLanes) {
                              return const SizedBox.shrink();
                            }
                            return Positioned(
                              left: e.startCol * cellWidth + 2,
                              top: dayNumberHeight +
                                  lane * (barHeight + barGap),
                              width: (e.endCol - e.startCol + 1) *
                                      cellWidth -
                                  4,
                              height: barHeight,
                              child: GestureDetector(
                                onTap: () {
                                  final date =
                                      e.booking.startDate ??
                                      e.booking.bookingDate;
                                  final dayEvents =
                                      _getEventsForDay(date, byDate);
                                  _showDayBookings(date, dayEvents);
                                },
                                child: _SpanningEventBar(
                                  booking: e.booking,
                                  isStart: e.isStart,
                                  isEnd: e.isEnd,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _showDayBookings(DateTime day, List<Booking> events) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.mutedInk.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                DateFormat('EEEE, MMM d, yyyy').format(day),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${events.length} booking${events.length == 1 ? '' : 's'}',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.mutedInk),
              ),
              const SizedBox(height: 12),
              ...events.map((b) {
                final roles =
                    context.read<AuthProvider>().session?.roles ?? [];
                final isFca = roles.contains('fca');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _CompactBookingCard(
                    booking: b,
                    isFca: isFca,
                    onCancel: b.isCancellable
                        ? () {
                            Navigator.pop(ctx);
                            _confirmCancel(b.id);
                          }
                        : null,
                    onApprove:
                        isFca && b.isApprovable && b.farmerName != null
                            ? () {
                                Navigator.pop(ctx);
                                _approveBooking(b.id);
                              }
                            : null,
                    onReject:
                        isFca && b.isApprovable && b.farmerName != null
                            ? () {
                                Navigator.pop(ctx);
                                _showRejectDialog(b.id);
                              }
                            : null,
                    onEdit: b.isEditable
                        ? () {
                            Navigator.pop(ctx);
                            _showEditBookingSheet(b);
                          }
                        : null,
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildListingTab(BookingProvider provider) {
    if (provider.loading && provider.bookings.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.forest),
      );
    }

    if (provider.error != null && provider.bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48,
                color: AppColors.danger.withValues(alpha: 0.7)),
            const SizedBox(height: 12),
            Text(
              provider.error!,
              style:
                  const TextStyle(fontSize: 14, color: AppColors.mutedInk),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => provider.fetchBookings(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final filtered = _filterBookings(provider.bookings);
    final active = filtered
        .where((b) => b.status == 'pending' || b.status == 'approved')
        .toList();
    final done = filtered
        .where((b) =>
            b.status == 'completed' ||
            b.status == 'cancelled' ||
            b.status == 'rejected')
        .toList();

    final roles = context.read<AuthProvider>().session?.roles ?? [];
    final isFca = roles.contains('fca');

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy_rounded,
                size: 56,
                color: AppColors.mutedInk.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            const Text(
              'No bookings found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedInk,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.fetchBookings(),
      color: AppColors.forest,
      child: ListView(
        controller: _listScrollController,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // Active / Ongoing section
          if (active.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.schedule_rounded,
              label: 'Active',
              count: active.length,
              color: AppColors.forest,
            ),
            const SizedBox(height: 8),
            ...active.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _CompactBookingCard(
                    booking: b,
                    isFca: isFca,
                    onCancel: b.isCancellable
                        ? () => _confirmCancel(b.id)
                        : null,
                    onApprove: isFca && b.isApprovable && b.farmerName != null
                        ? () => _approveBooking(b.id)
                        : null,
                    onReject: isFca && b.isApprovable && b.farmerName != null
                        ? () => _showRejectDialog(b.id)
                        : null,
                    onEdit: b.isEditable
                        ? () => _showEditBookingSheet(b)
                        : null,
                  ),
                )),
          ],

          // Done / History section
          if (done.isNotEmpty) ...[
            if (active.isNotEmpty) const SizedBox(height: 16),
            _SectionHeader(
              icon: Icons.check_circle_outline_rounded,
              label: 'History',
              count: done.length,
              color: AppColors.mutedInk,
            ),
            const SizedBox(height: 8),
            ...done.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _CompactBookingCard(
                    booking: b,
                    isFca: isFca,
                  ),
                )),
          ],

          if (provider.hasMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.forest),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _approveBooking(int bookingId) async {
    final success =
        await context.read<BookingProvider>().approveBooking(bookingId);
    if (mounted) {
      if (success) {
        AppToast.success('Booking approved');
      } else {
        AppToast.error('Failed to approve booking');
      }
    }
  }

  void _showRejectDialog(int bookingId) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reject Booking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection.'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Reason...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                AppToast.warning('Please enter a reason');
                return;
              }
              Navigator.pop(ctx);
              final success = await context
                  .read<BookingProvider>()
                  .rejectBooking(bookingId, reason);
              if (mounted) {
                if (success) {
                  AppToast.success('Booking rejected');
                } else {
                  AppToast.error('Failed to reject booking');
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _confirmCancel(int bookingId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Booking'),
        content:
            const Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await context
                  .read<BookingProvider>()
                  .cancelBooking(bookingId);
              if (mounted) {
                if (success) {
                  AppToast.success('Booking cancelled');
                } else {
                  AppToast.error('Failed to cancel');
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BookingProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF5F7F6),
          body: RefreshIndicator(
            color: AppColors.forest,
            onRefresh: () => provider.fetchBookings(),
            child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  floating: true,
                  snap: true,
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  toolbarHeight: 70,
                  title: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bookings',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Manage tractor reservations',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.mutedInk,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    FilledButton.icon(
                      onPressed: _showCreateBookingSheet,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Book'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.forest,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(100),
                    child: Column(
                      children: [
                        // Tractor selector
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F7F6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int?>(
                                value: _selectedTractorId,
                                isExpanded: true,
                                icon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: AppColors.mutedInk),
                                hint: Row(
                                  children: [
                                    Icon(Icons.agriculture_rounded,
                                        size: 18,
                                        color: AppColors.mutedInk
                                            .withValues(alpha: 0.6)),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'All Tractors',
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: AppColors.mutedInk),
                                    ),
                                  ],
                                ),
                                items: [
                                  const DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text('All Tractors',
                                        style: TextStyle(fontSize: 14)),
                                  ),
                                  ...provider.tractors.map((t) {
                                    final id = t['id'] as int;
                                    final plate =
                                        t['no_plate']?.toString() ?? '';
                                    final brand =
                                        t['brand']?.toString() ?? '';
                                    return DropdownMenuItem<int?>(
                                      value: id,
                                      child: Text('$plate - $brand',
                                          style:
                                              const TextStyle(fontSize: 14)),
                                    );
                                  }),
                                ],
                                onChanged: (val) {
                                  setState(
                                      () => _selectedTractorId = val);
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Tabs
                        Container(
                          color: Colors.white,
                          child: TabBar(
                            controller: _tabController,
                            labelColor: AppColors.forest,
                            unselectedLabelColor: AppColors.mutedInk,
                            indicatorColor: AppColors.forest,
                            indicatorSize: TabBarIndicatorSize.label,
                            labelStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                            unselectedLabelStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            tabs: const [
                              Tab(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.calendar_month_rounded,
                                        size: 18),
                                    SizedBox(width: 6),
                                    Text('Calendar'),
                                  ],
                                ),
                              ),
                              Tab(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.list_alt_rounded, size: 18),
                                    SizedBox(width: 6),
                                    Text('Listing'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildCalendarTab(provider),
                _buildListingTab(provider),
              ],
            ),
          ),
          ),
        );
      },
    );
  }
}

class _RowEvent {
  const _RowEvent({
    required this.booking,
    required this.startCol,
    required this.endCol,
    required this.isStart,
    required this.isEnd,
  });
  final Booking booking;
  final int startCol;
  final int endCol;
  final bool isStart; // event actually starts in this row
  final bool isEnd; // event actually ends in this row
}

class _SpanningEventBar extends StatelessWidget {
  const _SpanningEventBar({
    required this.booking,
    required this.isStart,
    required this.isEnd,
  });

  final Booking booking;
  final bool isStart;
  final bool isEnd;

  static const _statusColors = {
    'approved': AppColors.success,
    'pending': AppColors.gold,
    'completed': AppColors.pine,
    'in_use': AppColors.moss,
    'cancelled': AppColors.danger,
    'rejected': AppColors.danger,
  };

  @override
  Widget build(BuildContext context) {
    final color = _statusColors[booking.status] ?? AppColors.mutedInk;
    final label = booking.purpose ?? booking.tractorLabel ?? 'Booking';
    final time = isStart ? booking.startTime : null;

    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.horizontal(
          left: isStart ? const Radius.circular(4) : Radius.zero,
          right: isEnd ? const Radius.circular(4) : Radius.zero,
        ),
        border: Border(
          left: isStart
              ? BorderSide(color: color, width: 3)
              : BorderSide.none,
        ),
      ),
      padding: EdgeInsets.only(
        left: isStart ? 4 : 6,
        right: isEnd ? 4 : 2,
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: color.withValues(alpha: 0.9),
              ),
            ),
          ),
          if (time != null) ...[
            const SizedBox(width: 2),
            Text(
              time,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w600,
                color: color.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _CompactBookingCard extends StatelessWidget {
  const _CompactBookingCard({
    required this.booking,
    required this.isFca,
    this.onCancel,
    this.onApprove,
    this.onReject,
    this.onEdit,
  });

  final Booking booking;
  final bool isFca;
  final VoidCallback? onCancel;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onEdit;

  static const _statusColors = {
    'approved': AppColors.success,
    'pending': AppColors.gold,
    'completed': AppColors.pine,
    'in_use': AppColors.moss,
    'cancelled': AppColors.danger,
    'rejected': AppColors.danger,
  };

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColors[booking.status] ?? AppColors.mutedInk;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: statusColor, width: 3),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: tractor + status badge
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.forest.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.agriculture_rounded,
                    color: AppColors.forest,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.tractorLabel ?? 'Tractor',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (booking.purpose != null)
                        Text(
                          booking.purpose!,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.mutedInk.withValues(alpha: 0.8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    booking.statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Info chips row — wrapping to prevent overflow
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _InfoChip(
                  icon: Icons.calendar_today_rounded,
                  text: booking.formattedDate,
                ),
                if (booking.startTime != null)
                  _InfoChip(
                    icon: Icons.schedule_rounded,
                    text:
                        '${booking.startTime}${booking.endTime != null ? ' - ${booking.endTime}' : ''}',
                  ),
                if (booking.farmAreaHectares != null)
                  _InfoChip(
                    icon: Icons.straighten_rounded,
                    text: '${booking.farmAreaHectares} ha',
                  ),
              ],
            ),

            // Farmer / booked-by info
            if (booking.farmerName != null || booking.bookedByName != null) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  if (booking.farmerName != null)
                    _InfoChip(
                      icon: Icons.person_rounded,
                      text: booking.farmerName!,
                      color: AppColors.forest,
                    ),
                  if (booking.bookedByName != null)
                    _InfoChip(
                      icon: Icons.person_outline_rounded,
                      text: 'by ${booking.bookedByName}',
                    ),
                ],
              ),
            ],

            // Action buttons
            if (onApprove != null || onReject != null || onCancel != null || onEdit != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  if (onApprove != null) ...[
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: FilledButton.icon(
                          onPressed: onApprove,
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: const Text('Approve',
                              style: TextStyle(fontSize: 12)),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (onReject != null) ...[
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: OutlinedButton.icon(
                          onPressed: onReject,
                          icon: const Icon(Icons.close_rounded, size: 16),
                          label: const Text('Reject',
                              style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: BorderSide(
                              color: AppColors.danger.withValues(alpha: 0.3),
                            ),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (onEdit != null) ...[
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: OutlinedButton.icon(
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_rounded, size: 14),
                          label: const Text('Edit',
                              style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.forest,
                            side: BorderSide(
                              color: AppColors.forest.withValues(alpha: 0.3),
                            ),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (onCancel != null)
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: OutlinedButton(
                          onPressed: onCancel,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.mutedInk,
                            side: BorderSide(
                              color: AppColors.mutedInk.withValues(alpha: 0.2),
                            ),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Cancel',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.text,
    this.color,
  });

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.mutedInk;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: c.withValues(alpha: 0.7)),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            text,
            style: TextStyle(fontSize: 11, color: c),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({required this.date, required this.onPick});

  final DateTime date;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onPick,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.mutedInk.withValues(alpha: 0.2),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded,
                size: 16, color: AppColors.mutedInk),
            const SizedBox(width: 8),
            Text(
              DateFormat('MMM dd, yyyy').format(date),
              style: const TextStyle(fontSize: 13, color: AppColors.ink),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimePickerField extends StatelessWidget {
  const _TimePickerField({required this.time, required this.onPick});

  final TimeOfDay time;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final label =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onPick,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.mutedInk.withValues(alpha: 0.2),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule_rounded,
                size: 16, color: AppColors.mutedInk),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.ink),
            ),
          ],
        ),
      ),
    );
  }
}

