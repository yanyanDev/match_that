import 'package:flutter/material.dart';
import 'package:match_that/ui/app_colors.dart';
import 'package:match_that/ui/widgets/block_button.dart';

/// The cream button with a 1 px ink outline (Figma: MISSED, Results HOME;
/// pause menu Undo last call and End game).
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 56,
    this.showArrow = false,
  });

  final String label;

  /// Called on tap. `null` disables the button: grey label and outline
  /// (e.g. Undo last call when there is nothing to undo, U3).
  final VoidCallback? onPressed;

  /// 56 by default; MISSED on the Game screen is 72 (D4).
  final double height;

  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    return BlockButton(
      label: label,
      onPressed: onPressed,
      fill: AppColors.cream,
      disabledFill: AppColors.cream,
      border: AppColors.ink,
      height: height,
      showArrow: showArrow,
    );
  }
}
