import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: AppColors.forest,
            brightness: Brightness.light,
          ).copyWith(
            primary: AppColors.forest,
            secondary: AppColors.clay,
            tertiary: AppColors.gold,
            surface: Colors.white,
            onSurface: AppColors.ink,
          ),
      scaffoldBackgroundColor: AppColors.canvas,
    );

    final poppinsTheme = GoogleFonts.poppinsTextTheme(baseTheme.textTheme);

    final textTheme = poppinsTheme.copyWith(
      displayLarge: GoogleFonts.playfairDisplay(
        fontSize: 42,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      displayMedium: GoogleFonts.playfairDisplay(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      headlineLarge: GoogleFonts.playfairDisplay(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      headlineMedium: GoogleFonts.playfairDisplay(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      titleLarge: poppinsTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      bodyLarge: poppinsTheme.bodyLarge?.copyWith(
        color: AppColors.ink,
        height: 1.45,
      ),
      bodyMedium: poppinsTheme.bodyMedium?.copyWith(
        color: AppColors.mutedInk,
        height: 1.4,
      ),
    );

    return baseTheme.copyWith(
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.92),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: AppColors.forest.withValues(alpha: 0.08)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: AppColors.forest.withValues(alpha: 0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.forest, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.forest,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          textStyle: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      chipTheme: baseTheme.chipTheme.copyWith(
        backgroundColor: AppColors.sand,
        selectedColor: AppColors.forest,
        labelStyle: textTheme.bodyMedium?.copyWith(color: AppColors.ink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerColor: AppColors.forest.withValues(alpha: 0.08),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.clay,
      ),
    );
  }
}
