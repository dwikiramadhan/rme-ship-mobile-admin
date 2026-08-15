import 'package:flutter/material.dart';

import 'app_colors.dart';

const String appFontFamily = 'PlusJakartaSans';

/// App-wide [ThemeData], built to match the HTML prototype's visual language:
/// Plus Jakarta Sans, soft shadows instead of borders, rounded 10-14px radii.
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: appFontFamily,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.blue,
        brightness: Brightness.light,
        primary: AppColors.blue,
        error: AppColors.red,
        surface: AppColors.card,
      ),
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        fontFamily: appFontFamily,
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.card,
        foregroundColor: AppColors.text,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.blue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.red, width: 1.5),
        ),
        hintStyle: const TextStyle(color: AppColors.sub, fontSize: 14),
      ),
      splashFactory: InkRipple.splashFactory,
    );
  }
}
