/// Game state for Default (turn-based) mode (spec §4a G2, G8, G10, G11).
/// Pure Dart, immutable plain data: every input returns a new [GameState].
library;

import 'dart:math';

import 'players.dart';
import 'trick.dart';
import 'trick_bags.dart';
import 'turn_order.dart';

/// Where the game is (G2). The trick timer only runs in [attempting].
enum GamePhase { countdown, attempting, reveal, gameOver }

/// Why the game ended. [endedByPlayers] is End game from the pause menu (U7).
/// [suddenDeathWon] is one player left at the end of a sudden death round
/// (S4).
enum GameEndReason {
  targetReached,
  noDrawableTricks,
  endedByPlayers,
  suddenDeathWon;

  /// Whether a `landed()`/`missed()` call ended the game, so the Results
  /// screen can undo it (U3, S8).
  bool get endedByCall => this == targetReached || this == suddenDeathWon;
}

/// The current sudden death round (§3). Who is still in is not stored here:
/// it is [GameState.turnOrder]'s seats (P5). Immutable.
class SuddenDeath {
  SuddenDeath({
    required this.roundStarter,
    Set<int> landed = const {},
    Set<int> missed = const {},
  }) : landed = Set.unmodifiable(landed),
       missed = Set.unmodifiable(missed);

  /// The seat that started this round (S6).
  final int roundStarter;

  /// Seats that called Matched this round. Read-only.
  final Set<int> landed;

  /// Seats that called Missed this round. Read-only. Never overlaps
  /// [landed].
  final Set<int> missed;

  /// How many players have called this round.
  int get callCount => landed.length + missed.length;

  /// Whether [seat] has called this round.
  bool hasCalled(int seat) => landed.contains(seat) || missed.contains(seat);

  /// A copy with [seat]'s call added.
  SuddenDeath withCall(int seat, {required bool landed}) => SuddenDeath(
    roundStarter: roundStarter,
    landed: landed ? {...this.landed, seat} : this.landed,
    missed: landed ? missed : {...missed, seat},
  );

  @override
  String toString() =>
      'SuddenDeath(starter: $roundStarter, landed: $landed, missed: $missed)';
}

/// Where a resume countdown returns to: the phase that was paused and the
/// time it had left (U2).
class ResumeTarget {
  const ResumeTarget(this.phase, this.remaining);

  final GamePhase phase;
  final Duration remaining;

  @override
  String toString() => 'ResumeTarget(${phase.name}, $remaining)';
}

/// How the previous trick ended, so the UI can show "+3 ALEX",
/// "TIME'S UP" or "MISSED OUT" (G8).
sealed class TrickOutcome {
  const TrickOutcome(this.trick);

  final Trick trick;
}

/// The player with [playerId] landed [trick] and got [points].
final class LandedBy extends TrickOutcome {
  const LandedBy(super.trick, {required this.playerId, required this.points});

  final String playerId;
  final int points;

  @override
  String toString() => 'LandedBy(${trick.id}, $playerId, +$points)';
}

/// The trick's timer ran out (G7).
final class TimedOut extends TrickOutcome {
  const TimedOut(super.trick);

  @override
  String toString() => 'TimedOut(${trick.id})';
}

/// The trick reached the miss limit (R5, G6).
final class MissedOut extends TrickOutcome {
  const MissedOut(super.trick);

  @override
  String toString() => 'MissedOut(${trick.id})';
}

/// A sudden death round ended with someone landing (S4). [outIds] are the
/// players who missed and are now out; it is empty if everyone landed. A
/// round where nobody landed is a [MissedOut] instead (the trick is
/// discarded, S5).
final class RoundEnded extends TrickOutcome {
  RoundEnded(super.trick, {required List<String> outIds})
    : outIds = List.unmodifiable(outIds);

  final List<String> outIds;

  @override
  String toString() => 'RoundEnded(${trick.id}, out: $outIds)';
}

/// One moment of a Default-mode game.
class GameState {
  GameState({
    required List<Player> players,
    required Map<String, int> scores,
    required this.turnOrder,
    required this.bags,
    required this.phase,
    required this.currentTrick,
    required this.phaseRemaining,
    required this.missCount,
    required this.landedCount,
    required this.lastOutcome,
    required this.endReason,
    this.paused = false,
    this.resumeTo,
    this.trickClock = Duration.zero,
    this.beforeLastCall,
    this.suddenDeath,
  }) : players = List.unmodifiable(players),
       scores = Map.unmodifiable(scores);

  /// Every player, in seat order. Read-only.
  final List<Player> players;

  /// Points by [Player.id]. Read-only.
  final Map<String, int> scores;

  final TurnOrder turnOrder;
  final TrickBags bags;
  final GamePhase phase;

  /// The trick being attempted (or about to be revealed). `null` only when
  /// the game ended because nothing was drawable (G9).
  final Trick? currentTrick;

  /// Time left in the current phase: countdown, reveal, or the trick timer.
  /// Always 0 while attempting in sudden death, which has no timer (S3).
  final Duration phaseRemaining;

  /// Misses on [currentTrick] so far (R5).
  final int missCount;

