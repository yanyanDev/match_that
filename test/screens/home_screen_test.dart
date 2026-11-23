// Spec §10 step 8a — Home smoke test (§7 D10: renders without errors, its
// main button does the right thing). Written test-first.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_that/screens/game_settings_screen.dart';
import 'package:match_that/screens/home_screen.dart';
import 'package:match_that/ui/app_theme.dart';
import 'package:match_that/ui/widgets/primary_button.dart';

Future<void> pumpHome(WidgetTester tester) async {
  // The default test screen is 800×600; use a typical phone instead
  // (1080×2400 pixels at 2.625 px per dp = about 411×914 dp).
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(theme: buildAppTheme(), home: const HomeScreen(library: [])),
  );
}

void main() {
  testWidgets('renders the title without layout errors', (tester) async {
    await pumpHome(tester);

    expect(find.text('MATCH THAT!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('START is the shared PrimaryButton', (tester) async {
    await pumpHome(tester);

    expect(
      find.widgetWithText(PrimaryButton, 'START'),
      findsOneWidget,
    );
  });

  testWidgets('tapping START opens the settings screen', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.widgetWithText(PrimaryButton, 'START'));
    // pumpAndSettle keeps rendering frames until the page transition ends.
    await tester.pumpAndSettle();

    expect(find.byType(GameSettingsScreen), findsOneWidget);
  });
}
