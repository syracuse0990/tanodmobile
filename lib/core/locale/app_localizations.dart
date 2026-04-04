import 'package:flutter/material.dart';
import 'package:tanodmobile/core/locale/app_translations.dart';

/// Localization class that provides translated strings via [BuildContext].
class AppLocalizations {
  final Locale locale;

  const AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  /// Look up a translation key for the current locale.
  String tr(String key) {
    return AppTranslations.get(locale.languageCode, key);
  }

  // ─── Supported locales ───

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('fil'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'fil'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

/// Convenience extension so widgets can call `context.tr('key')`.
extension AppLocalizationsX on BuildContext {
  String tr(String key) => AppLocalizations.of(this).tr(key);
}
