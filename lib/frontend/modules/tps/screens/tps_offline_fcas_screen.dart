import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
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
        final drafts = provider.offlineFcaDrafts;

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7F6),
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
              onPressed: () => context.pop(),
            ),
            title: const Text(
              'Offline Revisit',
              style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800),
            ),
            actions: [
              TextButton.icon(
                onPressed: () => _refreshSavedData(authProvider),
                icon: Icon(Icons.cloud_sync_rounded, size: 18,
                    color: authProvider.isConnected ? AppColors.forest : AppColors.mutedInk),
                label: Text('Sync', style: TextStyle(
                    color: authProvider.isConnected ? AppColors.forest : AppColors.mutedInk)),
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
          body: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.forest))
              : drafts.isEmpty
                  ? const _OfflineFcaEmptyState(
                      icon: Icons.edit_note_rounded,
                      title: 'No drafts yet',
                      message: 'Tap New draft to add a revisit.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                      itemCount: drafts.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _DraftFeedCard(
                          draft: drafts[index],
                          dateFormat: _dateFormat,
                          onTap: () => _openDraftEditor(drafts[index]),
                          onDelete: () => _deleteDraft(drafts[index]),
                        ),
                      ),
                    ),
        );
      },
    );
  }
}

class _DraftFeedCard extends StatelessWidget {
  const _DraftFeedCard({
    required this.draft, required this.dateFormat,
    required this.onTap, required this.onDelete,
  });
  final OfflineFcaDraft draft;
  final DateFormat dateFormat;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dateLabel = draft.updatedAt != null
        ? dateFormat.format(draft.updatedAt!.toLocal())
        : (draft.createdAt != null ? dateFormat.format(draft.createdAt!.toLocal()) : '');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: AppColors.ink.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(color: AppColors.forest.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.groups_2_rounded, color: AppColors.forest, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(draft.organizationName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink)),
                    if (draft.contactName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(draft.contactName, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: AppColors.mutedInk, height: 1.35)),
                    ],
                    if (draft.locationLabel.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(children: [
                        Icon(Icons.place_outlined, size: 14, color: AppColors.mutedInk.withValues(alpha: 0.7)),
                        const SizedBox(width: 4),
                        Flexible(child: Text(draft.locationLabel, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: AppColors.mutedInk.withValues(alpha: 0.7)))),
                      ]),
                    ],
                    const SizedBox(height: 10),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.forest.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                        child: const Text('Draft', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.forest)),
                      ),
                      const Spacer(),
                      Text(dateLabel, style: const TextStyle(fontSize: 11, color: AppColors.mutedInk)),
                    ]),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onDelete,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.mutedInk.withValues(alpha: 0.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfflineFcaEmptyState extends StatelessWidget {
  const _OfflineFcaEmptyState({required this.icon, required this.title, required this.message});
  final IconData icon; final String title; final String message;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 64, height: 64, decoration: BoxDecoration(
            color: AppColors.forest.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)),
            child: Icon(icon, color: AppColors.forest, size: 32)),
          const SizedBox(height: 20),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.mutedInk, height: 1.45)),
        ]),
      ),
    );
  }
}
