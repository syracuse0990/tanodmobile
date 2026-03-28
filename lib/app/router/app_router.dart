import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:tanodmobile/frontend/modules/alerts/screens/alerts_screen.dart';
import 'package:tanodmobile/frontend/modules/auth/screens/login_screen.dart';
import 'package:tanodmobile/frontend/modules/bookings/screens/bookings_screen.dart';
import 'package:tanodmobile/frontend/modules/dashboard/screens/dashboard_shell.dart';
import 'package:tanodmobile/frontend/modules/home/screens/home_screen.dart';
import 'package:tanodmobile/frontend/modules/profile/screens/account_screen.dart';
import 'package:tanodmobile/frontend/modules/splash/screens/splash_screen.dart';
import 'package:tanodmobile/frontend/shared/providers/auth_provider.dart';

class AppRouter {
  const AppRouter._();

  static GoRouter create(AuthProvider authProvider) {
    return GoRouter(
      refreshListenable: authProvider,
      initialLocation: '/home',
      redirect: (BuildContext context, GoRouterState state) {
        final status = authProvider.status;
        final isAuthRoute = state.matchedLocation == '/login';

        if (status == AuthStatus.initial || status == AuthStatus.loading) {
          return '/splash';
        }

        if (status == AuthStatus.unauthenticated ||
            status == AuthStatus.error) {
          return isAuthRoute ? null : '/login';
        }

        if (status == AuthStatus.authenticated && isAuthRoute) {
          return '/home';
        }

        if (state.matchedLocation == '/splash') {
          return '/home';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) =>
              const SplashScreen(key: ValueKey('splash')),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) =>
              const LoginScreen(key: ValueKey('login')),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return DashboardShell(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (context, state) => const HomeScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/alerts',
                  builder: (context, state) => const AlertsScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/bookings',
                  builder: (context, state) => const BookingsScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/account',
                  builder: (context, state) => const AccountScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
