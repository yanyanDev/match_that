/// Expands `data/trick_rules.json` into the flat `assets/tricks.json` format
/// (spec T1, T3, T6a). Pure Dart — no Flutter imports.
///
/// Unlike the app-side parser, the generator is a developer tool: any problem
/// in the rules throws a [TrickRulesException], so a broken rules file can
/// never produce a half-generated library.
library;

import 'dart:convert';

import 'trick.dart';
import 'trick_parser.dart' show supportedTricksVersion;

/// The only rules file format version this generator understands.
const int supportedRulesVersion = 1;

/// Thrown when `trick_rules.json` is invalid.
class TrickRulesException implements Exception {
  const TrickRulesException(this.message);

  final String message;

  @override
  String toString() => 'TrickRulesException: $message';
}

/// The generator's output: thresholds plus every expanded trick, in order.
class TrickLibrary {
  TrickLibrary({required this.thresholds, required List<Trick> tricks})
      : tricks = List.unmodifiable(tricks);

  final DifficultyThresholds thresholds;
  final List<Trick> tricks;
}

/// Expands the contents of `trick_rules.json` into a [TrickLibrary].
///
/// Order: base tricks in rules order → stances in rules order → the plain
/// entry first, then the trick's modifiers in listed order.
TrickLibrary generateTricks(String rulesSource) {
  final Object? decoded;
  try {
    decoded = jsonDecode(rulesSource);
  } on FormatException catch (e) {
    throw TrickRulesException('invalid JSON: ${e.message}');
  }
  final root = _map(decoded, 'top level');

  final version = root['version'];
  if (version != supportedRulesVersion) {
    throw TrickRulesException(
        'unsupported version $version (expected $supportedRulesVersion)');
  }

  final thresholds = _thresholds(root['thresholds']);

  final stances = <String, _StanceDef>{};
  final rawStances = _list(root['stances'], '"stances"');
  for (var i = 0; i < rawStances.length; i++) {
    final def = _StanceDef.parse(rawStances[i], 'stances[$i]');
    if (stances.containsKey(def.id)) {
      throw TrickRulesException('stances[$i]: duplicate id "${def.id}"');
    }
    stances[def.id] = def;
  }

  final modifiers = <String, _ModifierDef>{};
  final rawModifiers = _list(root['modifiers'], '"modifiers"');
  for (var i = 0; i < rawModifiers.length; i++) {
    final def = _ModifierDef.parse(rawModifiers[i], 'modifiers[$i]', stances);
    if (modifiers.containsKey(def.id)) {
      throw TrickRulesException('modifiers[$i]: duplicate id "${def.id}"');
    }
    modifiers[def.id] = def;
  }

  final tricks = <Trick>[];
  final seenIds = <String>{};
  final seenNames = <String>{};

  final rawTricks = _list(root['tricks'], '"tricks"');
  for (var i = 0; i < rawTricks.length; i++) {
    final expanded =
        _expandTrick(rawTricks[i], 'tricks[$i]', stances, modifiers, thresholds);
    for (final trick in expanded) {
      if (!seenIds.add(trick.id)) {
        throw TrickRulesException('duplicate generated id "${trick.id}"');
      }
      if (!seenNames.add(trick.name)) {
        throw TrickRulesException(
            'duplicate generated name "${trick.name}" (${trick.id})');
      }
    }
    tricks.addAll(expanded);
  }

  return TrickLibrary(thresholds: thresholds, tricks: tricks);
}

/// Encodes [library] in the exact `assets/tricks.json` format: 2-space
/// indent, LF line endings, no trailing newline, `modifier` omitted when
/// there is none.
String encodeTricksJson(TrickLibrary library) {
  return const JsonEncoder.withIndent('  ').convert({
    'version': supportedTricksVersion,
    'thresholds': {
      'intermediate': library.thresholds.intermediate,
      'advanced': library.thresholds.advanced,
    },
    'tricks': [
      for (final trick in library.tricks)
        {
          'id': trick.id,
          'name': trick.name,
          'trick': trick.trick,
          'stance': trick.stance.json,
          if (trick.modifier != null) 'modifier': trick.modifier!.name,
          'points': trick.points,
        },
    ],
  });
}

