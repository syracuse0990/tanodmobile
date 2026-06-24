import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/core/locale/app_localizations.dart';
import 'package:tanodmobile/frontend/shared/providers/auth_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/chat_unread_provider.dart';
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
  /// The farmers module lives under Account for FCA users, so it is hidden
  /// from the bottom navigation while keeping the legacy branch index intact.
  List<int> _visibleBranchIndices({required bool showChat}) {
    return [0, 1, 2, if (showChat) 3, 5];
  }

  int _tabToBranch(int tabIndex, List<int> visibleBranches) {
    return visibleBranches[tabIndex];
  }

  int _branchToTab(int branchIndex, List<int> visibleBranches) {
    final tabIndex = visibleBranches.indexOf(branchIndex);
    return tabIndex >= 0 ? tabIndex : visibleBranches.length - 1;
  }

  String _branchRootPath(int branchIndex, bool isTps) {
    return switch (branchIndex) {
      0 => '/home',
      1 => '/alerts',
      2 => isTps ? '/tps' : '/bookings',
      3 => '/chat',
      5 => '/account',
      _ => '/home',
    };
  }

  @override
  Widget build(BuildContext context) {
    final isTps = _isTps(context);
    final isFca = _isFca(context);
    final showChat = isTps || isFca;
    final visibleBranches = _visibleBranchIndices(showChat: showChat);
    final tractorProvider = context.read<TractorProvider>();
    final chatUnreadCount = context
        .watch<ChatUnreadProvider>()
        .totalUnreadCount;

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
              selectedIndex: _branchToTab(
                navigationShell.currentIndex,
                visibleBranches,
              ),
              onTabChange: (index) {
                final branchIndex = _tabToBranch(index, visibleBranches);

                // Tap on already-active tab → reset branch to its root
                if (branchIndex == navigationShell.currentIndex) {
                  final rootPath = _branchRootPath(
                    branchIndex,
                    isTps,
                  );
                  GoRouter.of(context).go(rootPath);
                  return;
                }

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
                if (showChat)
                  GButton(
                    icon: Icons.forum_rounded,
                    text: context.tr('nav_chat'),
                    leading: _BottomNavIcon(
                      icon: Icons.forum_rounded,
                      unreadCount: chatUnreadCount,
                      active: navigationShell.currentIndex == 3,
                    ),
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

class _BottomNavIcon extends StatelessWidget {
  const _BottomNavIcon({
    required this.icon,
    required this.unreadCount,
    required this.active,
  });

  final IconData icon;
  final int unreadCount;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final iconColor = active ? AppColors.forest : AppColors.mutedInk;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: iconColor, size: 22),
        if (unreadCount > 0)
          Positioned(
            right: -7,
            top: -7,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              decoration: const BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.all(Radius.circular(999)),
              ),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
