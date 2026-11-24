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
import 'package:match_that/screens/setup_screen.dart';

import 'helpers/game_helpers.dart';

Future<void> pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MyApp(library: TrickLibraryLoaded(equalLibrary(6))));
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
}
