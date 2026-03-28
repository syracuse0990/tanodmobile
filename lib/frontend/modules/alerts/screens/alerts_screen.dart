import 'package:flutter/material.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  String _filter = 'all';

  // Sample alert data — will be replaced by API calls
  static final List<_AlertItem> _alerts = [
    _AlertItem(
      id: 1,
      type: 'geofence',
      title: 'Geofence Breach',
      message: 'TRC-001 exited the designated farming zone in Nueva Ecija.',
      tractorLabel: 'TRC-001',
      timeAgo: '5 min ago',
      isAcknowledged: false,
    ),
    _AlertItem(
      id: 2,
      type: 'speed',
      title: 'Over-speed Alert',
      message: 'TRC-005 exceeded 40 km/h on a rural road in Davao.',
      tractorLabel: 'TRC-005',
      timeAgo: '12 min ago',
      isAcknowledged: false,
    ),
    _AlertItem(
      id: 3,
      type: 'maintenance',
      title: 'Maintenance Due',
      message: 'TRC-003 has reached 500 km since last oil change.',
      tractorLabel: 'TRC-003',
      timeAgo: '1 hour ago',
      isAcknowledged: false,
    ),
    _AlertItem(
      id: 4,
      type: 'offline',
      title: 'Device Offline',
      message: 'TRC-006 GPS device lost connection in Cebu.',
      tractorLabel: 'TRC-006',
      timeAgo: '2 hours ago',
      isAcknowledged: true,
    ),
    _AlertItem(
      id: 5,
      type: 'geofence',
      title: 'Geofence Entry',
      message:
          'TRC-011 entered the designated area in Pangasinan farming zone.',
      tractorLabel: 'TRC-011',
      timeAgo: '3 hours ago',
      isAcknowledged: true,
    ),
    _AlertItem(
      id: 6,
      type: 'speed',
      title: 'Over-speed Alert',
      message: 'TRC-008 exceeded 35 km/h near Bukidnon highway.',
      tractorLabel: 'TRC-008',
      timeAgo: '5 hours ago',
      isAcknowledged: true,
    ),
    _AlertItem(
      id: 7,
      type: 'maintenance',
      title: 'Maintenance Overdue',
      message: 'TRC-009 is 200 km overdue for scheduled maintenance.',
      tractorLabel: 'TRC-009',
      timeAgo: 'Yesterday',
      isAcknowledged: true,
    ),
    _AlertItem(
      id: 8,
      type: 'offline',
      title: 'Extended Offline',
      message: 'TRC-003 has been offline for 48+ hours in Zambales.',
      tractorLabel: 'TRC-003',
      timeAgo: '2 days ago',
      isAcknowledged: true,
    ),
  ];

  List<_AlertItem> get _filteredAlerts {
    if (_filter == 'all') return _alerts;
    if (_filter == 'unread') {
      return _alerts.where((a) => !a.isAcknowledged).toList();
    }
    return _alerts.where((a) => a.type == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _alerts.where((a) => !a.isAcknowledged).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      body: CustomScrollView(
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
                    if (unreadCount > 0)
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
                          '$unreadCount',
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
                onPressed: () {},
                icon: const Icon(Icons.done_all_rounded, color: AppColors.pine),
                tooltip: 'Mark all as read',
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
                    onTap: () => setState(() => _filter = 'all'),
                  ),
                  _FilterChip(
                    label: 'Unread',
                    isActive: _filter == 'unread',
                    onTap: () => setState(() => _filter = 'unread'),
                  ),
                  _FilterChip(
                    label: 'Geofence',
                    isActive: _filter == 'geofence',
                    onTap: () => setState(() => _filter = 'geofence'),
                  ),
                  _FilterChip(
                    label: 'Speed',
                    isActive: _filter == 'speed',
                    onTap: () => setState(() => _filter = 'speed'),
                  ),
                  _FilterChip(
                    label: 'Maintenance',
                    isActive: _filter == 'maintenance',
                    onTap: () => setState(() => _filter = 'maintenance'),
                  ),
                  _FilterChip(
                    label: 'Offline',
                    isActive: _filter == 'offline',
                    onTap: () => setState(() => _filter = 'offline'),
                  ),
                ],
              ),
            ),
          ),

          // ─── Alert List ───
          if (_filteredAlerts.isEmpty)
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
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.separated(
                itemCount: _filteredAlerts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final alert = _filteredAlerts[index];
                  return _AlertCard(alert: alert);
                },
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
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
  const _AlertCard({required this.alert});

  final _AlertItem alert;

  IconData get _icon {
    switch (alert.type) {
      case 'geofence':
        return Icons.fence_rounded;
      case 'speed':
        return Icons.speed_rounded;
      case 'maintenance':
        return Icons.build_circle_rounded;
      case 'offline':
        return Icons.wifi_off_rounded;
      default:
        return Icons.warning_amber_rounded;
    }
  }

  Color get _color {
    switch (alert.type) {
      case 'geofence':
        return AppColors.warning;
      case 'speed':
        return AppColors.danger;
      case 'maintenance':
        return AppColors.clay;
      case 'offline':
        return AppColors.mutedInk;
      default:
        return AppColors.ink;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
                        alert.tractorLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.forest,
                        ),
                      ),
                    ),
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
    );
  }
}

class _AlertItem {
  const _AlertItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.tractorLabel,
    required this.timeAgo,
    required this.isAcknowledged,
  });

  final int id;
  final String type;
  final String title;
  final String message;
  final String tractorLabel;
  final String timeAgo;
  final bool isAcknowledged;
}
