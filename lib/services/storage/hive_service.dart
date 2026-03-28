import 'package:hive_flutter/hive_flutter.dart';
import 'package:tanodmobile/core/constants/hive_boxes.dart';
import 'package:tanodmobile/models/local/app_session.dart';

class HiveService {
  static Future<void> initialize() async {
    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(AppSessionAdapter());
    }

    if (!Hive.isBoxOpen(HiveBoxes.session)) {
      await Hive.openBox<AppSession>(HiveBoxes.session);
    }
  }

  Box<AppSession> get _sessionBox => Hive.box<AppSession>(HiveBoxes.session);

  AppSession? getSession() {
    return _sessionBox.get(HiveBoxes.sessionKey);
  }

  Future<void> saveSession(AppSession session) async {
    await _sessionBox.put(HiveBoxes.sessionKey, session);
  }

  Future<void> clearSession() async {
    await _sessionBox.delete(HiveBoxes.sessionKey);
  }
}
