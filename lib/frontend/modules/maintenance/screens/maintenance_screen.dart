import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/frontend/shared/providers/auth_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/maintenance_provider.dart';
import 'package:tanodmobile/models/domain/maintenance_tractor.dart';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  @override
  void initState() {
    super.initState();
    context.read<MaintenanceProvider>().fetchTractors();
  }

  void _showPmsActions(BuildContext ctx, MaintenanceTractor tractor) {
    final isTps =
        ctx.read<AuthProvider>().session?.roles.contains('tps') ?? false;

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
              leading: const Icon(Icons.history_rounded,
                  color: AppColors.forest),
              title: const Text('PMS History'),
              subtitle: const Text('View past PMS records'),
              onTap: () {
                Navigator.pop(sheetCtx);
                ctx.push('/account/maintenance/history', extra: tractor);
              },
            ),
            if (!isTps)
              ListTile(
                leading: const Icon(Icons.checklist_rounded,
                    color: AppColors.forest),
                title: const Text('Record PMS'),
                subtitle: const Text('Self-service PMS checklist'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  ctx.push('/account/maintenance/record', extra: tractor);
                },
              ),
            if (!isTps)
              ListTile(
                leading: const Icon(Icons.support_agent_rounded,
                    color: Color(0xFFE65100)),
                title: const Text('Request TPS Help'),
                subtitle: const Text('Notify technician for PMS service'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  ctx.push('/account/maintenance/request', extra: tractor);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MaintenanceProvider>();
    final tractors = provider.tractors;

    // Sort: PMS due first, then upcoming, then ok
    final sorted = List<MaintenanceTractor>.from(tractors)
      ..sort((a, b) {
        const order = {'due': 0, 'upcoming': 1, 'ok': 2};
        final cmp =
            (order[a.pmsStatus] ?? 2).compareTo(order[b.pmsStatus] ?? 2);
        if (cmp != 0) return cmp;
        return a.totalRunningHours.compareTo(b.totalRunningHours);
      });

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      appBar: AppBar(
        title: const Text('Maintenance'),
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/account'),
        ),
      ),
      body: provider.loading && tractors.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.forest),
            )
          : provider.error != null && tractors.isEmpty
              ? _ErrorState(
                  error: provider.error!,
                  onRetry: provider.fetchTractors,
                )
              : RefreshIndicator(
                  color: AppColors.forest,
                  onRefresh: provider.fetchTractors,
                  child: tractors.isEmpty
                      ? _EmptyState()
                      : CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            // ─── Summary cards ───
                            SliverToBoxAdapter(
                              child: _SummaryBar(
                                total: tractors.length,
                                dueCount: provider.dueCount,
                                upcomingCount: provider.upcomingCount,
                              ),
                            ),

                            // ─── Tractor list ───
                            SliverPadding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    if (index >= sorted.length) return null;
                                    final tractor = sorted[index];
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: GestureDetector(
                                        onTap: () => _showPmsActions(
                                          context,
                                          tractor,
                                        ),
                                        child:
                                            _TractorCard(tractor: tractor),
                                      ),
                                    );
                                  },
                                  childCount: sorted.length,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
    );
  }
}

// ─── Summary bar ────────────────────────────────

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({
    required this.total,
    required this.dueCount,
    required this.upcomingCount,
  });

  final int total;
  final int dueCount;
  final int upcomingCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _SummaryChip(
            label: 'Total',
            count: total,
            color: AppColors.forest,
          ),
          const SizedBox(width: 10),
          _SummaryChip(
            label: 'PMS Due',
            count: dueCount,
            color: AppColors.danger,
          ),
          const SizedBox(width: 10),
          _SummaryChip(
            label: 'Upcoming',
            count: upcomingCount,
            color: const Color(0xFFE65100),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tractor card ───────────────────────────────

class _TractorCard extends StatelessWidget {
  const _TractorCard({required this.tractor});

  final MaintenanceTractor tractor;

  @override
  Widget build(BuildContext context) {
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
        border: tractor.isPmsDue
            ? Border.all(color: AppColors.danger.withValues(alpha: 0.4), width: 1.5)
            : tractor.isPmsUpcoming
                ? Border.all(
                    color: const Color(0xFFE65100).withValues(alpha: 0.3),
                    width: 1)
                : null,
      ),
      child: Column(
        children: [
          // ─── Header row ───
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                // Tractor icon
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
                // Tractor info
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
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.mutedInk,
                          ),
                        ),
                    ],
                  ),
                ),
                // PMS badge
                _PmsBadge(status: tractor.pmsStatus),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ─── Stats row ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _StatTile(
                  icon: Icons.schedule_rounded,
                  label: 'Running Hours',
                  value: '${tractor.totalRunningHours.toStringAsFixed(1)}h',
                ),
                const SizedBox(width: 12),
                _StatTile(
                  icon: Icons.straighten_rounded,
                  label: 'Distance',
                  value: '${tractor.totalDistance.toStringAsFixed(1)} km',
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ─── PMS progress ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _PmsProgress(tractor: tractor),
          ),

          // ─── Assignee ───
          if (tractor.assigneeName != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    size: 14,
                    color: AppColors.mutedInk.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    tractor.assigneeName!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.mutedInk,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),
        ],
      ),
    );
  }
}

// ─── PMS Badge ──────────────────────────────────

class _PmsBadge extends StatelessWidget {
  const _PmsBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, String text) = switch (status) {
      'due' => (
        const Color(0xFFFFEBEE),
        AppColors.danger,
        'PMS DUE',
      ),
      'upcoming' => (
        const Color(0xFFFFF3E0),
        const Color(0xFFE65100),
        'UPCOMING',
      ),
      _ => (
        const Color(0xFFE8F5E9),
        AppColors.forest,
        'OK',
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
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

// ─── Stat tile ──────────────────────────────────

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7F6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.mutedInk),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.mutedInk,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── PMS progress bar ───────────────────────────

class _PmsProgress extends StatelessWidget {
  const _PmsProgress({required this.tractor});

  final MaintenanceTractor tractor;

  @override
  Widget build(BuildContext context) {
    final nextPms = tractor.nextPmsHours;
    if (nextPms == null) return const SizedBox.shrink();

    // Determine progress toward next PMS
    // Find previous milestone
    const milestones = [0, 50, 100, 200, 300];
    double prevMilestone = 0;
    for (final m in milestones) {
      if (m < nextPms) {
        prevMilestone = m.toDouble();
      }
    }
    if (nextPms > 300) {
      prevMilestone = nextPms - 300;
    }

    final range = nextPms - prevMilestone;
    final progress = range > 0
        ? ((tractor.totalRunningHours - prevMilestone) / range).clamp(0.0, 1.0)
        : 0.0;

    final progressColor = tractor.isPmsDue
        ? AppColors.danger
        : tractor.isPmsUpcoming
            ? const Color(0xFFE65100)
            : AppColors.forest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Next PMS at ${nextPms.toStringAsFixed(0)}h',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: progressColor,
              ),
            ),
            Text(
              tractor.hoursUntilNextPms.isFinite
                  ? '${tractor.hoursUntilNextPms.toStringAsFixed(1)}h remaining'
                  : '',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.mutedInk,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: progressColor.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          ),
        ),
      ],
    );
  }
}

// ─── Empty state ────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Center(
          child: Column(
            children: [
              Icon(
                Icons.build_outlined,
                size: 56,
                color: AppColors.mutedInk.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'No tractors assigned',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedInk,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tractors assigned to you will appear here\nwith their maintenance status.',
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

// ─── Error state ────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

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
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.forest,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
