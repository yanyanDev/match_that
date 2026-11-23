import 'package:flutter/material.dart';
import 'package:match_that/ui/app_colors.dart';
import 'package:match_that/ui/app_text_styles.dart';

/// The shared shape of the app's buttons: full width, square corners, no
/// shadow, mono label on the left and an optional arrow on the right.
///
/// Screens use [PrimaryButton] or [SecondaryButton], which only choose the
/// fill and border. Keeping the layout here means the two can't drift apart.
class BlockButton extends StatelessWidget {
  const BlockButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.fill,
    required this.disabledFill,
    this.border,
    this.height = 56,
    this.showArrow = false,
  });

  final String label;

  /// Called on tap. `null` disables the button: grey label, no taps.
  final VoidCallback? onPressed;

  final Color fill;
  final Color disabledFill;

  /// Outline color, or `null` for no outline. Always 1 px (D1).
  final Color? border;

  final double height;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final foreground = enabled ? AppColors.ink : AppColors.grey;
    final border = this.border;

    return SizedBox(
      width: double.infinity,
      height: height,
      // Material paints the fill (and outline); InkWell on top handles the
      // tap and draws the ripple.
      child: Material(
        color: enabled ? fill : disabledFill,
        // RoundedRectangleBorder with no radius = square corners.
        shape: RoundedRectangleBorder(
          side: border == null
              ? BorderSide.none
              : BorderSide(color: enabled ? border : AppColors.grey),
        ),
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.button.copyWith(color: foreground),
                  ),
                ),
                if (showArrow) ...[
                  const Spacer(),
                  Icon(Icons.arrow_forward, color: foreground),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
