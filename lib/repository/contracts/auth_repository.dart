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

  Future<void> registerFcmToken();

  Future<void> signOut();
}
