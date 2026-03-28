import 'package:flutter/material.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static final List<_BookingItem> _bookings = [
    _BookingItem(
      id: 1,
      tractorLabel: 'TRC-001',
      location: 'Nueva Ecija',
      date: 'Mar 30, 2026',
      time: '8:00 AM – 12:00 PM',
      purpose: 'Land preparation for rice planting',
      status: 'approved',
      farmArea: '2.5 ha',
    ),
    _BookingItem(
      id: 2,
      tractorLabel: 'TRC-004',
      location: 'Benguet',
      date: 'Mar 31, 2026',
      time: '1:00 PM – 5:00 PM',
      purpose: 'Post-harvest plowing',
      status: 'pending',
      farmArea: '1.8 ha',
    ),
    _BookingItem(
      id: 3,
      tractorLabel: 'TRC-007',
      location: 'Albay',
      date: 'Apr 2, 2026',
      time: '6:00 AM – 11:00 AM',
      purpose: 'Harrowing for corn field',
      status: 'pending',
      farmArea: '3.0 ha',
    ),
    _BookingItem(
      id: 4,
      tractorLabel: 'TRC-002',
      location: 'Tarlac',
      date: 'Mar 25, 2026',
      time: '7:00 AM – 11:00 AM',
      purpose: 'Soil preparation',
      status: 'completed',
      farmArea: '2.0 ha',
    ),
    _BookingItem(
      id: 5,
      tractorLabel: 'TRC-010',
      location: 'Laguna',
      date: 'Mar 20, 2026',
      time: '8:00 AM – 3:00 PM',
      purpose: 'Full field plowing',
      status: 'completed',
      farmArea: '4.0 ha',
    ),
    _BookingItem(
      id: 6,
      tractorLabel: 'TRC-005',
      location: 'Davao',
      date: 'Mar 22, 2026',
      time: '6:00 AM – 10:00 AM',
      purpose: 'Banana grove preparation',
      status: 'cancelled',
      farmArea: '1.5 ha',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<_BookingItem> _filterByTab(int index) {
    switch (index) {
      case 0:
        return _bookings
            .where((b) => b.status == 'pending' || b.status == 'approved')
            .toList();
      case 1:
        return _bookings.where((b) => b.status == 'completed').toList();
      case 2:
        return _bookings.where((b) => b.status == 'cancelled').toList();
      default:
        return _bookings;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      body: NestedScrollView(
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
                  onPressed: () {},
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
                preferredSize: const Size.fromHeight(48),
                child: Container(
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
                      Tab(text: 'Upcoming'),
                      Tab(text: 'Completed'),
                      Tab(text: 'Cancelled'),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            for (int tab = 0; tab < 3; tab++)
              Builder(
                builder: (context) {
                  final items = _filterByTab(tab);
                  if (items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.event_busy_rounded,
                            size: 56,
                            color: AppColors.mutedInk,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No bookings here',
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

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return _BookingCard(booking: items[index]);
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking});

  final _BookingItem booking;

  Color get _statusColor {
    switch (booking.status) {
      case 'approved':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'completed':
        return AppColors.pine;
      case 'cancelled':
        return AppColors.danger;
      default:
        return AppColors.mutedInk;
    }
  }

  String get _statusLabel {
    switch (booking.status) {
      case 'approved':
        return 'Approved';
      case 'pending':
        return 'Pending';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return booking.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.forest.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.agriculture_rounded,
                  color: AppColors.forest,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.tractorLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      booking.location,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.mutedInk,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _statusLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAF9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.purpose,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _DetailTag(
                      icon: Icons.calendar_today_rounded,
                      text: booking.date,
                    ),
                    const SizedBox(width: 12),
                    _DetailTag(
                      icon: Icons.schedule_rounded,
                      text: booking.time,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _DetailTag(
                  icon: Icons.straighten_rounded,
                  text: 'Farm: ${booking.farmArea}',
                ),
              ],
            ),
          ),
          if (booking.status == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: BorderSide(
                        color: AppColors.danger.withValues(alpha: 0.3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailTag extends StatelessWidget {
  const _DetailTag({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.mutedInk),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: AppColors.mutedInk),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _BookingItem {
  const _BookingItem({
    required this.id,
    required this.tractorLabel,
    required this.location,
    required this.date,
    required this.time,
    required this.purpose,
    required this.status,
    required this.farmArea,
  });

  final int id;
  final String tractorLabel;
  final String location;
  final String date;
  final String time;
  final String purpose;
  final String status;
  final String farmArea;
}
