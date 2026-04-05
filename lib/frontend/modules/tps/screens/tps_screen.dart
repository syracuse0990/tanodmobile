import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/core/locale/app_localizations.dart';
import 'package:tanodmobile/frontend/shared/providers/maintenance_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/tps_provider.dart';
import 'package:tanodmobile/models/domain/distribution.dart';
import 'package:tanodmobile/models/domain/farmer_feedback.dart';
import 'package:tanodmobile/models/domain/maintenance_tractor.dart';
import 'package:tanodmobile/models/domain/ticket.dart';

class TpsScreen extends StatefulWidget {
  const TpsScreen({super.key});

  @override
  State<TpsScreen> createState() => _TpsScreenState();
}

class _TpsScreenState extends State<TpsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    context.read<TpsProvider>().loadAll();
    context.read<MaintenanceProvider>().fetchTractors();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TpsProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF5F7F6),
          floatingActionButton: AnimatedBuilder(
            animation: _tabController,
            builder: (context, child) {
              final index = _tabController.index;
              final showFab = index == 4;
              return AnimatedScale(
                scale: showFab ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: showFab
                    ? FloatingActionButton.extended(
                        onPressed: () {
                          context.go('/tps/distribute');
                        },
                        backgroundColor: AppColors.forest,
                        foregroundColor: Colors.white,
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: Text(context.tr('distribute_tractor')),
                      )
                    : const SizedBox.shrink(),
              );
            },
          ),
          body: RefreshIndicator(
            onRefresh: () => provider.loadAll(),
            color: AppColors.forest,
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
                        'TPS Dashboard',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Manage assigned tractors & services',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.mutedInk,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(132),
                    child: Column(
                      children: [
                        // Summary cards
                        _SummaryRow(provider: provider),
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
                            isScrollable: true,
                            tabAlignment: TabAlignment.start,
                            labelStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                            unselectedLabelStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            tabs: const [
                              Tab(text: 'Tickets'),
                              Tab(text: 'Feedbacks'),
                              Tab(text: 'Tractors'),
                              Tab(text: 'Maintenance'),
                              Tab(text: 'Distributions'),
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
                _TicketsTab(provider: provider),
                _FeedbacksTab(provider: provider),
                _TractorsTab(provider: provider),
                const _MaintenanceTab(),
                _DistributionsTab(provider: provider),
              ],
            ),
          ),
          ),
        );
      },
    );
  }
}

