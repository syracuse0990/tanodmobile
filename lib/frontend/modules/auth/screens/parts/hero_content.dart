import 'package:flutter/material.dart';
import 'package:tanodmobile/frontend/modules/auth/screens/login_screen.dart';
import 'package:tanodmobile/frontend/modules/auth/screens/parts/tractor_fleet.dart';

class HeroContent extends StatelessWidget {
  const HeroContent({super.key, required this.authMode});

  final AuthMode authMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final tractorW = (constraints.maxWidth * 0.36).clamp(90.0, 150.0);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    authMode == AuthMode.login
                        ? 'Rent, Track &\nManage Tractors'
                        : 'Join the Smart\nFarming Platform',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    authMode == AuthMode.login
                        ? 'Real-time GPS tracking, booking &\nfleet management for Filipino farmers.'
                        : 'Create your account and start\nmanaging your farm operations.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TractorFleet(width: tractorW),
          ],
        );
      },
    );
  }
}
