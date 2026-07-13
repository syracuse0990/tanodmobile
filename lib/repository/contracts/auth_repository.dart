import 'dart:io';

import 'package:tanodmobile/models/domain/app_user.dart';
import 'package:tanodmobile/models/domain/registration_role.dart';
import 'package:tanodmobile/models/local/app_session.dart';

abstract class AuthRepository {
  Future<AppSession?> restoreSession();

  Future<void> persistSession(AppSession session);

  Future<AppSession?> restoreOfflineTpsSession();

  Future<void> saveOfflineTpsSession(AppSession session);

  Future<void> clearOfflineTpsSession();

  Future<bool> getOfflineModeEnabled();

  Future<void> setOfflineModeEnabled(bool enabled);

  Future<AppSession> signIn({required String login, required String password});

  Future<AppSession> signUp({
    required String role,
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? coopName,
    String? phone,
  });

  Future<List<RegistrationRole>> fetchRegistrationRoles();

  Future<AppSession> refreshSession(AppSession session);

  Future<AppUser> updateProfile({
    required Map<String, dynamic> fields,
    File? photo,
  });

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  });

  Future<void> sendPhoneVerificationCode();

  Future<AppUser> verifyPhone({required String code});

  Future<void> registerFcmToken();

  Future<Map<String, dynamic>> sendForgotPasswordOtp({required String contact});

  Future<Map<String, dynamic>> verifyForgotPasswordOtp({required String contact, required String otp});

  Future<void> resetForgotPassword({
    required String contact,
    required String verifiedToken,
    required String password,
    required String passwordConfirmation,
  });

  Future<void> requestAccountDeletion({required String password});

  Future<void> cancelAccountDeletion();

  Future<Map<String, dynamic>> fetchAccountDeletionStatus();

  Future<void> signOut();
}
