// Shared helpers for the Default-mode engine tests (steps 4 and 5).

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:match_that/engine/draw_weights.dart';
import 'package:match_that/engine/game_config.dart';
import 'package:match_that/engine/game_state.dart';
import 'package:match_that/engine/players.dart';
import 'package:match_that/engine/trick.dart';
import 'package:match_that/engine/turn_based_game.dart';

import 'fake_random.dart';

Trick trick(String id, int points, [Difficulty tier = Difficulty.beginner]) =>
    Trick(
      id: id,
      name: id,
      trick: id,
      stance: Stance.regular,
      modifier: null,
      points: points,
      difficulty: tier,
    );

/// Three beginner tricks worth 3, 5 and 7 points.
final library3 = [trick('b0', 3), trick('b1', 5), trick('b2', 7)];

final onlyBeginner = DrawWeights(beginner: 1, intermediate: 0, advanced: 0);

/// [n] beginner tricks t0…t(n-1), all worth 1 point, so ties are easy.
List<Trick> equalLibrary(int n) => [
  for (var i = 0; i < n; i++) trick('t$i', 1),
];

/// Ticks through a countdown or reveal, so the trick is being attempted.
GameState toPlay(TurnBasedGame game, GameState s) =>
    s.phase == GamePhase.attempting ? s : game.tick(s, s.phaseRemaining);

/// Applies [calls] in order ('L' = landed, 'M' = missed), ticking through
/// any countdown or reveal before each one.
GameState play(TurnBasedGame game, GameState s, String calls) {
  var state = s;
  for (final call in calls.split('')) {
    state = toPlay(game, state);
    state = switch (call) {
      'L' => game.landed(state),
      'M' => game.missed(state),
      _ => throw ArgumentError.value(call, 'calls', "Use 'L' or 'M'"),
    };
  }
  return state;
}

/// [n] players with ids p1…pN at seats 0…N-1. Built directly (not with
/// `buildPlayers`) so tests can also make invalid counts.
List<Player> makePlayers(int n) => [
  for (var seat = 0; seat < n; seat++)
    Player(
      id: 'p${seat + 1}',
      seat: seat,
      name: 'P${seat + 1}',
      color: PlayerColor.color1,
    ),
];

/// A config with no countdown and no reveal, so no ticks are needed.
GameConfig instant({int target = 10, DrawWeights? weights}) => GameConfig(
  target: target,
  weights: weights ?? onlyBeginner,
  countdown: Duration.zero,
  reveal: Duration.zero,
);

/// The engine plus its starting state. ZeroRandom by default: seat 0 starts
/// and tricks come out in library order.
(TurnBasedGame, GameState) startGame({
  int players = 2,
  List<Trick>? library,
  GameConfig? config,
  Random? random,
}) {
  final game = TurnBasedGame(
    config: config ?? instant(),
    library: library ?? library3,
    random: random ?? ZeroRandom(),
  );
  return (game, game.start(makePlayers(players)));
}

/// Applies [input] [n] times.
GameState times(int n, GameState state, GameState Function(GameState) input) {
  var s = state;
  for (var i = 0; i < n; i++) {
    s = input(s);
  }
  return s;
}

Matcher landedBy(String trickId, String playerId, int points) => isA<LandedBy>()
    .having((o) => o.trick.id, 'trick', trickId)
    .having((o) => o.playerId, 'playerId', playerId)
    .having((o) => o.points, 'points', points);

Matcher missedOut(String trickId) =>
    isA<MissedOut>().having((o) => o.trick.id, 'trick', trickId);

List<String> ids(Iterable<Player> players) => [for (final p in players) p.id];

Matcher timedOut(String trickId) =>
    isA<TimedOut>().having((o) => o.trick.id, 'trick', trickId);

Duration ms(int n) => Duration(milliseconds: n);
Duration secs(int n) => Duration(seconds: n);

/// A config with real phase lengths: by default 3 s countdown, 1 s reveal,
/// 60 s per trick.
GameConfig timed({
  int target = 10,
  Duration countdown = const Duration(seconds: 3),
  Duration reveal = const Duration(seconds: 1),
}) => GameConfig(
  target: target,
  weights: onlyBeginner,
  countdown: countdown,
  reveal: reveal,
);

/// The fields that make two states "the same game", for comparing runs.
Map<String, Object?> summary(GameState s) => {
  'phase': s.phase,
  'left': s.phaseRemaining,
  'trick': s.currentTrick?.id,
  'turn': s.turnOrder.current,
  'misses': s.missCount,
  'landed': s.landedCount,
  'scores': s.scores,
  'outcome': s.lastOutcome?.toString(),
  'discarded': s.bags.discardedIds,
  'end': s.endReason,
  'remaining': s.turnOrder.seats,
  'sd': s.suddenDeath?.toString(),
};

// Sudden death (step 6).

/// 2 players, target 2, 1-point tricks t0…t5: p1 lands t0, p2 lands t1 →
/// 1–1 → sudden death, p1 to start on t2.
(TurnBasedGame, GameState) tiedGame({GameConfig? config}) {
  final (game, start) = startGame(
    library: equalLibrary(6),
    config: config ?? instant(target: 2),
  );
  return (game, play(game, start, 'LL'));
}

/// [players] players, target [players]: everyone lands one 1-point trick,
/// so everyone ties and the last seat's landing starts sudden death. The
/// library has [tricks] tricks.
(TurnBasedGame, GameState) allTied(int players, {int tricks = 6}) {
  final (game, start) = startGame(
    players: players,
    library: equalLibrary(tricks),
    config: instant(target: players),
  );
  return (game, play(game, start, 'L' * players));
}

Matcher roundEnded(String trickId, List<String> outIds) => isA<RoundEnded>()
    .having((RoundEnded o) => o.trick.id, 'trick', trickId)
    .having((RoundEnded o) => o.outIds, 'outIds', outIds);
