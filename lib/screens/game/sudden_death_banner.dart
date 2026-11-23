import 'package:flutter/widgets.dart';

import '../../ui/app_colors.dart';
import '../../ui/app_text_styles.dart';

/// The "SUDDEN DEATH" strip on the countdown and play views (§7 screen 8).
class SuddenDeathBanner extends StatelessWidget {
  const SuddenDeathBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: AppColors.ink,
      child: Text(
        'SUDDEN DEATH',
        style: AppTextStyles.label.copyWith(color: AppColors.lime),
      ),
    );
  }
}
