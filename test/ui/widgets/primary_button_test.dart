// Spec §10 step 8a — PrimaryButton: the lime button with an arrow (Figma
// START / START GAME / DONE; D2 "lime stays the UI accent"). Written test-first.
//
// testWidgets gives us a WidgetTester: `pumpWidget` builds widgets in a fake
// screen, `find` locates them, and `tap` simulates a finger.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_that/ui/app_colors.dart';
import 'package:match_that/ui/widgets/primary_button.dart';

import '../../helpers/pump_themed.dart';

/// The fill color of the button's Material surface.
Color? fillOf(WidgetTester tester) => tester
    .widget<Material>(
      find
          .descendant(
            of: find.byType(PrimaryButton),
            matching: find.byType(Material),
          )
          .first,
    )
    .color;

void main() {
  testWidgets('shows the label and a right arrow', (tester) async {
    await pumpThemed(tester, PrimaryButton(label: 'START', onPressed: () {}));

    expect(find.text('START'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
  });

  testWidgets('tapping it calls onPressed', (tester) async {
    var taps = 0;
    await pumpThemed(
      tester,
      PrimaryButton(label: 'START', onPressed: () => taps++),
    );

    await tester.tap(find.byType(PrimaryButton));
    expect(taps, 1);
  });

  testWidgets('is filled lime and fills the width', (tester) async {
    await pumpThemed(tester, PrimaryButton(label: 'START', onPressed: () {}));

    expect(fillOf(tester), AppColors.lime);
    // pumpThemed pads the 800 px wide test screen by 16 on each side.
    expect(tester.getSize(find.byType(PrimaryButton)).width, 800 - 32);
    expect(
      tester.getSize(find.byType(PrimaryButton)).height,
      greaterThanOrEqualTo(56),
    );
  });

  testWidgets('with onPressed null it is disabled and not lime', (
    tester,
  ) async {
    await pumpThemed(
      tester,
      const PrimaryButton(label: 'START GAME', onPressed: null),
    );

    // Nothing to call, so the tap just must not throw.
    await tester.tap(find.byType(PrimaryButton));
    expect(fillOf(tester), isNot(AppColors.lime));
  });
}
