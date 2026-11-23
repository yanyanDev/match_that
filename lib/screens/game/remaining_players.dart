import 'package:flutter/widgets.dart';

import '../../engine/game_state.dart';
import '../../ui/app_colors.dart';
import '../../ui/app_text_styles.dart';

/// Sudden death's replacement for the score row (§7 screen 8): only the
/// tied players still in, each with this round's call (S3, S4). The player
/// whose turn it is gets their color (D2).
class RemainingPlayers extends StatelessWidget {
  const RemainingPlayers({super.key, required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final round = state.suddenDeath!;
    final current = state.currentPlayer.seat;

    // Wrap lays children out in a row and continues on the next line when
    // they don't fit, so 8 tied players never overflow.
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final player in state.remainingPlayers)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: player.seat == current
                  ? player.color.color
                  : AppColors.cream,
              border: Border.all(color: AppColors.ink),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  player.name,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 13,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  round.landed.contains(player.seat)
                      ? 'LANDED'
                      : round.missed.contains(player.seat)
                      ? 'MISSED'
                      : '—',
                  style: AppTextStyles.label.copyWith(
                    fontSize: 10,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
