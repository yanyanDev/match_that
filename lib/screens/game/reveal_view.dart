import 'package:flutter/widgets.dart';

import '../../engine/game_state.dart';
import '../../ui/app_colors.dart';
import '../../ui/app_text_styles.dart';
import 'game_display.dart';

/// The ~1 s transition before every new trick (§4), filled with the next
/// player's color (D2). First half: how the last trick ended (G8). Second
/// half: NEW TRICK and whose turn it is.
class RevealView extends StatelessWidget {
  const RevealView({super.key, required this.state, required this.reveal});

  final GameState state;

  /// The configured reveal length, to know which half we're in.
  final Duration reveal;

  @override
  Widget build(BuildContext context) {
    final next = state.currentPlayer;
    final outcome = state.lastOutcome;
    final showOutcome = outcome != null && revealShowsOutcome(state, reveal);

    // ColoredBox outside SafeArea, so the color reaches behind the status
    // bar too: the whole screen flashes the player's color.
    return ColoredBox(
      color: next.color.color,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: showOutcome
                  ? [
                      Text(
                        outcomeText(
                          outcome,
                          state.players,
                          suddenDeath: state.suddenDeath != null,
                        ),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.headline,
                      ),
                    ]
                  : [
                      const Text(
                        'NEW TRICK',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.headline,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "${next.name.toUpperCase()}'S TURN",
                        textAlign: TextAlign.center,
                        style: AppTextStyles.label.copyWith(fontSize: 14),
                      ),
                    ],
            ),
          ),
        ),
      ),
    );
  }
}
