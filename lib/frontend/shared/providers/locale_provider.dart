import 'package:flutter/material.dart';
import 'package:tanodmobile/services/storage/hive_service.dart';

/// Manages the app locale and persists the choice via [HiveService].
class LocaleProvider extends ChangeNotifier {
  LocaleProvider({required HiveService hiveService})
      : _hiveService = hiveService {
    final saved = _hiveService.getLocale();
    _locale = Locale(saved);
  }

  final HiveService _hiveService;
  late Locale _locale;

  Locale get locale => _locale;

  /// Display name for the current locale.
  String get displayName {
    switch (_locale.languageCode) {
      case 'fil':
        return 'Filipino (Tagalog)';
      default:
        return 'English';
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    await _hiveService.saveLocale(locale.languageCode);
    notifyListeners();
  }
}
