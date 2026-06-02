import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/frontend/shared/providers/auth_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/tps_provider.dart';
import 'package:tanodmobile/models/local/offline_distribution_draft.dart';

class TpsOfflineDistributionsScreen extends StatefulWidget {
  const TpsOfflineDistributionsScreen({super.key});

  @override
  State<TpsOfflineDistributionsScreen> createState() =>
      _TpsOfflineDistributionsScreenState();
}

class _TpsOfflineDistributionsScreenState
    extends State<TpsOfflineDistributionsScreen> {
  bool _loading = true;
  final DateFormat _dateFormat = DateFormat('MMM d, yyyy');
  final DateFormat _timestampFormat = DateFormat('MMM d, yyyy • h:mm a');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    if (!mounted) {
      return;
    }

    setState(() => _loading = true);
    final provider = context.read<TpsProvider>();
    await provider.loadOfflineDistributionDrafts();

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _openDraftEditor([OfflineDistributionDraft? draft]) async {
    await context.push('/tps/offline/distributions/draft', extra: draft);
    if (!mounted) {
      return;
    }

    await _loadData();
  }

  Future<void> _deleteDraft(OfflineDistributionDraft draft) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete local draft?'),
          content: Text(
            'Remove the draft for ${draft.recipientName} from this phone?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await context.read<TpsProvider>().deleteOfflineDistributionDraft(draft.id);
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Draft deleted.')));
  }

  Future<void> _refreshSavedData(AuthProvider authProvider) async {
    if (!authProvider.isConnected) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Connect first to update offline data.'),
          ),
        );
      return;
    }

    await context.push('/tps/offline-download?manual=1');
    if (!mounted) {
      return;
    }

    await _loadData();
  }

  String _formatTimestamp(DateTime? value) {
    if (value == null) {
      return 'Not updated yet';
    }

    return _timestampFormat.format(value.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<TpsProvider, AuthProvider>(
      builder: (context, provider, authProvider, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF5F7F6),
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            title: const Text(
              'Tractor Distribution',
              style: TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            actions: [
              IconButton(
                onPressed: () => _refreshSavedData(authProvider),
                tooltip: 'Update data',
                icon: Icon(
                  Icons.cloud_sync_rounded,
                  color: authProvider.isConnected
                      ? AppColors.forest
                      : AppColors.mutedInk,
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openDraftEditor(),
            backgroundColor: AppColors.forest,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('New draft'),
          ),
          body: RefreshIndicator(
            color: AppColors.forest,
            onRefresh: _loadData,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.ink.withValues(alpha: 0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tractor distribution drafts',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Create and edit drafts here.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.mutedInk,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _CountChip(
                            icon: Icons.edit_note_rounded,
                            label:
                                '${provider.offlineDistributionDrafts.length} draft${provider.offlineDistributionDrafts.length == 1 ? '' : 's'}',
                            color: AppColors.pine,
                          ),
                          _CountChip(
                            icon: Icons.cloud_done_rounded,
                            label: provider.offlineReferenceDataSyncedAt == null
                                ? 'Update data first'
                                : 'Data ready',
                            color: AppColors.clay,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Last update: ${_formatTimestamp(provider.offlineReferenceDataSyncedAt)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mutedInk,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.forest),
                    ),
                  )
                else ...[
                  _SectionHeader(
                    title: 'My drafts',
                    subtitle: 'Tap a draft to edit it.',
                  ),
                  const SizedBox(height: 10),
                  if (provider.offlineDistributionDrafts.isEmpty)
                    const _EmptySectionCard(
                      icon: Icons.edit_note_rounded,
                      title: 'No drafts yet',
                      message: 'Tap New draft to add a tractor distribution.',
                    )
                  else
                    ...provider.offlineDistributionDrafts.map(
                      (draft) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _OfflineDraftCard(
                          draft: draft,
                          dateFormat: _dateFormat,
                          onEdit: () => _openDraftEditor(draft),
                          onDelete: () => _deleteDraft(draft),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.mutedInk,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySectionCard extends StatelessWidget {
  const _EmptySectionCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.mutedInk),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.mutedInk,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineDraftCard extends StatelessWidget {
  const _OfflineDraftCard({
    required this.draft,
    required this.dateFormat,
    required this.onEdit,
    required this.onDelete,
  });

  final OfflineDistributionDraft draft;
  final DateFormat dateFormat;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
              const Expanded(
                child: Text(
                  'Local draft',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.clay,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              IconButton(
                onPressed: onEdit,
                tooltip: 'Edit draft',
                icon: const Icon(Icons.edit_rounded, color: AppColors.forest),
              ),
              IconButton(
                onPressed: onDelete,
                tooltip: 'Delete draft',
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
          Text(
            draft.recipientName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            draft.tractorLabel,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedInk,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _DraftMetaChip(
                icon: Icons.calendar_month_rounded,
                label: dateFormat.format(draft.distributionDate.toLocal()),
              ),
              if ((draft.area ?? '').trim().isNotEmpty)
                _DraftMetaChip(
                  icon: Icons.place_rounded,
                  label: draft.area!.trim(),
                ),
            ],
          ),
          if ((draft.notes ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              draft.notes!.trim(),
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.mutedInk,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DraftMetaChip extends StatelessWidget {
  const _DraftMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.pine),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
