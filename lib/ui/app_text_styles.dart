import 'package:flutter/painting.dart';
import 'package:match_that/ui/app_colors.dart';

/// The app's text styles: Anton for headlines, IBM Plex Mono for labels,
/// Inter for body text (CLAUDE.md).
///
/// A [TextStyle] is an immutable bundle of font family, size, weight, color,
/// letter spacing and line height. To make a variant, use `copyWith`, e.g.
/// `AppTextStyles.label.copyWith(color: AppColors.grey)`.
///
/// The family names must match `family:` in pubspec.yaml exactly.
abstract final class AppTextStyles {
  static const _anton = 'Anton';
  static const _mono = 'IBM Plex Mono';
  static const _inter = 'Inter';

  /// "MATCH THAT!" on Home.
  static const display = TextStyle(
    fontFamily: _anton,
    fontSize: 116,
    height: 1,
    color: AppColors.ink,
  );

  /// Screen headlines: "SET IT OFF.", "YOUR CREW.", "PLAYER 1 WINS!".
  static const headline = TextStyle(
    fontFamily: _anton,
    fontSize: 44,
    height: 1,
    color: AppColors.ink,
  );

  /// Smaller Anton: the current-turn name "Player 1", scores.
  static const title = TextStyle(
    fontFamily: _anton,
    fontSize: 28,
    height: 1.1,
    color: AppColors.ink,
  );

  /// Small caps-style labels: "01 / PLAYERS", "SMALL BOARD. BIG GAME.".
  static const label = TextStyle(
    fontFamily: _mono,
    fontSize: 12,
    letterSpacing: 2,
    color: AppColors.ink,
  );

  /// Text inside buttons: "START", "QUICK PLAY".
  static const button = TextStyle(
    fontFamily: _mono,
    fontSize: 14,
    color: AppColors.ink,
  );

  /// Body and helper text: "Set a trick. Match the move."
  static const body = TextStyle(
    fontFamily: _inter,
    fontSize: 15,
    color: AppColors.grey,
  );
}
