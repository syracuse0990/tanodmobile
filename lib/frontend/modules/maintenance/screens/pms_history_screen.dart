import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/frontend/shared/providers/auth_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/pms_provider.dart';
import 'package:tanodmobile/frontend/shared/widgets/app_toast.dart';
import 'package:tanodmobile/frontend/shared/widgets/primary_button.dart';
import 'package:tanodmobile/models/domain/maintenance_tractor.dart';
import 'package:tanodmobile/models/domain/pms_record.dart';

class PmsHistoryScreen extends StatefulWidget {
  const PmsHistoryScreen({super.key, required this.tractor});

  final MaintenanceTractor tractor;

  @override
  State<PmsHistoryScreen> createState() => _PmsHistoryScreenState();
}

class _PmsHistoryScreenState extends State<PmsHistoryScreen> {
  @override
  void initState() {
    super.initState();
    context.read<PmsProvider>().fetchRecordsForTractor(widget.tractor.id);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PmsProvider>();
    final isTps =
        context.read<AuthProvider>().session?.roles.contains('tps') ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      appBar: AppBar(
        title: Text(widget.tractor.label),
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: provider.loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.forest),
            )
          : provider.error != null && provider.records.isEmpty
              ? _ErrorBody(
                  error: provider.error!,
                  onRetry: () => provider.fetchRecordsForTractor(
                    widget.tractor.id,
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.forest,
                  onRefresh: () =>
                      provider.fetchRecordsForTractor(widget.tractor.id),
                  child: provider.records.isEmpty
                      ? _EmptyBody()
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: provider.records.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, i) => _RecordCard(
                            record: provider.records[i],
                            isTps: isTps,
                            tractor: widget.tractor,
                          ),
                        ),
                ),
    );
  }
}

// ─── Record card ────────────────────────────────

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.record,
    required this.isTps,
    required this.tractor,
  });

  final PmsRecord record;
  final bool isTps;
  final MaintenanceTractor tractor;

  @override
  Widget build(BuildContext context) {
    final doneCount = record.checklist.where((c) => c.done).length;
    final statusInfo = _statusInfo(record.status);

    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header ───
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              children: [
                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusInfo.$1,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusInfo.$3,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusInfo.$2,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Spacer(),
                if (record.createdAt != null)
                  Text(
                    _formatDate(record.createdAt!),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.mutedInk,
                    ),
                  ),
              ],
            ),
          ),

          // ─── Checklist summary ───
          if (record.checklist.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Row(
                children: [
                  Icon(Icons.checklist_rounded,
                      size: 16, color: AppColors.mutedInk),
                  const SizedBox(width: 6),
                  Text(
                    '$doneCount / ${record.checklist.length} items checked',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),

          // ─── Creator/Requester info ───
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (record.creator != null)
                  _InfoRow(
                    icon: Icons.person_outline_rounded,
                    text: 'Recorded by ${record.creator!.name ?? 'Unknown'}',
                  ),
                if (record.requester != null)
                  _InfoRow(
                    icon: Icons.support_agent_rounded,
                    text: 'Requested by ${record.requester!.name ?? 'Unknown'}',
                  ),
                if (record.performer != null)
                  _InfoRow(
                    icon: Icons.engineering_rounded,
                    text: 'Performed by ${record.performer!.name ?? 'Unknown'}',
                  ),
              ],
            ),
          ),

          // ─── Request notes ───
          if (record.requestNotes != null &&
              record.requestNotes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Text(
                record.requestNotes!,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.mutedInk,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // ─── TPS complete button ───
          if (isTps && record.isScheduled) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showCompletePms(context),
                  icon: const Icon(Icons.check_circle_outline_rounded,
                      size: 18),
                  label: const Text('Complete PMS'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.forest,
                    side: const BorderSide(color: AppColors.forest),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),
        ],
      ),
    );
  }

  void _showCompletePms(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CompletePmsSheet(
        record: record,
        tractor: tractor,
      ),
    );
  }

  (Color, Color, String) _statusInfo(String status) {
    return switch (status) {
      'completed' => (
        const Color(0xFFE8F5E9),
        AppColors.forest,
        'COMPLETED',
      ),
      'scheduled' => (
        const Color(0xFFFFF3E0),
        const Color(0xFFE65100),
        'PENDING',
      ),
      'in_progress' => (
        const Color(0xFFE3F2FD),
        const Color(0xFF1565C0),
        'IN PROGRESS',
      ),
      'cancelled' => (
        const Color(0xFFFFEBEE),
        AppColors.danger,
        'CANCELLED',
      ),
      _ => (
        const Color(0xFFF5F5F5),
        AppColors.mutedInk,
        status.toUpperCase(),
      ),
    };
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (_) {
      return dateStr;
    }
  }
}

