import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/frontend/shared/providers/ticket_provider.dart';
import 'package:tanodmobile/models/domain/ticket.dart';

class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    context.read<TicketProvider>().fetchTickets();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        context.read<TicketProvider>().fetchMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TicketProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      appBar: AppBar(
        title: const Text('Tickets'),
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/account'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.forest,
        onPressed: () => context.go('/account/tickets/create'),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: Column(
        children: [
          // ─── Status filter chips ───
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: provider.statusFilter == null,
                    onTap: () => provider.setFilter(null),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Open',
                    selected: provider.statusFilter == 'open',
                    onTap: () => provider.setFilter('open'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'In Progress',
                    selected: provider.statusFilter == 'in_progress',
                    onTap: () => provider.setFilter('in_progress'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Resolved',
                    selected: provider.statusFilter == 'resolved',
                    onTap: () => provider.setFilter('resolved'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Closed',
                    selected: provider.statusFilter == 'closed',
                    onTap: () => provider.setFilter('closed'),
                  ),
                ],
              ),
            ),
          ),

          // ─── Ticket list ───
          Expanded(
            child: provider.loading && provider.tickets.isEmpty
                ? const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.forest))
                : provider.error != null && provider.tickets.isEmpty
                    ? _ErrorView(
                        message: provider.error!,
                        onRetry: provider.fetchTickets,
                      )
                    : provider.tickets.isEmpty
                        ? _EmptyView(
                            onCreateTap: () =>
                                context.go('/account/tickets/create'),
                          )
                        : RefreshIndicator(
                            color: AppColors.forest,
                            onRefresh: provider.fetchTickets,
                            child: ListView.separated(
                              controller: _scrollController,
                              padding: const EdgeInsets.fromLTRB(
                                  16, 12, 16, 100),
                              itemCount: provider.tickets.length +
                                  (provider.hasMore ? 1 : 0),
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                if (index >= provider.tickets.length) {
                                  return const Center(
                                    child: Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 16),
                                      child: CircularProgressIndicator(
                                          color: AppColors.forest,
                                          strokeWidth: 2),
                                    ),
                                  );
                                }
                                return _TicketCard(
                                  ticket: provider.tickets[index],
                                  onTap: () => context.go(
                                    '/account/tickets/${provider.tickets[index].id}',
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

// ─── Filter Chip ─────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.forest : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.mutedInk,
          ),
        ),
      ),
    );
  }
}

// ─── Ticket Card ─────────────────────────────────

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.onTap});

  final Ticket ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
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
            // Header row: subject + priority
            Row(
              children: [
                Expanded(
                  child: Text(
                    ticket.subject,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _PriorityBadge(priority: ticket.priority),
              ],
            ),
            const SizedBox(height: 8),

            // Description preview
            if (ticket.description != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  ticket.description!,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.mutedInk,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            // Footer: status + tractor + time
            Row(
              children: [
                _StatusBadge(status: ticket.status),
                if (ticket.tractorLabel != null) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.agriculture_rounded,
                      size: 14, color: AppColors.mutedInk),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      ticket.tractorLabel!,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedInk,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Text(
                  ticket.timeAgo,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedInk,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Status Badge ────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (status) {
      'open' => (const Color(0xFFE8F5E9), AppColors.forest),
      'in_progress' => (const Color(0xFFFFF3E0), const Color(0xFFE65100)),
      'resolved' => (const Color(0xFFE3F2FD), const Color(0xFF1565C0)),
      'closed' => (Colors.grey.shade100, AppColors.mutedInk),
      _ => (Colors.grey.shade100, AppColors.mutedInk),
    };

    final label = switch (status) {
      'open' => 'Open',
      'in_progress' => 'In Progress',
      'resolved' => 'Resolved',
      'closed' => 'Closed',
      _ => status,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

// ─── Priority Badge ──────────────────────────────

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

  final String priority;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (priority) {
      'critical' => (const Color(0xFFFFEBEE), AppColors.danger),
      'high' => (const Color(0xFFFFF3E0), const Color(0xFFE65100)),
      'medium' => (const Color(0xFFFFFDE7), const Color(0xFFF9A825)),
      'low' => (const Color(0xFFE8F5E9), AppColors.forest),
      _ => (Colors.grey.shade100, AppColors.mutedInk),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        priority.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─── Empty View ──────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onCreateTap});

  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.confirmation_num_outlined,
                size: 64, color: AppColors.mutedInk.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            const Text(
              'No tickets yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a ticket to report an issue or request support.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.mutedInk),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onCreateTap,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Create Ticket'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.forest,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Error View ──────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.danger.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: AppColors.ink),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.forest,
                side: const BorderSide(color: AppColors.forest),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
