/// The Default (turn-based) mode rules (spec R1, R2, R5–R9, §4, §4a, §4b).
/// Pure Dart.
library;

import 'dart:math';

import 'game_config.dart';
import 'game_state.dart';
import 'players.dart';
import 'trick.dart';
import 'trick_bags.dart';
import 'turn_order.dart';

/// Applies the rules to a [GameState]. Holds no game state itself, only the
/// config, the trick library and the injected [Random] (G11), so a state
/// stays plain data that undo can snapshot.
class TurnBasedGame {
  TurnBasedGame({
    required this.config,
    required List<Trick> library,
    required this._random,
  }) : _library = List.unmodifiable(library);

  final GameConfig config;
  final List<Trick> _library;
  final Random _random;

  /// A new game: random first player (P4), first trick drawn, countdown
  /// running. Also used for a rematch.
  ///
  /// Uses [Random] once for the first player, then twice per draw.
  /// Throws [ArgumentError] if [players] is outside Default mode's limits.
  GameState start(List<Player> players) {
    if (!GameMode.turnBased.allows(players.length)) {
      throw ArgumentError.value(
        players.length,
        'players.length',
        'Default mode needs ${GameMode.turnBased.minPlayers}–'
            '${GameMode.turnBased.maxPlayers} players',
      );
    }
    final fresh = GameState(
      players: players,
      scores: {for (final player in players) player.id: 0},
      turnOrder: TurnOrder.randomStart([
        for (final player in players) player.seat,
      ], _random),
      bags: TrickBags(_library),
      phase: GamePhase.countdown,
      currentTrick: null,
      phaseRemaining: Duration.zero,
      missCount: 0,
      landedCount: 0,
      lastOutcome: null,
      endReason: null,
    );
    return _drawThen(fresh, GamePhase.countdown, config.countdown);
  }

  /// Spends [elapsed] on the current phase, carrying any leftover into the
  /// next one (G3). Throws [ArgumentError] if [elapsed] is negative.
  ///
  /// Ends because every pass either returns or uses up the whole phase, and
  /// outside gameOver `phaseRemaining` is always above 0 (zero-length phases
  /// are skipped on entry; `trickTime` > 0). Each expiry also discards a
  /// trick for good, so a huge tick ends in gameOver once tricks run out.
  ///
  /// While paused no time passes: the same state comes back (U1).
  GameState tick(GameState state, Duration elapsed) {
    if (elapsed.isNegative) {
      throw ArgumentError.value(elapsed, 'elapsed', 'Must not be negative');
    }
    if (state.paused) return state;
    var s = state;
    var left = elapsed;
    while (left > Duration.zero && s.phase != GamePhase.gameOver) {
      if (left < s.phaseRemaining) {
        return s.copyWith(phaseRemaining: s.phaseRemaining - left);
      }
      left -= s.phaseRemaining;
      s = _endPhase(s);
    }
    return s; // unchanged (same object) for a zero tick or in gameOver
  }

  /// What happens when the current phase's time runs out.
  GameState _endPhase(GameState state) => switch (state.phase) {
    GamePhase.countdown => _leaveCountdown(state),
    GamePhase.reveal => state.copyWith(
      phase: GamePhase.attempting,
      phaseRemaining: config.trickTime,
    ),
    // G7: discard, the turn advances from the player whose turn it was.
    GamePhase.attempting => _discard(
      state.copyWith(turnOrder: state.turnOrder.advance()),
      TimedOut(state.currentTrick!),
    ),
    GamePhase.gameOver => state,
  };

  /// A resume countdown returns to the phase it saved (U2); the game-start
  /// countdown goes to a full trick.
  GameState _leaveCountdown(GameState state) {
    final target = state.resumeTo;
    if (target == null) {
      return state.copyWith(
        phase: GamePhase.attempting,
        phaseRemaining: config.trickTime,
      );
    }
    return state.copyWith(
      phase: target.phase,
      phaseRemaining: target.remaining,
      clearResumeTo: true,
    );
  }

