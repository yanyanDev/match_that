// Spec §10 step 2 — DrawWeights (T8, T8a). Written test-first.

import 'package:flutter_test/flutter_test.dart';
import 'package:match_that/engine/draw_weights.dart';
import 'package:match_that/engine/trick.dart';

void main() {
  group('T8: default weights per game difficulty', () {
    void expectWeights(DrawWeights w, int b, int i, int a) {
      expect(w.beginner, b);
      expect(w.intermediate, i);
      expect(w.advanced, a);
    }

    test('beginner game is 80/20/0', () {
      expectWeights(DrawWeights.defaultsFor(Difficulty.beginner), 80, 20, 0);
    });

    test('intermediate game is 20/60/20', () {
      expectWeights(
        DrawWeights.defaultsFor(Difficulty.intermediate),
        20,
        60,
        20,
      );
    });

    test('advanced game is 10/30/60', () {
      expectWeights(DrawWeights.defaultsFor(Difficulty.advanced), 10, 30, 60);
    });
  });

  group('T8a: validation', () {
    test('a negative weight throws ArgumentError', () {
      expect(
        () => DrawWeights(beginner: -1, intermediate: 10, advanced: 10),
        throwsArgumentError,
      );
    });

    test('all-zero weights throw ArgumentError', () {
      expect(
        () => DrawWeights(beginner: 0, intermediate: 0, advanced: 0),
        throwsArgumentError,
      );
    });

    test('custom weights are accepted and weightOf returns each tier', () {
      final w = DrawWeights(beginner: 1, intermediate: 0, advanced: 7);
      expect(w.weightOf(Difficulty.beginner), 1);
      expect(w.weightOf(Difficulty.intermediate), 0);
      expect(w.weightOf(Difficulty.advanced), 7);
    });
  });
}
