// Spec §10 step 8a — the app's ThemeData (§7 D5 style; CLAUDE.md colors and
// fonts). Written test-first.
//
// buildAppTheme() returns a plain ThemeData object, so we can inspect its
// fields directly without putting anything on screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_that/ui/app_colors.dart';
import 'package:match_that/ui/app_text_styles.dart';
import 'package:match_that/ui/app_theme.dart';

void main() {
  final theme = buildAppTheme();

  test('every Scaffold gets the cream background', () {
    expect(theme.scaffoldBackgroundColor, AppColors.cream);
  });

  test('color scheme: ink on cream, lime as the accent', () {
    expect(theme.colorScheme.surface, AppColors.cream);
    expect(theme.colorScheme.onSurface, AppColors.ink);
    expect(theme.colorScheme.secondary, AppColors.lime);
    expect(theme.colorScheme.onSecondary, AppColors.ink);
  });

  test('AppBars are flat and cream (no Material 3 tint or shadow)', () {
    final appBar = theme.appBarTheme;
    expect(appBar.backgroundColor, AppColors.cream);
    expect(appBar.foregroundColor, AppColors.ink);
    expect(appBar.elevation, 0);
    expect(appBar.scrolledUnderElevation, 0);
    expect(appBar.surfaceTintColor, Colors.transparent);
    expect(appBar.centerTitle, isFalse);
    expect(appBar.titleTextStyle?.fontFamily, 'IBM Plex Mono');
  });

  test('text theme uses Anton for headlines, Plex Mono for labels, '
      'Inter for body', () {
    final t = theme.textTheme;
    expect(t.displayLarge?.fontFamily, 'Anton');
    expect(t.headlineMedium?.fontFamily, 'Anton');
    expect(t.titleLarge?.fontFamily, 'Anton');
    expect(t.labelMedium?.fontFamily, 'IBM Plex Mono');
    expect(t.bodyMedium?.fontFamily, 'Inter');
  });

  test('text styles keep the sizes Home uses today', () {
    expect(AppTextStyles.display.fontSize, 116);
    expect(AppTextStyles.display.height, 1);
    expect(AppTextStyles.label.fontSize, 12);
    expect(AppTextStyles.label.letterSpacing, 2);
    expect(AppTextStyles.body.fontSize, 15);
    expect(AppTextStyles.body.color, AppColors.grey);
  });
}
