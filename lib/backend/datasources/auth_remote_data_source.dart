import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:tanodmobile/core/config/app_config.dart';
import 'package:tanodmobile/backend/dio/api_client.dart';
import 'package:tanodmobile/backend/endpoints/app_endpoints.dart';
import 'package:tanodmobile/core/errors/app_exception.dart';
import 'package:tanodmobile/models/domain/app_user.dart';
import 'package:tanodmobile/models/domain/registration_role.dart';
import 'package:tanodmobile/models/local/app_session.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<AppSession> signIn({
    required String login,
    required String password,
  }) async {
    try {
      final payload = await _apiClient.post(
        AppEndpoints.login,
        data: {
          'login': login,
          'password': password,
          'device_name': AppConfig.appName,
        },
      );

      return AppSession.fromJson(payload);
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    } catch (error) {
      throw AppException(error.toString());
    }
  }

  Future<AppUser> fetchCurrentUser() async {
    try {
      final payload = await _apiClient.get(AppEndpoints.me);
      final userPayload = payload['user'] ?? payload['data'] ?? payload;

      if (userPayload is Map<String, dynamic>) {
        return AppUser.fromJson(userPayload);
      }

      if (userPayload is Map) {
        return AppUser.fromJson(Map<String, dynamic>.from(userPayload));
      }

      throw const AppException('Could not parse the user profile response.');
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  Future<AppSession> signUp({
    required String role,
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final payload = await _apiClient.post(
        AppEndpoints.register,
        data: {
          'role': role,
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': passwordConfirmation,
          'device_name': AppConfig.appName,
        },
      );

      return AppSession.fromJson(payload);
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    } catch (error) {
      throw AppException(error.toString());
    }
  }

  Future<List<RegistrationRole>> fetchRegistrationRoles() async {
    try {
      final payload = await _apiClient.get(AppEndpoints.registrationRoles);
      final rolesPayload = payload['data'];

      if (rolesPayload is! List) {
        return RegistrationRole.fallbacks;
      }

      final roles = rolesPayload
          .whereType<Map>()
          .map(
            (role) =>
                RegistrationRole.fromJson(Map<String, dynamic>.from(role)),
          )
          .toList(growable: false);

      return roles.isEmpty ? RegistrationRole.fallbacks : roles;
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    } catch (error) {
      throw AppException(error.toString());
    }
  }

  Future<void> signOut() async {
    try {
      await _apiClient.post(AppEndpoints.logout);
    } on DioException {
      // A failed logout should not block local session cleanup.
    }
  }

  /// Send the FCM token to the backend so push notifications can be delivered.
  Future<void> registerFcmToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      await _apiClient.put(
        AppEndpoints.fcmToken,
        data: {
          'fcm_token': token,
          'device_type': Platform.isIOS ? 'ios' : 'android',
        },
      );
    } catch (_) {
      // Non-critical — don't block the user flow.
    }
  }
}
