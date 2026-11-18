/// Trick model (spec §5, T1–T5). Pure Dart — no Flutter imports.
library;

/// Difficulty tier, derived from a trick's final points (T4).
enum Difficulty { beginner, intermediate, advanced }

/// Stance a trick is performed in.
///
/// [json] is the value used in `assets/tricks.json`. It is separate from the
/// enum name because `switch` is a reserved word in Dart.
enum Stance {
  regular('regular'),
  fakie('fakie'),
  nollie('nollie'),
  switchStance('switch');

  const Stance(this.json);

  final String json;

  static final Map<String, Stance> _byJson = {
    for (final stance in values) stance.json: stance,
  };

  /// The stance for a JSON value, or `null` if it is unknown.
  static Stance? fromJson(String value) => _byJson[value];
}

/// The single optional modifier on a trick: a rotation or a revert (T3).
/// Enum names match the JSON values exactly.
enum Modifier {
  fs180,
  bs180,
  fs360,
  bs360,
  revert;

  static final Map<String, Modifier> _byName = values.asNameMap();

  /// The modifier for a JSON value, or `null` if it is unknown.
  static Modifier? fromJson(String value) => _byName[value];
}

/// Points thresholds that split tricks into difficulty tiers (T4).
///
/// `points < intermediate` is beginner, `intermediate <= points < advanced`
/// is intermediate, and `points >= advanced` is advanced.
class DifficultyThresholds {
  const DifficultyThresholds({
    required this.intermediate,
    required this.advanced,
  });

  final int intermediate;
  final int advanced;

  Difficulty difficultyFor(int points) {
    if (points >= advanced) return Difficulty.advanced;
    if (points >= intermediate) return Difficulty.intermediate;
    return Difficulty.beginner;
  }

  @override
  String toString() =>
      'DifficultyThresholds(intermediate: $intermediate, advanced: $advanced)';
}

/// One flatground trick from the library (T1, T2). Immutable.
class Trick {
  const Trick({
    required this.id,
    required this.name,
    required this.trick,
    required this.stance,
    required this.modifier,
    required this.points,
    required this.difficulty,
  });

  /// Unique id, e.g. `fakie_kickflip_bs180`.
  final String id;

  /// Display name, e.g. `Halfcab Flip` (T5: name only).
  final String name;

  /// Base trick key, e.g. `kickflip`.
  final String trick;

  final Stance stance;

  /// At most one modifier; `null` means none (T3).
  final Modifier? modifier;

  /// Final points, as computed by the generator (T3).
  final int points;

  /// Derived from [points] via the file's thresholds (T4).
  final Difficulty difficulty;

  @override
  String toString() => 'Trick($id, $points pts, ${difficulty.name})';
}
