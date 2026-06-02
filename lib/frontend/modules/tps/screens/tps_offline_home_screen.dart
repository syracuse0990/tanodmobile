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
  final DateFormat _dateFormat = DateFormat('MMM d, yyyy • h:mm a');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _loadOfflineWorkspace(),
    );
  }

  Future<void> _loadOfflineWorkspace() async {
    if (!mounted) {
      return;
    }

    setState(() => _loading = true);
    await context.read<TpsProvider>().loadOfflineWorkspaceSnapshot();

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  String _formatLastDownloaded(DateTime? value) {
    if (value == null) {
      return 'No form data update yet';
    }

    return _dateFormat.format(value.toLocal());
  }

  Future<void> _refreshOfflineData(AuthProvider authProvider) async {
    if (!authProvider.isConnected) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Connect to the internet first to refresh offline form data.',
            ),
          ),
        );
      return;
    }

    await context.push('/tps/offline-download?manual=1');
    if (!mounted) {
      return;
    }

    await _loadOfflineWorkspace();
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
        final formDataStatus = provider.offlineReferenceDataSyncedAt == null
            ? 'Data not updated yet'
            : 'Data updated ${_formatLastDownloaded(provider.offlineReferenceDataSyncedAt)}';

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7F6),
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            title: const Text(
              'Offline Work',
              style: TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w800,
              ),
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
          body: RefreshIndicator(
            color: AppColors.forest,
            onRefresh: _loadOfflineWorkspace,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.ink.withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _StatusPill(
                            icon: authProvider.isConnected
                                ? Icons.wifi_tethering_rounded
                                : Icons.cloud_off_rounded,
                            label: authProvider.isConnected
                                ? 'Online'
                                : 'Offline',
                            color: authProvider.isConnected
                                ? AppColors.success
                                : AppColors.pine,
                          ),
                          _StatusPill(
                            icon: Icons.folder_copy_rounded,
                            label:
                                '$totalLocalDrafts local draft${totalLocalDrafts == 1 ? '' : 's'}',
                            color: AppColors.clay,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Pick a module',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        authProvider.isConnected
                            ? 'Open a module or update data while you have signal.'
                            : 'Open a module and keep saving drafts on this phone.',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.mutedInk,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        formDataStatus,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mutedInk,
                        ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: () => _refreshOfflineData(authProvider),
                        icon: const Icon(Icons.cloud_sync_rounded),
                        label: Text(
                          authProvider.isConnected
                              ? 'Update data'
                              : 'Need signal to update',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.forest,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.forest),
                    ),
                  )
                else ...[
                  OfflineLocationCacheCard(summary: offlineLocationSummary),
                  const SizedBox(height: 14),
                  _OfflineModuleCard(
                    title: 'Tractor Distribution',
                    subtitle: 'Open drafts',
                    icon: Icons.local_shipping_rounded,
                    color: AppColors.pine,
                    countLabel:
                        '${provider.offlineDistributionDrafts.length} draft${provider.offlineDistributionDrafts.length == 1 ? '' : 's'}',
                    statusLabel: 'Save drafts',
                    onTap: () => context.push('/tps/offline/distributions'),
                  ),
                  const SizedBox(height: 14),
                  _OfflineModuleCard(
                    title: 'Offline Revisit',
                    subtitle: 'Open drafts',
                    icon: Icons.groups_2_rounded,
                    color: AppColors.forest,
                    countLabel:
                        '${provider.offlineFcaDrafts.length} draft${provider.offlineFcaDrafts.length == 1 ? '' : 's'}',
                    statusLabel: offlineLocationSummary.hasData
                        ? '${offlineLocationSummary.provinceCount} ${offlineLocationSummary.provinceCount == 1 ? 'province' : 'provinces'} ready'
                        : 'Update data first',
                    onTap: () => context.push('/tps/offline/fcas'),
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

class _OfflineModuleCard extends StatelessWidget {
  const _OfflineModuleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.countLabel,
    required this.statusLabel,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String countLabel;
  final String statusLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
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
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: color, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
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
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_rounded, color: color),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _StatusPill(
                    icon: Icons.edit_note_rounded,
                    label: countLabel,
                    color: color,
                  ),
                  _StatusPill(
                    icon: Icons.check_circle_outline_rounded,
                    label: statusLabel,
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({
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
