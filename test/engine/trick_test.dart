// Spec §10 step 1a — Trick model + parser for assets/tricks.json.
// Covers T1, T3, T4, T6, T7. Written test-first: lib/engine/ does not exist yet.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:match_that/engine/trick.dart';
import 'package:match_that/engine/trick_parser.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// A valid trick entry. Pass [overrides] to change fields; pass a value of
/// [_remove] to delete a key entirely.
Map<String, Object?> entry([Map<String, Object?> overrides = const {}]) {
  final map = <String, Object?>{
    'id': 'regular_kickflip',
    'name': 'Kickflip',
    'trick': 'kickflip',
    'stance': 'regular',
    'points': 3,
  };
  overrides.forEach((key, value) {
    if (identical(value, _remove)) {
      map.remove(key);
    } else {
      map[key] = value;
    }
  });
  return map;
}

const Object _remove = Object();

/// Two distinct valid entries used around a bad one (good, bad, good).
Map<String, Object?> goodA() =>
    entry({'id': 'a_trick', 'name': 'Trick A', 'points': 2});
Map<String, Object?> goodC() =>
    entry({'id': 'c_trick', 'name': 'Trick C', 'points': 6});

/// A whole tricks.json document. Pass [_remove] to omit a top-level key.
String doc({
  Object? tricks = const <Object?>[],
  Object? thresholds = const {'intermediate': 5, 'advanced': 8},
  Object? version = 1,
}) {
  final map = <String, Object?>{
    'version': version,
    'thresholds': thresholds,
    'tricks': tricks,
  };
  map.removeWhere((_, value) => identical(value, _remove));
  return jsonEncode(map);
}

/// Parses good, [bad], good and checks the bad one is skipped with an error
/// at index 1 while both good entries still load (T6).
TrickParseResult expectOnlyMiddleRejected(Object? bad) {
  final result = parseTricks(doc(tricks: [goodA(), bad, goodC()]));
  expect(result.tricks.map((t) => t.id), ['a_trick', 'c_trick'],
      reason: 'good entries must still load');
  expect(result.errors, isNotEmpty, reason: 'bad entry must be reported');
  expect(result.errors.every((e) => e.index == 1), isTrue,
      reason: 'errors: ${result.errors.join('\n')}');
  return result;
}