// ---------------------------------------------------------------------------
// Expansion
// ---------------------------------------------------------------------------

List<Trick> _expandTrick(
  Object? raw,
  String where,
  Map<String, _StanceDef> stances,
  Map<String, _ModifierDef> modifiers,
  DifficultyThresholds thresholds,
) {
  final map = _map(raw, where);
  final id = _string(map, 'id', where);
  where = '$where ($id)';
  final name = _string(map, 'name', where);
  final basePoints = _int(map, 'points', where, min: 1);

  final trickModifiers = <_ModifierDef>[
    for (final m in _stringList(map['modifiers'], '$where "modifiers"'))
      modifiers[m] ??
          (throw TrickRulesException('$where: unknown modifier "$m"')),
  ];

  final trickStances = map.containsKey('stances')
      ? [
          for (final s in _stringList(map['stances'], '$where "stances"'))
            stances[s] ??
                (throw TrickRulesException('$where: unknown stance "$s"')),
        ]
      : stances.values.toList();

  final customNames = [
    if (map.containsKey('customNames'))
      for (final (i, c)
          in _list(map['customNames'], '$where "customNames"').indexed)
        _CustomName.parse(c, '$where customNames[$i]', stances, modifiers),
  ];
  final usedCustomNames = <_CustomName>{};

  final result = <Trick>[];
  for (final stance in trickStances) {
    for (final modifier in [
      null,
      ...trickModifiers.where((m) => m.stances.contains(stance.id)),
    ]) {
      final points = basePoints + stance.points + (modifier?.points ?? 0);
      result.add(Trick(
        id: [stance.id, id, if (modifier != null) modifier.id].join('_'),
        name: _name(name, stance, modifier, customNames, usedCustomNames),
        trick: id,
        stance: stance.stance,
        modifier: modifier?.modifier,
        points: points,
        difficulty: thresholds.difficultyFor(points),
      ));
    }
  }

  for (final custom in customNames) {
    if (!usedCustomNames.contains(custom)) {
      throw TrickRulesException('${custom.where}: "${custom.name}" matches '
          'no generated trick');
    }
  }
  return result;
}

/// Display name (T6a). Most specific rule wins:
/// 1. custom name with a stance, matching stance and modifier → full override
///    (a stance-only custom name applies only to the plain entry);
/// 2. custom name with only a modifier → keeps the stance prefix;
/// 3. default: stance · rotation · trick · revert.
String _name(
  String trickName,
  _StanceDef stance,
  _ModifierDef? modifier,
  List<_CustomName> customNames,
  Set<_CustomName> used,
) {
  for (final custom in customNames) {
    if (custom.stance == stance.id && custom.modifier == modifier?.id) {
      used.add(custom);
      return custom.name;
    }
  }

  String base;
  final modifierOnly = modifier == null
      ? null
      : customNames
          .where((c) => c.stance == null && c.modifier == modifier.id)
          .firstOrNull;
  if (modifierOnly != null) {
    used.add(modifierOnly);
    base = modifierOnly.name;
  } else {
    final isRotation = modifier?.type == 'rotation';
    base = [
      if (isRotation) modifier!.name,
      trickName,
      if (modifier != null && !isRotation) modifier.name,
    ].join(' ');
  }
  return [if (stance.name.isNotEmpty) stance.name, base].join(' ');
}

// ---------------------------------------------------------------------------
// Rules definitions
// ---------------------------------------------------------------------------

class _StanceDef {
  const _StanceDef(this.id, this.name, this.points, this.stance);

  final String id;
  final String name;
  final int points;
  final Stance stance;

  static _StanceDef parse(Object? raw, String where) {
    final map = _map(raw, where);
    final id = _string(map, 'id', where);
    final stance = Stance.fromJson(id) ??
        (throw TrickRulesException('$where: stance "$id" is unknown to the '
            'app (see Stance in trick.dart)'));
    return _StanceDef(
      id,
      _string(map, 'name', where, allowEmpty: true),
      _int(map, 'points', where, min: 0),
      stance,
    );
  }
}

class _ModifierDef {
  const _ModifierDef(
      this.id, this.type, this.name, this.points, this.stances, this.modifier);

