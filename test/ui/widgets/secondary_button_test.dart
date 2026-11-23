// Spec §10 step 8b — SecondaryButton: the cream outlined button (Figma Game
// MISSED, Results HOME; pause menu Undo / End game). Written test-first.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_that/ui/app_colors.dart';
import 'package:match_that/ui/widgets/secondary_button.dart';

import '../../helpers/pump_themed.dart';

/// The button's Material surface (fill color and border).
Material surfaceOf(WidgetTester tester) => tester.widget<Material>(
  find
      .descendant(
        of: find.byType(SecondaryButton),
        matching: find.byType(Material),
      )
      .first,
);

void main() {
  testWidgets('shows the label, no arrow by default', (tester) async {
    await pumpThemed(tester, SecondaryButton(label: 'MISSED', onPressed: () {}));

    expect(find.text('MISSED'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward), findsNothing);
  });

  testWidgets('tapping it calls onPressed', (tester) async {
    var taps = 0;
    await pumpThemed(
      tester,
      SecondaryButton(label: 'MISSED', onPressed: () => taps++),
    );

    await tester.tap(find.byType(SecondaryButton));
    expect(taps, 1);
  });

  testWidgets('cream fill with a square 1 px ink border, full width', (
    tester,
  ) async {
    await pumpThemed(tester, SecondaryButton(label: 'HOME', onPressed: () {}));

    final surface = surfaceOf(tester);
    expect(surface.color, AppColors.cream);
    final shape = surface.shape! as RoundedRectangleBorder;
    expect(shape.side.color, AppColors.ink);
    expect(shape.side.width, 1);
    expect(shape.borderRadius, BorderRadius.zero);
    expect(tester.getSize(find.byType(SecondaryButton)).width, 800 - 32);
    expect(tester.getSize(find.byType(SecondaryButton)).height, 56);
  });

  testWidgets('height can be changed (MISSED, D4)', (tester) async {
    await pumpThemed(
      tester,
      SecondaryButton(label: 'MISSED', onPressed: () {}, height: 72),
    );

    expect(tester.getSize(find.byType(SecondaryButton)).height, 72);
  });

  testWidgets('with onPressed null it is disabled: grey label (U3 Undo)', (
    tester,
  ) async {
    await pumpThemed(
      tester,
      const SecondaryButton(label: 'UNDO LAST CALL', onPressed: null),
    );

    await tester.tap(find.byType(SecondaryButton)); // must not throw
    final text = tester.widget<Text>(find.text('UNDO LAST CALL'));
    expect(text.style?.color, AppColors.grey);
  });
}
