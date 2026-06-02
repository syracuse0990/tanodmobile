import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/core/errors/app_exception.dart';
import 'package:tanodmobile/frontend/modules/tps/widgets/tps_user_picker_sheet.dart';
import 'package:tanodmobile/frontend/modules/tickets/models/ticket_issue_photo.dart';
import 'package:tanodmobile/frontend/modules/tickets/services/ticket_issue_photo_service.dart';
import 'package:tanodmobile/frontend/shared/providers/tps_provider.dart';
import 'package:tanodmobile/frontend/shared/widgets/app_toast.dart';
import 'package:tanodmobile/models/domain/fca_machine_hour_entry.dart';
import 'package:tanodmobile/models/domain/tps_user_option.dart';

class FcaMachineHoursSection extends StatefulWidget {
  const FcaMachineHoursSection({
    super.key,
    this.initialEntries = const [],
  });

  final List<Map<String, dynamic>> initialEntries;

  @override
  State<FcaMachineHoursSection> createState() => FcaMachineHoursSectionState();
}

class FcaMachineHoursSectionState extends State<FcaMachineHoursSection> {
  static const _gpsStatusOptions = ['Active', 'Inactive', 'No GPS'];

  final TicketIssuePhotoService _photoService = TicketIssuePhotoService();
  final List<_MachineHourRowState> _rows = [_MachineHourRowState()];
  final DateFormat _dateFormat = DateFormat('MM / dd / yyyy');

  List<TpsUserOption> _tpsUsers = const [];
  bool _loadingTpsUsers = true;

  bool get isPhotoProcessing => _rows.any((row) => row.isPhotoProcessing);

  @override
  void initState() {
    super.initState();
    _restoreRows(widget.initialEntries);
    _loadTpsUsers();
  }

  @override
  void didUpdateWidget(covariant FcaMachineHoursSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.initialEntries != widget.initialEntries) {
      restoreFromDraft(widget.initialEntries);
    }
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  String? validateBeforeSubmit() {
    for (var index = 0; index < _rows.length; index++) {
      final row = _rows[index];
      if (!row.hasAnyValue) {
        continue;
      }

      final missingFields = <String>[];
      if (row.dateVisited == null) {
        missingFields.add('Date visited');
      }
      if (row.machineHoursController.text.trim().isEmpty) {
        missingFields.add('Machine hours');
      }
      if (row.gpsStatus == null || row.gpsStatus!.trim().isEmpty) {
        missingFields.add('GPS status');
      }
      if (row.selectedInCharge == null) {
        missingFields.add('In Charge');
      }

      if (missingFields.isNotEmpty) {
        return 'Visit ${(index + 1).toString().padLeft(2, '0')} needs ${_joinMissingFields(missingFields)}.';
      }
    }

    return null;
  }

  List<FcaMachineHourEntry> buildSubmissionEntries() {
    final entries = <FcaMachineHourEntry>[];

    for (var index = 0; index < _rows.length; index++) {
      final row = _rows[index];
      if (!row.hasAnyValue) {
        continue;
      }

      final inCharge = row.selectedInCharge;
      final dateVisited = row.dateVisited;
      final machineHoursText = row.machineHoursController.text.trim();
      final gpsStatus = row.gpsStatus?.trim();
      final parsedMachineHours = int.tryParse(machineHoursText);

      if (inCharge == null ||
          dateVisited == null ||
          parsedMachineHours == null ||
          gpsStatus == null ||
          gpsStatus.isEmpty) {
        continue;
      }

      entries.add(
        FcaMachineHourEntry(
          entryOrder: index,
          dateVisited: dateVisited,
          machineHours: parsedMachineHours,
          gpsStatus: gpsStatus,
          inChargeUserId: inCharge.id,
          inChargeName: inCharge.name,
          inspectionPhotos: row.photos
              .map((photo) => photo.file)
              .toList(growable: false),
        ),
      );
    }

    return entries;
  }

