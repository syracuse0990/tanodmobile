import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/backend/dio/api_client.dart';
import 'package:tanodmobile/core/errors/app_exception.dart';
import 'package:tanodmobile/frontend/modules/tps/screens/tps_offline_download_screen.dart';
import 'package:tanodmobile/frontend/shared/providers/auth_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/tps_provider.dart';
import 'package:tanodmobile/models/domain/app_user.dart';
import 'package:tanodmobile/models/domain/registration_role.dart';
import 'package:tanodmobile/models/local/app_session.dart';
import 'package:tanodmobile/repository/contracts/auth_repository.dart';
import 'package:tanodmobile/services/connectivity/connectivity_service.dart';
import 'package:tanodmobile/services/storage/hive_service.dart';

void main() {
  testWidgets(
    'shows offline form data as the active sync step while reference sync is running',
    (WidgetTester tester) async {
      final referenceDataCompleter = Completer<void>();
      final connectivityService = _FakeConnectivityService(
        initialConnected: true,
      );
      final authProvider = AuthProvider(
        authRepository: _FakeAuthRepository(),
        connectivityService: connectivityService,
        bootstrapDelay: Duration.zero,
      );
      final tpsProvider = _FakeSyncingTpsProvider(
        referenceDataCompleter: referenceDataCompleter,
      );

      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        if (!referenceDataCompleter.isCompleted) {
          referenceDataCompleter.complete();
        }
        await connectivityService.dispose();
        authProvider.dispose();
        tpsProvider.dispose();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<TpsProvider>.value(value: tpsProvider),
          ],
          child: const MaterialApp(
            home: TpsOfflineDownloadScreen(isManualSync: true),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.text('Offline form data'), findsOneWidget);
      expect(
        find.text(
          'Prepare the dropdown and reference data used by offline forms.',
        ),
        findsOneWidget,
      );
      expect(find.text('Refreshing TPS offline data...'), findsOneWidget);
      expect(tpsProvider.referenceSyncCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'manual sync success shows feedback and closes back to the previous screen',
    (WidgetTester tester) async {
      final referenceDataCompleter = Completer<void>();
      final connectivityService = _FakeConnectivityService(
        initialConnected: true,
      );
      final authProvider = AuthProvider(
        authRepository: _FakeAuthRepository(),
        connectivityService: connectivityService,
        bootstrapDelay: Duration.zero,
      );
      final tpsProvider = _FakeSyncingTpsProvider(
        referenceDataCompleter: referenceDataCompleter,
      );
      final router = GoRouter(
        initialLocation: '/sync',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const _ManualSyncHost(),
            routes: [
              GoRoute(
                path: 'sync',
                builder: (_, _) =>
                    const TpsOfflineDownloadScreen(isManualSync: true),
              ),
            ],
          ),
        ],
      );

      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        if (!referenceDataCompleter.isCompleted) {
          referenceDataCompleter.complete();
        }
        await connectivityService.dispose();
        authProvider.dispose();
        tpsProvider.dispose();
        router.dispose();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<TpsProvider>.value(value: tpsProvider),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pump();

      expect(find.byType(TpsOfflineDownloadScreen), findsOneWidget);

      referenceDataCompleter.complete();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        find.text('Offline TPS data refreshed successfully.'),
        findsOneWidget,
      );
      expect(find.text('Host screen'), findsOneWidget);
      expect(find.byType(TpsOfflineDownloadScreen), findsNothing);
      expect(tpsProvider.referenceSyncCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reference data failure marks the only sync step as failed', (
    WidgetTester tester,
  ) async {
    final referenceDataCompleter = Completer<void>();
    final connectivityService = _FakeConnectivityService(
      initialConnected: true,
    );
    final authProvider = AuthProvider(
      authRepository: _FakeAuthRepository(),
      connectivityService: connectivityService,
      bootstrapDelay: Duration.zero,
    );
    final tpsProvider = _FakeSyncingTpsProvider(
      referenceDataCompleter: referenceDataCompleter,
    );

    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      if (!referenceDataCompleter.isCompleted) {
        referenceDataCompleter.complete();
      }
      await connectivityService.dispose();
      authProvider.dispose();
      tpsProvider.dispose();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<TpsProvider>.value(value: tpsProvider),
        ],
        child: const MaterialApp(
          home: TpsOfflineDownloadScreen(isManualSync: true),
        ),
      ),
    );

    await tester.pump();

    referenceDataCompleter.completeError(
      const AppException('Failed to download offline reference data.'),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Failed to download offline reference data.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'The refresh did not finish. You can retry now or close this screen.',
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.downloading_rounded), findsNothing);
    expect(find.text('Retry refresh'), findsOneWidget);
    expect(tpsProvider.referenceSyncCalls, 1);
    expect(tester.takeException(), isNull);
  });
}