// ─── Summary cards row ──────────────────────────

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.provider});
  final TpsProvider provider;

  @override
  Widget build(BuildContext context) {
    if (provider.dashboardLoading) {
      return const SizedBox(
        height: 72,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.forest),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _StatChip(
            label: 'Tractors',
            value: provider.tractorsCount.toString(),
            icon: Icons.agriculture_rounded,
            color: AppColors.forest,
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: 'Open Tickets',
            value: provider.openTickets.toString(),
            icon: Icons.confirmation_number_rounded,
            color: AppColors.warning,
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: 'PMS Due',
            value: provider.pendingMaintenance.toString(),
            icon: Icons.build_circle_rounded,
            color: AppColors.clay,
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: 'Distributions',
            value: provider.activeDistributions.toString(),
            icon: Icons.local_shipping_rounded,
            color: AppColors.pine,
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.mutedInk,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Tickets Tab ────────────────────────────────

class _TicketsTab extends StatelessWidget {
  const _TicketsTab({required this.provider});
  final TpsProvider provider;

  @override
  Widget build(BuildContext context) {
    if (provider.ticketsLoading && provider.tickets.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.forest),
      );
    }

    if (provider.tickets.isEmpty) {
      return _buildEmpty(Icons.confirmation_number_outlined, 'No tickets');
    }

    return RefreshIndicator(
      onRefresh: () => provider.fetchTickets(),
      color: AppColors.forest,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: provider.tickets.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final ticket = provider.tickets[i];
          return GestureDetector(
            onTap: () => context.go('/tps/tickets/${ticket.id}'),
            child: _TicketCard(ticket: ticket),
          );
        },
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket});
  final Ticket ticket;

  Color get _statusColor {
    switch (ticket.status) {
      case 'open':
        return AppColors.warning;
      case 'in_progress':
        return AppColors.pine;
      case 'resolved':
        return AppColors.success;
      case 'closed':
        return AppColors.mutedInk;
      default:
        return AppColors.mutedInk;
    }
  }

  Color get _priorityColor {
    switch (ticket.priority) {
      case 'critical':
        return AppColors.danger;
      case 'high':
        return AppColors.clay;
      case 'medium':
        return AppColors.warning;
      case 'low':
        return AppColors.success;
      default:
        return AppColors.mutedInk;
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _priorityColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.confirmation_number_rounded,
                    size: 20, color: _priorityColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.subject,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (ticket.tractorLabel != null)
                      Text(
                        ticket.tractorLabel!,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.mutedInk),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _Badge(label: ticket.statusLabel, color: _statusColor),
            ],
          ),
          if (ticket.description != null) ...[
            const SizedBox(height: 10),
            Text(
              ticket.description!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.mutedInk,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              _Badge(label: ticket.priorityLabel, color: _priorityColor),
              const Spacer(),
              Text(
                ticket.timeAgo,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.mutedInk),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Feedbacks Tab ──────────────────────────────

class _FeedbacksTab extends StatelessWidget {
  const _FeedbacksTab({required this.provider});
  final TpsProvider provider;

  @override
  Widget build(BuildContext context) {
    if (provider.feedbacksLoading && provider.feedbacks.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.forest),
      );
    }

    if (provider.feedbacks.isEmpty) {
      return _buildEmpty(Icons.rate_review_outlined, 'No feedbacks');
    }

    return RefreshIndicator(
      onRefresh: () => provider.fetchFeedbacks(),
      color: AppColors.forest,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: provider.feedbacks.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) =>
            _FeedbackCard(feedback: provider.feedbacks[i]),
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.feedback});
  final FarmerFeedbackItem feedback;

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
              // Star rating
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  final r = feedback.rating ?? 0;
                  return Icon(
                    i < r
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    size: 18,
                    color: i < r
                        ? AppColors.gold
                        : AppColors.mutedInk.withValues(alpha: 0.3),
                  );
                }),
              ),
              const Spacer(),
              Text(
                feedback.timeAgo,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.mutedInk),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (feedback.feedback != null)
            Text(
              feedback.feedback!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.ink,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (feedback.tractorLabel != null)
                _InfoChip(
                  icon: Icons.agriculture_rounded,
                  text: feedback.tractorLabel!,
                ),
              if (feedback.submitterName != null) ...[
                const SizedBox(width: 10),
                _InfoChip(
                  icon: Icons.person_outline_rounded,
                  text: feedback.submitterName!,
                ),
              ],
              if (feedback.category != null) ...[
                const SizedBox(width: 10),
                _InfoChip(
                  icon: Icons.category_outlined,
                  text: feedback.category!,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Tractors Tab ───────────────────────────────

class _TractorsTab extends StatelessWidget {
  const _TractorsTab({required this.provider});
  final TpsProvider provider;

  @override
  Widget build(BuildContext context) {
    if (provider.tractorsLoading && provider.tractors.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.forest),
      );
    }

    if (provider.tractors.isEmpty) {
      return _buildEmpty(Icons.agriculture_outlined, 'No tractors assigned');
    }

    return RefreshIndicator(
      onRefresh: () => provider.fetchTractors(),
      color: AppColors.forest,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: provider.tractors.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final t = provider.tractors[i];
          final plate = t['no_plate']?.toString() ?? 'N/A';
          final brand = t['brand']?.toString() ?? '';
          final model = t['model']?.toString() ?? '';
          final status = t['status']?.toString() ?? 'unknown';
          final year = t['year']?.toString();
          final group = (t['groups'] is List && (t['groups'] as List).isNotEmpty)
              ? (t['groups'] as List).first['name']?.toString()
              : null;

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
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.forest.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.agriculture_rounded,
                      color: AppColors.forest, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plate,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        '$brand $model${year != null ? ' ($year)' : ''}'.trim(),
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.mutedInk),
                      ),
                      if (group != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: _InfoChip(
                            icon: Icons.group_work_rounded,
                            text: group,
                          ),
                        ),
                    ],
                  ),
                ),
                _Badge(
                  label: status[0].toUpperCase() + status.substring(1),
                  color: status == 'active'
                      ? AppColors.success
                      : status == 'maintenance'
                          ? AppColors.warning
                          : AppColors.mutedInk,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Maintenance Tab ────────────────────────────

class _MaintenanceTab extends StatelessWidget {
  const _MaintenanceTab();

  void _showPmsActions(BuildContext ctx, MaintenanceTractor tractor) {
    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.mutedInk.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                tractor.label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading:
                  const Icon(Icons.history_rounded, color: AppColors.forest),
              title: const Text('PMS History'),
              subtitle: const Text('View past PMS records'),
              onTap: () {
                Navigator.pop(sheetCtx);
                ctx.push('/account/maintenance/history', extra: tractor);
              },
            ),
            ListTile(
              leading: const Icon(Icons.checklist_rounded,
                  color: AppColors.forest),
              title: const Text('Record PMS'),
              subtitle: const Text('Perform PMS checklist'),
              onTap: () {
                Navigator.pop(sheetCtx);
                ctx.push('/account/maintenance/record', extra: tractor);
              },
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MaintenanceProvider>();
    final tractors = List<MaintenanceTractor>.from(provider.tractors)
      ..sort((a, b) {
        const order = {'due': 0, 'upcoming': 1, 'ok': 2};
        final cmp =
            (order[a.pmsStatus] ?? 2).compareTo(order[b.pmsStatus] ?? 2);
        if (cmp != 0) return cmp;
        return a.totalRunningHours.compareTo(b.totalRunningHours);
      });

    if (provider.loading && tractors.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.forest),
      );
    }

    if (tractors.isEmpty) {
      return _buildEmpty(Icons.build_circle_outlined, 'No maintenance data');
    }

    return RefreshIndicator(
      onRefresh: () => provider.fetchTractors(),
      color: AppColors.forest,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: tractors.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final tractor = tractors[i];
          return GestureDetector(
            onTap: () => _showPmsActions(context, tractor),
            child: _MaintenanceCard(tractor: tractor),
          );
        },
      ),
    );
  }
}