  List<Map<String, dynamic>> buildDraftEntries() {
    final entries = <Map<String, dynamic>>[];

    for (var index = 0; index < _rows.length; index++) {
      final row = _rows[index];
      if (!row.hasAnyValue) {
        continue;
      }

      entries.add({
        'entry_order': index,
        'date_visited': row.dateVisited?.toIso8601String().split('T').first,
        'machine_hours': row.machineHoursController.text.trim(),
        'gps_status': row.gpsStatus,
        'in_charge_user_id': row.selectedInCharge?.id,
        'in_charge_name': row.inChargeController.text.trim(),
        'inspection_photos': row.photos
            .map(
              (photo) => {
                'path': photo.file.path,
                'latitude': photo.latitude,
                'longitude': photo.longitude,
                'verified_at': photo.verifiedAt.toIso8601String(),
                'address': photo.address,
              },
            )
            .toList(growable: false),
      });
    }

    return entries;
  }

  void restoreFromDraft(List<Map<String, dynamic>> entries) {
    setState(() => _restoreRows(entries));
  }

  String _joinMissingFields(List<String> missingFields) {
    if (missingFields.length == 1) {
      return missingFields.first;
    }

    if (missingFields.length == 2) {
      return '${missingFields.first} and ${missingFields.last}';
    }

    final leading = missingFields
        .sublist(0, missingFields.length - 1)
        .join(', ');
    return '$leading, and ${missingFields.last}';
  }

