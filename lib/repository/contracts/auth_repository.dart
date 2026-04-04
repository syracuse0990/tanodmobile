import 'dart:io';

import 'package:tanodmobile/models/domain/app_user.dart';
import 'package:tanodmobile/models/domain/registration_role.dart';
import 'package:tanodmobile/models/local/app_session.dart';

abstract class AuthRepository {
  Future<AppSession?> restoreSession();

  Future<AppSession> signIn({required String login, required String password});

  Future<AppSession> signUp({
    required String role,
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
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

  Future<void> requestAccountDeletion({required String password});

  Future<void> cancelAccountDeletion();

  Future<Map<String, dynamic>> fetchAccountDeletionStatus();

  Future<void> signOut();
}
