// Spec §10 step 8a — OptionBox: the outlined choice box (Figma Setup: Quick
// play / Full game, Beginner / Intermediate / Advanced). Written test-first.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_that/ui/app_colors.dart';
import 'package:match_that/ui/widgets/option_box.dart';

import '../../helpers/pump_themed.dart';

/// The box's Material surface (fill color and border).
Material surfaceOf(WidgetTester tester) => tester.widget<Material>(
  find
      .descendant(of: find.byType(OptionBox), matching: find.byType(Material))
      .first,
);

void main() {
  testWidgets('shows title and subtitle', (tester) async {
    await pumpThemed(
      tester,
      OptionBox(
        title: 'QUICK PLAY',
        subtitle: '10 TRICKS',
        selected: false,
        onTap: () {},
      ),
    );

    expect(find.text('QUICK PLAY'), findsOneWidget);
    expect(find.text('10 TRICKS'), findsOneWidget);
  });

  testWidgets('subtitle is optional', (tester) async {
    await pumpThemed(
      tester,
      OptionBox(title: 'Beginner', selected: false, onTap: () {}),
    );

    expect(find.text('Beginner'), findsOneWidget);
  });

  testWidgets('selected = lime fill, unselected = cream fill', (tester) async {
    await pumpThemed(
      tester,
      OptionBox(title: 'A', selected: true, onTap: () {}),
    );
    expect(surfaceOf(tester).color, AppColors.lime);

    await pumpThemed(
      tester,
      OptionBox(title: 'A', selected: false, onTap: () {}),
    );
    expect(surfaceOf(tester).color, AppColors.cream);
  });

  testWidgets('always has a square 1 px ink border', (tester) async {
    for (final selected in [true, false]) {
      await pumpThemed(
        tester,
        OptionBox(title: 'A', selected: selected, onTap: () {}),
      );
      final shape = surfaceOf(tester).shape;
      expect(shape, isA<RoundedRectangleBorder>());
      shape as RoundedRectangleBorder;
      expect(shape.side.color, AppColors.ink);
      expect(shape.side.width, 1);
      expect(shape.borderRadius, BorderRadius.zero);
    }
  });

  testWidgets('tapping it calls onTap', (tester) async {
    var taps = 0;
    await pumpThemed(
      tester,
      OptionBox(title: 'A', selected: false, onTap: () => taps++),
    );

    await tester.tap(find.byType(OptionBox));
    expect(taps, 1);
  });

  testWidgets('tells screen readers it is a selected button', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpThemed(
      tester,
      OptionBox(title: 'A', selected: true, onTap: () {}),
    );

    expect(
      tester.getSemantics(find.byType(OptionBox)),
      isSemantics(isButton: true, isSelected: true),
    );
    semantics.dispose();
  });
}
