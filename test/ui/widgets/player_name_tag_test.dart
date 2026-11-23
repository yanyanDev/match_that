// Spec §10 step 8b — PlayerNameTag: a player's name on their color (§7 D1,
// D2: the current-turn name uses the player's color). Written test-first.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_that/engine/players.dart';
import 'package:match_that/ui/app_colors.dart';
import 'package:match_that/ui/widgets/player_name_tag.dart';

import '../../helpers/pump_themed.dart';

/// The tag's box decoration (fill and border).
BoxDecoration decorationOf(WidgetTester tester) =>
    tester
            .widget<DecoratedBox>(
              find
                  .descendant(
                    of: find.byType(PlayerNameTag),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .decoration
        as BoxDecoration;

void main() {
  testWidgets('shows the name in Anton, ink text', (tester) async {
    await pumpThemed(
      tester,
      const PlayerNameTag(name: 'Alex', color: PlayerColor.color2),
    );

    final text = tester.widget<Text>(find.text('Alex'));
    expect(text.style?.fontFamily, 'Anton');
    expect(text.style?.color, AppColors.ink);
  });

  testWidgets("fills with the player's color and a 1 px ink border (D1)", (
    tester,
  ) async {
    await pumpThemed(
      tester,
      const PlayerNameTag(name: 'Alex', color: PlayerColor.color2),
    );

    final decoration = decorationOf(tester);
    expect(decoration.color, PlayerColor.color2.color); // Sky
    final border = decoration.border! as Border;
    expect(border.isUniform, isTrue);
    expect(border.top.color, AppColors.ink);
    expect(border.top.width, 1);
  });

  testWidgets('is only as wide as the name, not the whole row', (
    tester,
  ) async {
    await pumpThemed(
      tester,
      const PlayerNameTag(name: 'Al', color: PlayerColor.color1),
    );

    expect(
      tester.getSize(find.byType(PlayerNameTag)).width,
      lessThan(800 - 32),
    );
  });

  testWidgets('a 12-character name fits on a phone without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    await pumpThemed(
      tester,
      const PlayerNameTag(name: 'WWWWWWWWWWWW', color: PlayerColor.color8),
    );

    expect(tester.takeException(), isNull);
  });
}