/// Checks a whole-file problem: no tricks, exactly one error, no throw.
void expectFileRejected(String json) {
  final result = parseTricks(json);
  expect(result.tricks, isEmpty);
  expect(result.errors, hasLength(1),
      reason: 'errors: ${result.errors.join('\n')}');
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('A. Difficulty from points (T4)', () {
    const thresholds = DifficultyThresholds(intermediate: 5, advanced: 8);

    test('1. tier boundaries at 5 / 8', () {
      expect(thresholds.difficultyFor(1), Difficulty.beginner);
      expect(thresholds.difficultyFor(4), Difficulty.beginner);
      expect(thresholds.difficultyFor(5), Difficulty.intermediate);
      expect(thresholds.difficultyFor(7), Difficulty.intermediate);
      expect(thresholds.difficultyFor(8), Difficulty.advanced);
      expect(thresholds.difficultyFor(13), Difficulty.advanced);
    });

    test('2. parser uses the file thresholds, not hardcoded ones', () {
      final result = parseTricks(doc(
        thresholds: {'intermediate': 3, 'advanced': 6},
        tricks: [
          entry({'id': 'two', 'name': 'Two', 'points': 2}),
          entry({'id': 'three', 'name': 'Three', 'points': 3}),
          entry({'id': 'six', 'name': 'Six', 'points': 6}),
        ],
      ));
      expect(result.errors, isEmpty);
      expect(result.thresholds?.intermediate, 3);
      expect(result.thresholds?.advanced, 6);
      expect(result.tricks.map((t) => t.difficulty), [
        Difficulty.beginner,
        Difficulty.intermediate,
        Difficulty.advanced,
      ]);
    });
  });

  group('B. Valid entry parses correctly', () {
    test('4. entry without modifier', () {
      final result = parseTricks(doc(tricks: [entry()]));
      expect(result.errors, isEmpty);
      final trick = result.tricks.single;
      expect(trick.id, 'regular_kickflip');
      expect(trick.name, 'Kickflip');
      expect(trick.trick, 'kickflip');
      expect(trick.stance, Stance.regular);
      expect(trick.modifier, isNull);
      expect(trick.points, 3);
      expect(trick.difficulty, Difficulty.beginner);
    });

    test('5. entry with modifier', () {
      final result = parseTricks(doc(tricks: [
        entry({'id': 'regular_kickflip_fs180', 'modifier': 'fs180'}),
      ]));
      expect(result.errors, isEmpty);
      expect(result.tricks.single.modifier, Modifier.fs180);
    });

    test('5b. every modifier in the file format is recognised', () {
      const names = ['fs180', 'bs180', 'fs360', 'bs360', 'revert'];
      final result = parseTricks(doc(tricks: [
        for (final m in names) entry({'id': 'k_$m', 'name': 'K $m', 'modifier': m}),
      ]));
      expect(result.errors, isEmpty);
      expect(result.tricks.map((t) => t.modifier), [
        Modifier.fs180,
        Modifier.bs180,
        Modifier.fs360,
        Modifier.bs360,
        Modifier.revert,
      ]);
    });

    test('6. every stance is recognised; "switch" maps to Stance.switchStance',
        () {
      final result = parseTricks(doc(tricks: [
        for (final s in ['regular', 'fakie', 'nollie', 'switch'])
          entry({'id': '${s}_kickflip', 'name': '$s Kickflip', 'stance': s}),
      ]));
      expect(result.errors, isEmpty);
      expect(result.tricks.map((t) => t.stance), [
        Stance.regular,
        Stance.fakie,
        Stance.nollie,
        Stance.switchStance,
      ]);
    });

    test('7. tricks keep file order', () {
      final result = parseTricks(doc(tricks: [goodC(), goodA()]));
      expect(result.tricks.map((t) => t.id), ['c_trick', 'a_trick']);
    });

    test('8. empty tricks list gives no tricks and no errors', () {
      final result = parseTricks(doc(tricks: []));
      expect(result.tricks, isEmpty);
      expect(result.errors, isEmpty);
    });

    test('9. returned lists are unmodifiable', () {
      final result = parseTricks(doc(tricks: [entry()]));
      expect(() => result.tricks.add(result.tricks.first),
          throwsUnsupportedError);
      expect(() => result.errors.clear(), throwsUnsupportedError);
    });

    test('15a. explicit "modifier": null means no modifier', () {
      final result = parseTricks(doc(tricks: [
        entry({'modifier': null}),
      ]));
      expect(result.errors, isEmpty);
      expect(result.tricks.single.modifier, isNull);
    });
  });

  group('C. Per-entry errors — good entries still load (T6)', () {
    for (final field in ['id', 'name', 'trick', 'stance', 'points']) {
      test('10. missing required field "$field"', () {
        final result = expectOnlyMiddleRejected(
            entry({'id': 'bad', 'name': 'Bad', field: _remove}));
        expect(result.errors.single.message, contains(field));
      });
    }

    final wrongTypes = <String, Map<String, Object?>>{
      'points as string': {'points': '3'},
      'points as fraction': {'points': 3.5},
      'name as number': {'name': 7},
      'id as number': {'id': 7},
      'trick as bool': {'trick': true},
      'stance as number': {'stance': 1},
    };
    wrongTypes.forEach((label, override) {
      test('11. wrong type: $label', () {
        expectOnlyMiddleRejected(entry({
          'id': 'bad',
          'name': 'Bad',
          ...override,
        }));
      });
    });

    for (final field in ['id', 'name', 'trick']) {
      test('12. empty string "$field"', () {
        expectOnlyMiddleRejected(
            entry({'id': 'bad', 'name': 'Bad', field: ''}));
      });
    }

    test('13. unknown stance', () {
      expectOnlyMiddleRejected(
          entry({'id': 'bad', 'name': 'Bad', 'stance': 'goofy'}));
    });

    test('14. unknown modifier', () {
      expectOnlyMiddleRejected(
          entry({'id': 'bad', 'name': 'Bad', 'modifier': 'fs540'}));
    });

    test('15b. non-string modifier', () {
      expectOnlyMiddleRejected(
          entry({'id': 'bad', 'name': 'Bad', 'modifier': 7}));
    });

    test('16. zero points', () {
      expectOnlyMiddleRejected(
          entry({'id': 'bad', 'name': 'Bad', 'points': 0}));
    });

    test('16. negative points', () {
      expectOnlyMiddleRejected(
          entry({'id': 'bad', 'name': 'Bad', 'points': -2}));
    });

    test('17. entry is not an object', () {
      expectOnlyMiddleRejected(42);
    });

    test('18. duplicate id: first kept, second rejected', () {
      final result = parseTricks(doc(tricks: [
        goodA(),
        entry({'id': 'a_trick', 'name': 'Different Name'}),
        goodC(),
      ]));
      expect(result.tricks.map((t) => t.name), ['Trick A', 'Trick C']);
      final error = result.errors.single;
      expect(error.index, 1);
      expect(error.id, 'a_trick');
    });

    test('19. duplicate name rejected', () {
      expectOnlyMiddleRejected(entry({'id': 'other_id', 'name': 'Trick A'}));
    });

    test('20. several problems in one entry are all reported, entry skipped',
        () {
      final result = expectOnlyMiddleRejected(entry({
        'id': 'bad',
        'name': _remove,
        'stance': 'goofy',
        'points': -1,
      }));
      expect(result.errors.length, greaterThanOrEqualTo(3),
          reason: 'errors: ${result.errors.join('\n')}');
    });
  });

  group('D. Whole-file errors', () {
    test('21. malformed JSON does not throw', () {
      expectFileRejected('{"version": 1, "tricks": [');
    });

    test('22. top level is not an object', () {
      expectFileRejected('[]');
    });

    test('23. thresholds missing', () {
      expectFileRejected(doc(thresholds: _remove, tricks: [entry()]));
    });

    test('23. thresholds.intermediate missing', () {
      expectFileRejected(doc(thresholds: {'advanced': 8}, tricks: [entry()]));
    });

    test('23. thresholds.advanced not an int', () {
      expectFileRejected(doc(
          thresholds: {'intermediate': 5, 'advanced': 8.5},
          tricks: [entry()]));
    });

    test('23. thresholds value as string', () {
      expectFileRejected(doc(
          thresholds: {'intermediate': '5', 'advanced': 8},
          tricks: [entry()]));
    });

    test('24. intermediate == advanced', () {
      expectFileRejected(doc(
          thresholds: {'intermediate': 5, 'advanced': 5}, tricks: [entry()]));
    });

    test('24. intermediate > advanced', () {
      expectFileRejected(doc(
          thresholds: {'intermediate': 8, 'advanced': 5}, tricks: [entry()]));
    });

    test('24. intermediate below 1', () {
      expectFileRejected(doc(
          thresholds: {'intermediate': 0, 'advanced': 5}, tricks: [entry()]));
    });

    test('25. tricks missing', () {
      expectFileRejected(doc(tricks: _remove));
    });

    test('25. tricks is not a list', () {
      expectFileRejected(doc(tricks: {'id': 'x'}));
    });

    test('26. version missing', () {
      expectFileRejected(doc(version: _remove, tricks: [entry()]));
    });

    test('26. unsupported version', () {
      expectFileRejected(doc(version: 2, tricks: [entry()]));
    });

    test('26. version as string', () {
      expectFileRejected(doc(version: '1', tricks: [entry()]));
    });
  });

  group('E. Real assets/tricks.json (T6, T7)', () {
    late TrickParseResult result;

    setUpAll(() {
      result = parseTricks(File('assets/tricks.json').readAsStringSync());
    });

    test('27. parses with zero errors and 324 tricks', () {
      expect(result.errors, isEmpty, reason: result.errors.join('\n'));
      expect(result.tricks, hasLength(324));
    });

    test('3. every difficulty matches thresholds.difficultyFor(points)', () {
      final thresholds = result.thresholds!;
      for (final trick in result.tricks) {
        expect(trick.difficulty, thresholds.difficultyFor(trick.points),
            reason: trick.id);
      }
    });

    test('28. every tier has at least 15 tricks (T7)', () {
      for (final tier in Difficulty.values) {
        final count = result.tricks.where((t) => t.difficulty == tier).length;
        expect(count, greaterThanOrEqualTo(15), reason: '$tier has $count');
      }
    });
  });

  test('29. lib/engine has no Flutter imports (spec §8)', () {
    final offenders = Directory('lib/engine')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => f.readAsStringSync().contains('package:flutter'))
        .map((f) => f.path)
        .toList();
    expect(offenders, isEmpty);
  });
}
