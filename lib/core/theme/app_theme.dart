import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Material 3 semantic color roles that ColorScheme doesn't cover
/// (success / warning / info-purple), exposed as a [ThemeExtension] so
/// widgets can read them via `Theme.of(context).extension<AppSemanticColors>()`.
///
/// Values map 1:1 to the existing [AppColors] tokens so the visual language
/// stays identical while following the M3 "color role + container" pattern
/// (https://m3.material.io/styles/color/roles).
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
    required this.info,
    required this.infoContainer,
  });

  final Color success;
  final Color successContainer;
  final Color warning;
  final Color warningContainer;
  final Color info;
  final Color infoContainer;

  static const light = AppSemanticColors(
    success: AppColors.green,
    successContainer: AppColors.greenLt,
    warning: AppColors.yellow,
    warningContainer: AppColors.yellowLt,
    info: AppColors.purple,
    infoContainer: AppColors.purpleLt,
  );

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? successContainer,
    Color? warning,
    Color? warningContainer,
    Color? info,
    Color? infoContainer,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      info: info ?? this.info,
      infoContainer: infoContainer ?? this.infoContainer,
    );
  }

  @override
  AppSemanticColors lerp(AppSemanticColors? other, double t) {
    if (other == null) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
    );
  }
}

const String appFontFamily = 'PlusJakartaSans';

/// App-wide [ThemeData] following Material 3 (https://m3.material.io):
/// tonal color scheme seeded from the brand blue, M3 component themes, and
/// the M3 type scale rendered in Plus Jakarta Sans. Visual language of the
/// original prototype (soft shadows, white cards, rounded corners) is kept.
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    // Full M3 tonal palette derived from the brand seed. Brand-critical roles
    // (primary, error, surface) are pinned to the prototype tokens; every
    // other role (containers, on-colors, outline, inverse, etc.) comes from
    // the seed so the scheme stays M3-consistent.
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.blue,
      brightness: Brightness.light,
      primary: AppColors.blue,
      onPrimary: Colors.white,
      primaryContainer: AppColors.blueLt,
      onPrimaryContainer: AppColors.blue,
      secondary: AppColors.blueMid,
      onSecondary: Colors.white,
      tertiary: AppColors.purple,
      tertiaryContainer: AppColors.purpleLt,
      onTertiaryContainer: AppColors.purple,
      error: AppColors.red,
      onError: Colors.white,
      errorContainer: AppColors.redLt,
      onErrorContainer: AppColors.red,
      surface: AppColors.card,
      onSurface: AppColors.text,
      surfaceContainerLowest: AppColors.card,
      surfaceContainerLow: AppColors.card2,
      surfaceContainer: AppColors.bg,
      onSurfaceVariant: AppColors.sub,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
    );

    final base = ThemeData(
      useMaterial3: true,
      fontFamily: appFontFamily,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.bg,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );

    // M3 type scale (display -> label) in Plus Jakarta Sans.
    final textTheme = base.textTheme.apply(
      fontFamily: appFontFamily,
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    );

    return base.copyWith(
      textTheme: textTheme,
      extensions: const [AppSemanticColors.light],

      // -- App bar (M3 small top app bar: flat, surface, no tint shift) ----
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.card,
        foregroundColor: AppColors.text,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),

      // -- Cards (M3 elevated card, radius 12, no surface tint) -----------
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 1,
        surfaceTintColor: Colors.transparent,
        shadowColor: AppColors.text.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.zero,
      ),

      // -- Buttons ---------------------------------------------------------
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, fontFamily: appFontFamily),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, fontFamily: appFontFamily),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          side: const BorderSide(color: AppColors.border, width: 1.5),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, fontFamily: appFontFamily),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontFamily: appFontFamily),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),

      // -- Inputs (M3 filled text field, kept as the prototype's soft fill) -
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
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.red, width: 1.5),
        ),
        hintStyle: const TextStyle(color: AppColors.sub, fontSize: 14),
      ),

      // -- Chips (M3 assist/filter chip shape) ------------------------------
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.card2,
        selectedColor: AppColors.blueLt,
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
          fontFamily: appFontFamily,
        ),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),

      // -- Navigation rail (M3 rail with secondary-container indicator) -----
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.shellBg,
        indicatorColor: colorScheme.primary,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        selectedIconTheme: const IconThemeData(color: Colors.white, size: 22),
        unselectedIconTheme: IconThemeData(color: Colors.white.withValues(alpha: 0.6), size: 22),
        selectedLabelTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          fontFamily: appFontFamily,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          fontFamily: appFontFamily,
        ),
      ),

      // -- Dialogs / sheets / snackbars ------------------------------------
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titleTextStyle: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.text,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 13.5,
          fontFamily: appFontFamily,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // -- Misc -------------------------------------------------------------
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.sub,
        textColor: AppColors.text,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.blue),
    );
  }
}