  final String id;

  /// `rotation` (named before the trick) or `revert` (named after it).
  final String type;
  final String name;
  final int points;

  /// Stance ids this modifier is allowed with (T6a).
  final Set<String> stances;
  final Modifier modifier;

  static _ModifierDef parse(
      Object? raw, String where, Map<String, _StanceDef> knownStances) {
    final map = _map(raw, where);
    final id = _string(map, 'id', where);
    final modifier = Modifier.fromJson(id) ??
        (throw TrickRulesException('$where: modifier "$id" is unknown to the '
            'app (see Modifier in trick.dart)'));
    final type = _string(map, 'type', where);
    if (type != 'rotation' && type != 'revert') {
      throw TrickRulesException(
          '$where: "type" must be "rotation" or "revert", got "$type"');
    }
    final stances = _stringList(map['stances'], '$where "stances"');
    for (final s in stances) {
      if (!knownStances.containsKey(s)) {
        throw TrickRulesException('$where: unknown stance "$s"');
      }
    }
    return _ModifierDef(
      id,
      type,
      _string(map, 'name', where),
      _int(map, 'points', where, min: 0),
      stances.toSet(),
      modifier,
    );
  }
}

class _CustomName {
  const _CustomName(this.stance, this.modifier, this.name, this.where);

  /// Stance id, or `null` for "any stance, keep the prefix".
  final String? stance;

  /// Modifier id, or `null` for "no modifier".
  final String? modifier;
  final String name;

  /// Location in the rules file, for error messages.
  final String where;

  static _CustomName parse(Object? raw, String where,
      Map<String, _StanceDef> stances, Map<String, _ModifierDef> modifiers) {
    final map = _map(raw, where);
    final stance = map['stance'];
    final modifier = map['modifier'];
    if (stance != null && !stances.containsKey(stance)) {
      throw TrickRulesException('$where: unknown stance "$stance"');
    }
    if (modifier != null && !modifiers.containsKey(modifier)) {
      throw TrickRulesException('$where: unknown modifier "$modifier"');
    }
    if (stance == null && modifier == null) {
      throw TrickRulesException('$where: needs a "stance", a "modifier" '
          'or both');
    }
    return _CustomName(
        stance as String?, modifier as String?, _string(map, 'name', where),
        where);
  }
}

// ---------------------------------------------------------------------------
// JSON helpers — each throws TrickRulesException with a location.
// ---------------------------------------------------------------------------

DifficultyThresholds _thresholds(Object? raw) {
  final map = _map(raw, '"thresholds"');
  final intermediate = _int(map, 'intermediate', 'thresholds', min: 1);
  final advanced = _int(map, 'advanced', 'thresholds', min: 1);
  if (intermediate >= advanced) {
    throw const TrickRulesException(
        'thresholds: "intermediate" must be less than "advanced"');
  }
  return DifficultyThresholds(intermediate: intermediate, advanced: advanced);
}

Map<String, dynamic> _map(Object? raw, String where) {
  if (raw is Map<String, dynamic>) return raw;
  throw TrickRulesException('$where must be a JSON object');
}

List<Object?> _list(Object? raw, String where) {
  if (raw is List) return raw;
  throw TrickRulesException('$where must be a list');
}

List<String> _stringList(Object? raw, String where) {
  final list = _list(raw, where);
  if (list.every((e) => e is String)) return list.cast<String>();
  throw TrickRulesException('$where must be a list of strings');
}

String _string(Map<String, dynamic> map, String key, String where,
    {bool allowEmpty = false}) {
  final value = map[key];
  if (value is! String) {
    throw TrickRulesException('$where: "$key" must be a string');
  }
  if (!allowEmpty && value.isEmpty) {
    throw TrickRulesException('$where: "$key" must not be empty');
  }
  return value;
}

int _int(Map<String, dynamic> map, String key, String where,
    {required int min}) {
  final value = map[key];
  if (value is! int) {
    throw TrickRulesException('$where: "$key" must be an integer');
  }
  if (value < min) {
    throw TrickRulesException('$where: "$key" must be at least $min');
  }
  return value;
}
