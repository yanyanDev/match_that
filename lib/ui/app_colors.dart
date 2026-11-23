import 'package:flutter/painting.dart';
import 'package:match_that/engine/players.dart';

/// The app's fixed colors (CLAUDE.md, Figma).
///
/// `abstract final class` with only `static const` fields is Dart's way of
/// saying "a namespace": nobody can create or subclass an AppColors; you just
/// write `AppColors.lime`.
abstract final class AppColors {
  /// Page background.
  static const cream = Color(0xFFF3F1E9);

  /// Text, borders and icons.
  static const ink = Color(0xFF1A1A1A);

  /// Secondary text (helper lines, captions).
  static const grey = Color(0xFF696861);

  /// UI accent: Matched, Start and other primary buttons (D2).
  static const lime = Color(0xFFD9FF43);
}

/// Maps the engine's [PlayerColor] to a real Flutter [Color] (D1, P3b).
///
/// An *extension* adds members to a type we don't want to change: the engine
/// stays pure Dart (no Flutter `Color`), and the UI still gets to write
/// `player.color.color`.
extension PlayerColorUi on PlayerColor {
  Color get color => switch (this) {
    // A switch over an enum must cover every value, so a 9th PlayerColor
    // would be a compile error here until it gets a color.
    PlayerColor.color1 => AppColors.lime, // Lime (matches the Figma)
    PlayerColor.color2 => const Color(0xFF7CC8FF), // Sky
    PlayerColor.color3 => const Color(0xFFFFA24C), // Tangerine
    PlayerColor.color4 => const Color(0xFFFF8FC7), // Pink
    PlayerColor.color5 => const Color(0xFF5EE6B0), // Mint
    PlayerColor.color6 => const Color(0xFFB9A6FF), // Lavender
    PlayerColor.color7 => const Color(0xFFFFD84D), // Sun
    PlayerColor.color8 => const Color(0xFFFF7A6B), // Coral
  };
}
