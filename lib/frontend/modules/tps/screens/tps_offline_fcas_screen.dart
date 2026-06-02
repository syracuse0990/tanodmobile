import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/frontend/modules/tps/widgets/offline_location_cache_card.dart';
import 'package:tanodmobile/frontend/shared/providers/auth_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/tps_provider.dart';
import 'package:tanodmobile/models/local/offline_fca_draft.dart';

class TpsOfflineFcasScreen extends StatefulWidget {
  const TpsOfflineFcasScreen({super.key});

  @override
  State<TpsOfflineFcasScreen> createState() => _TpsOfflineFcasScreenState();
}

class _TpsOfflineFcasScreenState extends State<TpsOfflineFcasScreen> {
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
    await provider.loadOfflineFcaDrafts();
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _openDraftEditor([OfflineFcaDraft? draft]) async {
    await context.push('/tps/offline/fcas/draft', extra: draft);
    if (!mounted) {
      return;
    }

    await _loadData();
  }

  Future<void> _deleteDraft(OfflineFcaDraft draft) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete local draft?'),
          content: Text(
            'Remove the draft for ${draft.organizationName} from this phone?',
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

    await context.read<TpsProvider>().deleteOfflineFcaDraft(draft.id);
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
        final offlineLocationSummary = provider.offlineLocationCacheSummary;

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7F6),
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            title: const Text(
              'Offline Revisit',
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
                        'Offline revisit drafts',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Create and edit revisit drafts here.',
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
                          _OfflineFcaCountChip(
                            icon: Icons.edit_note_rounded,
                            label:
                                '${provider.offlineFcaDrafts.length} draft${provider.offlineFcaDrafts.length == 1 ? '' : 's'}',
                            color: AppColors.forest,
                          ),
                          _OfflineFcaCountChip(
                            icon: Icons.map_outlined,
                            label: offlineLocationSummary.hasData
                                ? '${offlineLocationSummary.cityCount} ${offlineLocationSummary.cityCount == 1 ? 'city' : 'cities'} ready'
                                : 'Update data first',
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
                const SizedBox(height: 14),
                OfflineLocationCacheCard(
                  summary: offlineLocationSummary,
                  showProvinceBreakdown: true,
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
                  const _OfflineFcaSectionHeader(
                    title: 'My drafts',
                    subtitle: 'Tap a draft to edit it.',
                  ),
                  const SizedBox(height: 10),
                  if (provider.offlineFcaDrafts.isEmpty)
                    const _OfflineFcaEmptyState(
                      icon: Icons.edit_note_rounded,
                      title: 'No drafts yet',
                      message: 'Tap New draft to add a revisit.',
                    )
                  else
                    ...provider.offlineFcaDrafts.map(
                      (draft) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _OfflineFcaDraftCard(
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

class _OfflineFcaEmptyState extends StatelessWidget {
  const _OfflineFcaEmptyState({
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.mutedInk),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
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

class _OfflineFcaSectionHeader extends StatelessWidget {
  const _OfflineFcaSectionHeader({required this.title, required this.subtitle});

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

class _OfflineFcaCountChip extends StatelessWidget {
  const _OfflineFcaCountChip({
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

class _OfflineFcaDraftCard extends StatelessWidget {
  const _OfflineFcaDraftCard({
    required this.draft,
    required this.dateFormat,
    required this.onEdit,
    required this.onDelete,
  });

  final OfflineFcaDraft draft;
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
                  'Draft',
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
            draft.organizationName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            draft.contactName,
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
              if (draft.contactLabel.isNotEmpty)
                _OfflineFcaMetaChip(
                  icon: Icons.call_outlined,
                  label: draft.contactLabel,
                ),
              if (draft.locationLabel.isNotEmpty)
                _OfflineFcaMetaChip(
                  icon: Icons.place_outlined,
                  label: draft.locationLabel,
                ),
              if (draft.dateReceived != null)
                _OfflineFcaMetaChip(
                  icon: Icons.calendar_month_rounded,
                  label: dateFormat.format(draft.dateReceived!.toLocal()),
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

class _OfflineFcaMetaChip extends StatelessWidget {
  const _OfflineFcaMetaChip({required this.icon, required this.label});

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
          Icon(icon, size: 16, color: AppColors.forest),
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