  /// Tricks landed this game; only these count toward the target (R8).
  final int landedCount;

  /// How the previous trick ended; kept until the next one ends (G8).
  final TrickOutcome? lastOutcome;

  /// Set exactly when [phase] is [GamePhase.gameOver].
  final GameEndReason? endReason;

  /// Paused from the pause menu (U1). Separate from [phase] (G2): [phase]
  /// and [phaseRemaining] keep what was paused, and no time passes.
  final bool paused;

  /// Set only during a resume countdown ([phase] is [GamePhase.countdown]):
  /// where it returns to when it ends (U2). `null` for the game-start
  /// countdown, which goes to a full trick.
  final ResumeTarget? resumeTo;

  /// Total time spent in [GamePhase.attempting] this game. Only ever goes
  /// forward, also across an undo (R3). Undo uses the difference with the
  /// snapshot's clock as "trick time spent since the call" (U5).
  final Duration trickClock;

  /// The state just before the last `landed()`/`missed()`: the one-step
  /// undo snapshot (U3, U5). Its own [beforeLastCall] is always `null`.
  /// Cleared by a timeout, End game, undo, or a game over that isn't the
  /// target (U4).
  final GameState? beforeLastCall;

  /// Set from the moment sudden death starts (S1), and kept at gameOver if
  /// sudden death was running then, so [winners] knows to use who is left.
  /// `null` in normal play.
  final SuddenDeath? suddenDeath;

  /// Whether a sudden death is being played right now.
  bool get inSuddenDeath => suddenDeath != null && phase != GamePhase.gameOver;

  /// The players still taking turns, in seat order: everyone in normal
  /// play, only those still in during sudden death.
  List<Player> get remainingPlayers => [
    for (final player in players)
      if (turnOrder.seats.contains(player.seat)) player,
  ];

  /// Whether "Undo last call" is offered: from the pause menu, or on the
  /// Results screen after a call ended the game: reaching the target, or
  /// deciding sudden death (U3, S8).
  bool get canUndo =>
      beforeLastCall != null &&
      (paused ||
          (phase == GamePhase.gameOver && (endReason?.endedByCall ?? false)));

  /// The player whose turn it is.
  Player get currentPlayer => _playerAt(turnOrder.current);

  /// The player after [currentPlayer].
  Player get upNext => _playerAt(turnOrder.upNext);

  /// Misses that discard the trick: two full rounds (R5).
  int get missLimit => 2 * turnOrder.seats.length;

  /// Everyone tied for the highest score, in seat order (G10). Once sudden
  /// death has started, the players still in instead: scores no longer
  /// change, so who is left decides it (S4, S7, S9).
  List<Player> get winners {
    if (suddenDeath != null) return remainingPlayers;
    final best = scores.values.fold(0, max);
    return [
      for (final player in players)
        if (scores[player.id] == best) player,
    ];
  }

  /// A copy with the given fields replaced.
  ///
  /// `null` means "keep the current value", so a nullable field can't be
  /// cleared this way; [clearCurrentTrick], [clearResumeTo] and
  /// [clearBeforeLastCall] do that for the fields that go back to `null`.
  GameState copyWith({
    Map<String, int>? scores,
    TurnOrder? turnOrder,
    TrickBags? bags,
    GamePhase? phase,
    Trick? currentTrick,
    bool clearCurrentTrick = false,
    Duration? phaseRemaining,
    int? missCount,
    int? landedCount,
    TrickOutcome? lastOutcome,
    GameEndReason? endReason,
    bool? paused,
    ResumeTarget? resumeTo,
    bool clearResumeTo = false,
    Duration? trickClock,
    GameState? beforeLastCall,
    bool clearBeforeLastCall = false,
    SuddenDeath? suddenDeath,
  }) => GameState(
    players: players,
    scores: scores ?? this.scores,
    turnOrder: turnOrder ?? this.turnOrder,
    bags: bags ?? this.bags,
    phase: phase ?? this.phase,
    currentTrick: clearCurrentTrick ? null : currentTrick ?? this.currentTrick,
    phaseRemaining: phaseRemaining ?? this.phaseRemaining,
    missCount: missCount ?? this.missCount,
    landedCount: landedCount ?? this.landedCount,
    lastOutcome: lastOutcome ?? this.lastOutcome,
    endReason: endReason ?? this.endReason,
    paused: paused ?? this.paused,
    resumeTo: clearResumeTo ? null : resumeTo ?? this.resumeTo,
    trickClock: trickClock ?? this.trickClock,
    beforeLastCall: clearBeforeLastCall
        ? null
        : beforeLastCall ?? this.beforeLastCall,
    suddenDeath: suddenDeath ?? this.suddenDeath,
  );

  Player _playerAt(int seat) => players.firstWhere((p) => p.seat == seat);

  @override
  String toString() =>
      'GameState(${phase.name}${paused ? ' (paused)' : ''}, trick: ${currentTrick?.id}, '
      'turn: ${turnOrder.current}, misses: $missCount, '
      'landed: $landedCount, scores: $scores, left: $phaseRemaining'
      '${suddenDeath == null ? '' : ', $suddenDeath in ${turnOrder.seats}'})';
}
