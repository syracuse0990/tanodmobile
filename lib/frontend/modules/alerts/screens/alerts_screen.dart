import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/frontend/shared/providers/alert_provider.dart';
import 'package:tanodmobile/models/domain/alert.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  String _filter = 'all';
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final provider = context.read<AlertProvider>();
    provider.startPolling();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        provider.fetchMore();
      }
    });
  }

  @override
  void dispose() {
    context.read<AlertProvider>().stopPolling();
    _scrollController.dispose();
    super.dispose();
  }

  void _onFilterTap(String filter) {
    if (_filter == filter) return;
    setState(() => _filter = filter);

    final provider = context.read<AlertProvider>();
    if (filter == 'all') {
      provider.setFilter(null);
    } else if (filter == 'unread') {
      // Unread is a client-side filter on unacknowledged
      provider.setFilter(null);
    } else {
      provider.setFilter(filter);
    }
  }

  List<Alert> _applyClientFilter(List<Alert> alerts) {
    if (_filter == 'unread') {
      return alerts.where((a) => !a.isAcknowledged).toList();
    }
    return alerts;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AlertProvider>(
      builder: (context, provider, _) {
        final alerts = _applyClientFilter(provider.alerts);
        final badgeCount = provider.unacknowledgedCount;

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7F6),
          body: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // ─── App Bar ───
              SliverAppBar(
                floating: true,
                snap: true,
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                toolbarHeight: 70,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Alerts',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (badgeCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.danger,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$badgeCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Tractor fleet notifications',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.mutedInk,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    onPressed: () => provider.fetchAlerts(),
                    icon:
                        const Icon(Icons.refresh_rounded, color: AppColors.pine),
                    tooltip: 'Refresh',
                  ),
                  const SizedBox(width: 8),
                ],
              ),

              // ─── Filter Chips ───
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        isActive: _filter == 'all',
                        onTap: () => _onFilterTap('all'),
                      ),
                      _FilterChip(
                        label: 'Unread',
                        isActive: _filter == 'unread',
                        onTap: () => _onFilterTap('unread'),
                      ),
                      _FilterChip(
                        label: 'Geofence',
                        isActive: _filter == 'geofence_breach',
                        onTap: () => _onFilterTap('geofence_breach'),
                      ),
                      _FilterChip(
                        label: 'Speed',
                        isActive: _filter == 'speed',
                        onTap: () => _onFilterTap('speed'),
                      ),
                      _FilterChip(
                        label: 'Idle',
                        isActive: _filter == 'idle',
                        onTap: () => _onFilterTap('idle'),
                      ),
                      _FilterChip(
                        label: 'Offline',
                        isActive: _filter == 'offline',
                        onTap: () => _onFilterTap('offline'),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Loading State ───
              if (provider.loading && alerts.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.pine),
                  ),
                )
              // ─── Error State ───
              else if (provider.error != null && alerts.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 56,
                          color: AppColors.danger,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          provider.error!,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mutedInk,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => provider.fetchAlerts(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              // ─── Empty State ───
              else if (alerts.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.notifications_off_rounded,
                          size: 56,
                          color: AppColors.mutedInk,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No alerts found',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mutedInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              // ─── Alert List ───
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.separated(
                    itemCount: alerts.length + (provider.hasMore ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      if (index >= alerts.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.pine,
                              ),
                            ),
                          ),
                        );
                      }
                      final alert = alerts[index];
                      return _AlertCard(
                        alert: alert,
                        onAcknowledge: !alert.isAcknowledged
                            ? () => provider.acknowledge(alert.id)
                            : null,
                      );
                    },
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? AppColors.forest : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive
                  ? AppColors.forest
                  : AppColors.ink.withValues(alpha: 0.08),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : AppColors.mutedInk,
            ),
          ),
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, this.onAcknowledge});

  final Alert alert;
  final VoidCallback? onAcknowledge;

  IconData get _icon {
    switch (alert.type) {
      case 'geofence_breach':
        return Icons.fence_rounded;
      case 'speed':
        return Icons.speed_rounded;
      case 'maintenance_due':
        return Icons.build_circle_rounded;
      case 'offline':
        return Icons.wifi_off_rounded;
      case 'idle':
        return Icons.pause_circle_rounded;
      default:
        return Icons.warning_amber_rounded;
    }
  }

  Color get _color {
    switch (alert.type) {
      case 'geofence_breach':
        return AppColors.warning;
      case 'speed':
        return AppColors.danger;
      case 'maintenance_due':
        return AppColors.clay;
      case 'offline':
        return AppColors.mutedInk;
      case 'idle':
        return AppColors.gold;
      default:
        return AppColors.ink;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAcknowledge,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: alert.isAcknowledged
              ? null
              : Border.all(color: _color.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_icon, color: _color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          alert.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: alert.isAcknowledged
                                ? FontWeight.w600
                                : FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      if (!alert.isAcknowledged)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _color,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alert.message,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.mutedInk,
                      height: 1.4,
                      fontWeight: alert.isAcknowledged
                          ? FontWeight.w400
                          : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (alert.tractorLabel != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.forest.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            alert.tractorLabel!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.forest,
                            ),
                          ),
                        ),
                      if (alert.tractorLabel != null)
                        const SizedBox(width: 8),
                      Icon(
                        Icons.schedule_rounded,
                        size: 13,
                        color: AppColors.mutedInk.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        alert.timeAgo,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.mutedInk.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
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
