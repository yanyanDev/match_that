/// Game settings for Default (turn-based) mode (spec §4a G1). Pure Dart.
library;

import 'draw_weights.dart';
import 'trick.dart';

/// How many **landed** tricks end the game (R8, G1).
enum GameLength {
  quickplay(10),
  full(30);

  const GameLength(this.target);

  final int target;
}

/// Everything the engine needs to know about a game besides the players and
/// the trick library. Immutable.
class GameConfig {
  /// Throws [ArgumentError] if [target] < 1, [trickTime] <= 0, or
  /// [countdown] / [reveal] are negative. 0 is allowed for [countdown] and
  /// [reveal] (tests use it to skip those phases).
  GameConfig({
    required this.target,
    required this.weights,
    this.trickTime = const Duration(seconds: 60),
    this.countdown = const Duration(seconds: 3),
    this.reveal = const Duration(seconds: 1),
  }) {
    if (target < 1) {
      throw ArgumentError.value(target, 'target', 'Must be at least 1');
    }
    if (trickTime <= Duration.zero) {
      throw ArgumentError.value(trickTime, 'trickTime', 'Must be above 0');
    }
    if (countdown.isNegative) {
      throw ArgumentError.value(countdown, 'countdown', 'Must not be negative');
    }
    if (reveal.isNegative) {
      throw ArgumentError.value(reveal, 'reveal', 'Must not be negative');
    }
  }

  /// The spec's defaults for a game of [difficulty] and [length] (G1, T8).
  factory GameConfig.forSetup(Difficulty difficulty, GameLength length) =>
      GameConfig(
        target: length.target,
        weights: DrawWeights.defaultsFor(difficulty),
      );

  /// Landed tricks needed to end the game (R8).
  final int target;

  /// Tier weights for every draw (T8).
  final DrawWeights weights;

  /// Time allowed per trick (§4).
  final Duration trickTime;

  /// The 3-2-1 before play starts (§4).
  final Duration countdown;

  /// The transition shown before every new trick (§4).
  final Duration reveal;
}
