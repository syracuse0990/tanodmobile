import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:tanodmobile/frontend/modules/alerts/screens/alerts_screen.dart';
import 'package:tanodmobile/frontend/modules/auth/screens/login_screen.dart';
import 'package:tanodmobile/frontend/modules/bookings/screens/bookings_screen.dart';
import 'package:tanodmobile/frontend/modules/dashboard/screens/dashboard_shell.dart';
import 'package:tanodmobile/frontend/modules/home/screens/home_screen.dart';
import 'package:tanodmobile/frontend/modules/profile/screens/account_screen.dart';
import 'package:tanodmobile/frontend/modules/profile/screens/change_password_screen.dart';
import 'package:tanodmobile/frontend/modules/profile/screens/edit_profile_screen.dart';
import 'package:tanodmobile/frontend/modules/profile/screens/phone_verification_screen.dart';
import 'package:tanodmobile/frontend/modules/splash/screens/splash_screen.dart';
import 'package:tanodmobile/frontend/modules/tickets/screens/create_ticket_screen.dart';
import 'package:tanodmobile/frontend/modules/tickets/screens/ticket_detail_screen.dart';
import 'package:tanodmobile/frontend/modules/tickets/screens/tickets_screen.dart';
import 'package:tanodmobile/frontend/modules/maintenance/screens/maintenance_screen.dart';
import 'package:tanodmobile/frontend/modules/maintenance/screens/pms_record_screen.dart';
import 'package:tanodmobile/frontend/modules/maintenance/screens/pms_request_screen.dart';
import 'package:tanodmobile/frontend/modules/maintenance/screens/pms_history_screen.dart';
import 'package:tanodmobile/frontend/modules/geofences/screens/geofences_screen.dart';
import 'package:tanodmobile/frontend/modules/geofences/screens/geofence_detail_screen.dart';
import 'package:tanodmobile/frontend/modules/geofences/screens/create_geofence_screen.dart';
import 'package:tanodmobile/frontend/modules/geofences/screens/edit_geofence_screen.dart';
import 'package:tanodmobile/frontend/modules/farmers/screens/farmers_screen.dart';
import 'package:tanodmobile/frontend/modules/feedback/screens/feedback_screen.dart';
import 'package:tanodmobile/frontend/modules/feedback/screens/create_feedback_screen.dart';
import 'package:tanodmobile/frontend/modules/profile/screens/help_center_screen.dart';
import 'package:tanodmobile/frontend/modules/profile/screens/about_screen.dart';
import 'package:tanodmobile/frontend/modules/profile/screens/terms_privacy_screen.dart';
import 'package:tanodmobile/frontend/modules/profile/screens/delete_account_screen.dart';
import 'package:tanodmobile/frontend/modules/reports/screens/reports_screen.dart';
import 'package:tanodmobile/frontend/modules/tps/screens/tps_screen.dart';
import 'package:tanodmobile/frontend/shared/providers/auth_provider.dart';
import 'package:tanodmobile/models/domain/maintenance_tractor.dart';

class AppRouter {
  const AppRouter._();

  static GoRouter create(
    AuthProvider authProvider, {
    GlobalKey<NavigatorState>? navigatorKey,
  }) {
    final isTps = authProvider.session?.roles.contains('tps') ?? false;

    return GoRouter(
      navigatorKey: navigatorKey,
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
                  path: isTps ? '/tps' : '/bookings',
                  builder: (context, state) =>
                      isTps ? const TpsScreen() : const BookingsScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/farmers',
                  builder: (context, state) => const FarmersScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/account',
                  builder: (context, state) => const AccountScreen(),
                  routes: [
                    GoRoute(
                      path: 'edit-profile',
                      builder: (context, state) => const EditProfileScreen(),
                    ),
                    GoRoute(
                      path: 'change-password',
                      builder: (context, state) => const ChangePasswordScreen(),
                    ),
                    GoRoute(
                      path: 'phone-verification',
                      builder: (context, state) =>
                          const PhoneVerificationScreen(),
                    ),
                    GoRoute(
                      path: 'tickets',
                      builder: (context, state) => const TicketsScreen(),
                      routes: [
                        GoRoute(
                          path: 'create',
                          builder: (context, state) =>
                              const CreateTicketScreen(),
                        ),
                        GoRoute(
                          path: ':id',
                          builder: (context, state) {
                            final id =
                                int.parse(state.pathParameters['id']!);
                            return TicketDetailScreen(ticketId: id);
                          },
                        ),
                      ],
                    ),
                    GoRoute(
                      path: 'maintenance',
                      builder: (context, state) =>
                          const MaintenanceScreen(),
                      routes: [
                        GoRoute(
                          path: 'record',
                          builder: (context, state) {
                            final tractor =
                                state.extra as MaintenanceTractor;
                            return PmsRecordScreen(tractor: tractor);
                          },
                        ),
                        GoRoute(
                          path: 'request',
                          builder: (context, state) {
                            final tractor =
                                state.extra as MaintenanceTractor;
                            return PmsRequestScreen(tractor: tractor);
                          },
                        ),
                        GoRoute(
                          path: 'history',
                          builder: (context, state) {
                            final tractor =
                                state.extra as MaintenanceTractor;
                            return PmsHistoryScreen(tractor: tractor);
                          },
                        ),
                      ],
                    ),
                    GoRoute(
                      path: 'geofences',
                      builder: (context, state) =>
                          const GeofencesScreen(),
                      routes: [
                        GoRoute(
                          path: 'create',
                          builder: (context, state) =>
                              const CreateGeofenceScreen(),
                        ),
                        GoRoute(
                          path: ':id',
                          builder: (context, state) {
                            final id =
                                int.parse(state.pathParameters['id']!);
                            return GeofenceDetailScreen(geofenceId: id);
                          },
                          routes: [
                            GoRoute(
                              path: 'edit',
                              builder: (context, state) {
                                final id =
                                    int.parse(state.pathParameters['id']!);
                                return EditGeofenceScreen(geofenceId: id);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    GoRoute(
                      path: 'feedback',
                      builder: (context, state) =>
                          const FeedbackScreen(),
                      routes: [
                        GoRoute(
                          path: 'create',
                          builder: (context, state) =>
                              const CreateFeedbackScreen(),
                        ),
                      ],
                    ),
                    GoRoute(
                      path: 'reports',
                      builder: (context, state) =>
                          const ReportsScreen(),
                    ),
                    GoRoute(
                      path: 'help-center',
                      builder: (context, state) =>
                          const HelpCenterScreen(),
                    ),
                    GoRoute(
                      path: 'about',
                      builder: (context, state) =>
                          const AboutScreen(),
                    ),
                    GoRoute(
                      path: 'terms-privacy',
                      builder: (context, state) =>
                          const TermsPrivacyScreen(),
                    ),
                    GoRoute(
                      path: 'delete-account',
                      builder: (context, state) =>
                          const DeleteAccountScreen(),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