  Future<void> _loadTpsUsers() async {
    try {
      final tpsUsers = await context.read<TpsProvider>().fetchTpsUserOptions();

      if (!mounted) {
        return;
      }

      setState(() {
        _tpsUsers = tpsUsers;
        _loadingTpsUsers = false;
      });
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _loadingTpsUsers = false);
      AppToast.error(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() => _loadingTpsUsers = false);
      AppToast.error('Failed to load TPS suggestions.');
    }
  }

  Future<void> _pickDate(_MachineHourRowState row) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: row.dateVisited ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.forest,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.ink,
            ),
          ),
          child: child!,
        );
      },
    );

    if (!mounted || picked == null || !_rows.contains(row)) {
      return;
    }

    setState(
      () => row.dateVisited = DateTime(picked.year, picked.month, picked.day),
    );
  }

  Future<void> _pickPhotosFromGallery(_MachineHourRowState row) async {
    if (row.photos.length >= TicketIssuePhotoService.maxPhotos) {
      AppToast.error('Only up to 2 inspection photos are allowed.');
      return;
    }

    await _appendPhotos(
      row,
      loadingLabel: 'Applying secure watermark...',
      action: () => _photoService.pickFromGallery(
        remainingSlots: TicketIssuePhotoService.maxPhotos - row.photos.length,
      ),
    );
  }

  Future<void> _capturePhoto(_MachineHourRowState row) async {
    if (row.photos.length >= TicketIssuePhotoService.maxPhotos) {
      AppToast.error('Only up to 2 inspection photos are allowed.');
      return;
    }

    await _appendPhotos(
      row,
      loadingLabel: 'Stamping GPS verification...',
      action: () async {
        final capturedPhoto = await _photoService.captureWithCamera();
        return capturedPhoto == null ? const [] : [capturedPhoto];
      },
    );
  }

  Future<void> _appendPhotos(
    _MachineHourRowState row, {
    required String loadingLabel,
    required Future<List<TicketIssuePhoto>> Function() action,
  }) async {
    if (row.isPhotoProcessing) {
      return;
    }

    setState(() {
      row.isPhotoProcessing = true;
      row.photoProcessingLabel = loadingLabel;
    });

    try {
      final newPhotos = await action();
      if (newPhotos.isEmpty || !mounted || !_rows.contains(row)) {
        return;
      }

      setState(() {
        row.photos = [
          ...row.photos,
          ...newPhotos,
        ].take(TicketIssuePhotoService.maxPhotos).toList(growable: false);
      });
    } on TicketIssuePhotoException catch (error) {
      if (mounted) {
        AppToast.error(error.message);
      }
    } catch (error, stackTrace) {
      if (mounted) {
        debugPrint(
          'FcaMachineHoursSection._appendPhotos error: $error\n$stackTrace',
        );
        AppToast.error(_friendlyPhotoError(error));
      }
    } finally {
      if (mounted && _rows.contains(row)) {
        setState(() => row.isPhotoProcessing = false);
      }
    }
  }

  void _removePhotoAt(_MachineHourRowState row, int index) {
    setState(() {
      row.photos = [...row.photos]..removeAt(index);
    });
  }

  String _friendlyPhotoError(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '').trim();
    if (text.isNotEmpty && text != 'null') {
      return text;
    }

    return 'Unable to prepare the verified inspection photo right now.';
  }

  void _restoreRows(List<Map<String, dynamic>> entries) {
    for (final row in _rows) {
      row.dispose();
    }
    _rows.clear();

    if (entries.isEmpty) {
      _rows.add(_MachineHourRowState());
      return;
    }

    for (final entry in entries) {
      final row = _MachineHourRowState();
      row.dateVisited = DateTime.tryParse(
        entry['date_visited']?.toString() ?? '',
      );
      row.machineHoursController.text = entry['machine_hours']?.toString() ?? '';
      row.gpsStatus = entry['gps_status']?.toString();

      final inChargeName = entry['in_charge_name']?.toString().trim() ?? '';
      final inChargeId = int.tryParse(
        entry['in_charge_user_id']?.toString() ?? '',
      );

      if (inChargeName.isNotEmpty || inChargeId != null) {
        final restoredUser = TpsUserOption(
          id: inChargeId ?? 0,
          name: inChargeName.isEmpty ? 'Selected user' : inChargeName,
        );

        row.selectedInCharge = restoredUser;
        row.inChargeController.text = restoredUser.name;
      }

      row.photos = _restorePhotos(entry['inspection_photos']);
      _rows.add(row);
    }
  }

  List<TicketIssuePhoto> _restorePhotos(dynamic value) {
    if (value is! List) {
      return const [];
    }

    final photos = <TicketIssuePhoto>[];

    for (final item in value) {
      if (item is! Map) {
        continue;
      }

      final path = item['path']?.toString() ?? '';
      if (path.trim().isEmpty) {
        continue;
      }

      final file = File(path);
      if (!file.existsSync()) {
        continue;
      }

      final latitude = double.tryParse(item['latitude']?.toString() ?? '');
      final longitude = double.tryParse(item['longitude']?.toString() ?? '');
      final verifiedAt = DateTime.tryParse(
        item['verified_at']?.toString() ?? '',
      );

      if (latitude == null || longitude == null || verifiedAt == null) {
        continue;
      }

      photos.add(
        TicketIssuePhoto(
          file: file,
          latitude: latitude,
          longitude: longitude,
          verifiedAt: verifiedAt,
          address: item['address']?.toString(),
        ),
      );
    }

    return photos;
  }

  void _addRow() {
    setState(() => _rows.add(_MachineHourRowState()));
  }

  void _removeRow(int index) {
    if (_rows.length <= 1) {
      return;
    }

    final row = _rows.removeAt(index);
    row.dispose();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
      children: [
        for (var index = 0; index < _rows.length; index++) ...[
          _MachineHoursEntryCard(
            index: index,
            row: _rows[index],
            dateLabel: _rows[index].dateVisited == null
                ? null
                : _dateFormat.format(_rows[index].dateVisited!),
            gpsStatusOptions: _gpsStatusOptions,
            tpsUsers: _tpsUsers,
            loadingTpsUsers: _loadingTpsUsers,
            onPickDate: () => _pickDate(_rows[index]),
            onPickGallery: () => _pickPhotosFromGallery(_rows[index]),
            onCapturePhoto: () => _capturePhoto(_rows[index]),
            onRemovePhoto: (photoIndex) =>
                _removePhotoAt(_rows[index], photoIndex),
            onRemove: _rows.length > 1 ? () => _removeRow(index) : null,
            onStatusChanged: (value) {
              setState(() => _rows[index].gpsStatus = value);
            },
            onInChargeSelected: (user) {
              setState(() {
                _rows[index].selectedInCharge = user;
                _rows[index].inChargeController.text = user.name;
              });
            },
          ),
          if (index < _rows.length - 1) const SizedBox(height: 10),
        ],
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _addRow,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add another machine hour'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.forest,
              side: BorderSide(color: AppColors.forest.withValues(alpha: 0.24)),
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MachineHoursEntryCard extends StatelessWidget {
  const _MachineHoursEntryCard({
    required this.index,
    required this.row,
    required this.dateLabel,
    required this.gpsStatusOptions,
    required this.tpsUsers,
    required this.loadingTpsUsers,
    required this.onPickDate,
    required this.onPickGallery,
    required this.onCapturePhoto,
    required this.onRemovePhoto,
    required this.onStatusChanged,
    required this.onInChargeSelected,
    this.onRemove,
  });

  final int index;
  final _MachineHourRowState row;
  final String? dateLabel;
  final List<String> gpsStatusOptions;
  final List<TpsUserOption> tpsUsers;
  final bool loadingTpsUsers;
  final VoidCallback onPickDate;
  final VoidCallback onPickGallery;
  final VoidCallback onCapturePhoto;
  final ValueChanged<int> onRemovePhoto;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<TpsUserOption> onInChargeSelected;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final entryLabel = 'Visit ${(index + 1).toString().padLeft(2, '0')}';
    final photoCountLabel =
        '${row.photos.length}/${TicketIssuePhotoService.maxPhotos}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.forest.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  entryLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.forest,
                  ),
                ),
              ),
              const Spacer(),
              if (row.photos.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F7F4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$photoCountLabel photos',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forest,
                    ),
                  ),
                ),
              if (onRemove != null) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: onRemove,
                  borderRadius: BorderRadius.circular(10),
                  child: Ink(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _MachineHoursFieldPair(
            leading: _MachineHoursFieldGroup(
              label: 'DATE VISITED',
              child: _MachineHoursDateField(
                label: dateLabel,
                onTap: onPickDate,
              ),
            ),
            trailing: _MachineHoursFieldGroup(
              label: 'MACHINE HOURS',
              child: _MachineHoursTextField(
                controller: row.machineHoursController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                suffixText: 'hrs',
              ),
            ),
          ),
          const SizedBox(height: 10),
          _MachineHoursFieldPair(
            leading: _MachineHoursFieldGroup(
              label: 'GPS STATUS',
              child: _MachineHoursStatusField(
                value: row.gpsStatus,
                options: gpsStatusOptions,
                onChanged: onStatusChanged,
              ),
            ),
            trailing: _MachineHoursFieldGroup(
              label: 'IN CHARGE (who recorded)',
              child: _MachineHoursInChargeField(
                controller: row.inChargeController,
                selectedUser: row.selectedInCharge,
                options: tpsUsers,
                isLoading: loadingTpsUsers,
                onSelected: onInChargeSelected,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _MachineHoursPhotoPanel(
            photos: row.photos,
            isProcessing: row.isPhotoProcessing,
            processingLabel: row.photoProcessingLabel,
            onPickGallery: onPickGallery,
            onCapturePhoto: onCapturePhoto,
            onRemovePhoto: onRemovePhoto,
          ),
        ],
      ),
    );
  }
}