class _ManualSyncHost extends StatelessWidget {
  const _ManualSyncHost();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Host screen')));
  }
}

class _FakeSyncingTpsProvider extends TpsProvider {
  _FakeSyncingTpsProvider({required this.referenceDataCompleter})
    : super(
        apiClient: ApiClient(Dio()),
        dio: Dio(),
        hiveService: _FakeHiveService(),
      );

  final Completer<void> referenceDataCompleter;
  int referenceSyncCalls = 0;

  @override
  Future<void> syncOfflineReferenceData() {
    referenceSyncCalls += 1;
    return referenceDataCompleter.future;
  }
}

class _FakeAuthRepository implements AuthRepository {
  AppSession? session;
  AppSession? offlineTpsSession;
  bool offlineModeEnabled = false;

  @override
  Future<void> cancelAccountDeletion() async {}

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {}

  @override
  Future<void> clearOfflineTpsSession() async {
    offlineTpsSession = null;
  }

  @override
  Future<List<RegistrationRole>> fetchRegistrationRoles() async {
    return RegistrationRole.fallbacks;
  }

  @override
  Future<Map<String, dynamic>> fetchAccountDeletionStatus() async {
    return {'deletion_requested': false};
  }

  @override
  Future<bool> getOfflineModeEnabled() async {
    return offlineModeEnabled;
  }

  @override
  Future<void> persistSession(AppSession session) async {
    this.session = session;
  }

  @override
  Future<void> registerFcmToken() async {}

  @override
  Future<void> requestAccountDeletion({required String password}) async {}

  @override
  Future<AppSession?> restoreOfflineTpsSession() async {
    return offlineTpsSession;
  }

  @override
  Future<AppSession?> restoreSession() async {
    return session;
  }

  @override
  Future<AppSession> refreshSession(AppSession session) async {
    this.session = session;
    return session;
  }

  @override
  Future<void> saveOfflineTpsSession(AppSession session) async {
    offlineTpsSession = session;
  }

  @override
  Future<void> sendPhoneVerificationCode() async {}

  @override
  Future<void> setOfflineModeEnabled(bool enabled) async {
    offlineModeEnabled = enabled;
  }

  @override
  Future<AppSession> signIn({required String login, required String password}) {
    final nextSession = _tpsSession();
    session = nextSession;
    return Future.value(nextSession);
  }

  @override
  Future<void> signOut() async {
    session = null;
    offlineModeEnabled = false;
  }

  @override
  Future<AppSession> signUp({
    required String role,
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) {
    final nextSession = _tpsSession();
    session = nextSession;
    return Future.value(nextSession);
  }

  @override
  Future<AppUser> updateProfile({
    required Map<String, dynamic> fields,
    File? photo,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AppUser> verifyPhone({required String code}) {
    throw UnimplementedError();
  }
}

class _FakeConnectivityService extends ConnectivityService {
  _FakeConnectivityService({required bool initialConnected})
    : _connected = initialConnected;

  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  bool _connected;

  @override
  Future<bool> isConnected() async {
    return _connected;
  }

  @override
  Stream<bool> watchConnectivity() {
    return _controller.stream;
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}

class _FakeHiveService extends HiveService {
  final Map<String, String> _preferences = <String, String>{};

  @override
  String? getPreference(String key) {
    return _preferences[key];
  }

  @override
  Future<void> savePreference(String key, String value) async {
    _preferences[key] = value;
  }

  @override
  Future<void> removePreference(String key) async {
    _preferences.remove(key);
  }
}

AppSession _tpsSession() {
  return AppSession(
    token: 'token',
    userId: 7,
    name: 'TPS User',
    email: 'tps@example.com',
    roles: const ['tps'],
    savedAt: DateTime(2026, 6, 1),
  );
}
