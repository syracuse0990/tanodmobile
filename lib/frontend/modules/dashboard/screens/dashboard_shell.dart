import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/frontend/shared/providers/auth_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/tractor_provider.dart';

class DashboardShell extends StatelessWidget {
  const DashboardShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  bool _isTps(BuildContext context) {
    final roles = context.read<AuthProvider>().session?.roles ?? [];
    return roles.contains('tps');
  }

  @override
  Widget build(BuildContext context) {
    final isTps = _isTps(context);
    final tractorProvider = context.read<TractorProvider>();

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: GNav(
              selectedIndex: navigationShell.currentIndex,
              onTabChange: (index) {
                tractorProvider.setHomeVisible(index == 0);
                navigationShell.goBranch(index);
              },
              gap: 8,
              activeColor: AppColors.forest,
              iconSize: 22,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              duration: const Duration(milliseconds: 400),
              tabBackgroundColor: AppColors.forest.withValues(alpha: 0.08),
              color: AppColors.mutedInk,
              tabBorderRadius: 16,
              tabs: [
                const GButton(
                  icon: Icons.home_rounded,
                  text: 'Home',
                  iconActiveColor: AppColors.forest,
                  textStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                  ),
                ),
                const GButton(
                  icon: Icons.notifications_active_rounded,
                  text: 'Alerts',
                  iconActiveColor: AppColors.forest,
                  textStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                  ),
                ),
                GButton(
                  icon: isTps
                      ? Icons.build_circle_rounded
                      : Icons.calendar_month_rounded,
                  text: isTps ? 'TPS' : 'Booking',
                  iconActiveColor: AppColors.forest,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                  ),
                ),
                const GButton(
                  icon: Icons.person_rounded,
                  text: 'Account',
                  iconActiveColor: AppColors.forest,
                  textStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
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
