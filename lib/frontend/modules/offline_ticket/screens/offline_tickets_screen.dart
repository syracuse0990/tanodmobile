import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/frontend/shared/providers/offline_ticket_provider.dart';

class OfflineTicketsScreen extends StatefulWidget {
  const OfflineTicketsScreen({super.key});

  @override
  State<OfflineTicketsScreen> createState() => _OfflineTicketsScreenState();
}

class _OfflineTicketsScreenState extends State<OfflineTicketsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OfflineTicketProvider>().refreshCachedTractors();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.watch<OfflineTicketProvider>();
    // Navigate to tickets screen when all drafts have been synced
    if (provider.justSynced && mounted) {
      // Reset flag so it doesn't navigate again
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<OfflineTicketProvider>().resetJustSynced();
      });
      context.go('/account/tickets');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OfflineTicketProvider>();
    final drafts = provider.drafts;
    final pendingCount = provider.pendingCount;
    final isOnline = provider.isOnline;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.go('/account');
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7F6),
        appBar: AppBar(
          title: const Text('Offline Tickets'),
          backgroundColor: AppColors.forest,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go('/account'),
          ),
          actions: [
            if (pendingCount > 0 && isOnline)
              TextButton.icon(
                onPressed: () => provider.syncNow(),
                icon: const Icon(
                  Icons.sync_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                label: const Text(
                  'Sync',
                  style: TextStyle(color: Colors.white),
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            // Offline/Online Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: isOnline
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.warning.withValues(alpha: 0.15),
              child: Row(
                children: [
                  Icon(
                    isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                    size: 18,
                    color: isOnline ? AppColors.success : AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isOnline
                          ? 'You are online. Drafts will be submitted automatically.'
                          : 'You are offline. Tickets will be saved as drafts and submitted when connected.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isOnline ? AppColors.success : AppColors.warning,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Pending sync banner
            if (pendingCount > 0 && isOnline)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: AppColors.pine.withValues(alpha: 0.1),
                child: Row(
                  children: [
                    const Icon(
                      Icons.sync_rounded,
                      size: 16,
                      color: AppColors.pine,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        provider.loading
                            ? 'Syncing drafts...'
                            : '$pendingCount draft(s) pending submission.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.pine,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (!provider.loading)
                      TextButton(
                        onPressed: () => provider.syncNow(),
                        child: const Text(
                          'Sync Now',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),

            // Content
            Expanded(
              child: drafts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.note_add_rounded,
                            size: 64,
                            color: AppColors.mutedInk.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No offline ticket drafts',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.mutedInk,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Create a new ticket offline — it will be saved\nas a draft and submitted when online.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.mutedInk,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: drafts.length,
                      itemBuilder: (context, index) {
                        final draft = drafts[index];
                        return _DraftCard(
                          draft: draft,
                          onTap: () {
                            // Optionally navigate to edit draft
                          },
                          onDelete: () => _deleteDraft(draft.id),
                        );
                      },
                    ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/account/tickets/offline/create'),
          backgroundColor: AppColors.forest,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('New Ticket'),
        ),
      ),
    );
  }

  Future<void> _deleteDraft(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Draft'),
        content: const Text('This draft will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      context.read<OfflineTicketProvider>().deleteDraft(id);
    }
  }
}

class _DraftCard extends StatelessWidget {
  final dynamic draft;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _DraftCard({
    required this.draft,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: draft.synced
                ? AppColors.success.withValues(alpha: 0.1)
                : AppColors.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            draft.synced
                ? Icons.check_circle_rounded
                : Icons.cloud_upload_rounded,
            color: draft.synced ? AppColors.success : AppColors.warning,
            size: 20,
          ),
        ),
        title: Text(
          draft.subject,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          draft.tractorLabel ?? 'No tractor',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded, size: 20),
          onPressed: onDelete,
        ),
        onTap: onTap,
      ),
    );
  }
}
