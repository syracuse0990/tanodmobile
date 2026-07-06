import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/frontend/modules/tickets/models/ticket_issue_photo.dart';
import 'package:tanodmobile/frontend/modules/tickets/services/ticket_issue_photo_service.dart';
import 'package:tanodmobile/frontend/modules/tickets/widgets/ticket_issue_photo_picker.dart';
import 'package:tanodmobile/frontend/shared/providers/pms_provider.dart';
import 'package:tanodmobile/frontend/shared/widgets/app_toast.dart';
import 'package:tanodmobile/frontend/shared/widgets/primary_button.dart';
import 'package:tanodmobile/models/domain/maintenance_tractor.dart';
import 'package:tanodmobile/models/domain/pms_record.dart';

class PmsRecordScreen extends StatefulWidget {
  const PmsRecordScreen({super.key, required this.tractor});

  final MaintenanceTractor tractor;

  @override
  State<PmsRecordScreen> createState() => _PmsRecordScreenState();
}

class _PmsRecordScreenState extends State<PmsRecordScreen> {
  final _descriptionController = TextEditingController();
  List<PmsChecklistItem> _checklist = [];
  bool _loaded = false;

  final _photoService = TicketIssuePhotoService();
  bool _submitting = false;

  // Nameplate
  List<TicketIssuePhoto> _nameplatePhotos = const [];
  bool _nameplateProcessing = false;
  String _nameplateProcessingLabel = 'Applying secure watermark...';
  String? _nameplateError;

  // Dashboard
  List<TicketIssuePhoto> _dashboardPhotos = const [];
  bool _dashboardProcessing = false;
  String _dashboardProcessingLabel = 'Applying secure watermark...';
  String? _dashboardError;

  // Damaged Parts
  List<TicketIssuePhoto> _damagePhotos = const [];
  bool _damageProcessing = false;
  String _damageProcessingLabel = 'Applying secure watermark...';
  String? _damageError;

  @override
  void initState() {
    super.initState();
    _loadChecklist();
  }

