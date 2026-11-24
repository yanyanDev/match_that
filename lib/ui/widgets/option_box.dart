import 'package:flutter/material.dart';
import 'package:match_that/ui/app_colors.dart';
import 'package:match_that/ui/app_text_styles.dart';

/// A square, outlined choice box (Figma Setup: QUICK PLAY / FULL GAME,
/// Beginner / Intermediate / Advanced). Selected = lime fill.
///
/// It doesn't know which option is chosen; the screen passes [selected] and
/// rebuilds it when the choice changes.
class OptionBox extends StatelessWidget {
  const OptionBox({
    super.key,
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final String title;

  /// Optional second line, e.g. "10 TRICKS".
  final String? subtitle;

  final bool selected;
  final VoidCallback onTap;

  /// For a row of three narrow boxes (difficulty): a smaller, centered,
  /// single-line title with less side padding, so all three look the same.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;

    // Semantics describes the widget to screen readers: "button, selected".
    // `container: true` gives it its own node so the flags aren't merged away.
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.lime : AppColors.cream,
        // RoundedRectangleBorder with no radius = square corners; `side` is
        // the 1 px ink outline.
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: AppColors.ink),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: compact
                ? const EdgeInsets.symmetric(horizontal: 8, vertical: 12)
                : const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: compact
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                if (compact)
                  // FittedBox(scaleDown): if the title still doesn't fit
                  // (a very narrow phone, large system text), it shrinks to
                  // fit on one line instead of wrapping. It never grows.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      title,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.button.copyWith(fontSize: 12),
                    ),
                  )
                else
                  Text(title, style: AppTextStyles.button),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: AppTextStyles.label.copyWith(
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
