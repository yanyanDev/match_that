// Spec §10 step 8a — app colors and the player palette (§7 D1, P3b).
// Written test-first.
//
// These are plain `test`s, not widget tests: a Color is just data, so
// nothing has to be built on screen to check it.

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_that/engine/players.dart';
import 'package:match_that/ui/app_colors.dart';

/// WCAG contrast ratio between two colors (1 : 1 up to 21 : 1).
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('AppColors', () {
    test('match the CLAUDE.md / Figma values', () {
      expect(AppColors.cream, const Color(0xFFF3F1E9));
      expect(AppColors.ink, const Color(0xFF1A1A1A));
      expect(AppColors.grey, const Color(0xFF696861));
      expect(AppColors.lime, const Color(0xFFD9FF43));
    });
  });

  group('PlayerColor.color (D1)', () {
    test('maps each seat to its palette color, seat 1 = lime', () {
      expect(PlayerColor.color1.color, const Color(0xFFD9FF43)); // Lime
      expect(PlayerColor.color2.color, const Color(0xFF7CC8FF)); // Sky
      expect(PlayerColor.color3.color, const Color(0xFFFFA24C)); // Tangerine
      expect(PlayerColor.color4.color, const Color(0xFFFF8FC7)); // Pink
      expect(PlayerColor.color5.color, const Color(0xFF5EE6B0)); // Mint
      expect(PlayerColor.color6.color, const Color(0xFFB9A6FF)); // Lavender
      expect(PlayerColor.color7.color, const Color(0xFFFFD84D)); // Sun
      expect(PlayerColor.color8.color, const Color(0xFFFF7A6B)); // Coral
    });

    test('seat 1 is the same lime as the UI accent', () {
      expect(PlayerColor.color1.color, AppColors.lime);
    });

    test('all 8 colors are different', () {
      final colors = PlayerColor.values.map((c) => c.color).toSet();
      expect(colors, hasLength(8));
    });

    test('ink text on every player color has at least 6.8 : 1 contrast', () {
      for (final c in PlayerColor.values) {
        expect(
          contrast(AppColors.ink, c.color),
          greaterThanOrEqualTo(6.8),
          reason: '${c.name} is too dark for ink text',
        );
      }
    });
  });
}
