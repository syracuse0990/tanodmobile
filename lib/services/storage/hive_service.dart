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

  // ─── Tutorials ──────────────────────────────────

  static const _tutorialEnabledKey = 'tutorials_enabled';
  static const _tutorialKeys = [
    'tutorial_home',
    'tutorial_tractor_detail',
    'tutorial_bookings',
    'tutorial_chat',
    'tutorial_account',
    'tutorial_track_history',
    'tutorial_feedback',
    'tutorial_alerts',
    'tutorial_tickets',
    'tutorial_create_ticket',
    'tutorial_ticket_detail',
    'tutorial_geofences',
    'tutorial_create_geofence',
    'tutorial_geofence_detail',
    'tutorial_edit_geofence',
  ];

  /// Whether tutorials are enabled (default: true).
  bool get tutorialsEnabled => _preferencesBox.get(_tutorialEnabledKey) != 'false';

  Future<void> setTutorialsEnabled(bool enabled) async {
    await _preferencesBox.put(_tutorialEnabledKey, enabled ? 'true' : 'false');
  }

  /// Delete all tutorial "already seen" flags so they show again.
  Future<void> resetAllTutorials() async {
    for (final key in _tutorialKeys) {
      await _preferencesBox.delete(key);
    }
    await _preferencesBox.put(_tutorialEnabledKey, 'true');
  }
}
