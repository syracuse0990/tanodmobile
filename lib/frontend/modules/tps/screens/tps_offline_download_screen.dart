import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/core/errors/app_exception.dart';
import 'package:tanodmobile/frontend/shared/providers/auth_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/tps_provider.dart';

enum _OfflineSyncStep { referenceData }

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
  _OfflineSyncStep _activeStep = _OfflineSyncStep.referenceData;
  bool _referenceDataReady = false;

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
      _activeStep = _OfflineSyncStep.referenceData;
      _referenceDataReady = false;
    });

    final authProvider = context.read<AuthProvider>();
    final tpsProvider = context.read<TpsProvider>();

    try {
      await tpsProvider.syncOfflineReferenceData();
      if (!mounted) {
        return;
      }

      setState(() => _referenceDataReady = true);

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
      context.go('/home');
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
      context.pop();
      return;
    }

    if (context.read<AuthProvider>().isOfflineMode) {
      context.go('/tps/offline');
      return;
    }

    context.go('/tps');
  }

  void _continueToDashboard() {
    if (widget.isManualSync) {
      _closeScreen();
      return;
    }

    context.read<AuthProvider>().completeTpsOfflineSync();
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.isManualSync && !_isSyncing,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7F6),
        body: SafeArea(
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
                    _SyncStepTile(
                      title: 'Offline form data',
                      subtitle: _referenceDataReady
                          ? 'Dropdown and reference data are ready on this phone.'
                          : 'Prepare the dropdown and reference data used by offline forms.',
                      status:
                          _errorMessage != null &&
                              _activeStep == _OfflineSyncStep.referenceData
                          ? _SyncStepStatus.error
                          : _referenceDataReady
                          ? _SyncStepStatus.completed
                          : _activeStep == _OfflineSyncStep.referenceData
                          ? _SyncStepStatus.active
                          : _SyncStepStatus.pending,
                    ),
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
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _continueToDashboard,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.mutedInk,
                                minimumSize: const Size.fromHeight(50),
                                side: BorderSide(
                                  color: AppColors.ink.withValues(alpha: 0.10),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                widget.isManualSync
                                    ? 'Close'
                                    : 'Continue to dashboard',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: _startSync,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.forest,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                widget.isManualSync
                                    ? 'Retry refresh'
                                    : 'Retry download',
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
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

class _SyncStepTile extends StatelessWidget {
  const _SyncStepTile({
    required this.title,
    required this.subtitle,
    required this.status,
  });

  final String title;
  final String subtitle;
  final _SyncStepStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      _SyncStepStatus.pending => AppColors.mutedInk,
      _SyncStepStatus.active => AppColors.forest,
      _SyncStepStatus.completed => AppColors.success,
      _SyncStepStatus.error => AppColors.danger,
    };
    final icon = switch (status) {
      _SyncStepStatus.pending => Icons.circle_outlined,
      _SyncStepStatus.active => Icons.downloading_rounded,
      _SyncStepStatus.completed => Icons.check_circle_rounded,
      _SyncStepStatus.error => Icons.error_outline_rounded,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.mutedInk,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
