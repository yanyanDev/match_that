// Spec §10 step 8c — Setup screen smoke tests (§7 D8, D10, D14; §4c A4;
// §6 P1). Written test-first.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_that/cubits/setup_cubit.dart';
import 'package:match_that/engine/game_config.dart';
import 'package:match_that/engine/trick.dart';
import 'package:match_that/screens/game/game_screen.dart';
import 'package:match_that/screens/how_to_play_screen.dart';
import 'package:match_that/screens/names_screen.dart';
import 'package:match_that/screens/setup_screen.dart';
import 'package:match_that/ui/widgets/option_box.dart';
import 'package:match_that/ui/widgets/primary_button.dart';

import '../helpers/game_helpers.dart';
import '../helpers/setup_screen_helpers.dart';

Future<SetupCubit> pumpSetup(WidgetTester tester, {SetupCubit? cubit}) =>
    pumpWithSetup(tester, SetupScreen(library: equalLibrary(6)), cubit: cubit);

OptionBox option(WidgetTester tester, String title) =>
    tester.widget(find.widgetWithText(OptionBox, title));

IconButton stepperButton(WidgetTester tester, String tooltip) => tester.widget(
  find.widgetWithIcon(IconButton, switch (tooltip) {
    'Add player' => Icons.add,
    _ => Icons.remove,
  }),
);

/// Scrolls [finder] into view (small screens scroll), then taps it.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('1. renders the defaults; no ☰ menu or Rush-only text (D8)', (
    tester,
  ) async {
    await pumpSetup(tester);

    expect(find.text('SET IT OFF.'), findsOneWidget);
    expect(find.text('01 / PLAYERS'), findsOneWidget);
    expect(find.text('02 / GAME LENGTH'), findsOneWidget);
    expect(find.text('03 / DIFFICULTY'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(option(tester, 'QUICK PLAY').selected, isTrue);
    expect(option(tester, 'FULL GAME').selected, isFalse);
    expect(option(tester, 'Beginner').selected, isTrue);
    expect(option(tester, 'Advanced').selected, isFalse);

    expect(find.byIcon(Icons.menu), findsNothing);
    expect(find.textContaining('your own boards'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('2. the stepper adds and removes players within 2–8 (P1)', (
    tester,
  ) async {
    final setup = await pumpSetup(tester);
    expect(stepperButton(tester, 'Remove player').onPressed, isNull); // at 2

    await tapVisible(tester, find.byTooltip('Add player'));
    expect(setup.state.playerCount, 3);
    expect(find.text('3'), findsOneWidget);

    await tapVisible(tester, find.byTooltip('Remove player'));
    expect(setup.state.playerCount, 2);
  });

  testWidgets('2b. + is disabled at 8 players', (tester) async {
    await pumpSetup(
      tester,
      cubit: SetupCubit(SetupState(names: List.filled(8, ''))),
    );

    expect(find.text('8'), findsOneWidget);
    expect(stepperButton(tester, 'Add player').onPressed, isNull);
    expect(stepperButton(tester, 'Remove player').onPressed, isNotNull);
  });

  testWidgets('3. option boxes set length and difficulty', (tester) async {
    final setup = await pumpSetup(tester);

    await tapVisible(tester, find.text('FULL GAME'));
    expect(setup.state.length, GameLength.full);
    expect(option(tester, 'FULL GAME').selected, isTrue);

    await tapVisible(tester, find.text('Advanced'));
    expect(setup.state.difficulty, Difficulty.advanced);
    expect(option(tester, 'Advanced').selected, isTrue);
  });

  testWidgets('4. invalid names disable START GAME and say why (A4)', (
    tester,
  ) async {
    await pumpSetup(
      tester,
      cubit: SetupCubit(SetupState(names: ['Sam', 'sam'])),
    );

    final start = tester.widget<PrimaryButton>(
      find.widgetWithText(PrimaryButton, 'START GAME'),
    );
    expect(start.onPressed, isNull);
    expect(find.text('Fix the player names to start.'), findsOneWidget);
  });

  testWidgets('5. PLAYER NAMES opens the Names screen', (tester) async {
    await pumpSetup(tester);

    await tapVisible(tester, find.text('PLAYER NAMES'));
    expect(find.byType(NamesScreen), findsOneWidget);
  });

  testWidgets('5b. HOW TO PLAY opens the How to play screen (D8, D16)', (
    tester,
  ) async {
    await pumpSetup(tester);

    await tapVisible(tester, find.text('HOW TO PLAY'));
    expect(find.byType(HowToPlayScreen), findsOneWidget);
  });

  testWidgets('6. START GAME opens the Game screen with these players (D14)', (
    tester,
  ) async {
    await pumpSetup(
      tester,
      cubit: SetupCubit(SetupState(names: ['Alex', 'Sam'])),
    );

    await tester.ensureVisible(find.text('START GAME'));
    await tester.tap(find.text('START GAME'));
    // Not pumpAndSettle: the new game runs on the real 100 ms clock, which
    // keeps scheduling frames. Pump past the page transition instead.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(GameScreen), findsOneWidget);
    expect(find.text('GET READY'), findsOneWidget);
    // P4: a random player starts, so it's one of the two.
    expect(
      find.text('Alex').evaluate().length + find.text('Sam').evaluate().length,
      1,
    );

    // Remove everything: the game's BlocProvider closes its Cubit, which
    // stops the real clock. A test must not end with a timer running.
    await tester.pumpWidget(const SizedBox());
  });

  for (final width in [411.0, 360.0]) {
    testWidgets('7. the three difficulty boxes are the same size, one line '
        'each, at $width dp wide', (tester) async {
      await pumpSetup(tester);
      // Narrow the screen after pumping (pumpWithSetup sets a 411 dp phone).
      tester.view.physicalSize = Size(width * 2.625, 2400);
      await tester.pumpAndSettle();

      final sizes = [
        for (final title in ['Beginner', 'Intermediate', 'Advanced'])
          tester.getSize(find.widgetWithText(OptionBox, title)),
      ];
      expect(sizes[1], sizes[0]);
      expect(sizes[2], sizes[0]);
      for (final title in ['Beginner', 'Intermediate', 'Advanced']) {
        // A single 12 pt line, never wrapped onto two.
        expect(tester.getSize(find.text(title)).height, lessThan(20));
      }
      expect(tester.takeException(), isNull);
    });
  }
}
