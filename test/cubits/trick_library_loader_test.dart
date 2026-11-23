// Spec §10 step 7, round 1 — trick library loading (§4c A3).
// Written test-first.
//
// The loader reads tricks.json once at app start. Any parse error is a bug
// in the data, so it fails the whole load (the app shows an error screen)
// instead of starting a game with part of the library. It never throws.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_that/cubits/trick_library_loader.dart';
import 'package:match_that/engine/trick_parser.dart';

/// A tricks.json with the given entries.
String file(List<Object?> tricks) => jsonEncode({
  'version': 1,
  'thresholds': {'intermediate': 5, 'advanced': 8},
  'tricks': tricks,
});

Map<String, Object?> entry(String id, int points) => {
  'id': id,
  'name': id,
  'trick': id,
  'stance': 'regular',
  'points': points,
};

/// A reader that returns [source], like rootBundle would.
Future<String> Function() reads(String source) =>
    () async => source;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a valid file loads every trick, in file order', () async {
    final result = await loadTrickLibrary(
      read: reads(file([entry('ollie', 1), entry('kickflip', 3)])),
    );

    expect(result, isA<TrickLibraryLoaded>());
    final tricks = (result as TrickLibraryLoaded).tricks;
    expect([for (final t in tricks) t.id], ['ollie', 'kickflip']);
  });

  test('one bad entry among good ones fails the whole load (A3)', () async {
    final result = await loadTrickLibrary(
      read: reads(file([entry('ollie', 1), entry('broken', 0)])),
    );

    expect(result, isA<TrickLibraryFailed>());
    final errors = (result as TrickLibraryFailed).errors;
    expect(errors, hasLength(1));
    expect(errors.single, contains('broken'));
    expect(errors.single, contains('"points" must be at least 1'));
  });

  test('invalid JSON fails', () async {
    final result = await loadTrickLibrary(read: reads('{not json'));

    expect(result, isA<TrickLibraryFailed>());
    expect((result as TrickLibraryFailed).errors.single, contains('JSON'));
  });

  test('a file with no tricks fails: no game could be played', () async {
    final result = await loadTrickLibrary(read: reads(file([])));

    expect(result, isA<TrickLibraryFailed>());
    expect((result as TrickLibraryFailed).errors.single, contains('no tricks'));
  });

  test('a reader that throws fails with its message, never throws', () async {
    final result = await loadTrickLibrary(
      read: () async => throw FlutterError('Unable to load asset'),
    );

    expect(result, isA<TrickLibraryFailed>());
    expect(
      (result as TrickLibraryFailed).errors.single,
      contains('Unable to load asset'),
    );
  });

  test('by default it loads the bundled assets/tricks.json', () async {
    final result = await loadTrickLibrary();

    expect(result, isA<TrickLibraryLoaded>());
    final tricks = (result as TrickLibraryLoaded).tricks;
    expect(tricks, isNotEmpty);

    // Same as parsing the file directly; the exact contents are guarded by
    // the generator's golden test.
    final source = await rootBundle.loadString('assets/tricks.json');
    expect(tricks, hasLength(parseTricks(source).tricks.length));
  });
}
