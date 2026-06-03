import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/core/errors/app_exception.dart';
import 'package:tanodmobile/frontend/shared/providers/auth_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/tps_provider.dart';

enum _OfflineSyncStep { locations, tractors, users }

class TpsOfflineDownloadScreen extends StatefulWidget {
  const TpsOfflineDownloadScreen({super.key, this.isManualSync = false});

  final bool isManualSync;

  @override
  State<TpsOfflineDownloadScreen> createState() =>
      _TpsOfflineDownloadScreenState();
}

class _TpsOfflineDownloadScreenState extends State<TpsOfflineDownloadScreen> {
  bool _isSyncing = false;
  String? _errorMessage;
  _OfflineSyncStep _activeStep = _OfflineSyncStep.locations;
  bool _locationsReady = false;
  bool _tractorsReady = false;
  bool _usersReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startSync());
  }

  Future<void> _startSync() async {
    if (_isSyncing || !mounted) {
      return;
    }

    setState(() {
      _isSyncing = true;
      _errorMessage = null;
      _activeStep = _OfflineSyncStep.locations;
      _locationsReady = false;
      _tractorsReady = false;
      _usersReady = false;
    });

    final authProvider = context.read<AuthProvider>();
    final tpsProvider = context.read<TpsProvider>();

    try {
      setState(() => _activeStep = _OfflineSyncStep.locations);
      await tpsProvider.syncOfflineFcaLocationCache();
      if (!mounted) return;
      setState(() => _locationsReady = true);

      setState(() => _activeStep = _OfflineSyncStep.tractors);
      await tpsProvider.syncOfflineTractorOptions();
      if (!mounted) return;
      setState(() => _tractorsReady = true);

      setState(() => _activeStep = _OfflineSyncStep.users);
      await tpsProvider.syncOfflineUserOptions();
      if (!mounted) return;
      setState(() => _usersReady = true);

      await tpsProvider.finalizeOfflineReferenceDataSync();
      if (!mounted) return;

      if (widget.isManualSync) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Offline TPS data refreshed successfully.'),
            ),
          );
        _closeScreen();
        return;
      }

      authProvider.completeTpsOfflineSync();
      GoRouter.of(context).go('/home');
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _errorMessage = error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(
        () => _errorMessage =
            'Failed to download offline TPS data. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  void _closeScreen() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    final router = GoRouter.of(context);
    if (context.read<AuthProvider>().isOfflineMode) {
      router.go('/tps/offline');
      return;
    }

    router.go('/tps');
  }

  void _continueToDashboard() {
    if (widget.isManualSync) {
      _closeScreen();
      return;
    }

    context.read<AuthProvider>().completeTpsOfflineSync();
    GoRouter.of(context).go('/home');
  }

  _SyncStepStatus _statusFor({bool locations = false, bool tractors = false, bool users = false}) {
    if (_errorMessage != null) {
      if (locations && _activeStep == _OfflineSyncStep.locations) return _SyncStepStatus.error;
      if (tractors && _activeStep == _OfflineSyncStep.tractors) return _SyncStepStatus.error;
      if (users && _activeStep == _OfflineSyncStep.users) return _SyncStepStatus.error;
    }
    if (locations) return _locationsReady ? _SyncStepStatus.completed : _activeStep == _OfflineSyncStep.locations ? _SyncStepStatus.active : _SyncStepStatus.pending;
    if (tractors) return _tractorsReady ? _SyncStepStatus.completed : _activeStep == _OfflineSyncStep.tractors ? _SyncStepStatus.active : _SyncStepStatus.pending;
    if (users) return _usersReady ? _SyncStepStatus.completed : _activeStep == _OfflineSyncStep.users ? _SyncStepStatus.active : _SyncStepStatus.pending;
    return _SyncStepStatus.pending;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.isManualSync && !_isSyncing,
      child: Scaffold(
        backgroundColor: AppColors.pine,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C), Color(0xFF43A047)],
            ),
          ),
          child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 460),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.ink.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.isManualSync)
                      Align(
                        alignment: Alignment.topRight,
                        child: IconButton(
                          onPressed: _isSyncing ? null : _closeScreen,
                          tooltip: 'Close',
                          icon: const Icon(
                            Icons.close_rounded,
                            color: AppColors.mutedInk,
                          ),
                        ),
                      ),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.forest.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        widget.isManualSync
                            ? Icons.cloud_sync_rounded
                            : Icons.cloud_download_rounded,
                        size: 30,
                        color: AppColors.forest,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      widget.isManualSync
                          ? 'Refresh TPS offline data'
                          : 'Preparing TPS offline data',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage == null
                          ? widget.isManualSync
                                ? 'Download the latest dropdown and reference data needed for offline forms on this device.'
                                : 'Please wait while this device prepares the dropdown and reference data needed for offline forms.'
                          : widget.isManualSync
                          ? 'The refresh did not finish. You can retry now or close this screen.'
                          : 'The offline download did not finish. You can retry now or continue to the dashboard and download again later.',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.mutedInk,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _StepCard(icon: Icons.map_rounded, label: 'Provinces and cities', sublabel: 'FCA location reference data',
                      status: _statusFor(locations: true)),
                    const SizedBox(height: 8),
                    _StepCard(icon: Icons.agriculture_rounded, label: 'Tractor list', sublabel: 'Tractor models and serials',
                      status: _statusFor(tractors: true)),
                    const SizedBox(height: 8),
                    _StepCard(icon: Icons.people_rounded, label: 'In-charge users', sublabel: 'TPS personnel assignments',
                      status: _statusFor(users: true)),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.16),
                          ),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.danger,
                            fontWeight: FontWeight.w600,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (_isSyncing)
                      Row(
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: AppColors.forest,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.isManualSync
                                  ? 'Refreshing TPS offline data...'
                                  : 'Preparing TPS offline form data...',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            if (widget.isManualSync) { _closeScreen(); return; }
                            context.read<AuthProvider>().completeTpsOfflineSync();
                            GoRouter.of(context).go('/home');
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.forest,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text(widget.isManualSync ? 'Close' : 'Continue to dashboard'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          ),
        ),
      ),
    );
  }
}

enum _SyncStepStatus { pending, active, completed, error }

class _StepCard extends StatelessWidget {
  const _StepCard({required this.icon, required this.label, required this.sublabel, required this.status});
  final IconData icon;
  final String label;
  final String sublabel;
  final _SyncStepStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      _SyncStepStatus.pending => AppColors.mutedInk,
      _SyncStepStatus.active => AppColors.forest,
      _SyncStepStatus.completed => AppColors.success,
      _SyncStepStatus.error => AppColors.danger,
    };
    final statusIcon = switch (status) {
      _SyncStepStatus.pending => Icons.circle_outlined,
      _SyncStepStatus.active => Icons.downloading_rounded,
      _SyncStepStatus.completed => Icons.check_circle_rounded,
      _SyncStepStatus.error => Icons.error_outline_rounded,
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.12))),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
          child: Icon(status == _SyncStepStatus.active ? Icons.downloading_rounded : icon, size: 20, color: color)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(sublabel, style: const TextStyle(fontSize: 11, color: AppColors.mutedInk, height: 1.3)),
        ])),
        const SizedBox(width: 8),
        if (status == _SyncStepStatus.active)
          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.forest))
        else
          Icon(statusIcon, size: 22, color: color),
      ]),
    );
  }
}
