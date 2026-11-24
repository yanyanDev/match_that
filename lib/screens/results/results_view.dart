import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../cubits/game_cubit.dart';
import '../../engine/game_config.dart';
import '../../engine/game_state.dart';
import '../../ui/app_colors.dart';
import '../../ui/app_text_styles.dart';
import '../../ui/widgets/primary_button.dart';
import '../../ui/widgets/secondary_button.dart';
import 'results_display.dart';

/// Results (spec §7 D7, D15; Figma 05): the Game screen's view once the game
/// is over.
///
/// It is not a page of its own: it lives inside GameScreen, under the same
/// BlocProvider, so `context.read<GameCubit>()` is the Cubit that ran the
/// game. Undo last call (U3) and Play again (A2) need exactly that Cubit:
/// its undo snapshot, players, config and library.
class ResultsView extends StatelessWidget {
  const ResultsView({super.key, required this.state, required this.config});

  final GameState state;
  final GameConfig config;

  @override
  Widget build(BuildContext context) {
    final game = context.read<GameCubit>();
    final rows = standings(state);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('GAME COMPLETE', style: AppTextStyles.label),
            const SizedBox(height: 8),
            Text(resultsHeadline(state), style: AppTextStyles.headline),
            const SizedBox(height: 8),
            Text(lengthLabel(config.target), style: AppTextStyles.label),
            const SizedBox(height: 24),
            Text(
              'FINAL STANDINGS',
              style: AppTextStyles.label.copyWith(color: AppColors.grey),
            ),
            const SizedBox(height: 8),
            // Expanded: the list takes the space left between the header
            // and the buttons, and scrolls if 8 players don't fit.
            Expanded(
              child: ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (_, i) => _StandingRow(rows[i]),
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(label: 'PLAY AGAIN', onPressed: game.rematch),
            const SizedBox(height: 12),
            SecondaryButton(
              // Back to Setup, the page below, with the setup kept (D14).
              // System Back does the same: GameScreen's PopScope lets the
              // pop through once the game is over (D15).
              label: 'NEW GAME',
              onPressed: () => Navigator.of(context).pop(),
            ),
            // Only when a call ended the game (U3, S8); End game can't be
            // undone (U4).
            if (state.canUndo) ...[
              const SizedBox(height: 12),
              SecondaryButton(label: 'UNDO LAST CALL', onPressed: game.undo),
            ],
          ],
        ),
      ),
    );
  }
}

/// One standings row: rank, name, optional SUDDEN DEATH tag, points.
/// Winners fill with their own player color (D2, D15) and keep the 1 px
/// ink border (D1); everyone else is cream with a thin rule underneath.
class _StandingRow extends StatelessWidget {
  const _StandingRow(this.row);

  final Standing row;

  @override
  Widget build(BuildContext context) {
    final decoration = row.isWinner
        ? BoxDecoration(
            color: row.player.color.color,
            border: Border.all(color: AppColors.ink),
          )
        : BoxDecoration(
            color: AppColors.cream,
            border: Border(
              bottom: BorderSide(color: AppColors.ink.withValues(alpha: 0.2)),
            ),
          );

    return DecoratedBox(
      decoration: decoration,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Text(
              row.rank.toString().padLeft(2, '0'),
              style: AppTextStyles.label,
            ),
            const SizedBox(width: 16),
            // Expanded + ellipsis: a long name never pushes the points off.
            Expanded(
              child: Text(
                row.player.name,
                style: AppTextStyles.button,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (row.wonSuddenDeath) ...[
              const SizedBox(width: 8),
              Text(
                'SUDDEN DEATH',
                style: AppTextStyles.label.copyWith(
                  fontSize: 10,
                  letterSpacing: 1,
                ),
              ),
            ],
            const SizedBox(width: 12),
            Text('${row.score} PTS', style: AppTextStyles.label),
          ],
        ),
      ),
    );
  }
}
