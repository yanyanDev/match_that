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
  /// While paused no time passes: the same state comes back (U1). Nor does
  /// it while attempting in sudden death, which has no timer (S3); its
  /// countdown and reveals still run.
  GameState tick(GameState state, Duration elapsed) {
    if (elapsed.isNegative) {
      throw ArgumentError.value(elapsed, 'elapsed', 'Must not be negative');
    }
    if (state.paused) return state;
    var s = state;
    var left = elapsed;
    while (left > Duration.zero && s.phase != GamePhase.gameOver) {
      if (s.inSuddenDeath && s.phase == GamePhase.attempting) return s;
      if (left < s.phaseRemaining) {
        return _spend(s, left);
      }
      left -= s.phaseRemaining;
      s = _endPhase(_spend(s, s.phaseRemaining));
    }
    return s; // unchanged (same object) for a zero tick or in gameOver
  }

  /// Spends [time] (at most what's left) on the current phase. Time in
  /// attempting also moves the trick clock forward (U5).
  GameState _spend(GameState state, Duration time) => state.copyWith(
    phaseRemaining: state.phaseRemaining - time,
    trickClock: state.phase == GamePhase.attempting
        ? state.trickClock + time
        : null,
  );

  /// What happens when the current phase's time runs out.
  GameState _endPhase(GameState state) => switch (state.phase) {
    GamePhase.countdown => _leaveCountdown(state),
    GamePhase.reveal => state.copyWith(
      phase: GamePhase.attempting,
      phaseRemaining: _trickTime(state),
    ),
    // G7: discard, the turn advances from the player whose turn it was.
    // A timeout is not a call and clears the undo (U4).
    GamePhase.attempting => _discard(
      state.copyWith(
        turnOrder: state.turnOrder.advance(),
        clearBeforeLastCall: true,
      ),
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
        phaseRemaining: _trickTime(state),
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
  /// decide the winners (G10). A tie starts sudden death instead (S1), with
  /// the undo cleared (U4); End game during sudden death is a shared win
  /// among the players still in (S7). Ignored when not paused.
  GameState endGame(GameState state) {
    if (!state.paused) return state;
    final ended = state.copyWith(paused: false, clearResumeTo: true);
    if (ended.suddenDeath == null && ended.winners.length >= 2) {
      return _startSuddenDeath(
        ended.copyWith(clearBeforeLastCall: true),
        atOrAfter: ended.turnOrder.current,
      );
    }
    return _gameOver(ended, GameEndReason.endedByPlayers);
  }

  /// Undo last call (U3–U6): the state from just before the last
  /// `landed()`/`missed()`, minus the trick time spent since. If that leaves
  /// no time, the restored trick times out at once (G7). The result is
  /// paused, unless that timeout ended the game (G9). Ignored when
  /// [GameState.canUndo] is false.
  GameState undo(GameState state) {
    if (!state.canUndo) return state;

    final before = state.beforeLastCall!;
    final spent = state.trickClock - before.trickClock;
    final restored = before.copyWith(
      phaseRemaining: before.phaseRemaining - spent,
      trickClock: state.trickClock, // the clock never goes back (R3)
    );
    if (restored.phaseRemaining > Duration.zero) {
      return restored.copyWith(paused: true);
    }
    final expired = _endPhase(restored);
    return expired.phase == GamePhase.gameOver
        ? expired
        : expired.copyWith(paused: true);
  }

  /// [state] with no undo of its own: the snapshot a call stores (U3).
  GameState _snapshot(GameState state) =>
      state.copyWith(clearBeforeLastCall: true);

  /// The current player landed the trick (R6, G5). Reaching the target with
  /// a tie starts sudden death (S1); in sudden death it is one call of the
  /// round (S3). Ignored outside [GamePhase.attempting] (G4) and while
  /// paused (U1).
  GameState landed(GameState state) {
    if (state.phase != GamePhase.attempting || state.paused) return state;
    if (state.suddenDeath != null) {
      return _suddenDeathCall(state, landed: true);
    }

    final player = state.currentPlayer;
    final trick = state.currentTrick!;
    final scored = state.copyWith(
      beforeLastCall: _snapshot(state),
      scores: {
        ...state.scores,
        player.id: state.scores[player.id]! + trick.points,
      },
      landedCount: state.landedCount + 1,
      lastOutcome: LandedBy(trick, playerId: player.id, points: trick.points),
    );
    if (scored.landedCount >= config.target) {
      // The undo is kept, so the call that started sudden death can be
      // undone (S8).
      return scored.winners.length >= 2
          ? _startSuddenDeath(scored, atOrAfter: scored.turnOrder.upNext)
          : _gameOver(scored, GameEndReason.targetReached);
    }
    return _nextTrick(scored.copyWith(turnOrder: scored.turnOrder.advance()));
  }

  /// The current player missed (R1, G6). In sudden death it is one call of
  /// the round, with no miss limit (S3). Ignored outside
  /// [GamePhase.attempting] (G4) and while paused (U1).
  GameState missed(GameState state) {
    if (state.phase != GamePhase.attempting || state.paused) return state;
    if (state.suddenDeath != null) {
      return _suddenDeathCall(state, landed: false);
    }

    final next = state.copyWith(
      beforeLastCall: _snapshot(state),
      missCount: state.missCount + 1,
      turnOrder: state.turnOrder.advance(),
    );
    if (next.missCount < next.missLimit) return next;
    return _discard(next, MissedOut(state.currentTrick!));
  }

  /// Starts sudden death among the players tied for the lead (S1): they
  /// take turns from the first of them at or after seat [atOrAfter] (S6),
  /// on a fresh trick after the countdown (S2). Scores stay as they are.
  GameState _startSuddenDeath(GameState state, {required int atOrAfter}) {
    final tied = [for (final player in state.winners) player.seat];
    final order = TurnOrder.from(tied, atOrAfter: atOrAfter);
    return _drawThen(
      state.copyWith(
        turnOrder: order,
        suddenDeath: SuddenDeath(roundStarter: order.current),
        clearResumeTo: true,
      ),
      GamePhase.countdown,
      config.countdown,
    );
  }

  /// One sudden death call (S3): recorded for this round, no points, no
  /// miss count. The next player gets the same trick straight away; the
  /// last call of the round ends it (S4).
  GameState _suddenDeathCall(GameState state, {required bool landed}) {
    final called = state.copyWith(
      beforeLastCall: _snapshot(state),
      suddenDeath: state.suddenDeath!.withCall(
        state.turnOrder.current,
        landed: landed,
      ),
    );
    if (called.suddenDeath!.callCount < called.turnOrder.seats.length) {
      return called.copyWith(turnOrder: called.turnOrder.advance());
    }
    return _endRound(called);
  }

  /// Everyone still in has called (S4). Landers stay and missers are out,
  /// unless nobody landed. One player left wins; otherwise the next round
  /// starts after the previous starter (S6) with a new trick. A trick
  /// nobody landed is discarded (S5).
  GameState _endRound(GameState state) {
    final round = state.suddenDeath!;
    final trick = state.currentTrick!;
    final seats = state.turnOrder.seats;
    final survivors = round.landed.isEmpty
        ? seats
        : [
            for (final seat in seats)
              if (round.landed.contains(seat)) seat,
          ];

    final order = TurnOrder.from(survivors, atOrAfter: round.roundStarter + 1);
    final next = state.copyWith(turnOrder: order);
    final nextRound = SuddenDeath(roundStarter: order.current);

    if (round.landed.isEmpty) {
      return _discard(next.copyWith(suddenDeath: nextRound), MissedOut(trick));
    }
    final outcome = RoundEnded(
      trick,
      outIds: [
        for (final player in state.remainingPlayers)
          if (!round.landed.contains(player.seat)) player.id,
      ],
    );
    if (survivors.length == 1) {
      // Keeps this round's calls, so Results can show how it was decided.
      return _gameOver(
        next.copyWith(lastOutcome: outcome),
        GameEndReason.suddenDeathWon,
      );
    }
    return _nextTrick(
      next.copyWith(lastOutcome: outcome, suddenDeath: nextRound),
    );
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
                phaseRemaining: _trickTime(drawn),
              );
    }
  }

  /// A full trick timer, or none (0) in sudden death (S3).
  Duration _trickTime(GameState state) =>
      state.suddenDeath == null ? config.trickTime : Duration.zero;

  /// Ends the game, never paused. Only a game that reached the target keeps
  /// its undo, for the Results screen (U3).
  GameState _gameOver(GameState state, GameEndReason reason) => state.copyWith(
    phase: GamePhase.gameOver,
    phaseRemaining: Duration.zero,
    endReason: reason,
    paused: false,
    clearBeforeLastCall: reason != GameEndReason.targetReached,
  );
}
