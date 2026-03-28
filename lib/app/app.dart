import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/router/app_router.dart';
import 'package:tanodmobile/app/theme/app_theme.dart';
import 'package:tanodmobile/backend/datasources/auth_local_data_source.dart';
import 'package:tanodmobile/backend/datasources/auth_remote_data_source.dart';
import 'package:tanodmobile/backend/dio/api_client.dart';
import 'package:tanodmobile/backend/dio/dio_factory.dart';
import 'package:tanodmobile/frontend/shared/providers/auth_provider.dart';
import 'package:tanodmobile/repository/contracts/auth_repository.dart';
import 'package:tanodmobile/repository/implementations/auth_repository_impl.dart';
import 'package:tanodmobile/services/connectivity/connectivity_service.dart';
import 'package:tanodmobile/services/storage/hive_service.dart';

class TanodMobileApp extends StatelessWidget {
  const TanodMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<HiveService>(create: (_) => HiveService()),
        Provider<ConnectivityService>(create: (_) => ConnectivityService()),
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
          create: (context) =>
              AuthRemoteDataSource(apiClient: context.read<ApiClient>()),
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
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = AppRouter.create(context.read<AuthProvider>());
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Tanod Mobile',
      theme: AppTheme.light(),
      routerConfig: _router,
    );
  }
}
