import 'package:flutter/material.dart';
import 'package:match_that/ui/app_colors.dart';
import 'package:match_that/ui/app_text_styles.dart';

/// The full-width lime button with the label on the left and an arrow on the
/// right (Figma: START, START GAME, DONE, PLAY AGAIN).
///
/// A StatelessWidget: what it shows depends only on its constructor fields,
/// so it has no state of its own. The screen that uses it owns any state and
/// rebuilds it with new values.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;

  /// Called on tap. `null` disables the button (e.g. Start game while a name
  /// is invalid, A4). Same convention as Flutter's own buttons.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final foreground = enabled ? AppColors.ink : AppColors.grey;

    return SizedBox(
      width: double.infinity,
      height: 56,
      // Material paints the fill; InkWell on top of it handles the tap and
      // draws the ripple. Square corners, no shadow, as in the Figma.
      child: Material(
        color: enabled ? AppColors.lime : AppColors.grey.withValues(alpha: 0.15),
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  label,
                  style: AppTextStyles.button.copyWith(color: foreground),
                ),
                const Spacer(),
                Icon(Icons.arrow_forward, color: foreground),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
