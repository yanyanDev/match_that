// Spec §10 step 1b — generator that expands data/trick_rules.json into
// assets/tricks.json. Covers T1, T3, T4, T6a, T7.
// Written test-first: lib/engine/trick_generator.dart does not exist yet.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:match_that/engine/trick.dart';
import 'package:match_that/engine/trick_generator.dart';
import 'package:match_that/engine/trick_parser.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const Object _remove = Object();

/// Same stances and modifiers as the real data/trick_rules.json.
const List<Map<String, Object?>> defaultStances = [
  {'id': 'regular', 'name': '', 'points': 0},
  {'id': 'fakie', 'name': 'Fakie', 'points': 1},
  {'id': 'nollie', 'name': 'Nollie', 'points': 1},
  {'id': 'switch', 'name': 'Switch', 'points': 2},
];

const List<String> allStances = ['regular', 'fakie', 'nollie', 'switch'];

const List<Map<String, Object?>> defaultModifiers = [
  {'id': 'fs180', 'type': 'rotation', 'name': 'Frontside 180', 'points': 1, 'stances': allStances},
  {'id': 'bs180', 'type': 'rotation', 'name': 'Backside 180', 'points': 1, 'stances': allStances},
  {'id': 'bs360', 'type': 'rotation', 'name': 'Backside 360', 'points': 3, 'stances': ['regular', 'fakie', 'nollie']},
  {'id': 'fs360', 'type': 'rotation', 'name': 'Frontside 360', 'points': 3, 'stances': ['switch']},
  {'id': 'revert', 'type': 'revert', 'name': 'Revert', 'points': 1, 'stances': allStances},
];

const List<String> allRotations = ['fs180', 'bs180', 'bs360', 'fs360'];

/// One base trick in the rules format.
Map<String, Object?> rule(
  String id,
  String name,
  int points, {
  List<String> modifiers = const [],
  List<String>? stances,
  List<Map<String, Object?>>? customNames,
}) =>
    {
      'id': id,
      'name': name,
      'points': points,
      'modifiers': modifiers,
      'stances': ?stances,
      'customNames': ?customNames,
    };

/// A whole trick_rules.json document. Pass [_remove] to omit a top-level key.
String rulesDoc({
  Object? tricks = const <Object?>[],
  Object? thresholds = const {'intermediate': 5, 'advanced': 8},
  Object? version = 1,
  Object? stances = defaultStances,
  Object? modifiers = defaultModifiers,
}) {
  final map = <String, Object?>{
    'version': version,
    'thresholds': thresholds,
    'stances': stances,
    'modifiers': modifiers,
    'tricks': tricks,
  };
  map.removeWhere((_, value) => identical(value, _remove));
  return jsonEncode(map);
}

/// Generates from [tricks] with default stances/modifiers.
List<Trick> gen(List<Map<String, Object?>> tricks) =>
    generateTricks(rulesDoc(tricks: tricks)).tricks;

/// id → name, for checking names.
Map<String, String> namesById(List<Trick> tricks) =>
    {for (final t in tricks) t.id: t.name};

Trick byId(List<Trick> tricks, String id) =>
    tricks.firstWhere((t) => t.id == id, orElse: () => fail('no trick $id'));

