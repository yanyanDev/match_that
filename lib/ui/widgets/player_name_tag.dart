import 'package:flutter/widgets.dart';
import 'package:match_that/engine/players.dart';
import 'package:match_that/ui/app_colors.dart';
import 'package:match_that/ui/app_text_styles.dart';

/// A player's name in Anton on their color, with a 1 px ink border.
///
/// D2 says the current-turn name uses the player's color. The palette is
/// light (D1), so colored *text* on cream would be hard to read; ink text on
/// a colored *fill* keeps ≥ 6.8 : 1 contrast.
class PlayerNameTag extends StatelessWidget {
  const PlayerNameTag({super.key, required this.name, required this.color});

  final String name;
  final PlayerColor color;

  @override
  Widget build(BuildContext context) {
    // No width set: the Container shrinks to fit the name, up to the space
    // its parent allows; then the name ends in "…".
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.color,
        border: Border.all(color: AppColors.ink),
      ),
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.title,
      ),
    );
  }
}
