// Spec §10 step 8a — SectionLabel: the numbered mono label above each Setup
// section ("01 / PLAYERS"). Written test-first.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_that/ui/widgets/section_label.dart';

import '../../helpers/pump_themed.dart';

void main() {
  testWidgets('pads the number to 2 digits and upper-cases the text', (
    tester,
  ) async {
    await pumpThemed(tester, const SectionLabel(number: 1, text: 'Players'));
    expect(find.text('01 / PLAYERS'), findsOneWidget);
  });

  testWidgets('two-digit numbers are not padded', (tester) async {
    await pumpThemed(tester, const SectionLabel(number: 12, text: 'x'));
    expect(find.text('12 / X'), findsOneWidget);
  });

  testWidgets('uses IBM Plex Mono', (tester) async {
    await pumpThemed(tester, const SectionLabel(number: 2, text: 'Game length'));
    final text = tester.widget<Text>(find.text('02 / GAME LENGTH'));
    expect(text.style?.fontFamily, 'IBM Plex Mono');
  });
}
