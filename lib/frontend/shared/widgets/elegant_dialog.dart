import 'package:flutter/material.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';

enum ElegantDialogType { confirmation, info, success, warning }

class ElegantDialog extends StatefulWidget {
  const ElegantDialog({
    super.key,
    required this.type,
    required this.title,
    required this.message,
    this.confirmText,
    this.cancelText = 'Cancel',
    this.onConfirm,
    this.onConfirmAsync,
    this.onCancel,
  });

  final ElegantDialogType type;
  final String title;
  final String message;
  final String? confirmText;
  final String cancelText;
  final VoidCallback? onConfirm;
  final Future<void> Function()? onConfirmAsync;
  final VoidCallback? onCancel;

  static Future<bool?> show(
    BuildContext context, {
    required ElegantDialogType type,
    required String title,
    required String message,
    String? confirmText,
    String cancelText = 'Cancel',
    VoidCallback? onConfirm,
    Future<void> Function()? onConfirmAsync,
    VoidCallback? onCancel,
  }) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) => ElegantDialog(
        type: type,
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        onConfirm: onConfirm,
        onConfirmAsync: onConfirmAsync,
        onCancel: onCancel,
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curved,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }

  @override
  State<ElegantDialog> createState() => _ElegantDialogState();
}

class _ElegantDialogState extends State<ElegantDialog>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color get _accentColor => switch (widget.type) {
        ElegantDialogType.confirmation => AppColors.forest,
        ElegantDialogType.info => const Color(0xFF3B82F6),
        ElegantDialogType.success => AppColors.success,
        ElegantDialogType.warning => AppColors.danger,
      };

  Color get _iconBgColor => _accentColor.withValues(alpha: 0.1);

  IconData get _icon => switch (widget.type) {
        ElegantDialogType.confirmation => Icons.help_outline_rounded,
        ElegantDialogType.info => Icons.info_outline_rounded,
        ElegantDialogType.success => Icons.check_circle_outline_rounded,
        ElegantDialogType.warning => Icons.warning_amber_rounded,
      };

  String get _defaultConfirmText => switch (widget.type) {
        ElegantDialogType.confirmation => 'Confirm',
        ElegantDialogType.info => 'OK',
        ElegantDialogType.success => 'OK',
        ElegantDialogType.warning => 'Delete',
      };

  Future<void> _handleConfirm() async {
    if (_loading) return;

    if (widget.onConfirmAsync != null) {
      setState(() => _loading = true);
      _pulseController.repeat(reverse: true);
      try {
        await widget.onConfirmAsync!();
      } finally {
        if (mounted) {
          _pulseController.stop();
          Navigator.pop(context, true);
        }
      }
    } else {
      Navigator.pop(context, true);
      widget.onConfirm?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveConfirmText = widget.confirmText ?? _defaultConfirmText;
    final showCancel =
        widget.type == ElegantDialogType.confirmation ||
        widget.type == ElegantDialogType.warning;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 32),

                // Icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_icon, size: 32, color: _accentColor),
                ),

                const SizedBox(height: 20),

                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      height: 1.3,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Message
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    widget.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.mutedInk,
                      height: 1.5,
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Row(
                    children: [
                      if (showCancel) ...[
                        Expanded(
                          child: OutlinedButton(
                              onPressed: _loading
                                  ? null
                                  : () {
                                      Navigator.pop(context, false);
                                      widget.onCancel?.call();
                                    },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.mutedInk,
                                minimumSize: const Size.fromHeight(48),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                side: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                widget.cancelText,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _loading ? _pulseAnimation.value : 1.0,
                              child: child,
                            );
                          },
                          child: ElevatedButton(
                            onPressed: _loading ? null : _handleConfirm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accentColor,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  _accentColor.withValues(alpha: 0.7),
                              minimumSize: const Size.fromHeight(48),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: _loading
                                  ? const SizedBox(
                                      key: ValueKey('loader'),
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      effectiveConfirmText,
                                      key: const ValueKey('text'),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
