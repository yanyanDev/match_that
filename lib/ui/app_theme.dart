import 'package:flutter/material.dart';
import 'package:match_that/ui/app_colors.dart';
import 'package:match_that/ui/app_text_styles.dart';

/// The app-wide [ThemeData], passed to `MaterialApp(theme: ...)`.
///
/// Every widget below MaterialApp can read it with `Theme.of(context)`, and
/// Material widgets (Scaffold, AppBar, Text, ...) use it as their defaults.
/// So colors and fonts are set once here instead of on every widget.
ThemeData buildAppTheme() {
  return ThemeData(
    // Every Scaffold gets this unless it sets its own backgroundColor.
    scaffoldBackgroundColor: AppColors.cream,

    // Material widgets pick their colors from this scheme. Ink on cream, with
    // lime as the accent (D2).
    colorScheme: const ColorScheme.light(
      primary: AppColors.ink,
      onPrimary: AppColors.cream,
      secondary: AppColors.lime,
      onSecondary: AppColors.ink,
      surface: AppColors.cream,
      onSurface: AppColors.ink,
    ),

    // Note: no `fontFamily: 'Inter'` here. ThemeData applies that family to
    // *every* style in the text theme, which would turn the Anton headlines
    // into Inter. Each style below names its own family instead.
    textTheme: TextTheme(
      displayLarge: AppTextStyles.display,
      headlineMedium: AppTextStyles.headline,
      titleLarge: AppTextStyles.title,
      labelLarge: AppTextStyles.button,
      labelMedium: AppTextStyles.label,
      labelSmall: AppTextStyles.label,
      bodyLarge: AppTextStyles.body.copyWith(color: AppColors.ink),
      bodyMedium: AppTextStyles.body,
      bodySmall: AppTextStyles.body.copyWith(fontSize: 13),
    ),

    // Material 3 paints AppBars with the surface color plus a "surface tint",
    // and darkens them when content scrolls under. That's why the Settings
    // AppBar didn't match the Scaffold. Flat cream everywhere instead.
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.cream,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: AppTextStyles.label,
    ),
  );
}
