import 'package:tanodmobile/models/local/app_session.dart';
import 'package:tanodmobile/services/storage/hive_service.dart';

class AuthLocalDataSource {
  AuthLocalDataSource({required HiveService hiveService})
    : _hiveService = hiveService;

  final HiveService _hiveService;

  AppSession? getSession() {
    return _hiveService.getSession();
  }

  Future<void> persistSession(AppSession session) async {
    await _hiveService.saveSession(session);
  }

  Future<void> clearSession() async {
    await _hiveService.clearSession();
  }
}
