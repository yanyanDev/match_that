import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../cubits/game_cubit.dart';
import '../../engine/game_state.dart';
import '../../ui/app_colors.dart';
import 'countdown_view.dart';
import 'game_display.dart';
import '../results/results_view.dart';
import 'pause_menu.dart';
import 'play_view.dart';
import 'reveal_view.dart';
import 'screen_wakelock.dart';

/// The Game screen (§7 screens 4–8): one view per state of the game, with
/// the pause menu on top while paused.
///
/// Needs a [GameCubit] and a [ScreenWakelock] above it (providers).
/// Countdown, reveal, pause and sudden death all happen inside this one
/// screen (D6).
///
/// A StatefulWidget so it can do something when the page opens and closes:
/// keep the screen awake (L3) and watch for the app being hidden (L1)
/// exactly while it's open.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // Kept from initState: dispose must not look things up through context,
  // because by then this widget is leaving the tree.
  late final ScreenWakelock _wakelock;
  late final AppLifecycleListener _lifecycle;

  /// Runs once, when the Game page enters the widget tree (it opens).
  @override
  void initState() {
    super.initState();
    _wakelock = context.read<ScreenWakelock>()..enable();
    // The app's lifecycle goes resumed ⇄ inactive ⇄ hidden ⇄ paused.
    // onHide fires on inactive → hidden only: the game is out of sight
    // (home, app switch, lock, tab hidden). A brief overlay (notification
    // shade, Control Center) stops at inactive and doesn't pause (L1).
    // Coming back fires other callbacks, so nothing resumes by itself (L2).
    // pause() is ignored when already paused or in gameOver (U1).
    _lifecycle = AppLifecycleListener(
      onHide: () => context.read<GameCubit>().pause(),
    );
  }

  /// Runs once, when the Game page leaves the tree for good (it's popped).
  @override
  void dispose() {
    _lifecycle.dispose(); // stop listening: no game is open any more
    _wakelock.disable();
    super.dispose();
  }

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
          GamePhase.gameOver => ResultsView(state: state, config: config),
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
