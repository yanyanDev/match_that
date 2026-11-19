/// Tier weights for drawing tricks (spec T8, T8a). Pure Dart.
library;

import 'trick.dart';

/// How likely each trick tier is to be rolled. Weights are relative: only
/// their ratio matters, so 80/20/0 and 4/1/0 behave the same.
class DrawWeights {
  /// Throws [ArgumentError] if any weight is negative or all are 0 (T8a).
  DrawWeights({
    required this.beginner,
    required this.intermediate,
    required this.advanced,
  }) {
    if (beginner < 0 || intermediate < 0 || advanced < 0) {
      throw ArgumentError('Weights must be >= 0, got $this');
    }
    if (beginner + intermediate + advanced == 0) {
      throw ArgumentError('Weights must not all be 0');
    }
  }

  /// The spec's start weights for a game of [gameDifficulty] (T8).
  factory DrawWeights.defaultsFor(Difficulty gameDifficulty) =>
      switch (gameDifficulty) {
        Difficulty.beginner => DrawWeights(
          beginner: 80,
          intermediate: 20,
          advanced: 0,
        ),
        Difficulty.intermediate => DrawWeights(
          beginner: 20,
          intermediate: 60,
          advanced: 20,
        ),
        Difficulty.advanced => DrawWeights(
          beginner: 10,
          intermediate: 30,
          advanced: 60,
        ),
      };

  final int beginner;
  final int intermediate;
  final int advanced;

  /// The weight of trick tier [tier].
  int weightOf(Difficulty tier) => switch (tier) {
    Difficulty.beginner => beginner,
    Difficulty.intermediate => intermediate,
    Difficulty.advanced => advanced,
  };

  @override
  String toString() => 'DrawWeights($beginner/$intermediate/$advanced)';
}
