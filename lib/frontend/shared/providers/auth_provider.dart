import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tanodmobile/core/errors/app_exception.dart';
import 'package:tanodmobile/models/domain/app_user.dart';
import 'package:tanodmobile/models/domain/registration_role.dart';
import 'package:tanodmobile/models/local/app_session.dart';
import 'package:tanodmobile/repository/contracts/auth_repository.dart';
import 'package:tanodmobile/services/connectivity/connectivity_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    required AuthRepository authRepository,
    required ConnectivityService connectivityService,
    Duration bootstrapDelay = const Duration(seconds: 3),
    Duration tpsSignalGracePeriod = const Duration(seconds: 20),
  }) : _authRepository = authRepository,
       _connectivityService = connectivityService,
       _bootstrapDelay = bootstrapDelay,
       _tpsSignalGracePeriod = tpsSignalGracePeriod {
    _bindConnectivityWatch();
  }

  final AuthRepository _authRepository;
  final ConnectivityService _connectivityService;
  final Duration _bootstrapDelay;
  final Duration _tpsSignalGracePeriod;

  static const String _tpsSignalLogoutMessage =
      'TPS was logged out after 20 seconds without signal. Use Offline Mode to continue.';

  AuthStatus _status = AuthStatus.initial;
  AppSession? _session;
  AppSession? _offlineTpsSession;
  String? _errorMessage;
  List<RegistrationRole> _registrationRoles = RegistrationRole.fallbacks;
  bool _isLoadingRegistrationRoles = false;
  bool _isConnected = true;
  bool _isOfflineMode = false;
  bool _requiresTpsOfflineSync = false;
  StreamSubscription<bool>? _connectivitySubscription;
  Timer? _tpsOfflineLogoutTimer;

  AuthStatus get status => _status;
  AppSession? get session => _session;
  AppUser? get currentUser => _session?.toUser();
  String? get errorMessage => _errorMessage;
  bool get isBusy => _status == AuthStatus.loading;
  List<RegistrationRole> get registrationRoles => _registrationRoles;
  bool get isLoadingRegistrationRoles => _isLoadingRegistrationRoles;
  bool get isConnected => _isConnected;
  bool get isOfflineMode => _isOfflineMode;
  bool get canUseOfflineMode =>
      _offlineTpsSession != null && _isTpsSession(_offlineTpsSession);
  bool get requiresTpsOfflineSync => _requiresTpsOfflineSync;

  Future<void> bootstrap() async {
    _status = AuthStatus.loading;
    notifyListeners();

    _session = await _authRepository.restoreSession();
    _offlineTpsSession = await _authRepository.restoreOfflineTpsSession();
    _isConnected = await _connectivityService.isConnected();

    final offlineModeEnabled = await _authRepository.getOfflineModeEnabled();
    _isOfflineMode = offlineModeEnabled && _isTpsSession(_session);
    _requiresTpsOfflineSync = false;
    if (!_isOfflineMode && offlineModeEnabled) {
      await _authRepository.setOfflineModeEnabled(false);
    }

    await Future.delayed(_bootstrapDelay); // minimum splash display
    _status = _session == null
        ? AuthStatus.unauthenticated
        : AuthStatus.authenticated;
    notifyListeners();

    _syncTpsConnectivityWatchdog();

    if (_session != null && !_isOfflineMode && _isConnected) {
      unawaited(refreshProfile());
      unawaited(_authRepository.registerFcmToken());
    }

    if (_session == null) {
      unawaited(loadRegistrationRoles());
    }
  }

  Future<bool> signIn({required String login, required String password}) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final nextSession = await _authRepository.signIn(
        login: login,
        password: password,
      );
      _session = nextSession;
      _isOfflineMode = false;
      _requiresTpsOfflineSync = _isTpsSession(nextSession) && _isConnected;
      await _authRepository.setOfflineModeEnabled(false);
      await _syncOfflineTpsSession(nextSession);
      _status = AuthStatus.authenticated;
      _syncTpsConnectivityWatchdog();
      if (_isConnected) {
        unawaited(_authRepository.registerFcmToken());
      }
      return true;
    } on AppException catch (error) {
      _status = AuthStatus.error;
      _errorMessage = error.message;
      return false;
    } catch (error) {
      _status = AuthStatus.error;
      _errorMessage = error.toString();
      return false;
    } finally {
      notifyListeners();
    }
  }

  Future<bool> signUp({
    required String role,
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final nextSession = await _authRepository.signUp(
        role: role,
        name: name,
        email: email,
        password: password,
        passwordConfirmation: passwordConfirmation,
      );
      _session = nextSession;
      _isOfflineMode = false;
      _requiresTpsOfflineSync = _isTpsSession(nextSession) && _isConnected;
      await _authRepository.setOfflineModeEnabled(false);
      await _syncOfflineTpsSession(nextSession);
      _status = AuthStatus.authenticated;
      _syncTpsConnectivityWatchdog();
      if (_isConnected) {
        unawaited(_authRepository.registerFcmToken());
      }
      return true;
    } on AppException catch (error) {
      _status = AuthStatus.error;
      _errorMessage = error.message;
      return false;
    } catch (error) {
      _status = AuthStatus.error;
      _errorMessage = error.toString();
      return false;
    } finally {
      notifyListeners();
    }
  }

  Future<void> loadRegistrationRoles({bool silent = true}) async {
    if (_isLoadingRegistrationRoles) {
      return;
    }

    _isLoadingRegistrationRoles = true;
    notifyListeners();

    try {
      final roles = await _authRepository.fetchRegistrationRoles();

      if (roles.isNotEmpty) {
        _registrationRoles = roles;
      }
    } on AppException catch (error) {
      if (!silent) {
        _errorMessage = error.message;
      }
    } finally {
      _isLoadingRegistrationRoles = false;
      notifyListeners();
    }
  }

  Future<void> refreshProfile() async {
    final activeSession = _session;

    if (activeSession == null) {
      return;
    }

    try {
      _session = await _authRepository.refreshSession(activeSession);
      await _syncOfflineTpsSession(_session);
      _status = AuthStatus.authenticated;
      _syncTpsConnectivityWatchdog();
      notifyListeners();
    } catch (_) {
      // Keep the last local state if refresh fails.
    }
  }

  Future<AppUser> updateProfile({
    required Map<String, dynamic> fields,
    File? photo,
  }) async {
    final user = await _authRepository.updateProfile(
      fields: fields,
      photo: photo,
    );

    if (_session != null) {
      _session = _session!.copyWith(
        name: user.name,
        email: user.email,
        phone: user.phone,
        gender: user.gender,
        profilePhotoUrl: user.profilePhotoUrl,
        province: user.province,
        city: user.city,
        barangay: user.barangay,
        savedAt: DateTime.now(),
      );
      await _syncOfflineTpsSession(_session);
      notifyListeners();
    }

    return user;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    await _authRepository.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
      newPasswordConfirmation: newPasswordConfirmation,
    );

    if (_session != null) {
      _session = _session!.copyWith(
        mustChangePassword: false,
        savedAt: DateTime.now(),
      );
      await _syncOfflineTpsSession(_session);
      notifyListeners();
    }
  }

  Future<void> sendPhoneVerificationCode() async {
    await _authRepository.sendPhoneVerificationCode();
  }

  Future<void> verifyPhone({required String code}) async {
    final user = await _authRepository.verifyPhone(code: code);

    if (_session != null) {
      _session = _session!.copyWith(
        phoneVerifiedAt: user.phoneVerifiedAt,
        savedAt: DateTime.now(),
      );
      await _syncOfflineTpsSession(_session);
      notifyListeners();
    }
  }

  Future<bool> enterOfflineMode() async {
    final offlineSession = _offlineTpsSession;

    if (!_isTpsSession(offlineSession)) {
      _status = AuthStatus.error;
      _errorMessage = 'Offline Mode is not available for this account.';
      notifyListeners();
      return false;
    }

    try {
      _errorMessage = null;
      await _authRepository.persistSession(offlineSession!);
      await _authRepository.setOfflineModeEnabled(true);
      _session = offlineSession;
      _isOfflineMode = true;
      _requiresTpsOfflineSync = false;
      _status = AuthStatus.authenticated;
      _cancelTpsOfflineLogoutTimer();
      notifyListeners();
      return true;
    } catch (_) {
      _status = AuthStatus.error;
      _errorMessage = 'Unable to open Offline Mode right now.';
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    final activeSession = _session;
    final preserveOfflineAccess = _isTpsSession(activeSession);

    _cancelTpsOfflineLogoutTimer();
    await _authRepository.setOfflineModeEnabled(false);
    _requiresTpsOfflineSync = false;

    if (preserveOfflineAccess && activeSession != null) {
      await _authRepository.saveOfflineTpsSession(activeSession);
      _offlineTpsSession = activeSession;
    } else {
      await _authRepository.clearOfflineTpsSession();
      _offlineTpsSession = null;
    }

    await _authRepository.signOut();
    _session = null;
    _isOfflineMode = false;
    _errorMessage = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void completeTpsOfflineSync() {
    if (!_requiresTpsOfflineSync) {
      return;
    }

    _requiresTpsOfflineSync = false;
    notifyListeners();
  }

  Future<void> requestAccountDeletion({required String password}) async {
    await _authRepository.requestAccountDeletion(password: password);
  }

  Future<void> cancelAccountDeletion() async {
    await _authRepository.cancelAccountDeletion();
  }

  Future<Map<String, dynamic>> fetchAccountDeletionStatus() async {
    return _authRepository.fetchAccountDeletionStatus();
  }

  Future<void> deleteAccountAndSignOut({required String password}) async {
    await _authRepository.requestAccountDeletion(password: password);
  }

  void _bindConnectivityWatch() {
    _connectivitySubscription ??= _connectivityService
        .watchConnectivity()
        .listen((isConnected) {
          if (_isConnected == isConnected) {
            return;
          }

          _isConnected = isConnected;
          _syncTpsConnectivityWatchdog();
          notifyListeners();
        });
  }

  Future<void> _syncOfflineTpsSession(AppSession? session) async {
    if (_isTpsSession(session) && session != null) {
      await _authRepository.saveOfflineTpsSession(session);
      _offlineTpsSession = session;
      return;
    }

    await _authRepository.clearOfflineTpsSession();
    _offlineTpsSession = null;
  }

  bool _isTpsSession(AppSession? session) {
    return session?.roles.contains('tps') ?? false;
  }

  void _syncTpsConnectivityWatchdog() {
    if (_status != AuthStatus.authenticated ||
        !_isTpsSession(_session) ||
        _isOfflineMode ||
        _isConnected) {
      _cancelTpsOfflineLogoutTimer();
      return;
    }

    _tpsOfflineLogoutTimer ??= Timer(
      _tpsSignalGracePeriod,
      () => unawaited(_handleTpsSignalTimeout()),
    );
  }

  void _cancelTpsOfflineLogoutTimer() {
    _tpsOfflineLogoutTimer?.cancel();
    _tpsOfflineLogoutTimer = null;
  }

  Future<void> _handleTpsSignalTimeout() async {
    _cancelTpsOfflineLogoutTimer();

    final activeSession = _session;
    if (_isConnected || _isOfflineMode || !_isTpsSession(activeSession)) {
      return;
    }

    await _authRepository.saveOfflineTpsSession(activeSession!);
    _offlineTpsSession = activeSession;
    await _authRepository.setOfflineModeEnabled(false);
    await _authRepository.signOut();

    _session = null;
    _isOfflineMode = false;
    _requiresTpsOfflineSync = false;
    _status = AuthStatus.unauthenticated;
    _errorMessage = _tpsSignalLogoutMessage;
    notifyListeners();
  }

  @override
  void dispose() {
    _cancelTpsOfflineLogoutTimer();
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
