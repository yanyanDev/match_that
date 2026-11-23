import 'package:flutter/widgets.dart';
import 'package:match_that/engine/players.dart';
import 'package:match_that/ui/app_colors.dart';
import 'package:match_that/ui/app_text_styles.dart';

/// One player's name and score on the Game screen (Figma Game).
///
/// The active player's card fills with their color (D2); the others are
/// cream. Every card keeps a 1 px ink border, because the player colors are
/// all close to the cream background (D1).
///
/// It takes plain values rather than a `Player`, so it's easy to build in
/// tests. The scrolling row of cards (D3) is the Game screen's job (8b).
class ScoreCard extends StatelessWidget {
  const ScoreCard({
    super.key,
    required this.name,
    required this.score,
    required this.color,
    required this.active,
  });

  final String name;
  final int score;
  final PlayerColor color;
  final bool active;

  /// Fixed width so a row of cards lines up and long names get "…".
  static const width = 120.0;

  @override
  Widget build(BuildContext context) {
    // Container with a `decoration` draws a DecoratedBox: fill + border.
    return Container(
      width: width,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: active ? color.color : AppColors.cream,
        border: Border.all(color: AppColors.ink),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body.copyWith(
              fontSize: 12,
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
              // Inter is a *variable* font: one file, any weight. The
              // `wght` axis is what actually makes it bold.
              fontVariations: const [FontVariation.weight(700)],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              // Flexible + FittedBox: a big score shrinks to fit the card
              // instead of overflowing it.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('$score', style: AppTextStyles.title),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'PTS',
                style: AppTextStyles.label.copyWith(
                  fontSize: 9,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