  Future<void> _loadChecklist() async {
    final provider = context.read<PmsProvider>();
    await provider.fetchChecklist();
    if (mounted) {
      setState(() {
        _checklist = provider.defaultChecklist
            .map((item) => PmsChecklistItem(name: item.name))
            .toList();
        _loaded = true;
      });
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _toggleItem(int index) {
    setState(() {
      _checklist[index] = _checklist[index].copyWith(
        done: !_checklist[index].done,
      );
    });
  }

  void _editNotes(int index) async {
    final controller = TextEditingController(
      text: _checklist[index].notes ?? '',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.forest.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.sticky_note_2_rounded,
                        color: AppColors.forest, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _checklist[index].name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Icon(Icons.close_rounded,
                        color: AppColors.mutedInk.withValues(alpha: 0.5),
                        size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Add notes for this item...',
                  hintStyle: TextStyle(
                    color: AppColors.mutedInk.withValues(alpha: 0.5),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF5F7F6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.forest),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.mutedInk,
                          side: BorderSide(
                            color: AppColors.mutedInk.withValues(alpha: 0.2),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 53,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, controller.text),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.forest,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Save',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    // Defer disposal — dialog widgets may still be alive during exit animation
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (result != null && mounted) {
      setState(() {
        _checklist[index] = _checklist[index].copyWith(
          notes: result.isEmpty ? null : result,
        );
      });
    }
  }

  // ── Photo helpers (modeled after CreateTicketScreen) ──

  Future<void> _appendPhotosForSection({
    required List<TicketIssuePhoto> currentPhotos,
    required int maxPhotos,
    required void Function(List<TicketIssuePhoto>) onUpdate,
    required void Function(bool) setProcessing,
    required void Function(String) setProcessingLabel,
    required void Function(String?) setError,
    required String loadingLabel,
    required Future<List<TicketIssuePhoto>> Function() action,
  }) async {
    setProcessing(true);
    setProcessingLabel(loadingLabel);

    try {
      final newPhotos = await action();
      if (newPhotos.isEmpty) {
        return;
      }

      final merged = [
        ...currentPhotos,
        ...newPhotos,
      ].take(maxPhotos).toList(growable: false);

      if (!mounted) {
        return;
      }

      onUpdate(merged);
      setError(null);
    } on TicketIssuePhotoException catch (error) {
      if (!mounted) {
        return;
      }

      AppToast.show(error.message, type: ToastType.error);
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }

      debugPrint(
        'PmsRecordScreen._appendPhotosForSection error: $error\n$stackTrace',
      );

      AppToast.show(_friendlyPhotoError(error), type: ToastType.error);
    } finally {
      if (mounted) {
        setProcessing(false);
      }
    }
  }

  String _friendlyPhotoError(Object error) {
    if (error is MissingPluginException) {
      return 'Restart the app once so the photo verification tools can finish loading.';
    }

    if (error is PlatformException) {
      final message = error.message?.trim();
      if (message != null && message.isNotEmpty) {
        return message;
      }
    }

    final text = error.toString().replaceFirst('Exception: ', '').trim();
    if (text.isNotEmpty && text != 'null') {
      return text;
    }

    return 'Unable to prepare the verified issue photo.';
  }

  // ── Nameplate ──

  Future<void> _pickNameplateFromGallery() async {
    if (_nameplatePhotos.length >= 1) {
      AppToast.show('Only 1 nameplate photo is allowed.',
          type: ToastType.error);
      return;
    }
    await _appendPhotosForSection(
      currentPhotos: _nameplatePhotos,
      maxPhotos: 1,
      onUpdate: (v) => setState(() => _nameplatePhotos = v),
      setProcessing: (v) => setState(() => _nameplateProcessing = v),
      setProcessingLabel: (v) =>
          setState(() => _nameplateProcessingLabel = v),
      setError: (v) => setState(() => _nameplateError = v),
      loadingLabel: 'Applying secure watermark...',
      action: () => _photoService.pickFromGallery(
        remainingSlots: 1 - _nameplatePhotos.length,
      ),
    );
  }

  Future<void> _captureNameplate() async {
    if (_nameplatePhotos.length >= 1) {
      AppToast.show('Only 1 nameplate photo is allowed.',
          type: ToastType.error);
      return;
    }
    await _appendPhotosForSection(
      currentPhotos: _nameplatePhotos,
      maxPhotos: 1,
      onUpdate: (v) => setState(() => _nameplatePhotos = v),
      setProcessing: (v) => setState(() => _nameplateProcessing = v),
      setProcessingLabel: (v) =>
          setState(() => _nameplateProcessingLabel = v),
      setError: (v) => setState(() => _nameplateError = v),
      loadingLabel: 'Stamping GPS verification...',
      action: () async {
        final p = await _photoService.captureWithCamera();
        return p == null ? const [] : [p];
      },
    );
  }

  void _removeNameplate() {
    setState(() {
      _nameplatePhotos = const [];
      _nameplateError = null;
    });
  }

  // ── Dashboard ──

  Future<void> _pickDashboardFromGallery() async {
    if (_dashboardPhotos.length >= 1) {
      AppToast.show('Only 1 dashboard photo is allowed.',
          type: ToastType.error);
      return;
    }
    await _appendPhotosForSection(
      currentPhotos: _dashboardPhotos,
      maxPhotos: 1,
      onUpdate: (v) => setState(() => _dashboardPhotos = v),
      setProcessing: (v) => setState(() => _dashboardProcessing = v),
      setProcessingLabel: (v) =>
          setState(() => _dashboardProcessingLabel = v),
      setError: (v) => setState(() => _dashboardError = v),
      loadingLabel: 'Applying secure watermark...',
      action: () => _photoService.pickFromGallery(
        remainingSlots: 1 - _dashboardPhotos.length,
      ),
    );
  }

  Future<void> _captureDashboard() async {
    if (_dashboardPhotos.length >= 1) {
      AppToast.show('Only 1 dashboard photo is allowed.',
          type: ToastType.error);
      return;
    }
    await _appendPhotosForSection(
      currentPhotos: _dashboardPhotos,
      maxPhotos: 1,
      onUpdate: (v) => setState(() => _dashboardPhotos = v),
      setProcessing: (v) => setState(() => _dashboardProcessing = v),
      setProcessingLabel: (v) =>
          setState(() => _dashboardProcessingLabel = v),
      setError: (v) => setState(() => _dashboardError = v),
      loadingLabel: 'Stamping GPS verification...',
      action: () async {
        final p = await _photoService.captureWithCamera();
        return p == null ? const [] : [p];
      },
    );
  }

  void _removeDashboard() {
    setState(() {
      _dashboardPhotos = const [];
      _dashboardError = null;
    });
  }

  // ── Damaged Parts ──

  Future<void> _pickDamageFromGallery() async {
    if (_damagePhotos.length >= 10) {
      AppToast.show('Only up to 10 damage photos are allowed.',
          type: ToastType.error);
      return;
    }
    await _appendPhotosForSection(
      currentPhotos: _damagePhotos,
      maxPhotos: 10,
      onUpdate: (v) => setState(() => _damagePhotos = v),
      setProcessing: (v) => setState(() => _damageProcessing = v),
      setProcessingLabel: (v) =>
          setState(() => _damageProcessingLabel = v),
      setError: (v) => setState(() => _damageError = v),
      loadingLabel: 'Applying secure watermark...',
      action: () => _photoService.pickFromGallery(
        remainingSlots: 10 - _damagePhotos.length,
      ),
    );
  }

  Future<void> _captureDamage() async {
    if (_damagePhotos.length >= 10) {
      AppToast.show('Only up to 10 damage photos are allowed.',
          type: ToastType.error);
      return;
    }
    await _appendPhotosForSection(
      currentPhotos: _damagePhotos,
      maxPhotos: 10,
      onUpdate: (v) => setState(() => _damagePhotos = v),
      setProcessing: (v) => setState(() => _damageProcessing = v),
      setProcessingLabel: (v) =>
          setState(() => _damageProcessingLabel = v),
      setError: (v) => setState(() => _damageError = v),
      loadingLabel: 'Stamping GPS verification...',
      action: () async {
        final p = await _photoService.captureWithCamera();
        return p == null ? const [] : [p];
      },
    );
  }

  void _removeDamageAt(int index) {
    setState(() {
      final nextPhotos = [..._damagePhotos]..removeAt(index);
      _damagePhotos = nextPhotos;
      _damageError = null;
    });
  }

  // ── Submit ──

  Future<void> _submit() async {
    if (_nameplateProcessing ||
        _dashboardProcessing ||
        _damageProcessing) {
      AppToast.show(
        'Please wait for photo processing to finish.',
        type: ToastType.error,
      );
      return;
    }

    if (_nameplatePhotos.isEmpty) {
      setState(() => _nameplateError = 'Nameplate photo is required.');
      return;
    }
    if (_dashboardPhotos.isEmpty) {
      setState(() => _dashboardError = 'Dashboard photo is required.');
      return;
    }
    if (_damagePhotos.isEmpty) {
      setState(
          () => _damageError = 'At least 1 damage photo is required.');
      return;
    }

    final doneCount = _checklist.where((c) => c.done).length;
    if (doneCount == 0) {
      AppToast.show('Please check at least one item',
          type: ToastType.error);
      return;
    }

    setState(() {
      _submitting = true;
      _nameplateError = null;
      _dashboardError = null;
      _damageError = null;
    });

    final success = await context.read<PmsProvider>().recordPms(
          tractorId: widget.tractor.id,
          checklist: _checklist,
          hoursAtMaintenance: widget.tractor.totalRunningHours,
          kmAtMaintenance: widget.tractor.totalDistance,
          description: _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          nameplatePhoto: _nameplatePhotos.first.file,
          dashboardPhoto: _dashboardPhotos.first.file,
          damagePhotos: _damagePhotos.map((p) => p.file).toList(),
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (success) {
      AppToast.show('PMS recorded successfully');
      context.pop();
    } else {
      AppToast.show('Failed to record PMS', type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PmsProvider>();
    final tractor = widget.tractor;
    final doneCount = _checklist.where((c) => c.done).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      appBar: AppBar(
        title: const Text('Record PMS'),
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: !_loaded
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.forest),
            )
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ─── Tractor info card ───
                        _TractorInfoCard(tractor: tractor),

                        const SizedBox(height: 20),

                        // ─── Checklist header ───
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'PMS Checklist',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                            Text(
                              '$doneCount / ${_checklist.length}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: doneCount == _checklist.length
                                    ? AppColors.forest
                                    : AppColors.mutedInk,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // ─── Checklist items ───
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: List.generate(
                              _checklist.length,
                              (i) => _ChecklistRow(
                                item: _checklist[i],
                                isLast: i == _checklist.length - 1,
                                onToggle: () => _toggleItem(i),
                                onEditNotes: () => _editNotes(i),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ─── Description ───
                        const Text(
                          'Notes (optional)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _descriptionController,
                          decoration: InputDecoration(
                            hintText: 'Additional notes about this PMS...',
                            hintStyle: TextStyle(
                              color: AppColors.mutedInk.withValues(alpha: 0.5),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color:
                                    AppColors.mutedInk.withValues(alpha: 0.15),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color:
                                    AppColors.mutedInk.withValues(alpha: 0.15),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.forest,
                              ),
                            ),
                            contentPadding: const EdgeInsets.all(14),
                          ),
                          maxLines: 3,
                          textCapitalization: TextCapitalization.sentences,
                        ),

                        const SizedBox(height: 20),

                        // ─── Nameplate Photo ───
                        TicketIssuePhotoPicker(
                          label: 'Photo of Nameplate',
                          subtitle: 'Required. Exactly 1 photo.',
                          maxPhotos: 1,
                          photos: _nameplatePhotos,
                          isProcessing: _nameplateProcessing,
                          processingLabel: _nameplateProcessingLabel,
                          errorText: _nameplateError,
                          onPickGallery: _pickNameplateFromGallery,
                          onCapture: _captureNameplate,
                          onRemove: (_) => _removeNameplate(),
                        ),

                        const SizedBox(height: 18),

                        // ─── Dashboard Photo ───
                        TicketIssuePhotoPicker(
                          label: 'Dashboard showing MACHINE HOURS',
                          subtitle: 'Required. Exactly 1 photo.',
                          maxPhotos: 1,
                          photos: _dashboardPhotos,
                          isProcessing: _dashboardProcessing,
                          processingLabel: _dashboardProcessingLabel,
                          errorText: _dashboardError,
                          onPickGallery: _pickDashboardFromGallery,
                          onCapture: _captureDashboard,
                          onRemove: (_) => _removeDashboard(),
                        ),

                        const SizedBox(height: 18),

                        // ─── Damaged Parts ───
                        TicketIssuePhotoPicker(
                          label: 'Damaged Parts',
                          subtitle: 'Required. 1 to 3 photos.',
                          maxPhotos: 3,
                          photos: _damagePhotos,
                          isProcessing: _damageProcessing,
                          processingLabel: _damageProcessingLabel,
                          errorText: _damageError,
                          onPickGallery: _pickDamageFromGallery,
                          onCapture: _captureDamage,
                          onRemove: _removeDamageAt,
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                // ─── Submit button ───
                StickyBottomButton(
                  label: 'Record PMS ($doneCount/${_checklist.length} checked)',
                  onPressed: _submitting ? null : _submit,
                  isLoading: _submitting || provider.submitting,
                ),
              ],
            ),
    );
  }
}

// ─── Tractor info card ──────────────────────────

class _TractorInfoCard extends StatelessWidget {
  const _TractorInfoCard({required this.tractor});

  final MaintenanceTractor tractor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
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
                  tractor.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${tractor.totalRunningHours.toStringAsFixed(1)}h  •  ${tractor.totalDistance.toStringAsFixed(1)} km',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedInk,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Checklist row ──────────────────────────────

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.item,
    required this.isLast,
    required this.onToggle,
    required this.onEditNotes,
  });

  final PmsChecklistItem item;
  final bool isLast;
  final VoidCallback onToggle;
  final VoidCallback onEditNotes;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Checkbox
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: item.done
                        ? AppColors.forest
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: item.done
                          ? AppColors.forest
                          : AppColors.mutedInk.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: item.done
                      ? const Icon(Icons.check_rounded,
                          size: 16, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),

                // Label + notes
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: item.done
                              ? AppColors.forest
                              : AppColors.ink,
                          decoration: item.done
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (item.notes != null && item.notes!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            item.notes!,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.mutedInk,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),

                // Notes button
                IconButton(
                  onPressed: onEditNotes,
                  icon: Icon(
                    item.notes != null && item.notes!.isNotEmpty
                        ? Icons.sticky_note_2_rounded
                        : Icons.sticky_note_2_outlined,
                    size: 20,
                    color: item.notes != null && item.notes!.isNotEmpty
                        ? AppColors.forest
                        : AppColors.mutedInk.withValues(alpha: 0.4),
                  ),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Add notes',
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 50,
            color: AppColors.mutedInk.withValues(alpha: 0.1),
          ),
      ],
    );
  }
}
