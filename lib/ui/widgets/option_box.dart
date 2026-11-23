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
  });

  final String title;

  /// Optional second line, e.g. "10 TRICKS".
  final String? subtitle;

  final bool selected;
  final VoidCallback onTap;

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
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
