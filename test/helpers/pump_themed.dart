import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_that/ui/app_theme.dart';

/// Builds [child] inside the real app theme, the way it will appear in a
/// screen.
///
/// Widgets need a MaterialApp above them for things like the theme, text
/// direction and ink ripples. `pumpWidget` builds that tree and renders one
/// frame.
Future<void> pumpThemed(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ),
  );
}