class _MaintenanceCard extends StatelessWidget {
  const _MaintenanceCard({required this.tractor});
  final MaintenanceTractor tractor;

  @override
  Widget build(BuildContext context) {
    final (Color badgeBg, Color badgeFg, String badgeText) =
        switch (tractor.pmsStatus) {
      'due' => (const Color(0xFFFFEBEE), AppColors.danger, 'PMS DUE'),
      'upcoming' => (
        const Color(0xFFFFF3E0),
        const Color(0xFFE65100),
        'UPCOMING',
      ),
      _ => (const Color(0xFFE8F5E9), AppColors.forest, 'OK'),
    };

    return Container(
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
        border: tractor.isPmsDue
            ? Border.all(
                color: AppColors.danger.withValues(alpha: 0.4), width: 1.5)
            : tractor.isPmsUpcoming
                ? Border.all(
                    color: const Color(0xFFE65100).withValues(alpha: 0.3),
                    width: 1)
                : null,
      ),
      padding: const EdgeInsets.all(16),
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
                child: tractor.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          tractor.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.agriculture_rounded,
                            color: AppColors.forest,
                            size: 24,
                          ),
                        ),
                      )
                    : const Icon(
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
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (tractor.brandModel.isNotEmpty)
                      Text(
                        tractor.brandModel,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.mutedInk),
                      ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: badgeFg,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _InfoChip(
                icon: Icons.schedule_rounded,
                text:
                    '${tractor.totalRunningHours.toStringAsFixed(1)}h running',
              ),
              const SizedBox(width: 12),
              _InfoChip(
                icon: Icons.straighten_rounded,
                text: '${tractor.totalDistance.toStringAsFixed(1)} km',
              ),
            ],
          ),
          if (tractor.assigneeName != null) ...[
            const SizedBox(height: 8),
            _InfoChip(
              icon: Icons.person_outline_rounded,
              text: tractor.assigneeName!,
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Distributions Tab ──────────────────────────

class _DistributionsTab extends StatelessWidget {
  const _DistributionsTab({required this.provider});
  final TpsProvider provider;

  @override
  Widget build(BuildContext context) {
    if (provider.distributionsLoading && provider.distributions.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.forest),
      );
    }

    if (provider.distributions.isEmpty) {
      return _buildEmpty(
          Icons.local_shipping_outlined, 'No distributions');
    }

    return RefreshIndicator(
      onRefresh: () => provider.fetchDistributions(),
      color: AppColors.forest,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: provider.distributions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) =>
            _DistributionCard(distribution: provider.distributions[i]),
      ),
    );
  }
}

class _DistributionCard extends StatelessWidget {
  const _DistributionCard({required this.distribution});
  final Distribution distribution;

  Color get _statusColor {
    switch (distribution.status) {
      case 'active':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'completed':
        return AppColors.pine;
      case 'recalled':
        return AppColors.danger;
      default:
        return AppColors.mutedInk;
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.pine.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_shipping_rounded,
                    size: 20, color: AppColors.pine),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      distribution.tractorLabel ?? 'Tractor',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    if (distribution.distributedToName != null)
                      Text(
                        'To: ${distribution.distributedToName}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.mutedInk),
                      ),
                  ],
                ),
              ),
              _Badge(label: distribution.statusLabel, color: _statusColor),
            ],
          ),
          if (distribution.area != null) ...[
            const SizedBox(height: 10),
            _InfoChip(
              icon: Icons.place_rounded,
              text: distribution.area!,
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Shared widgets ─────────────────────────────

Widget _buildEmpty(IconData icon, String message) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 56, color: AppColors.mutedInk.withValues(alpha: 0.4)),
        const SizedBox(height: 12),
        Text(
          message,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.mutedInk,
          ),
        ),
      ],
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});
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