class _MachineHoursFieldGroup extends StatelessWidget {
  const _MachineHoursFieldGroup({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
            color: AppColors.mutedInk,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _MachineHoursFieldPair extends StatelessWidget {
  const _MachineHoursFieldPair({required this.leading, required this.trailing});

  final Widget leading;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 300) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: leading),
              const SizedBox(width: 10),
              Expanded(child: trailing),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [leading, const SizedBox(height: 10), trailing],
        );
      },
    );
  }
}

class _MachineHoursPhotoPanel extends StatelessWidget {
  const _MachineHoursPhotoPanel({
    required this.photos,
    required this.isProcessing,
    required this.processingLabel,
    required this.onPickGallery,
    required this.onCapturePhoto,
    required this.onRemovePhoto,
  });

  final List<TicketIssuePhoto> photos;
  final bool isProcessing;
  final String processingLabel;
  final VoidCallback onPickGallery;
  final VoidCallback onCapturePhoto;
  final ValueChanged<int> onRemovePhoto;

  bool get _atMax => photos.length >= TicketIssuePhotoService.maxPhotos;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAF8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.ink.withValues(alpha: 0.05)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.forest.withValues(alpha: 0.12),
                      ),
                    ),
                    child: const Icon(
                      Icons.photo_camera_outlined,
                      color: AppColors.forest,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Inspection photo',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Optional. Watermarked and limited to 2 verified photos.',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.35,
                            color: AppColors.ink.withValues(alpha: 0.66),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.forest.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Text(
                      '${photos.length}/${TicketIssuePhotoService.maxPhotos}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.forest,
                      ),
                    ),
                  ),
                ],
              ),
              if (photos.isNotEmpty) ...[
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final photoWidth = photos.length == 1
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 10) / 2;

                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (var index = 0; index < photos.length; index++)
                          _MachineHoursPhotoThumbnail(
                            width: photoWidth,
                            photo: photos[index],
                            index: index,
                            total: photos.length,
                            onRemove: () => onRemovePhoto(index),
                          ),
                      ],
                    );
                  },
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isProcessing || _atMax ? null : onPickGallery,
                      icon: const Icon(Icons.upload_rounded, size: 18),
                      label: const Text('Upload'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.forest,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                          color: AppColors.forest.withValues(alpha: 0.24),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isProcessing || _atMax ? null : onCapturePhoto,
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: const Text('Capture'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.forest,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (isProcessing)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF102119),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF8DD6A5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          processingLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MachineHoursPhotoThumbnail extends StatelessWidget {
  const _MachineHoursPhotoThumbnail({
    required this.width,
    required this.photo,
    required this.index,
    required this.total,
    required this.onRemove,
  });

  final double width;
  final TicketIssuePhoto photo;
  final int index;
  final int total;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: 1.05,
              child: Image.file(photo.file, fit: BoxFit.cover),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: InkWell(
                onTap: onRemove,
                borderRadius: BorderRadius.circular(999),
                child: Ink(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.52),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.56),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Verified by TanodTractor',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Photo ${index + 1} of $total',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF8DD6A5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MachineHoursDateField extends StatelessWidget {
  const _MachineHoursDateField({required this.label, required this.onTap});

  final String? label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasValue = label != null && label!.trim().isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.ink.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                hasValue ? label! : 'Select date',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: hasValue ? AppColors.ink : AppColors.mutedInk,
                ),
              ),
            ),
            const Icon(
              Icons.calendar_today_rounded,
              size: 18,
              color: AppColors.mutedInk,
            ),
          ],
        ),
      ),
    );
  }
}

