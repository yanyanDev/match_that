import 'package:flutter/widgets.dart';

import '../../engine/game_state.dart';
import '../../ui/app_text_styles.dart';
import '../../ui/widgets/player_name_tag.dart';
import 'game_display.dart';
import 'sudden_death_banner.dart';

/// 3-2-1 before play (Figma 03; §4). Used at game start, on Resume (U2) and
/// at the start of sudden death (S2).
class CountdownView extends StatelessWidget {
  const CountdownView({super.key, required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final player = state.currentPlayer;
    final note = state.resumeTo != null
        ? 'The clock starts again after 1.'
        : state.inSuddenDeath
        ? 'The trick appears after 1.\nNo timer in sudden death.'
        : 'The trick appears after 1.\nYour shared clock starts then.';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.inSuddenDeath) ...[
              const SuddenDeathBanner(),
              const SizedBox(height: 16),
            ],
            const Text('GET READY', style: AppTextStyles.label),
            const SizedBox(height: 48),
            const Text('CURRENT TURN', style: AppTextStyles.label),
            const SizedBox(height: 8),
            PlayerNameTag(name: player.name, color: player.color),
            Expanded(
              child: Center(
                child: Text(
                  '${secondsUp(state.phaseRemaining)}',
                  style: AppTextStyles.display.copyWith(fontSize: 160),
                ),
              ),
            ),
            Text(note, style: AppTextStyles.body),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
