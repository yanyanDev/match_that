// Spec §10 step 8a — ScoreCard: one player's name and score on the Game
// screen (Figma Game; §7 D1, D2). Written test-first.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_that/engine/players.dart';
import 'package:match_that/ui/app_colors.dart';
import 'package:match_that/ui/widgets/score_card.dart';

import '../../helpers/pump_themed.dart';

/// The card's box decoration (fill and border).
BoxDecoration decorationOf(WidgetTester tester) =>
    tester
            .widget<DecoratedBox>(
              find
                  .descendant(
                    of: find.byType(ScoreCard),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .decoration
        as BoxDecoration;

void main() {
  testWidgets('shows name, score and PTS', (tester) async {
    await pumpThemed(
      tester,
      const ScoreCard(
        name: 'Alex',
        score: 7,
        color: PlayerColor.color2,
        active: false,
      ),
    );

    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('PTS'), findsOneWidget);
  });

  testWidgets("active card fills with the player's color (D2)", (
    tester,
  ) async {
    await pumpThemed(
      tester,
      const ScoreCard(
        name: 'Alex',
        score: 0,
        color: PlayerColor.color2,
        active: true,
      ),
    );

    expect(decorationOf(tester).color, PlayerColor.color2.color); // Sky
  });

  testWidgets('inactive card is cream', (tester) async {
    await pumpThemed(
      tester,
      const ScoreCard(
        name: 'Alex',
        score: 0,
        color: PlayerColor.color2,
        active: false,
      ),
    );

    expect(decorationOf(tester).color, AppColors.cream);
  });

  testWidgets('always has a 1 px ink border (D1)', (tester) async {
    for (final active in [true, false]) {
      await pumpThemed(
        tester,
        ScoreCard(
          name: 'Alex',
          score: 0,
          color: PlayerColor.color1,
          active: active,
        ),
      );
      final border = decorationOf(tester).border! as Border;
      expect(border.top.color, AppColors.ink);
      expect(border.top.width, 1);
      expect(border.isUniform, isTrue);
    }
  });

  testWidgets('long names do not overflow', (tester) async {
    await pumpThemed(
      tester,
      const ScoreCard(
        name: 'Abcdefghijkl', // 12 chars, the max (P3a)
        score: 120,
        color: PlayerColor.color1,
        active: true,
      ),
    );

    // A layout overflow is reported as an exception during the frame.
    expect(tester.takeException(), isNull);
  });
}
