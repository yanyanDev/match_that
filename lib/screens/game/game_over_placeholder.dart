// TEMPORARY: replaced by the Results screen in step 8d (D7).

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../cubits/game_cubit.dart';
import '../../engine/game_state.dart';
import '../../ui/app_text_styles.dart';
import '../../ui/widgets/primary_button.dart';
import '../../ui/widgets/secondary_button.dart';

/// A bare game-over view until Results exists: winners, Play again (A2),
/// Undo last call when a call ended the game (U3, S8), and Home.
class GameOverPlaceholder extends StatelessWidget {
  const GameOverPlaceholder({super.key, required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final game = context.read<GameCubit>();
    final winners = state.winners.map((p) => p.name).join(' & ');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('GAME OVER', style: AppTextStyles.headline),
            const SizedBox(height: 16),
            Text(
              '${state.winners.length == 1 ? 'WINNER' : 'WINNERS'}: $winners',
              style: AppTextStyles.label,
            ),
            const SizedBox(height: 8),
            const Text(
              'Placeholder until the Results screen (step 8d).',
              style: AppTextStyles.body,
            ),
            const Spacer(),
            PrimaryButton(label: 'PLAY AGAIN', onPressed: game.rematch),
            if (state.canUndo) ...[
              const SizedBox(height: 12),
              SecondaryButton(label: 'UNDO LAST CALL', onPressed: game.undo),
            ],
            const SizedBox(height: 12),
            SecondaryButton(
              label: 'HOME',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
