import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/core/locale/app_localizations.dart';
import 'package:tanodmobile/frontend/shared/providers/locale_provider.dart';

/// Shows a bottom sheet that lets the user pick English or Tagalog.
Future<void> showLanguagePicker(BuildContext context) {
  final localeProvider = context.read<LocaleProvider>();

  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.mutedInk.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.tr('select_language'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 20),
              _LanguageOption(
                label: 'English',
                locale: const Locale('en'),
                selected: localeProvider.locale.languageCode == 'en',
                onTap: () {
                  localeProvider.setLocale(const Locale('en'));
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 10),
              _LanguageOption(
                label: 'Filipino (Tagalog)',
                locale: const Locale('fil'),
                selected: localeProvider.locale.languageCode == 'fil',
                onTap: () {
                  localeProvider.setLocale(const Locale('fil'));
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.locale,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Locale locale;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.forest.withValues(alpha: 0.08)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.forest
                  : AppColors.mutedInk.withValues(alpha: 0.15),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Text(
                locale.languageCode == 'fil' ? '🇵🇭' : '🇺🇸',
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppColors.forest : AppColors.ink,
                  ),
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.forest,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