// ─── Info row ───────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.mutedInk.withValues(alpha: 0.6)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: AppColors.mutedInk),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Complete PMS bottom sheet ──────────────────

class _CompletePmsSheet extends StatefulWidget {
  const _CompletePmsSheet({
    required this.record,
    required this.tractor,
  });

  final PmsRecord record;
  final MaintenanceTractor tractor;

  @override
  State<_CompletePmsSheet> createState() => _CompletePmsSheetState();
}

class _CompletePmsSheetState extends State<_CompletePmsSheet> {
  late List<PmsChecklistItem> _checklist;
  final _conclusionController = TextEditingController();
  final List<File> _photos = [];

  @override
  void initState() {
    super.initState();
    // Pre-fill from checklist items fetched from API (default all unchecked)
    final provider = context.read<PmsProvider>();
    if (widget.record.checklist.isNotEmpty) {
      _checklist = widget.record.checklist
          .map((c) => PmsChecklistItem(name: c.name))
          .toList();
    } else {
      _checklist = provider.defaultChecklist
          .map((c) => PmsChecklistItem(name: c.name))
          .toList();
    }
  }

  @override
  void dispose() {
    _conclusionController.dispose();
    super.dispose();
  }

  void _toggleItem(int index) {
    setState(() {
      _checklist[index] =
          _checklist[index].copyWith(done: !_checklist[index].done);
    });
  }

  Future<void> _addPhoto() async {
    if (_photos.length >= 10) {
      AppToast.show('Maximum 10 photos', type: ToastType.error);
      return;
    }
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 80,
    );
    if (picked != null && mounted) {
      setState(() => _photos.add(File(picked.path)));
    }
  }

  Future<void> _submit() async {
    final doneCount = _checklist.where((c) => c.done).length;
    if (doneCount == 0) {
      AppToast.show('Please check at least one item', type: ToastType.error);
      return;
    }

    final success = await context.read<PmsProvider>().completePms(
          maintenanceId: widget.record.id,
          checklist: _checklist,
          conclusion: _conclusionController.text.trim().isNotEmpty
              ? _conclusionController.text.trim()
              : null,
          images: _photos,
        );

    if (!mounted) return;

    if (success) {
      AppToast.show('PMS completed');
      Navigator.pop(context);
      // Refresh list
      context
          .read<PmsProvider>()
          .fetchRecordsForTractor(widget.tractor.id);
    } else {
      AppToast.show('Failed to complete PMS', type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PmsProvider>();
    final doneCount = _checklist.where((c) => c.done).length;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ─── Handle ───
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.mutedInk.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ─── Title ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Complete PMS',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  '$doneCount / ${_checklist.length}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedInk,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ─── Scrollable content ───
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Checklist
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: List.generate(
                        _checklist.length,
                        (i) => InkWell(
                          onTap: () => _toggleItem(i),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _checklist[i].done
                                      ? Icons.check_box_rounded
                                      : Icons.check_box_outline_blank_rounded,
                                  color: _checklist[i].done
                                      ? AppColors.forest
                                      : AppColors.mutedInk
                                          .withValues(alpha: 0.4),
                                  size: 22,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _checklist[i].name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: _checklist[i].done
                                        ? AppColors.forest
                                        : AppColors.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Conclusion
                  const Text(
                    'Conclusion (optional)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _conclusionController,
                    decoration: InputDecoration(
                      hintText: 'Summary of work performed...',
                      hintStyle: TextStyle(
                        color: AppColors.mutedInk.withValues(alpha: 0.5),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.mutedInk.withValues(alpha: 0.15),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.mutedInk.withValues(alpha: 0.15),
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

                  const SizedBox(height: 12),

                  // Photos
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'After Photos',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _addPhoto,
                        icon: const Icon(Icons.camera_alt_rounded, size: 18),
                        label: const Text('Add'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.forest,
                        ),
                      ),
                    ],
                  ),
                  if (_photos.isNotEmpty)
                    SizedBox(
                      height: 70,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _photos.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 8),
                        itemBuilder: (_, i) => Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                _photos[i],
                                width: 70,
                                height: 70,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _photos.removeAt(i)),
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: Colors.black
                                        .withValues(alpha: 0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // ─── Submit ───
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SafeArea(
              top: false,
              child: PrimaryButton(
                label: 'Mark as Completed',
                onPressed: _submit,
                isLoading: provider.submitting,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty body ─────────────────────────────────

class _EmptyBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 100),
        Center(
          child: Column(
            children: [
              Icon(
                Icons.assignment_outlined,
                size: 56,
                color: AppColors.mutedInk.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'No PMS records yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedInk,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'PMS records for this tractor will\nappear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.mutedInk.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Error body ─────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.danger.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.forest,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
