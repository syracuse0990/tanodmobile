import 'package:flutter/material.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';

class MapFabControls extends StatelessWidget {
  const MapFabControls({
    super.key,
    required this.showSatellite,
    required this.onToggleSatellite,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onRecenter,
    required this.dark,
    required this.secondsUntilPoll,
    this.showTractorActions = false,
    this.onShareLocation,
    this.onTrackHistory,
    this.onClearFocus,
  });

  final bool showSatellite;
  final VoidCallback onToggleSatellite;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onRecenter;
  final bool dark;
  final int secondsUntilPoll;
  final bool showTractorActions;
  final VoidCallback? onShareLocation;
  final VoidCallback? onTrackHistory;
  final VoidCallback? onClearFocus;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ─── Poll countdown badge ───
        Container(
          width: 44,
          padding: const EdgeInsets.symmetric(vertical: 4),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: dark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: dark
                ? null
                : [
                    BoxShadow(
                      color: AppColors.ink.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            children: [
              Icon(
                Icons.sync_rounded,
                size: 14,
                color: dark ? Colors.white54 : AppColors.mutedInk,
              ),
              const SizedBox(height: 1),
              Text(
                '${secondsUntilPoll}s',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: dark ? Colors.white70 : AppColors.mutedInk,
                ),
              ),
            ],
          ),
        ),

        // ─── Main map controls ───
        Container(
          decoration: BoxDecoration(
            color: dark ? Colors.white.withValues(alpha: 0.12) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: dark
                ? null
                : [
                    BoxShadow(
                      color: AppColors.ink.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FabButton(
                icon: Icons.add_rounded,
                onTap: onZoomIn,
                dark: dark,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              _Divider(dark: dark),
              _FabButton(
                icon: Icons.remove_rounded,
                onTap: onZoomOut,
                dark: dark,
              ),
              _Divider(dark: dark),
              _FabButton(
                icon: Icons.my_location_rounded,
                onTap: onRecenter,
                dark: dark,
              ),
              _Divider(dark: dark),
              _FabButton(
                icon: showSatellite
                    ? Icons.map_rounded
                    : Icons.satellite_alt_rounded,
                onTap: onToggleSatellite,
                dark: dark,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
            ],
          ),
        ),

        // ─── Tractor-specific actions (when focused) ───
        if (showTractorActions) ...[
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color:
                  dark ? Colors.white.withValues(alpha: 0.12) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: dark
                  ? null
                  : [
                      BoxShadow(
                        color: AppColors.ink.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _FabButton(
                  icon: Icons.share_location_rounded,
                  onTap: onShareLocation ?? () {},
                  dark: dark,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                _Divider(dark: dark),
                _FabButton(
                  icon: Icons.route_rounded,
                  onTap: onTrackHistory ?? () {},
                  dark: dark,
                ),
                _Divider(dark: dark),
                _FabButton(
                  icon: Icons.close_rounded,
                  onTap: onClearFocus ?? () {},
                  dark: dark,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _FabButton extends StatelessWidget {
  const _FabButton({
    required this.icon,
    required this.onTap,
    required this.dark,
    this.borderRadius,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool dark;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(
            icon,
            size: 20,
            color: dark ? Colors.white70 : AppColors.ink,
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      width: 28,
      color: dark
          ? Colors.white.withValues(alpha: 0.08)
          : AppColors.ink.withValues(alpha: 0.06),
    );
  }
}
