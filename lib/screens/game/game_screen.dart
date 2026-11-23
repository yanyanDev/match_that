import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../cubits/game_cubit.dart';
import '../../engine/game_state.dart';
import '../../ui/app_text_styles.dart';
import 'countdown_view.dart';
import 'game_display.dart';
import 'play_view.dart';
import 'reveal_view.dart';

/// The Game screen (§7 screens 4–8): one view per state of the game.
///
/// Needs a [GameCubit] above it (a BlocProvider). Countdown, reveal, pause
/// and sudden death all happen inside this one screen (D6).
class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // read: get the Cubit once, without listening. Its config never changes.
    final config = context.read<GameCubit>().config;

    return Scaffold(
      body: BlocBuilder<GameCubit, GameState>(
        // buildWhen runs on every emitted state, before rebuilding. The Cubit
        // emits every 100 ms while time passes; returning false skips the
        // rebuild. Only real changes get through (D4); the timer has its own
        // BlocBuilder further down.
        buildWhen: (previous, current) =>
            screenChanged(previous, current, config),
        builder: (context, state) => switch (state.phase) {
          GamePhase.countdown => CountdownView(state: state),
          GamePhase.attempting => PlayView(state: state, config: config),
          GamePhase.reveal => RevealView(state: state, reveal: config.reveal),
          // Replaced by the game-over placeholder in the next commit and by
          // Results in 8d.
          GamePhase.gameOver => const SafeArea(
            child: Center(
              child: Text('GAME OVER', style: AppTextStyles.headline),
            ),
          ),
        },
      ),
    );
  }
}
