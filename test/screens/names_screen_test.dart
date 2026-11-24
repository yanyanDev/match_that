// Spec §10 step 8c — Names screen smoke tests (§7 D13, D10; §6 P3, P3a;
// §4c A4). Written test-first.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_that/screens/names_screen.dart';

import '../helpers/setup_screen_helpers.dart';

/// Opens the edit dialog by tapping the row that shows [name].
Future<void> openRow(WidgetTester tester, String name) async {
  await tester.tap(find.text(name));
  await tester.pumpAndSettle(); // the dialog's open animation
}

/// Types [text] into the dialog and taps SAVE.
Future<void> saveName(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.tap(find.text('SAVE'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('1. one row per seat with the default names and helper text', (
    tester,
  ) async {
    await pumpWithSetup(tester, const NamesScreen());

    expect(find.text('YOUR CREW.'), findsOneWidget);
    expect(
      find.text('Tap a name to change it. Leave it blank to use Player N.'),
      findsOneWidget,
    );
    expect(find.text('01'), findsOneWidget);
    expect(find.text('02'), findsOneWidget);
    expect(find.text('Player 1'), findsOneWidget);
    expect(find.text('Player 2'), findsOneWidget);
    expect(find.byIcon(Icons.north_east), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('2. tap a row, type a name, SAVE: the setup and row update', (
    tester,
  ) async {
    final setup = await pumpWithSetup(tester, const NamesScreen());

    await openRow(tester, 'Player 1');
    expect(find.text('PLAYER 01'), findsOneWidget); // dialog title
    await saveName(tester, 'Alex');

    expect(setup.state.names[0], 'Alex');
    expect(find.byType(TextField), findsNothing); // dialog closed
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Player 1'), findsNothing);
  });

  testWidgets('3. CANCEL leaves the name unchanged', (tester) async {
    final setup = await pumpWithSetup(tester, const NamesScreen());

    await openRow(tester, 'Player 1');
    await tester.enterText(find.byType(TextField), 'Alex');
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();

    expect(setup.state.names[0], '');
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Player 1'), findsOneWidget);
  });

  testWidgets('4. the field stops at 12 characters (P3a)', (tester) async {
    await pumpWithSetup(tester, const NamesScreen());

    await openRow(tester, 'Player 1');
    await tester.enterText(find.byType(TextField), 'ABCDEFGHIJKLM'); // 13

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'ABCDEFGHIJKL');
  });

  testWidgets('5. a duplicate shows its error under both rows; Start is '
      'blocked (A4)', (tester) async {
    final setup = await pumpWithSetup(tester, const NamesScreen());

    // Seat 2 typed as "player 1": the same as seat 1's default, ignoring
    // case (P3a).
    await openRow(tester, 'Player 2');
    await saveName(tester, 'player 1');

    expect(find.text('Same name as 02'), findsOneWidget); // under row 01
    expect(find.text('Same name as 01'), findsOneWidget); // under row 02
    expect(setup.state.canStart, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('6. DONE goes back', (tester) async {
    await pumpWithSetup(tester, const NamesScreen());

    await tester.tap(find.text('DONE'));
    await tester.pumpAndSettle();

    expect(find.byType(NamesScreen), findsNothing);
    expect(find.text(belowPage), findsOneWidget);
  });
}
