// Spec §10 step 8d — How to play smoke tests (§7 D8, D10, D16). Written
// test-first.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_that/screens/how_to_play_screen.dart';

import '../helpers/setup_screen_helpers.dart';

/// The section headings, in order (the text the developer approved, D16).
const headings = [
  'THE IDEA',
  'TAKING TURNS',
  'SCORING',
  'THE TIMER',
  'TOO HARD?',
  'WINNING',
  'PAUSE, UNDO, END GAME',
  'SUDDEN DEATH',
];

Future<void> pumpHowToPlay(WidgetTester tester) =>
    pumpWithSetup(tester, const HowToPlayScreen());

void main() {
  testWidgets('1. shows the title and starts with THE IDEA', (tester) async {
    await pumpHowToPlay(tester);

    expect(find.text('HOW TO PLAY'), findsOneWidget);
    expect(find.text('THE IDEA'), findsOneWidget);
    expect(find.textContaining('One phone, your board.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('2. every section is reachable by scrolling down (D16)', (
    tester,
  ) async {
    await pumpHowToPlay(tester);

    final list = tester.state<ScrollableState>(find.byType(Scrollable));

    // From the top each time: scroll down until the heading shows.
    for (final heading in headings) {
      list.position.jumpTo(0);
      await tester.pump();
      await tester.scrollUntilVisible(find.text(heading), 200);
      expect(find.text(heading), findsOneWidget);
    }
    // The last sentence of the last section.
    await tester.scrollUntilVisible(find.textContaining('shared win'), 200);
    expect(tester.takeException(), isNull);
  });

  testWidgets('3. the menu choices are three separate lines', (tester) async {
    await pumpHowToPlay(tester);

    await tester.scrollUntilVisible(find.text('PAUSE, UNDO, END GAME'), 200);
    // scrollUntilVisible ends with a jump; pump a frame so the lines below
    // the heading count as on screen.
    await tester.pump();
    for (final choice in ['Resume', 'Undo last call', 'End game']) {
      expect(find.textContaining(choice), findsWidgets);
    }
  });

  testWidgets('4. Back returns to the page below (Setup)', (tester) async {
    await pumpHowToPlay(tester);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(HowToPlayScreen), findsNothing);
    expect(find.text(belowPage), findsOneWidget);
  });
}
