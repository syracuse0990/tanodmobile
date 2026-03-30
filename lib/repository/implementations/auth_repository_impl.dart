import 'package:tanodmobile/backend/datasources/auth_local_data_source.dart';
import 'package:tanodmobile/backend/datasources/auth_remote_data_source.dart';
import 'package:tanodmobile/core/errors/app_exception.dart';
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
      savedAt: DateTime.now(),
    );

    await _localDataSource.persistSession(refreshedSession);

    return refreshedSession;
  }

  @override
  Future<void> registerFcmToken() async {
    await _remoteDataSource.registerFcmToken();
  }

  @override
  Future<void> signOut() async {
    await _remoteDataSource.signOut();
    await _localDataSource.clearSession();
  }
}
