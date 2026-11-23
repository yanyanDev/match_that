import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../cubits/game_cubit.dart';
import '../../engine/game_state.dart';
import '../../engine/trick.dart';
import '../../ui/app_colors.dart';
import '../../ui/app_text_styles.dart';
import 'game_display.dart';

/// The trick being attempted (Figma 04): difficulty, points, the name only
/// (T5), and the timer, except in sudden death, which has none (S3).
class TrickCard extends StatelessWidget {
  const TrickCard({
    super.key,
    required this.trick,
    required this.trickTime,
    required this.showTimer,
  });

  final Trick trick;
  final Duration trickTime;
  final bool showTimer;

  @override
  Widget build(BuildContext context) {
    final points = trick.points == 1 ? '1 POINT' : '${trick.points} POINTS';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: AppColors.ink)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                trick.difficulty.name.toUpperCase(),
                style: AppTextStyles.label,
              ),
              const Spacer(),
              Text(points, style: AppTextStyles.label),
            ],
          ),
          const SizedBox(height: 16),
          Text(trick.name, style: AppTextStyles.headline),
          const Spacer(),
          if (showTimer)
            TimerReadout(trickTime: trickTime)
          else
            Text(
              'NO TIMER · ONE TRY EACH',
              style: AppTextStyles.label.copyWith(color: AppColors.grey),
            ),
        ],
      ),
    );
  }
}

/// Seconds left (rounded up, G3) and a progress bar.
///
/// Its own BlocBuilder: the Cubit emits every 100 ms, but `buildWhen` lets
/// a rebuild through only when the shown second or the bar changes (D4).
/// The rest of the screen doesn't rebuild for ticks at all.
class TimerReadout extends StatelessWidget {
  const TimerReadout({super.key, required this.trickTime});

  final Duration trickTime;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameCubit, GameState>(
      buildWhen: (previous, current) =>
          timerChanged(previous, current, trickTime),
      builder: (context, state) {
        final left = state.phaseRemaining;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${secondsUp(left)}',
                  style: AppTextStyles.display.copyWith(fontSize: 64),
                ),
                const SizedBox(width: 12),
                const Text('SECONDS LEFT', style: AppTextStyles.label),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 8,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.ink),
              ),
              // FractionallySizedBox sizes its child to a fraction of the
              // space it's given: here, the share of the time that's left.
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: barStep(left, trickTime) / barSteps,
                child: const ColoredBox(color: AppColors.ink),
              ),
            ),
          ],
        );
      },
    );
  }
}