Matcher get throwsRules => throwsA(isA<TrickRulesException>());

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('A. Expansion & order (T1)', () {
    test('1. trick without modifiers → one entry per stance, in stance order',
        () {
      final tricks = gen([rule('kickflip', 'Kickflip', 2)]);
      expect(tricks.map((t) => t.id), [
        'regular_kickflip',
        'fakie_kickflip',
        'nollie_kickflip',
        'switch_kickflip',
      ]);
    });

    test('2. modifiers follow the plain entry, in the trick\'s listed order',
        () {
      final tricks =
          gen([rule('kickflip', 'Kickflip', 2, modifiers: ['bs180', 'fs180'])]);
      expect(tricks.take(3).map((t) => t.id), [
        'regular_kickflip',
        'regular_kickflip_bs180',
        'regular_kickflip_fs180',
      ]);
    });

    test('2b. base tricks keep rules order', () {
      final tricks = gen([
        rule('tre_flip', 'Tre Flip', 5),
        rule('kickflip', 'Kickflip', 2),
      ]);
      expect(tricks.first.trick, 'tre_flip');
      expect(tricks.last.trick, 'kickflip');
    });

    test('3. trick-level "stances" restricts stances', () {
      final tricks = gen([
        rule('no_comply_ollie', 'No-Comply Ollie', 2,
            stances: ['regular', 'fakie']),
      ]);
      expect(tricks.map((t) => t.stance), [Stance.regular, Stance.fakie]);
    });

    test('4. empty "modifiers" gives no modifier entries', () {
      final tricks = gen([rule('big_flip', 'Big Flip', 6)]);
      expect(tricks.every((t) => t.modifier == null), isTrue);
    });

    test('5. entries keep their components (trick, stance, modifier)', () {
      final tricks =
          gen([rule('kickflip', 'Kickflip', 2, modifiers: ['bs180'])]);
      final plain = byId(tricks, 'switch_kickflip');
      expect(plain.trick, 'kickflip');
      expect(plain.stance, Stance.switchStance);
      expect(plain.modifier, isNull);
      final rotated = byId(tricks, 'fakie_kickflip_bs180');
      expect(rotated.trick, 'kickflip');
      expect(rotated.stance, Stance.fakie);
      expect(rotated.modifier, Modifier.bs180);
    });

    test('6. id is {stance}_{trick}[_{modifier}]', () {
      final tricks =
          gen([rule('pop_shuv', 'Pop Shuv', 1, modifiers: ['revert'])]);
      expect(tricks.map((t) => t.id), [
        'regular_pop_shuv',
        'regular_pop_shuv_revert',
        'fakie_pop_shuv',
        'fakie_pop_shuv_revert',
        'nollie_pop_shuv',
        'nollie_pop_shuv_revert',
        'switch_pop_shuv',
        'switch_pop_shuv_revert',
      ]);
    });
  });

  group('B. Stance / rotation bans (T6a)', () {
    late List<Trick> tricks;
    setUp(() {
      tricks = gen([rule('kickflip', 'Kickflip', 2, modifiers: allRotations)]);
    });

    test('7. bs360 never with switch; fs360 only with switch', () {
      final bs360 = tricks.where((t) => t.modifier == Modifier.bs360);
      final fs360 = tricks.where((t) => t.modifier == Modifier.fs360);
      expect(bs360.map((t) => t.stance),
          [Stance.regular, Stance.fakie, Stance.nollie]);
      expect(fs360.map((t) => t.stance), [Stance.switchStance]);
    });

    test('8. fs180, bs180 and revert are allowed in all four stances', () {
      final withRevert = gen([
        rule('pop_shuv', 'Pop Shuv', 1, modifiers: ['revert']),
      ]);
      for (final m in [Modifier.fs180, Modifier.bs180]) {
        expect(tricks.where((t) => t.modifier == m), hasLength(4),
            reason: m.name);
      }
      expect(withRevert.where((t) => t.modifier == Modifier.revert),
          hasLength(4));
    });

    test('9. at most one modifier: each stance gets 1 + allowed modifiers', () {
      // Regular: plain + fs180 + bs180 + bs360. Switch: plain + fs180 + bs180 + fs360.
      for (final stance in Stance.values) {
        expect(tricks.where((t) => t.stance == stance), hasLength(4),
            reason: stance.name);
      }
      expect(tricks, hasLength(16));
    });
  });

  group('C. Points formula (T3, T4)', () {
    test('10. points = base + stance + modifier', () {
      final tricks = gen([
        rule('ollie', 'Ollie', 1, modifiers: allRotations),
        rule('pop_shuv', 'Pop Shuv', 1, modifiers: ['revert']),
      ]);
      expect(byId(tricks, 'regular_ollie').points, 1);
      expect(byId(tricks, 'fakie_ollie_bs180').points, 1 + 1 + 1);
      expect(byId(tricks, 'nollie_ollie_bs360').points, 1 + 1 + 3);
      expect(byId(tricks, 'switch_ollie_fs360').points, 1 + 2 + 3);
      expect(byId(tricks, 'switch_pop_shuv_revert').points, 1 + 2 + 1);
    });

    test('11. difficulty uses the rules file thresholds', () {
      final library = generateTricks(rulesDoc(
        thresholds: {'intermediate': 3, 'advanced': 4},
        tricks: [rule('kickflip', 'Kickflip', 2)],
      ));
      expect(library.thresholds.intermediate, 3);
      expect(library.thresholds.advanced, 4);
      expect(library.tricks.map((t) => t.difficulty), [
        Difficulty.beginner, // regular: 2
        Difficulty.intermediate, // fakie: 3
        Difficulty.intermediate, // nollie: 3
        Difficulty.advanced, // switch: 4
      ]);
    });
  });

  group('D. Names (T6a)', () {
    test('12. default order is stance · rotation · trick · revert', () {
      final names = namesById(gen([
        rule('kickflip', 'Kickflip', 2, modifiers: allRotations),
        rule('varial_flip', 'Varial Flip', 3, modifiers: ['revert']),
      ]));
      expect(names['nollie_kickflip_bs180'], 'Nollie Backside 180 Kickflip');
      expect(names['switch_kickflip_fs360'], 'Switch Frontside 360 Kickflip');
      expect(names['fakie_varial_flip_revert'], 'Fakie Varial Flip Revert');
    });

    test('13. regular stance adds no prefix', () {
      final names = namesById(gen([
        rule('kickflip', 'Kickflip', 2, modifiers: ['fs180']),
      ]));
      expect(names['regular_kickflip'], 'Kickflip');
      expect(names['regular_kickflip_fs180'], 'Frontside 180 Kickflip');
    });

    test('14. custom name with stance + modifier fully overrides', () {
      final names = namesById(gen([
        rule('kickflip', 'Kickflip', 2, modifiers: allRotations, customNames: [
          {'stance': 'fakie', 'modifier': 'bs180', 'name': 'Halfcab Flip'},
        ]),
      ]));
      expect(names['fakie_kickflip_bs180'], 'Halfcab Flip');
      // Other stances with the same modifier are untouched.
      expect(names['nollie_kickflip_bs180'], 'Nollie Backside 180 Kickflip');
    });

    test('15. custom name with only a modifier keeps the stance prefix', () {
      final names = namesById(gen([
        rule('hardflip', 'Hardflip', 4, modifiers: ['revert'], customNames: [
          {'modifier': 'revert', 'name': 'Ghetto Bird'},
        ]),
      ]));
      expect(names['regular_hardflip_revert'], 'Ghetto Bird');
      expect(names['nollie_hardflip_revert'], 'Nollie Ghetto Bird');
      expect(names['switch_hardflip_revert'], 'Switch Ghetto Bird');
      expect(names['nollie_hardflip'], 'Nollie Hardflip');
    });

    test('16. stance + modifier custom beats modifier-only custom', () {
      final names = namesById(gen([
        rule('ollie', 'Ollie', 1, modifiers: allRotations, customNames: [
          {'modifier': 'bs180', 'name': 'Backside 180'},
          {'stance': 'fakie', 'modifier': 'bs180', 'name': 'Halfcab Ollie'},
        ]),
      ]));
      expect(names['fakie_ollie_bs180'], 'Halfcab Ollie');
      expect(names['regular_ollie_bs180'], 'Backside 180');
      expect(names['nollie_ollie_bs180'], 'Nollie Backside 180');
    });

    test('16b. precedence does not depend on customNames order', () {
      final names = namesById(gen([
        rule('ollie', 'Ollie', 1, modifiers: allRotations, customNames: [
          {'stance': 'fakie', 'modifier': 'bs180', 'name': 'Halfcab Ollie'},
          {'modifier': 'bs180', 'name': 'Backside 180'},
        ]),
      ]));
      expect(names['fakie_ollie_bs180'], 'Halfcab Ollie');
    });

    test('17. stance-only custom applies only to the plain entry', () {
      final names = namesById(gen([
        rule('ollie', 'Ollie', 1, modifiers: allRotations, customNames: [
          {'stance': 'nollie', 'name': 'Nollie'},
          {'modifier': 'fs180', 'name': 'Frontside 180'},
        ]),
      ]));
      expect(names['nollie_ollie'], 'Nollie');
      expect(names['nollie_ollie_fs180'], 'Nollie Frontside 180');
      expect(names['nollie_ollie_bs180'], 'Nollie Backside 180 Ollie');
    });
  });

  group('E. Bad rules throw TrickRulesException', () {
    test('18. trick uses a modifier id that is not defined', () {
      expect(
          () => gen([rule('kickflip', 'Kickflip', 2, modifiers: ['fs540'])]),
          throwsRules);
    });

    test('19. modifier defined in rules but unknown to the app', () {
      final doc = rulesDoc(
        modifiers: [
          ...defaultModifiers,
          {'id': 'fs540', 'type': 'rotation', 'name': 'Frontside 540', 'points': 5, 'stances': allStances},
        ],
        tricks: [rule('kickflip', 'Kickflip', 2, modifiers: ['fs540'])],
      );
      expect(() => generateTricks(doc), throwsRules);
    });

    test('19. stance defined in rules but unknown to the app', () {
      final doc = rulesDoc(
        stances: [
          ...defaultStances,
          {'id': 'mongo', 'name': 'Mongo', 'points': 1},
        ],
        tricks: [rule('kickflip', 'Kickflip', 2)],
      );
      expect(() => generateTricks(doc), throwsRules);
    });

    test('20. unknown stance in a trick\'s "stances"', () {
      expect(
          () => gen([
                rule('kickflip', 'Kickflip', 2, stances: ['regular', 'goofy']),
              ]),
          throwsRules);
    });

    test('20. unknown stance in a custom name', () {
      expect(
          () => gen([
                rule('kickflip', 'Kickflip', 2, customNames: [
                  {'stance': 'goofy', 'name': 'Goofy Flip'},
                ]),
              ]),
          throwsRules);
    });

    test('21. custom name for a modifier the trick does not have', () {
      expect(
          () => gen([
                rule('kickflip', 'Kickflip', 2, modifiers: ['revert'], customNames: [
                  {'modifier': 'fs180', 'name': 'Typo Flip'},
                ]),
              ]),
          throwsRules);
    });

    test('21. custom name for a banned combination (switch + bs360)', () {
      expect(
          () => gen([
                rule('kickflip', 'Kickflip', 2, modifiers: allRotations, customNames: [
                  {'stance': 'switch', 'modifier': 'bs360', 'name': 'Never'},
                ]),
              ]),
          throwsRules);
    });

    test('21b. custom name with neither stance nor modifier', () {
      expect(
          () => gen([
                rule('kickflip', 'Kickflip', 2, customNames: [
                  {'name': 'Just A Name'},
                ]),
              ]),
          throwsRules);
    });

    test('22. duplicate generated id', () {
      expect(
          () => gen([
                rule('kickflip', 'Kickflip', 2),
                rule('kickflip', 'Kickflip Again', 3),
              ]),
          throwsRules);
    });

    test('22. duplicate generated name', () {
      expect(
          () => gen([
                rule('kickflip', 'Kickflip', 2),
                rule('kickflip_2', 'Kickflip', 3),
              ]),
          throwsRules);
    });

    test('23. malformed JSON', () {
      expect(() => generateTricks('{"version": 1, "tricks": ['), throwsRules);
    });

    test('23. thresholds missing', () {
      expect(() => generateTricks(rulesDoc(thresholds: _remove)), throwsRules);
    });

    test('23. thresholds out of order', () {
      expect(
          () => generateTricks(
              rulesDoc(thresholds: {'intermediate': 8, 'advanced': 5})),
          throwsRules);
    });

    test('23. unsupported version', () {
      expect(() => generateTricks(rulesDoc(version: 2)), throwsRules);
    });

    test('23. trick missing points', () {
      expect(
          () => generateTricks(rulesDoc(tricks: [
                {'id': 'kickflip', 'name': 'Kickflip', 'modifiers': <String>[]},
              ])),
          throwsRules);
    });
  });

  group('F. Serialization', () {
    late String json;
    setUp(() {
      json = encodeTricksJson(generateTricks(rulesDoc(tricks: [
        rule('kickflip', 'Kickflip', 2, modifiers: ['fs180']),
      ])));
    });

    test('24. key order and omitted modifier', () {
      final root = jsonDecode(json) as Map<String, dynamic>;
      expect(root.keys, ['version', 'thresholds', 'tricks']);
      final entries = (root['tricks'] as List).cast<Map<String, dynamic>>();
      expect(entries[0].keys, ['id', 'name', 'trick', 'stance', 'points']);
      expect(entries[1].keys,
          ['id', 'name', 'trick', 'stance', 'modifier', 'points']);
    });

    test('24b. 2-space indent, LF only, no trailing newline', () {
      expect(json, startsWith('{\n  "version": 1,\n'));
      expect(json.contains('\r'), isFalse);
      expect(json.endsWith('}'), isTrue);
    });

    test('25. round trip through parseTricks', () {
      final library = generateTricks(rulesDoc(tricks: [
        rule('kickflip', 'Kickflip', 2, modifiers: allRotations),
      ]));
      final parsed = parseTricks(encodeTricksJson(library));
      expect(parsed.errors, isEmpty, reason: parsed.errors.join('\n'));
      String describe(Trick t) =>
          '${t.id}|${t.name}|${t.trick}|${t.stance}|${t.modifier}|'
          '${t.points}|${t.difficulty}';
      expect(parsed.tricks.map(describe), library.tricks.map(describe));
    });
  });

  group('G. Real files', () {
    late TrickLibrary library;
    setUpAll(() {
      library =
          generateTricks(File('data/trick_rules.json').readAsStringSync());
    });

    test('26. golden: output matches committed assets/tricks.json', () {
      final committed = File('assets/tricks.json')
          .readAsStringSync()
          .replaceAll('\r\n', '\n');
      expect(encodeTricksJson(library), committed,
          reason: 'assets/tricks.json is stale — '
              'run `dart run tool/generate_tricks.dart`');
    });

    test('27. every tier has at least 15 tricks (T7)', () {
      for (final tier in Difficulty.values) {
        final count = library.tricks.where((t) => t.difficulty == tier).length;
        expect(count, greaterThanOrEqualTo(15), reason: '$tier has $count');
      }
    });
  });
}
