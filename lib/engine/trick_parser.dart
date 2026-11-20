/// Parser for `assets/tricks.json` (spec T6). Pure Dart — no Flutter imports.
///
/// The parser never throws. Bad entries are skipped and reported; good
/// entries still load. Problems with the file as a whole (bad JSON, version,
/// thresholds, missing `tricks` list) return no tricks and a single error.
library;

import 'dart:convert';

import 'trick.dart';

/// The only file format version this parser understands.
const int supportedTricksVersion = 1;

/// One validation problem found while parsing.
class TrickParseError {
  const TrickParseError(this.message, {this.index, this.id});

  /// Position in the `tricks` list, or `null` for a whole-file problem.
  final int? index;

  /// The entry's `id`, when it could be read.
  final String? id;

  final String message;

  @override
  String toString() {
    if (index == null) return message;
    final where = id == null ? 'tricks[$index]' : 'tricks[$index] ($id)';
    return '$where: $message';
  }
}

/// Result of [parseTricks]: the valid tricks plus every problem found.
class TrickParseResult {
  TrickParseResult({
    required List<Trick> tricks,
    required List<TrickParseError> errors,
    required this.thresholds,
  }) : tricks = List.unmodifiable(tricks),
       errors = List.unmodifiable(errors);

  final List<Trick> tricks;
  final List<TrickParseError> errors;

  /// The file's thresholds, or `null` if the file itself was rejected.
  final DifficultyThresholds? thresholds;
}

/// Parses the contents of `tricks.json`.
TrickParseResult parseTricks(String source) {
  TrickParseResult fileError(String message) => TrickParseResult(
    tricks: const [],
    errors: [TrickParseError(message)],
    thresholds: null,
  );

  final Object? root;
  try {
    root = jsonDecode(source);
  } on FormatException catch (e) {
    return fileError('invalid JSON: ${e.message}');
  }

  if (root is! Map<String, dynamic>) {
    return fileError('top level must be a JSON object');
  }

  final version = root['version'];
  if (version is! int) {
    return fileError('"version" must be an integer');
  }
  if (version != supportedTricksVersion) {
    return fileError(
      'unsupported version $version (expected $supportedTricksVersion)',
    );
  }

  final thresholdsOrError = _parseThresholds(root['thresholds']);
  if (thresholdsOrError is String) return fileError(thresholdsOrError);
  final thresholds = thresholdsOrError as DifficultyThresholds;

  final rawTricks = root['tricks'];
  if (rawTricks is! List) {
    return fileError('"tricks" must be a list');
  }

  final tricks = <Trick>[];
  final errors = <TrickParseError>[];
  final seenIds = <String>{};
  final seenNames = <String>{};

  for (var i = 0; i < rawTricks.length; i++) {
    final entryErrors = <TrickParseError>[];
    final trick = _parseEntry(rawTricks[i], i, thresholds, entryErrors);

    if (trick != null) {
      if (!seenIds.add(trick.id)) {
        entryErrors.add(
          TrickParseError('duplicate id', index: i, id: trick.id),
        );
      }
      if (!seenNames.add(trick.name)) {
        entryErrors.add(
          TrickParseError(
            'duplicate name "${trick.name}"',
            index: i,
            id: trick.id,
          ),
        );
      }
    }

    if (entryErrors.isEmpty && trick != null) {
      tricks.add(trick);
    } else {
      errors.addAll(entryErrors);
    }
  }

  return TrickParseResult(
    tricks: tricks,
    errors: errors,
    thresholds: thresholds,
  );
}

/// Returns a [DifficultyThresholds], or an error message.
Object _parseThresholds(Object? raw) {
  if (raw is! Map<String, dynamic>) {
    return '"thresholds" must be an object';
  }
  final intermediate = raw['intermediate'];
  final advanced = raw['advanced'];
  if (intermediate is! int) {
    return '"thresholds.intermediate" must be an integer';
  }
  if (advanced is! int) {
    return '"thresholds.advanced" must be an integer';
  }
  if (intermediate < 1) {
    return '"thresholds.intermediate" must be at least 1';
  }
  if (intermediate >= advanced) {
    return '"thresholds.intermediate" must be less than "thresholds.advanced"';
  }
  return DifficultyThresholds(intermediate: intermediate, advanced: advanced);
}

/// Parses one entry. Adds every problem to [errors] and returns `null` if
/// there were any.
Trick? _parseEntry(
  Object? raw,
  int index,
  DifficultyThresholds thresholds,
  List<TrickParseError> errors,
) {
  if (raw is! Map<String, dynamic>) {
    errors.add(TrickParseError('entry must be an object', index: index));
    return null;
  }

  final rawId = raw['id'];
  final knownId = rawId is String && rawId.isNotEmpty ? rawId : null;

  void problem(String message) =>
      errors.add(TrickParseError(message, index: index, id: knownId));

  String? requiredString(String field) {
    if (!raw.containsKey(field)) {
      problem('missing required field "$field"');
      return null;
    }
    final value = raw[field];
    if (value is! String) {
      problem('"$field" must be a string');
      return null;
    }
    if (value.isEmpty) {
      problem('"$field" must not be empty');
      return null;
    }
    return value;
  }

  final id = requiredString('id');
  final name = requiredString('name');
  final trick = requiredString('trick');

  Stance? stance;
  final stanceValue = requiredString('stance');
  if (stanceValue != null) {
    stance = Stance.fromJson(stanceValue);
    if (stance == null) problem('unknown stance "$stanceValue"');
  }

  // Optional: a missing key and an explicit null both mean "no modifier".
  Modifier? modifier;
  var modifierOk = true;
  final rawModifier = raw['modifier'];
  if (rawModifier != null) {
    if (rawModifier is! String) {
      problem('"modifier" must be a string');
      modifierOk = false;
    } else {
      modifier = Modifier.fromJson(rawModifier);
      if (modifier == null) {
        problem('unknown modifier "$rawModifier"');
        modifierOk = false;
      }
    }
  }

  int? points;
  if (!raw.containsKey('points')) {
    problem('missing required field "points"');
  } else {
    final value = raw['points'];
    if (value is! int) {
      problem('"points" must be an integer');
    } else if (value < 1) {
      problem('"points" must be at least 1');
    } else {
      points = value;
    }
  }

  if (id == null ||
      name == null ||
      trick == null ||
      stance == null ||
      !modifierOk ||
      points == null) {
    return null;
  }

  return Trick(
    id: id,
    name: name,
    trick: trick,
    stance: stance,
    modifier: modifier,
    points: points,
    difficulty: thresholds.difficultyFor(points),
  );
}
