import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../cubits/game_cubit.dart';
import '../../engine/game_state.dart';
import '../../ui/app_colors.dart';
import '../../ui/app_text_styles.dart';
import '../../ui/widgets/primary_button.dart';
import '../../ui/widgets/secondary_button.dart';

/// The pause menu panel (R2): Resume, Undo last call, End game (§7 screen 7).
///
/// Drawn by the Game screen on top of the game while `state.paused` is true,
/// rather than opened with showDialog: it can never be out of step with the
/// game state (e.g. after an undo, which keeps the game paused, U6).
class PauseMenu extends StatelessWidget {
  const PauseMenu({super.key, required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final game = context.read<GameCubit>();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.cream,
            border: Border.all(color: AppColors.ink),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('PAUSED', style: AppTextStyles.headline),
              const SizedBox(height: 24),
              // Resume runs the 3-2-1 countdown first (U2).
              PrimaryButton(label: 'RESUME', onPressed: game.resume),
              const SizedBox(height: 12),
              SecondaryButton(
                label: 'UNDO LAST CALL',
                // null = disabled: nothing to undo (U3, U4).
                onPressed: state.canUndo ? game.undo : null,
              ),
              const SizedBox(height: 12),
              SecondaryButton(label: 'END GAME', onPressed: game.endGame),
            ],
          ),
        ),
      ),
    );
  }
}
