import 'package:tanodmobile/models/local/app_session.dart';
import 'package:tanodmobile/services/storage/hive_service.dart';

class AuthLocalDataSource {
  AuthLocalDataSource({required HiveService hiveService})
    : _hiveService = hiveService;

  final HiveService _hiveService;

  AppSession? getSession() {
    return _hiveService.getSession();
  }

  AppSession? getOfflineTpsSession() {
    return _hiveService.getOfflineTpsSession();
  }

  Future<void> persistSession(AppSession session) async {
    await _hiveService.saveSession(session);
  }

  Future<void> persistOfflineTpsSession(AppSession session) async {
    await _hiveService.saveOfflineTpsSession(session);
  }

  Future<void> clearSession() async {
    await _hiveService.clearSession();
  }

  Future<void> clearOfflineTpsSession() async {
    await _hiveService.clearOfflineTpsSession();
  }

  bool getOfflineModeEnabled() {
    return _hiveService.getOfflineModeEnabled();
  }

  Future<void> setOfflineModeEnabled(bool enabled) async {
    await _hiveService.setOfflineModeEnabled(enabled);
  }
}
