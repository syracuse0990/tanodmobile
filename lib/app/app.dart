import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/router/app_router.dart';
import 'package:tanodmobile/app/theme/app_theme.dart';
import 'package:tanodmobile/backend/datasources/auth_local_data_source.dart';
import 'package:tanodmobile/backend/datasources/auth_remote_data_source.dart';
import 'package:tanodmobile/backend/dio/api_client.dart';
import 'package:tanodmobile/backend/dio/dio_factory.dart';
import 'package:tanodmobile/core/locale/app_localizations.dart';
import 'package:tanodmobile/frontend/shared/providers/auth_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/alert_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/booking_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/farmer_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/locale_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/realtime_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/tps_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/ticket_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/tractor_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/maintenance_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/pms_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/geofence_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/feedback_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/report_provider.dart';
import 'package:tanodmobile/frontend/shared/widgets/app_toast.dart';
import 'package:tanodmobile/repository/contracts/auth_repository.dart';
import 'package:tanodmobile/repository/implementations/auth_repository_impl.dart';
import 'package:tanodmobile/services/connectivity/connectivity_service.dart';
import 'package:tanodmobile/services/notifications/local_notification_service.dart';
import 'package:tanodmobile/services/storage/hive_service.dart';

class TanodMobileApp extends StatelessWidget {
  const TanodMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<HiveService>(create: (_) => HiveService()),
        Provider<ConnectivityService>(create: (_) => ConnectivityService()),
        ChangeNotifierProvider<LocaleProvider>(
          create: (context) =>
              LocaleProvider(hiveService: context.read<HiveService>()),
        ),
        Provider<Dio>(
          create: (context) =>
              DioFactory.create(hiveService: context.read<HiveService>()),
        ),
        Provider<ApiClient>(
          create: (context) => ApiClient(context.read<Dio>()),
        ),
        Provider<AuthLocalDataSource>(
          create: (context) =>
              AuthLocalDataSource(hiveService: context.read<HiveService>()),
        ),
        Provider<AuthRemoteDataSource>(
          create: (context) => AuthRemoteDataSource(
            apiClient: context.read<ApiClient>(),
            dio: context.read<Dio>(),
          ),
        ),
        Provider<AuthRepository>(
          create: (context) => AuthRepositoryImpl(
            remoteDataSource: context.read<AuthRemoteDataSource>(),
            localDataSource: context.read<AuthLocalDataSource>(),
            connectivityService: context.read<ConnectivityService>(),
          ),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (context) =>
              AuthProvider(authRepository: context.read<AuthRepository>())
                ..bootstrap(),
        ),
        ChangeNotifierProvider<TractorProvider>(
          create: (context) =>
              TractorProvider(apiClient: context.read<ApiClient>()),
        ),
        ChangeNotifierProvider<AlertProvider>(
          create: (context) =>
              AlertProvider(apiClient: context.read<ApiClient>()),
        ),
        ChangeNotifierProvider<BookingProvider>(
          create: (context) =>
              BookingProvider(apiClient: context.read<ApiClient>()),
        ),
        ChangeNotifierProvider<FarmerProvider>(
          create: (context) =>
              FarmerProvider(apiClient: context.read<ApiClient>()),
        ),
        ChangeNotifierProvider<TicketProvider>(
          create: (context) => TicketProvider(
            apiClient: context.read<ApiClient>(),
            dio: context.read<Dio>(),
          ),
        ),
        ChangeNotifierProvider<TpsProvider>(
          create: (context) => TpsProvider(
            apiClient: context.read<ApiClient>(),
            dio: context.read<Dio>(),
          ),
        ),
        ChangeNotifierProvider<MaintenanceProvider>(
          create: (context) =>
              MaintenanceProvider(apiClient: context.read<ApiClient>()),
        ),
        ChangeNotifierProvider<PmsProvider>(
          create: (context) => PmsProvider(
            apiClient: context.read<ApiClient>(),
            dio: context.read<Dio>(),
          ),
        ),
        ChangeNotifierProvider<GeoFenceProvider>(
          create: (context) =>
              GeoFenceProvider(apiClient: context.read<ApiClient>()),
        ),
        ChangeNotifierProvider<FeedbackProvider>(
          create: (context) =>
              FeedbackProvider(apiClient: context.read<ApiClient>()),
        ),
        ChangeNotifierProvider<ReportProvider>(
          create: (context) =>
              ReportProvider(apiClient: context.read<ApiClient>()),
        ),
        ChangeNotifierProxyProvider<AuthProvider, RealtimeProvider>(
          create: (context) => RealtimeProvider(
            dio: context.read<Dio>(),
            alertProvider: context.read<AlertProvider>(),
            feedbackProvider: context.read<FeedbackProvider>(),
          ),
          update: (context, auth, realtime) {
            final userId = auth.session?.userId;
            if (auth.status == AuthStatus.authenticated && userId != null) {
              realtime!.start(userId);
            } else if (auth.status == AuthStatus.unauthenticated) {
              realtime!.stop();
            }
            return realtime!;
          },
        ),
      ],
      child: const _RouterApp(),
    );
  }
}

class _RouterApp extends StatefulWidget {
  const _RouterApp();

  @override
  State<_RouterApp> createState() => _RouterAppState();
}

class _RouterAppState extends State<_RouterApp> {
  late GoRouter _router;
  AuthStatus? _lastAuthStatus;

  @override
  void initState() {
    super.initState();
    _router = _createRouter();

    // Navigate to ticket when a notification is tapped.
    LocalNotificationService.instance.onNotificationTapped =
        _handleNotificationTap;

    // Consume any pending FCM payload from a terminated-app tap.
    final pending = LocalNotificationService.instance.pendingFcmPayload;
    if (pending != null) {
      LocalNotificationService.instance.pendingFcmPayload = null;
      // Delay to let the router finish initial navigation.
      Future.delayed(
        const Duration(milliseconds: 500),
        () => _handleNotificationTap(pending),
      );
    }
  }

  GoRouter _createRouter() {
    return AppRouter.create(
      context.read<AuthProvider>(),
      navigatorKey: AppToast.navigatorKey,
    );
  }

  void _handleNotificationTap(Map<String, dynamic> payload) {
    final ticketId = payload['ticket_id'];
    if (ticketId != null) {
      _router.go('/account/tickets/$ticketId');
    }
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Eagerly watch RealtimeProvider so the ChangeNotifierProxyProvider
    // triggers its update callback (which calls start()) as soon as
    // AuthProvider emits authenticated. Without this read, the WebSocket
    // connection only starts when a widget on the tickets page reads it.
    context.watch<RealtimeProvider>();

    // Rebuild the router when a new session starts so role-dependent
    // branches (e.g. TPS vs Bookings) and StatefulShellRoute GlobalKeys
    // are recreated for the new user.
    final authStatus = context.watch<AuthProvider>().status;
    if (authStatus == AuthStatus.authenticated &&
        _lastAuthStatus != null &&
        _lastAuthStatus != AuthStatus.authenticated) {
      _router.dispose();
      _router = _createRouter();
    }
    _lastAuthStatus = authStatus;

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Tanod Tractor',
      theme: AppTheme.light(),
      locale: context.watch<LocaleProvider>().locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: _router,
    );
  }
}
