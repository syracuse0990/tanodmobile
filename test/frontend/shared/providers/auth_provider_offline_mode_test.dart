import 'dart:io';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tanodmobile/frontend/shared/providers/auth_provider.dart';
import 'package:tanodmobile/models/domain/app_user.dart';
import 'package:tanodmobile/models/domain/registration_role.dart';
import 'package:tanodmobile/models/local/app_session.dart';
import 'package:tanodmobile/repository/contracts/auth_repository.dart';
import 'package:tanodmobile/services/connectivity/connectivity_service.dart';

void main() {
  test('TPS auto-logs out after 20 seconds without signal', () async {
    final connectivityService = _FakeConnectivityService(
      initialConnected: true,
    );
    final repository = _FakeAuthRepository(signInSession: _tpsSession());
    final provider = AuthProvider(
      authRepository: repository,
      connectivityService: connectivityService,
      bootstrapDelay: Duration.zero,
      tpsSignalGracePeriod: const Duration(milliseconds: 30),
    );

    final success = await provider.signIn(
      login: 'tps@example.com',
      password: 'password',
    );

    expect(success, isTrue);
    expect(provider.status, AuthStatus.authenticated);

    connectivityService.setConnected(false);
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(provider.status, AuthStatus.unauthenticated);
    expect(provider.errorMessage, contains('20 seconds'));
    expect(provider.canUseOfflineMode, isTrue);
    expect(repository.signOutCallCount, 1);
    expect(repository.offlineTpsSession?.roles, contains('tps'));

    await connectivityService.dispose();
    provider.dispose();
  });

  test('Offline mode restores the saved TPS session locally', () async {
    final connectivityService = _FakeConnectivityService(
      initialConnected: false,
    );
    final repository = _FakeAuthRepository(offlineTpsSession: _tpsSession());
    final provider = AuthProvider(
      authRepository: repository,
      connectivityService: connectivityService,
      bootstrapDelay: Duration.zero,
      tpsSignalGracePeriod: const Duration(milliseconds: 30),
    );

    await provider.bootstrap();

    final success = await provider.enterOfflineMode();

    expect(success, isTrue);
    expect(provider.status, AuthStatus.authenticated);
    expect(provider.isOfflineMode, isTrue);
    expect(repository.session?.roles, contains('tps'));
    expect(repository.offlineModeEnabled, isTrue);

    await connectivityService.dispose();
    provider.dispose();
  });

  test('Manual TPS sign out still keeps offline mode available', () async {
    final connectivityService = _FakeConnectivityService(
      initialConnected: true,
    );
    final repository = _FakeAuthRepository(signInSession: _tpsSession());
    final provider = AuthProvider(
      authRepository: repository,
      connectivityService: connectivityService,
      bootstrapDelay: Duration.zero,
      tpsSignalGracePeriod: const Duration(milliseconds: 30),
    );

    final success = await provider.signIn(
      login: 'tps@example.com',
      password: 'password',
    );

    expect(success, isTrue);
    expect(provider.status, AuthStatus.authenticated);

    await provider.signOut();

    expect(provider.status, AuthStatus.unauthenticated);
    expect(provider.isOfflineMode, isFalse);
    expect(provider.canUseOfflineMode, isTrue);
    expect(repository.offlineTpsSession?.roles, contains('tps'));
    expect(repository.session, isNull);

    await connectivityService.dispose();
    provider.dispose();
  });

  test('TPS online sign in requires offline sync until completed', () async {
    final connectivityService = _FakeConnectivityService(
      initialConnected: true,
    );
    final repository = _FakeAuthRepository(signInSession: _tpsSession());
    final provider = AuthProvider(
      authRepository: repository,
      connectivityService: connectivityService,
      bootstrapDelay: Duration.zero,
      tpsSignalGracePeriod: const Duration(milliseconds: 30),
    );

    final success = await provider.signIn(
      login: 'tps@example.com',
      password: 'password',
    );

    expect(success, isTrue);
    expect(provider.requiresTpsOfflineSync, isTrue);

    provider.completeTpsOfflineSync();

    expect(provider.requiresTpsOfflineSync, isFalse);

    await connectivityService.dispose();
    provider.dispose();
  });
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.signInSession, this.offlineTpsSession});

  final AppSession? signInSession;
  AppSession? session;
  AppSession? offlineTpsSession;
  bool offlineModeEnabled = false;
  int signOutCallCount = 0;

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
  Future<AppSession> refreshSession(AppSession session) async {
    this.session = session;
    return session;
  }

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
  Future<void> saveOfflineTpsSession(AppSession session) async {
    offlineTpsSession = session;
  }

  @override
  Future<void> sendPhoneVerificationCode() async {}

  @override
  Future<AppSession> signIn({
    required String login,
    required String password,
  }) async {
    final nextSession = signInSession ?? _tpsSession();
    session = nextSession;
    return nextSession;
  }

  @override
  Future<void> signOut() async {
    signOutCallCount += 1;
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
    String? coopName,
  }) async {
    final nextSession = signInSession ?? _tpsSession();
    session = nextSession;
    return nextSession;
  }

  @override
  Future<void> setOfflineModeEnabled(bool enabled) async {
    offlineModeEnabled = enabled;
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
