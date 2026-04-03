import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tanodmobile/core/errors/app_exception.dart';
import 'package:tanodmobile/models/domain/app_user.dart';
import 'package:tanodmobile/models/domain/registration_role.dart';
import 'package:tanodmobile/models/local/app_session.dart';
import 'package:tanodmobile/repository/contracts/auth_repository.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  AuthProvider({required AuthRepository authRepository})
    : _authRepository = authRepository;

  final AuthRepository _authRepository;

  AuthStatus _status = AuthStatus.initial;
  AppSession? _session;
  String? _errorMessage;
  List<RegistrationRole> _registrationRoles = RegistrationRole.fallbacks;
  bool _isLoadingRegistrationRoles = false;

  AuthStatus get status => _status;
  AppSession? get session => _session;
  AppUser? get currentUser => _session?.toUser();
  String? get errorMessage => _errorMessage;
  bool get isBusy => _status == AuthStatus.loading;
  List<RegistrationRole> get registrationRoles => _registrationRoles;
  bool get isLoadingRegistrationRoles => _isLoadingRegistrationRoles;

  Future<void> bootstrap() async {
    _status = AuthStatus.loading;
    notifyListeners();

    _session = await _authRepository.restoreSession();
    await Future.delayed(const Duration(seconds: 3)); // minimum splash display
    _status = _session == null
        ? AuthStatus.unauthenticated
        : AuthStatus.authenticated;
    notifyListeners();

    if (_session != null) {
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
      _session = await _authRepository.signIn(login: login, password: password);
      _status = AuthStatus.authenticated;
      unawaited(_authRepository.registerFcmToken());
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
      _session = await _authRepository.signUp(
        role: role,
        name: name,
        email: email,
        password: password,
        passwordConfirmation: passwordConfirmation,
      );
      _status = AuthStatus.authenticated;
      unawaited(_authRepository.registerFcmToken());
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
      _status = AuthStatus.authenticated;
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
        savedAt: DateTime.now(),
      );
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
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _authRepository.signOut();
    _session = null;
    _errorMessage = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
