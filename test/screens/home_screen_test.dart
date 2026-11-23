// Spec §10 step 8a — Home smoke test (§7 D10: renders without errors, its
// main button does the right thing). Written test-first.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_that/cubits/setup_cubit.dart';
import 'package:match_that/engine/trick.dart';
import 'package:match_that/screens/game/game_screen.dart';
import 'package:match_that/screens/home_screen.dart';
import 'package:match_that/screens/setup_screen.dart';
import 'package:match_that/ui/app_theme.dart';
import 'package:match_that/ui/widgets/primary_button.dart';

import '../helpers/game_helpers.dart';

Future<void> pumpHome(
  WidgetTester tester, {
  List<Trick> library = const [],
}) async {
  // The default test screen is 800×600; use a typical phone instead
  // (1080×2400 pixels at 2.625 px per dp = about 411×914 dp).
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);

  // The SetupCubit sits above MaterialApp, as in the app (D14), so the Setup
  // page that START opens can find it.
  final setup = SetupCubit();
  addTearDown(setup.close);
  await tester.pumpWidget(
    BlocProvider.value(
      value: setup,
      child: MaterialApp(
        theme: buildAppTheme(),
        home: HomeScreen(library: library),
      ),
    ),
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

    expect(find.widgetWithText(PrimaryButton, 'START'), findsOneWidget);
  });

  testWidgets('tapping START opens the Setup screen (step 8c)', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.widgetWithText(PrimaryButton, 'START'));
    // pumpAndSettle keeps rendering frames until the page transition ends.
    await tester.pumpAndSettle();

    expect(find.byType(SetupScreen), findsOneWidget);
  });

  testWidgets('DEBUG GAME opens the Game screen with the default setup '
      '(step 8b)', (tester) async {
    await pumpHome(tester, library: equalLibrary(6));

    await tester.tap(find.text('DEBUG GAME'));
    // Not pumpAndSettle: this game runs on the real 100 ms clock, which
    // keeps scheduling frames. Pump past the page transition instead.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(GameScreen), findsOneWidget);
    expect(find.text('GET READY'), findsOneWidget);
    expect(
      find.text('Player 1').evaluate().isNotEmpty ||
          find.text('Player 2').evaluate().isNotEmpty,
      isTrue,
    );

    // Remove the screen: its BlocProvider closes the Cubit, which stops the
    // real clock. A test must not end with a timer still running.
    await tester.pumpWidget(const SizedBox());
  });
}
