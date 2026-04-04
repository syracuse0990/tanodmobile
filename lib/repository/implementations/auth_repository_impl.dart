import 'dart:io';

import 'package:tanodmobile/backend/datasources/auth_local_data_source.dart';
import 'package:tanodmobile/backend/datasources/auth_remote_data_source.dart';
import 'package:tanodmobile/core/errors/app_exception.dart';
import 'package:tanodmobile/models/domain/app_user.dart';
import 'package:tanodmobile/models/domain/registration_role.dart';
import 'package:tanodmobile/models/local/app_session.dart';
import 'package:tanodmobile/repository/contracts/auth_repository.dart';
import 'package:tanodmobile/services/connectivity/connectivity_service.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required AuthLocalDataSource localDataSource,
    required ConnectivityService connectivityService,
  }) : _remoteDataSource = remoteDataSource,
       _localDataSource = localDataSource,
       _connectivityService = connectivityService;

  final AuthRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _localDataSource;
  final ConnectivityService _connectivityService;

  @override
  Future<AppSession?> restoreSession() async {
    return _localDataSource.getSession();
  }

  @override
  Future<AppSession> signIn({
    required String login,
    required String password,
  }) async {
    final isOnline = await _connectivityService.isConnected();

    if (!isOnline) {
      throw const AppException(
        'No internet connection. Connect to the Tanod API and try again.',
      );
    }

    final session = await _remoteDataSource.signIn(
      login: login,
      password: password,
    );
    await _localDataSource.persistSession(session);

    return session;
  }

  @override
  Future<AppSession> signUp({
    required String role,
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final isOnline = await _connectivityService.isConnected();

    if (!isOnline) {
      throw const AppException(
        'No internet connection. Connect to the Tanod API and try again.',
      );
    }

    final session = await _remoteDataSource.signUp(
      role: role,
      name: name,
      email: email,
      password: password,
      passwordConfirmation: passwordConfirmation,
    );
    await _localDataSource.persistSession(session);

    return session;
  }

  @override
  Future<List<RegistrationRole>> fetchRegistrationRoles() async {
    return _remoteDataSource.fetchRegistrationRoles();
  }

  @override
  Future<AppSession> refreshSession(AppSession session) async {
    final isOnline = await _connectivityService.isConnected();

    if (!isOnline) {
      return session;
    }

    final user = await _remoteDataSource.fetchCurrentUser();
    final refreshedSession = session.copyWith(
      userId: user.id,
      name: user.name,
      email: user.email,
      roles: user.roles,
      phone: user.phone,
      gender: user.gender,
      profilePhotoUrl: user.profilePhotoUrl,
      mustChangePassword: user.mustChangePassword,
      phoneVerifiedAt: user.phoneVerifiedAt,
      savedAt: DateTime.now(),
    );

    await _localDataSource.persistSession(refreshedSession);

    return refreshedSession;
  }

  @override
  Future<AppUser> updateProfile({
    required Map<String, dynamic> fields,
    File? photo,
  }) async {
    final isOnline = await _connectivityService.isConnected();

    if (!isOnline) {
      throw const AppException(
        'No internet connection. Connect to the Tanod API and try again.',
      );
    }

    final user = await _remoteDataSource.updateProfile(
      fields: fields,
      photo: photo,
    );

    final currentSession = _localDataSource.getSession();
    if (currentSession != null) {
      final updated = currentSession.copyWith(
        name: user.name,
        email: user.email,
        phone: user.phone,
        gender: user.gender,
        profilePhotoUrl: user.profilePhotoUrl,
        savedAt: DateTime.now(),
      );
      await _localDataSource.persistSession(updated);
    }

    return user;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    final isOnline = await _connectivityService.isConnected();

    if (!isOnline) {
      throw const AppException(
        'No internet connection. Connect to the Tanod API and try again.',
      );
    }

    await _remoteDataSource.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
      newPasswordConfirmation: newPasswordConfirmation,
    );

    final currentSession = _localDataSource.getSession();
    if (currentSession != null) {
      final updated = currentSession.copyWith(
        mustChangePassword: false,
        savedAt: DateTime.now(),
      );
      await _localDataSource.persistSession(updated);
    }
  }

  @override
  Future<void> sendPhoneVerificationCode() async {
    final isOnline = await _connectivityService.isConnected();

    if (!isOnline) {
      throw const AppException(
        'No internet connection. Connect to the Tanod API and try again.',
      );
    }

    await _remoteDataSource.sendPhoneVerificationCode();
  }

  @override
  Future<AppUser> verifyPhone({required String code}) async {
    final isOnline = await _connectivityService.isConnected();

    if (!isOnline) {
      throw const AppException(
        'No internet connection. Connect to the Tanod API and try again.',
      );
    }

    final user = await _remoteDataSource.verifyPhone(code: code);

    final currentSession = _localDataSource.getSession();
    if (currentSession != null) {
      final updated = currentSession.copyWith(
        phoneVerifiedAt: user.phoneVerifiedAt,
        savedAt: DateTime.now(),
      );
      await _localDataSource.persistSession(updated);
    }

    return user;
  }

  @override
  Future<void> registerFcmToken() async {
    await _remoteDataSource.registerFcmToken();
  }

  @override
  Future<void> requestAccountDeletion({required String password}) async {
    final isOnline = await _connectivityService.isConnected();

    if (!isOnline) {
      throw const AppException(
        'No internet connection. Connect to the Tanod API and try again.',
      );
    }

    await _remoteDataSource.requestAccountDeletion(password: password);
  }

  @override
  Future<void> cancelAccountDeletion() async {
    final isOnline = await _connectivityService.isConnected();

    if (!isOnline) {
      throw const AppException(
        'No internet connection. Connect to the Tanod API and try again.',
      );
    }

    await _remoteDataSource.cancelAccountDeletion();
  }

  @override
  Future<Map<String, dynamic>> fetchAccountDeletionStatus() async {
    final isOnline = await _connectivityService.isConnected();

    if (!isOnline) {
      throw const AppException(
        'No internet connection. Connect to the Tanod API and try again.',
      );
    }

    return _remoteDataSource.fetchAccountDeletionStatus();
  }

  @override
  Future<void> signOut() async {
    await _remoteDataSource.signOut();
    await _localDataSource.clearSession();
  }
}
