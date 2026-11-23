/// One game, wrapping the engine and owning its clock (spec §4c A1, A2).
library;

import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../engine/game_config.dart';
import '../engine/game_state.dart';
import '../engine/players.dart';
import '../engine/trick.dart';
import '../engine/turn_based_game.dart';
import 'game_clock.dart';

/// Runs one game. Its state is the engine's [GameState].
///
/// Every method hands the current state to the engine and emits what comes
/// back. When the engine ignores an input it returns the very same object,
/// and then nothing is emitted, so widgets don't rebuild for nothing.
///
/// The clock runs exactly while [GameState.timePasses]: not while paused,
/// in gameOver, or during a sudden death attempt (A1).
class GameCubit extends Cubit<GameState> {
  /// Starts a new game right away (countdown running). [random] defaults to
  /// `Random()` and [clock] to a [PeriodicClock]; tests inject their own.
  factory GameCubit({
    required GameConfig config,
    required List<Player> players,
    required List<Trick> library,
    Random? random,
    GameClock? clock,
  }) {
    final game = TurnBasedGame(
      config: config,
      library: library,
      random: random ?? Random(),
    );
    return GameCubit._(
      game,
      List.unmodifiable(players),
      clock ?? PeriodicClock(),
    );
  }

  GameCubit._(this._game, this._players, this._clock)
    : super(_game.start(_players)) {
    _syncClock();
  }

  final TurnBasedGame _game;
  final List<Player> _players;
  final GameClock _clock;

  /// The current player landed the trick ("Matched" in the UI).
  void matched() => _apply(_game.landed(state));

  void missed() => _apply(_game.missed(state));
  void pause() => _apply(_game.pause(state));
  void resume() => _apply(_game.resume(state));
  void undo() => _apply(_game.undo(state));
  void endGame() => _apply(_game.endGame(state));

  /// Play again (P4): same settings and players, a new game with fresh bags
  /// and a random first player. Only from gameOver (A2).
  void rematch() {
    if (state.phase != GamePhase.gameOver) return;
    _apply(_game.start(_players));
  }

  @override
  Future<void> close() {
    _clock.stop();
    return super.close();
  }

  void _onTick(Duration elapsed) {
    if (isClosed) return;
    _apply(_game.tick(state, elapsed));
  }

  /// Emits [next] unless the engine returned the current state unchanged.
  ///
  /// Checked here rather than left to `emit`: bloc only skips an equal state
  /// after the first emit, so a no-op as the very first action would still
  /// be emitted.
  void _apply(GameState next) {
    if (identical(next, state)) return;
    emit(next);
    _syncClock();
  }

  /// Runs the clock exactly while time passes (A1). `start` and `stop` do
  /// nothing when the clock is already in that state.
  void _syncClock() {
    if (state.timePasses) {
      _clock.start(_onTick);
    } else {
      _clock.stop();
    }
  }
}
