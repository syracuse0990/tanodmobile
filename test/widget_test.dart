import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:tanodmobile/frontend/modules/auth/screens/login_screen.dart';
import 'package:tanodmobile/frontend/modules/splash/screens/splash_screen.dart';
import 'package:tanodmobile/frontend/shared/providers/auth_provider.dart';
import 'package:tanodmobile/models/domain/app_user.dart';
import 'package:tanodmobile/models/domain/registration_role.dart';
import 'package:tanodmobile/models/local/app_session.dart';
import 'package:tanodmobile/repository/contracts/auth_repository.dart';
import 'package:tanodmobile/services/connectivity/connectivity_service.dart';

void main() {
  testWidgets('Splash screen renders current branding copy', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    expect(find.text('Kasama ng magsasaka,'), findsOneWidget);
    expect(find.text('tuwing ani at araro.'), findsOneWidget);
  });

  testWidgets('Login screen renders without overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final connectivityService = _FakeConnectivityService(
      initialConnected: true,
    );
    final authProvider = AuthProvider(
      authRepository: _FakeAuthRepository(),
      connectivityService: connectivityService,
      bootstrapDelay: Duration.zero,
    );

    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await connectivityService.dispose();
      authProvider.dispose();
    });

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: authProvider,
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Login'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Login screen shows Offline Mode for saved TPS session', (
    WidgetTester tester,
  ) async {
    final connectivityService = _FakeConnectivityService(
      initialConnected: false,
    );
    final authProvider = AuthProvider(
      authRepository: _FakeAuthRepository(offlineTpsSession: _tpsSession()),
      connectivityService: connectivityService,
      bootstrapDelay: Duration.zero,
    );

    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await connectivityService.dispose();
      authProvider.dispose();
    });

    await authProvider.bootstrap();

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: authProvider,
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Offline Mode'), findsOneWidget);
    expect(
      find.textContaining('already logged in on this phone before'),
      findsOneWidget,
    );
  });
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.offlineTpsSession});

  AppSession? session;
  AppSession? offlineTpsSession;
  bool offlineModeEnabled = false;

  @override
  Future<void> clearOfflineTpsSession() async {
    offlineTpsSession = null;
  }

  @override
  Future<List<RegistrationRole>> fetchRegistrationRoles() async {
    return RegistrationRole.fallbacks;
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
  Future<AppSession?> restoreSession() async {
    return session;
  }

  @override
  Future<AppSession?> restoreOfflineTpsSession() async {
    return offlineTpsSession;
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
  Future<void> setOfflineModeEnabled(bool enabled) async {
    offlineModeEnabled = enabled;
  }

  @override
  Future<void> signOut() async {
    session = null;
    offlineModeEnabled = false;
  }

  @override
  Future<AppSession> signIn({required String login, required String password}) {
    final nextSession = _tpsSession();
    session = nextSession;
    return Future.value(nextSession);
  }

  @override
  Future<AppSession> signUp({
    required String role,
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? coopName,
  }) {
    final nextSession = _tpsSession();
    session = nextSession;
    return Future.value(nextSession);
  }

  @override
  Future<void> registerFcmToken() async {}

  @override
  Future<AppUser> updateProfile({
    required Map<String, dynamic> fields,
    File? photo,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> sendPhoneVerificationCode() {
    throw UnimplementedError();
  }

  @override
  Future<AppUser> verifyPhone({required String code}) {
    throw UnimplementedError();
  }

  @override
  Future<void> requestAccountDeletion({required String password}) {
    throw UnimplementedError();
  }

  @override
  Future<void> cancelAccountDeletion() {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> fetchAccountDeletionStatus() async {
    return {'deletion_requested': false};
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

  void setConnected(bool value) {
    _connected = value;
    _controller.add(value);
  }

  Future<void> dispose() async {
    await _controller.close();
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
