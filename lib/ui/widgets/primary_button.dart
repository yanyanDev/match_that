import 'package:flutter/material.dart';
import 'package:match_that/ui/app_colors.dart';
import 'package:match_that/ui/widgets/block_button.dart';

/// The lime button (Figma: START, START GAME, DONE, PLAY AGAIN, MATCHED).
/// Lime stays the UI accent (D2).
///
/// A StatelessWidget: what it shows depends only on its constructor fields,
/// so it has no state of its own. The screen that uses it owns any state and
/// rebuilds it with new values.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 56,
    this.showArrow = true,
  });

  final String label;

  /// Called on tap. `null` disables the button (e.g. Start game while a name
  /// is invalid, A4). Same convention as Flutter's own buttons.
  final VoidCallback? onPressed;

  /// 56 by default; MATCHED on the Game screen is 72 (D4).
  final double height;

  /// The arrow on the right. MATCHED has none (Figma).
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    return BlockButton(
      label: label,
      onPressed: onPressed,
      fill: AppColors.lime,
      disabledFill: AppColors.grey.withValues(alpha: 0.15),
      height: height,
      showArrow: showArrow,
    );
  }
}
