import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../cubits/game_cubit.dart';
import '../../engine/game_state.dart';
import '../../ui/app_colors.dart';
import 'countdown_view.dart';
import 'game_display.dart';
import 'game_over_placeholder.dart';
import 'pause_menu.dart';
import 'play_view.dart';
import 'reveal_view.dart';

/// The Game screen (§7 screens 4–8): one view per state of the game, with
/// the pause menu on top while paused.
///
/// Needs a [GameCubit] above it (a BlocProvider). Countdown, reveal, pause
/// and sudden death all happen inside this one screen (D6).
class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // read: get the Cubit once, without listening. Its config never changes.
    final game = context.read<GameCubit>();
    final config = game.config;

    return BlocBuilder<GameCubit, GameState>(
      // buildWhen runs on every emitted state, before rebuilding. The Cubit
      // emits every 100 ms while time passes; returning false skips the
      // rebuild. Only real changes get through (D4); the timer has its own
      // BlocBuilder further down.
      buildWhen: (previous, current) =>
          screenChanged(previous, current, config),
      builder: (context, state) {
        final view = switch (state.phase) {
          GamePhase.countdown => CountdownView(state: state),
          GamePhase.attempting => PlayView(state: state, config: config),
          GamePhase.reveal => RevealView(state: state, reveal: config.reveal),
          GamePhase.gameOver => GameOverPlaceholder(state: state),
        };

        // PopScope decides whether system Back may leave this page (D11).
        // During a game it may not: Back pauses instead (and does nothing
        // if already paused, since the engine ignores a second pause).
        // After game over, Back leaves as usual.
        return PopScope(
          canPop: state.phase == GamePhase.gameOver,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) game.pause();
          },
          child: Scaffold(
            // A Stack draws its children on top of each other. While
            // paused: the game, then a barrier that swallows every tap,
            // then the menu.
            body: Stack(
              fit: StackFit.expand,
              children: [
                view,
                if (state.paused) ...[
                  ModalBarrier(
                    color: AppColors.ink.withValues(alpha: 0.5),
                    dismissible: false, // tapping outside doesn't resume
                  ),
                  PauseMenu(state: state),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
