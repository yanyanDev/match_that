// Spec §10 step 8c — navigation through the real app (§7 D6, D14).
// Written test-first.
//
// Pumps MyApp itself, so the SetupCubit is the one MyApp provides above
// MaterialApp: the test checks that it survives leaving Setup.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_that/cubits/trick_library_loader.dart';
import 'package:match_that/main.dart';
import 'package:match_that/screens/home_screen.dart';
import 'package:match_that/screens/game/game_screen.dart';
import 'package:match_that/screens/names_screen.dart';
import 'package:match_that/screens/setup_screen.dart';

import 'helpers/fake_wakelock.dart';
import 'helpers/game_helpers.dart';

/// Pumps the real app with a [FakeWakelock] in place of the plugin (L4).
Future<void> pumpApp(WidgetTester tester, {FakeWakelock? wakelock}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MyApp(
      library: TrickLibraryLoaded(equalLibrary(6)),
      wakelock: wakelock ?? FakeWakelock(),
    ),
  );
}

Future<void> tapStart(WidgetTester tester) async {
  await tester.tap(find.text('START'));
  await tester.pumpAndSettle();
}

Future<void> pressBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Home START opens Setup; Back returns to Home (D14)', (
    tester,
  ) async {
    await pumpApp(tester);

    await tapStart(tester);
    expect(find.byType(SetupScreen), findsOneWidget);

    await pressBack(tester);
    expect(find.byType(SetupScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('the setup is kept after leaving Setup (D14)', (tester) async {
    await pumpApp(tester);
    await tapStart(tester);

    await tester.tap(find.byTooltip('Add player'));
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);

    await pressBack(tester); // Home
    await tapStart(tester); // a new Setup page, same SetupCubit
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('11. only the Game page keeps the screen awake (L3)', (
    tester,
  ) async {
    final wakelock = FakeWakelock();
    await pumpApp(tester, wakelock: wakelock);

    // Home → Setup → Names → back to Setup: the screen may sleep.
    await tapStart(tester);
    await tester.ensureVisible(find.text('PLAYER NAMES'));
    await tester.tap(find.text('PLAYER NAMES'));
    await tester.pumpAndSettle();
    expect(find.byType(NamesScreen), findsOneWidget);
    await tester.tap(find.text('DONE'));
    await tester.pumpAndSettle();
    expect(wakelock.enables, 0);

    await tester.ensureVisible(find.text('START GAME'));
    await tester.tap(find.text('START GAME'));
    // Not pumpAndSettle: the real 100 ms game clock keeps scheduling
    // frames (see setup_screen_test 6). Pump past the page transition.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(GameScreen), findsOneWidget);
    expect(wakelock.enabled, isTrue);

    // Remove everything: the Game page is disposed, which must release the
    // wakelock (and closes the Cubit, stopping the real clock). Playing to
    // Results needs a fake clock; that path is game_wakelock_test 10.
    await tester.pumpWidget(const SizedBox());
    expect(wakelock.enabled, isFalse);
  });
}