class _MachineHoursTextField extends StatelessWidget {
  const _MachineHoursTextField({
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.suffixText,
  });

  final TextEditingController controller;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? suffixText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        suffixText: suffixText,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.ink.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.forest, width: 1.2),
        ),
      ),
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.ink,
      ),
    );
  }
}

class _MachineHoursInChargeField extends StatelessWidget {
  const _MachineHoursInChargeField({
    required this.controller,
    required this.selectedUser,
    required this.options,
    required this.isLoading,
    required this.onSelected,
  });

  final TextEditingController controller;
  final TpsUserOption? selectedUser;
  final List<TpsUserOption> options;
  final bool isLoading;
  final ValueChanged<TpsUserOption> onSelected;

  @override
  Widget build(BuildContext context) {
    final selectedLabel = controller.text.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading
            ? null
            : () async {
                if (options.isEmpty) {
                  AppToast.error('No TPS users available.');
                  return;
                }

                final selected = await showTpsUserPickerSheet(
                  context,
                  options: options,
                  selectedUser: selectedUser,
                );

                if (selected != null) {
                  onSelected(selected);
                }
              },
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.ink.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selectedLabel.isEmpty ? 'Select In Charge' : selectedLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selectedLabel.isEmpty
                        ? FontWeight.w500
                        : FontWeight.w700,
                    color: selectedLabel.isEmpty
                        ? AppColors.mutedInk.withValues(alpha: 0.7)
                        : AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: AppColors.mutedInk,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MachineHoursStatusField extends StatelessWidget {
  const _MachineHoursStatusField({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.08)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: const Text(
            'Select',
            style: TextStyle(fontSize: 13, color: AppColors.mutedInk),
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.mutedInk,
          ),
          borderRadius: BorderRadius.circular(12),
          style: const TextStyle(fontSize: 13, color: AppColors.ink),
          items: options
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                ),
              )
              .toList(growable: false),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _MachineHourRowState {
  _MachineHourRowState()
    : machineHoursController = TextEditingController(),
      inChargeController = TextEditingController();

  DateTime? dateVisited;
  final TextEditingController machineHoursController;
  final TextEditingController inChargeController;
  String? gpsStatus;
  TpsUserOption? selectedInCharge;
  List<TicketIssuePhoto> photos = const [];
  bool isPhotoProcessing = false;
  String photoProcessingLabel = 'Applying secure watermark...';

  bool get hasAnyValue {
    return dateVisited != null ||
        machineHoursController.text.trim().isNotEmpty ||
        gpsStatus != null ||
        inChargeController.text.trim().isNotEmpty ||
        photos.isNotEmpty;
  }

  void dispose() {
    machineHoursController.dispose();
    inChargeController.dispose();
  }
}
