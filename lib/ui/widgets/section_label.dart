import 'package:flutter/widgets.dart';
import 'package:match_that/ui/app_text_styles.dart';

/// The numbered mono label above each Setup section: "01 / PLAYERS".
class SectionLabel extends StatelessWidget {
  const SectionLabel({super.key, required this.number, required this.text});

  /// Shown with at least 2 digits: 1 → "01".
  final int number;

  /// Shown upper-case: "Players" → "PLAYERS".
  final String text;

  @override
  Widget build(BuildContext context) {
    final n = number.toString().padLeft(2, '0');
    return Text('$n / ${text.toUpperCase()}', style: AppTextStyles.label);
  }
}
