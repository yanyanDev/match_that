import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../cubits/game_cubit.dart';
import '../../engine/game_config.dart';
import '../../engine/game_state.dart';
import '../../ui/app_colors.dart';
import '../../ui/app_text_styles.dart';
import '../../ui/widgets/player_name_tag.dart';
import '../../ui/widgets/primary_button.dart';
import '../../ui/widgets/secondary_button.dart';
import 'remaining_players.dart';
import 'score_row.dart';
import 'sudden_death_banner.dart';
import 'trick_card.dart';

/// A trick being attempted (Figma 04; D4), and its sudden-death variant
/// (§7 screen 8): banner instead of the progress label, the tied players
/// instead of the score row, no timer.
class PlayView extends StatelessWidget {
  const PlayView({super.key, required this.state, required this.config});

  final GameState state;
  final GameConfig config;

  @override
  Widget build(BuildContext context) {
    final game = context.read<GameCubit>();
    final suddenDeath = state.inSuddenDeath;
    final player = state.currentPlayer;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: suddenDeath
                      ? const SuddenDeathBanner()
                      : Text(
                          // Only landed tricks count toward the target (R8).
                          'LANDED ${state.landedCount}/${config.target}',
                          style: AppTextStyles.label,
                        ),
                ),
                IconButton(
                  onPressed: game.pause,
                  tooltip: 'Pause',
                  icon: const Icon(Icons.pause, color: AppColors.ink),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (suddenDeath)
              RemainingPlayers(state: state)
            else
              ScoreRow(
                players: state.players,
                scores: state.scores,
                activeSeat: player.seat,
              ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CURRENT TURN', style: AppTextStyles.label),
                      const SizedBox(height: 6),
                      PlayerNameTag(name: player.name, color: player.color),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('UP NEXT', style: AppTextStyles.label),
                    const SizedBox(height: 6),
                    Text(
                      state.upNext.name,
                      style: AppTextStyles.body.copyWith(color: AppColors.ink),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TrickCard(
                trick: state.currentTrick!,
                trickTime: config.trickTime,
                showTimer: !suddenDeath,
              ),
            ),
            const SizedBox(height: 16),
            // D4: tall buttons with a gap, tapped from across a table.
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'MISSED',
                    onPressed: game.missed,
                    height: 72,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: PrimaryButton(
                    label: 'MATCHED', // = landed in code
                    onPressed: game.matched,
                    height: 72,
                    showArrow: false,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
