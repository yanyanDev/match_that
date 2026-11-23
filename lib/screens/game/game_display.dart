/// What the Game screen shows and when it rebuilds (spec §4a G3, G8; §3 S4;
/// §7 D4). Plain functions, no widgets, so they're unit-tested directly and
/// the widgets stay free of game rules (CLAUDE.md).
library;

import 'package:flutter/foundation.dart' show mapEquals;

import '../../engine/game_config.dart';
import '../../engine/game_state.dart';
import '../../engine/players.dart';

/// Time left rounded **up** to whole seconds (G3): 0.1 s shows as 1, and
/// only a truly finished timer shows 0. Never negative.
int secondsUp(Duration remaining) {
  final us = remaining.inMicroseconds;
  if (us <= 0) return 0;
  return (us + Duration.microsecondsPerSecond - 1) ~/
      Duration.microsecondsPerSecond;
}

/// How many of the timer bar's [barSteps] are still filled, rounded up like
/// [secondsUp], so the bar only reaches 0 when the time is up.
int barStep(Duration remaining, Duration total) {
  final left = remaining.inMicroseconds;
  final all = total.inMicroseconds;
  if (left <= 0 || all <= 0) return 0;
  // Integer maths: ceil(left / all * barSteps) without float rounding.
  final step = (left * barSteps + all - 1) ~/ all;
  return step > barSteps ? barSteps : step;
}

/// The timer bar's resolution. 100 steps of a 60 s trick = one every 0.6 s.
const barSteps = 100;

/// `buildWhen` for the timer (D4): true only when the shown second or the
/// bar changes, not on every 100 ms tick.
bool timerChanged(GameState a, GameState b, Duration trickTime) =>
    secondsUp(a.phaseRemaining) != secondsUp(b.phaseRemaining) ||
    barStep(a.phaseRemaining, trickTime) !=
        barStep(b.phaseRemaining, trickTime);

/// `buildWhen` for everything except the timer (D4).
///
/// A clock tick only changes the time left, so it's ignored, unless it
/// changes what this part of the screen shows: the countdown digit, or the
/// reveal switching from the outcome to NEW TRICK. Anything else (a call,
/// pause, undo, a new phase) always rebuilds.
bool screenChanged(GameState a, GameState b, GameConfig config) {
  // Ticks build the next state with copyWith, which keeps unchanged fields
  // as the very same object, so `identical` is a cheap, exact check.
  // Except `scores`: the GameState constructor wraps it in a new
  // Map.unmodifiable on every copy, so it's compared by content.
  final sameGame =
      a.phase == b.phase &&
      a.paused == b.paused &&
      a.missCount == b.missCount &&
      a.landedCount == b.landedCount &&
      a.endReason == b.endReason &&
      identical(a.currentTrick, b.currentTrick) &&
      identical(a.turnOrder, b.turnOrder) &&
      mapEquals(a.scores, b.scores) &&
      identical(a.lastOutcome, b.lastOutcome) &&
      identical(a.suddenDeath, b.suddenDeath) &&
      identical(a.beforeLastCall, b.beforeLastCall) &&
      identical(a.resumeTo, b.resumeTo);
  if (!sameGame) return true;

  return switch (b.phase) {
    GamePhase.countdown =>
      secondsUp(a.phaseRemaining) != secondsUp(b.phaseRemaining),
    GamePhase.reveal =>
      revealShowsOutcome(a, config.reveal) !=
          revealShowsOutcome(b, config.reveal),
    // Attempting: only the timer changes, and it has its own builder.
    GamePhase.attempting || GamePhase.gameOver => false,
  };
}

/// Whether the reveal is in its first half, showing how the last trick
/// ended; the second half shows NEW TRICK (§4).
bool revealShowsOutcome(GameState s, Duration reveal) =>
    s.phase == GamePhase.reveal && s.phaseRemaining * 2 > reveal;

/// The reveal's first line (G8): "+3 ALEX", "TIME'S UP", "MISSED OUT", or
/// in sudden death who is out (S4).
String outcomeText(
  TrickOutcome outcome,
  List<Player> players, {
  required bool suddenDeath,
}) {
  String name(String id) =>
      players.firstWhere((p) => p.id == id).name.toUpperCase();

  return switch (outcome) {
    LandedBy(:final playerId, :final points) => '+$points ${name(playerId)}',
    TimedOut() => "TIME'S UP",
    // In sudden death a miss-out means everyone missed: nobody is out (S4).
    MissedOut() => suddenDeath ? 'NOBODY LANDED' : 'MISSED OUT',
    RoundEnded(:final outIds) => switch (outIds.length) {
      0 => 'NOBODY OUT',
      1 => '${name(outIds.single)} IS OUT',
      _ => '${_joinNames(outIds.map(name).toList())} ARE OUT',
    },
  };
}

/// "A & B", "A, B & C".
String _joinNames(List<String> names) =>
    '${names.sublist(0, names.length - 1).join(', ')} & ${names.last}';
