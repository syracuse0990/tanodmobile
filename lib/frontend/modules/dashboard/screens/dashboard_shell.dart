import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/core/locale/app_localizations.dart';
import 'package:tanodmobile/frontend/shared/providers/auth_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/tractor_provider.dart';
import 'package:tanodmobile/frontend/shared/widgets/force_change_password_dialog.dart';

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  bool _hasShownPasswordDialog = false;

  StatefulNavigationShell get navigationShell => widget.navigationShell;

  bool _isTps(BuildContext context) {
    final roles = context.read<AuthProvider>().session?.roles ?? [];
    return roles.contains('tps');
  }

  bool _isFca(BuildContext context) {
    final roles = context.read<AuthProvider>().session?.roles ?? [];
    return roles.contains('fca');
  }

  /// Maps a GNav tab index to the router branch index.
  /// Non-FCA users skip branch 3 (Farmers), so tab 3 → branch 4.
  int _tabToBranch(int tabIndex, bool isFca) {
    if (isFca || tabIndex < 3) return tabIndex;
    return tabIndex + 1; // skip farmers branch
  }

  /// Maps a router branch index to the GNav tab index.
  int _branchToTab(int branchIndex, bool isFca) {
    if (isFca || branchIndex < 3) return branchIndex;
    return branchIndex - 1; // farmers branch hidden
  }

  @override
  Widget build(BuildContext context) {
    final isTps = _isTps(context);
    final isFca = _isFca(context);
    final tractorProvider = context.read<TractorProvider>();

    // Show forced password change dialog for newly created users
    if (!_hasShownPasswordDialog) {
      _hasShownPasswordDialog = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ForceChangePasswordDialog.showIfRequired(context);
        }
      });
    }

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
              selectedIndex: _branchToTab(navigationShell.currentIndex, isFca),
              onTabChange: (index) {
                final branchIndex = _tabToBranch(index, isFca);
                tractorProvider.setHomeVisible(branchIndex == 0);
                navigationShell.goBranch(branchIndex);
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
                GButton(
                  icon: Icons.home_rounded,
                  text: context.tr('nav_home'),
                  iconActiveColor: AppColors.forest,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                  ),
                ),
                GButton(
                  icon: Icons.notifications_active_rounded,
                  text: context.tr('nav_alerts'),
                  iconActiveColor: AppColors.forest,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                  ),
                ),
                GButton(
                  icon: isTps
                      ? Icons.build_circle_rounded
                      : Icons.calendar_month_rounded,
                  text: isTps
                      ? context.tr('nav_tps')
                      : context.tr('nav_booking'),
                  iconActiveColor: AppColors.forest,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                  ),
                ),
                if (isFca)
                  GButton(
                    icon: Icons.people_rounded,
                    text: context.tr('nav_farmers'),
                    iconActiveColor: AppColors.forest,
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forest,
                    ),
                  ),
                GButton(
                  icon: Icons.person_rounded,
                  text: context.tr('nav_account'),
                  iconActiveColor: AppColors.forest,
                  textStyle: const TextStyle(
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
