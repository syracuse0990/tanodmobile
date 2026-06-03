import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/frontend/shared/providers/auth_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/tps_provider.dart';
import 'package:tanodmobile/frontend/modules/tps/widgets/offline_location_cache_card.dart';

class TpsOfflineHomeScreen extends StatefulWidget {
  const TpsOfflineHomeScreen({super.key});

  @override
  State<TpsOfflineHomeScreen> createState() => _TpsOfflineHomeScreenState();
}

class _TpsOfflineHomeScreenState extends State<TpsOfflineHomeScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _loadOfflineWorkspace(),
    );
  }

  Future<void> _loadOfflineWorkspace() async {
    if (!mounted) return;
    setState(() => _loading = true);
    await context.read<TpsProvider>().loadOfflineWorkspaceSnapshot();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _signOut() async {
    await context.read<AuthProvider>().signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<TpsProvider, AuthProvider>(
      builder: (context, provider, authProvider, _) {
        final totalLocalDrafts =
            provider.offlineDistributionDrafts.length +
            provider.offlineFcaDrafts.length;
        final offlineLocationSummary = provider.offlineLocationCacheSummary;
        final isOnline = authProvider.isConnected;

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7F6),
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: isOnline ? AppColors.success : AppColors.pine,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isOnline ? AppColors.success : AppColors.pine)
                            .withValues(alpha: 0.4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Offline Work',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sign out'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.mutedInk,
                ),
              ),
            ],
          ),
          body: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.forest),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // ── Status bar ──
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.ink.withValues(alpha: 0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          _StatusDot(
                            color: isOnline
                                ? AppColors.success
                                : AppColors.pine,
                            label: isOnline ? 'Online' : 'Offline',
                          ),
                          const SizedBox(width: 14),
                          _StatusDot(
                            color: totalLocalDrafts > 0
                                ? AppColors.clay
                                : AppColors.mutedInk,
                            label:
                                '$totalLocalDrafts draft${totalLocalDrafts == 1 ? '' : 's'}',
                          ),
                          const Spacer(),
                          Icon(
                            isOnline
                                ? Icons.wifi_tethering_rounded
                                : Icons.cloud_off_rounded,
                            size: 18,
                            color: isOnline
                                ? AppColors.success
                                : AppColors.pine,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Section header ──
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 12),
                      child: Text(
                        'Work modules',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),

                    // ── Tractor Distribution ──
                    _OfflineModuleCard(
                      title: 'Tractor Distribution',
                      subtitle: 'Assign tractors to farmers',
                      icon: Icons.local_shipping_rounded,
                      color: AppColors.pine,
                      countLabel:
                          '${provider.offlineDistributionDrafts.length} draft${provider.offlineDistributionDrafts.length == 1 ? '' : 's'}',
                      secondaryLabel: 'Save drafts offline',
                      onTap: () => context.push('/tps/offline/distributions'),
                    ),
                    const SizedBox(height: 14),

                    // ── Offline Revisit ──
                    _OfflineModuleCard(
                      title: 'Offline Revisit',
                      subtitle: 'Manage FCA visits',
                      icon: Icons.groups_2_rounded,
                      color: AppColors.forest,
                      countLabel:
                          '${provider.offlineFcaDrafts.length} draft${provider.offlineFcaDrafts.length == 1 ? '' : 's'}',
                      secondaryLabel: offlineLocationSummary.hasData
                          ? '${offlineLocationSummary.provinceCount} ${offlineLocationSummary.provinceCount == 1 ? 'province' : 'provinces'} cached'
                          : 'No location cache',
                      onTap: () => context.push('/tps/offline/fcas'),
                    ),
                    const SizedBox(height: 14),

                    // ── Location cache summary ──
                    OfflineLocationCacheCard(summary: offlineLocationSummary),
                  ],
                ),
        );
      },
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _OfflineModuleCard extends StatelessWidget {
  const _OfflineModuleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.countLabel,
    required this.secondaryLabel,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String countLabel;
  final String secondaryLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.mutedInk,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: color,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _ModuleChip(
                    icon: Icons.edit_note_rounded,
                    label: countLabel,
                    color: color,
                  ),
                  const SizedBox(width: 10),
                  _ModuleChip(
                    icon: Icons.check_circle_outline_rounded,
                    label: secondaryLabel,
                    color: AppColors.clay,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModuleChip extends StatelessWidget {
  const _ModuleChip({
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
