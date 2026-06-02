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

    if (!Hive.isBoxOpen(HiveBoxes.preferences)) {
      await Hive.openBox<String>(HiveBoxes.preferences);
    }
  }

  Box<AppSession> get _sessionBox => Hive.box<AppSession>(HiveBoxes.session);
  Box<String> get _preferencesBox => Hive.box<String>(HiveBoxes.preferences);

  AppSession _detachedSession(AppSession session) {
    return session.copyWith(
      roles: List<String>.from(session.roles),
      savedAt: session.savedAt,
    );
  }

  AppSession? getSession() {
    return _sessionBox.get(HiveBoxes.sessionKey);
  }

  AppSession? getOfflineTpsSession() {
    return _sessionBox.get(HiveBoxes.offlineTpsSessionKey);
  }

  Future<void> saveSession(AppSession session) async {
    await _sessionBox.put(HiveBoxes.sessionKey, _detachedSession(session));
  }

  Future<void> saveOfflineTpsSession(AppSession session) async {
    await _sessionBox.put(
      HiveBoxes.offlineTpsSessionKey,
      _detachedSession(session),
    );
  }

  Future<void> clearSession() async {
    await _sessionBox.delete(HiveBoxes.sessionKey);
  }

  Future<void> clearOfflineTpsSession() async {
    await _sessionBox.delete(HiveBoxes.offlineTpsSessionKey);
  }

  // ─── Locale Preference ───

  String getLocale() {
    return _preferencesBox.get(HiveBoxes.localeKey, defaultValue: 'en')!;
  }

  Future<void> saveLocale(String localeCode) async {
    await _preferencesBox.put(HiveBoxes.localeKey, localeCode);
  }

  String? getPreference(String key) {
    return _preferencesBox.get(key);
  }

  Future<void> savePreference(String key, String value) async {
    await _preferencesBox.put(key, value);
  }

  bool getOfflineModeEnabled() {
    return _preferencesBox.get(HiveBoxes.authOfflineModeEnabledKey) == 'true';
  }

  Future<void> setOfflineModeEnabled(bool enabled) async {
    if (enabled) {
      await _preferencesBox.put(HiveBoxes.authOfflineModeEnabledKey, 'true');
      return;
    }

    await _preferencesBox.delete(HiveBoxes.authOfflineModeEnabledKey);
  }

  Future<void> removePreference(String key) async {
    await _preferencesBox.delete(key);
  }
}