  /// Stops the clock and opens the pause menu (R2, U1). Allowed in
  /// countdown, attempting and reveal; ignored in gameOver or when already
  /// paused.
  GameState pause(GameState state) {
    if (state.paused || state.phase == GamePhase.gameOver) return state;
    return state.copyWith(paused: true);
  }

  /// Runs a full countdown, then goes back to the paused phase with the time
  /// it had left (U2). Paused in a countdown, the countdown restarts and
  /// still goes where it was going (a full trick, or the phase a resume
  /// countdown saved). With a 0 countdown, goes straight back. Ignored when
  /// not paused.
  GameState resume(GameState state) {
    if (!state.paused) return state;

    final resuming = state.phase == GamePhase.countdown
        ? state.copyWith(paused: false)
        : state.copyWith(
            paused: false,
            phase: GamePhase.countdown,
            resumeTo: ResumeTarget(state.phase, state.phaseRemaining),
          );
    return config.countdown > Duration.zero
        ? resuming.copyWith(phaseRemaining: config.countdown)
        : _leaveCountdown(resuming);
  }

  /// End game from the pause menu (R9, U7): gameOver now, current scores
  /// decide the winners (G10). Ignored when not paused.
  GameState endGame(GameState state) {
    if (!state.paused) return state;
    return _gameOver(
      state.copyWith(paused: false, clearResumeTo: true),
      GameEndReason.endedByPlayers,
    );
  }

  /// The current player landed the trick (R6, G5). Ignored outside
  /// [GamePhase.attempting] (G4) and while paused (U1).
  GameState landed(GameState state) {
    if (state.phase != GamePhase.attempting || state.paused) return state;

    final player = state.currentPlayer;
    final trick = state.currentTrick!;
    final scored = state.copyWith(
      scores: {
        ...state.scores,
        player.id: state.scores[player.id]! + trick.points,
      },
      landedCount: state.landedCount + 1,
      lastOutcome: LandedBy(trick, playerId: player.id, points: trick.points),
    );
    if (scored.landedCount >= config.target) {
      return _gameOver(scored, GameEndReason.targetReached);
    }
    return _nextTrick(scored.copyWith(turnOrder: scored.turnOrder.advance()));
  }

  /// The current player missed (R1, G6). Ignored outside
  /// [GamePhase.attempting] (G4) and while paused (U1).
  GameState missed(GameState state) {
    if (state.phase != GamePhase.attempting || state.paused) return state;

    final next = state.copyWith(
      missCount: state.missCount + 1,
      turnOrder: state.turnOrder.advance(),
    );
    if (next.missCount < next.missLimit) return next;
    return _discard(next, MissedOut(state.currentTrick!));
  }

  /// Removes the outcome's trick for the rest of the game (T10), then
  /// reveals a new one. The turn has already advanced.
  GameState _discard(GameState state, TrickOutcome outcome) => _nextTrick(
    state.copyWith(
      bags: state.bags.discard(outcome.trick),
      lastOutcome: outcome,
    ),
  );

  /// Draws a trick and shows the reveal before it (§4, G5–G7).
  GameState _nextTrick(GameState state) =>
      _drawThen(state, GamePhase.reveal, config.reveal);

  /// Draws a trick, then enters [phase] for [duration]. A zero [duration]
  /// skips straight to [GamePhase.attempting]. No drawable trick ends the
  /// game (G9).
  GameState _drawThen(GameState state, GamePhase phase, Duration duration) {
    switch (state.bags.draw(config.weights, _random)) {
      case NoDrawableTricks():
        return _gameOver(
          state.copyWith(clearCurrentTrick: true),
          GameEndReason.noDrawableTricks,
        );
      case Drawn(:final trick, :final bags):
        final drawn = state.copyWith(
          bags: bags,
          currentTrick: trick,
          missCount: 0,
        );
        return duration > Duration.zero
            ? drawn.copyWith(phase: phase, phaseRemaining: duration)
            : drawn.copyWith(
                phase: GamePhase.attempting,
                phaseRemaining: config.trickTime,
              );
    }
  }

  GameState _gameOver(GameState state, GameEndReason reason) => state.copyWith(
    phase: GamePhase.gameOver,
    phaseRemaining: Duration.zero,
    endReason: reason,
  );
}
