import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';

class DashboardShell extends StatelessWidget {
  const DashboardShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
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
              onTabChange: (index) => navigationShell.goBranch(index),
              gap: 8,
              activeColor: AppColors.forest,
              iconSize: 22,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              duration: const Duration(milliseconds: 400),
              tabBackgroundColor: AppColors.forest.withValues(alpha: 0.08),
              color: AppColors.mutedInk,
              tabBorderRadius: 16,
              tabs: const [
                GButton(
                  icon: Icons.home_rounded,
                  text: 'Home',
                  iconActiveColor: AppColors.forest,
                  textStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                  ),
                ),
                GButton(
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
                  icon: Icons.calendar_month_rounded,
                  text: 'Booking',
                  iconActiveColor: AppColors.forest,
                  textStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                  ),
                ),
                GButton(
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
