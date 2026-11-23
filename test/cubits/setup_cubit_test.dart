// Spec §10 step 7, round 1 — SetupCubit (§4c A4; P1, P3, P3a).
// Written test-first.
//
// blocTest builds a Cubit, runs `act` on it, and checks the exact list of
// states it emitted (the initial state is not in that list). `expect: () => []`
// therefore means "nothing was emitted".

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_that/cubits/setup_cubit.dart';
import 'package:match_that/engine/game_config.dart';
import 'package:match_that/engine/players.dart';
import 'package:match_that/engine/trick.dart';

/// Matches a [SetupState] whose raw names are [names].
Matcher hasNames(List<String> names) =>
    isA<SetupState>().having((s) => s.names, 'names', names);

/// A setup with [n] seats; seat i has the name [names] gives it, else blank.
SetupState withSeats(int n, [Map<int, String> names = const {}]) =>
    SetupState(names: [for (var i = 0; i < n; i++) names[i] ?? '']);

void main() {
  group('defaults (A4)', () {
    test('2 players, blank names, Quickplay, Beginner, turn-based', () {
      final s = SetupCubit().state;

      expect(s.mode, GameMode.turnBased);
      expect(s.playerCount, 2);
      expect(s.names, ['', '']);
      expect(s.length, GameLength.quickplay);
      expect(s.difficulty, Difficulty.beginner);
    });

    test('blank names are valid: players are "Player 1" and "Player 2"', () {
      final s = SetupCubit().state;

      expect(s.nameErrors, isEmpty);
      expect(s.canStart, isTrue);
      expect([for (final p in s.players!) p.name], ['Player 1', 'Player 2']);
    });

    test('config follows length and difficulty', () {
      final config = SetupCubit().state.config;

      expect(config.target, 10);
      expect(config.weights.toString(), 'DrawWeights(80/20/0)');
    });

    test('can add a player, cannot remove one (P1: 2–8)', () {
      final s = SetupCubit().state;

      expect(s.canAddPlayer, isTrue);
      expect(s.canRemovePlayer, isFalse);
    });
  });

  group('player count stepper (A4)', () {
    blocTest<SetupCubit, SetupState>(
      'addPlayer adds a blank seat and keeps the names',
      build: () => SetupCubit(withSeats(2, {0: 'Alex', 1: 'Sam'})),
      act: (c) => c.addPlayer(),
      expect: () => [
        hasNames(['Alex', 'Sam', '']),
      ],
    );

    blocTest<SetupCubit, SetupState>(
      'removePlayer drops the last seat',
      build: () => SetupCubit(withSeats(3, {0: 'Alex', 1: 'Sam', 2: 'Kim'})),
      act: (c) => c.removePlayer(),
      expect: () => [
        hasNames(['Alex', 'Sam']),
      ],
    );

    blocTest<SetupCubit, SetupState>(
      'addPlayer at 8 players does nothing',
      build: () => SetupCubit(withSeats(8)),
      act: (c) => c.addPlayer(),
      expect: () => [],
    );

    blocTest<SetupCubit, SetupState>(
      'removePlayer at 2 players does nothing',
      build: () => SetupCubit(),
      act: (c) => c.removePlayer(),
      expect: () => [],
    );

    test('canAddPlayer is false at 8, canRemovePlayer true', () {
      final s = withSeats(8);

      expect(s.canAddPlayer, isFalse);
      expect(s.canRemovePlayer, isTrue);
    });
  });

  group('names (P3a via buildPlayers)', () {
    blocTest<SetupCubit, SetupState>(
      'setName stores the raw text, untrimmed',
      build: () => SetupCubit(),
      act: (c) => c.setName(1, '  Sam '),
      expect: () => [
        hasNames(['', '  Sam ']),
      ],
      verify: (c) => expect(c.state.players![1].name, 'Sam'),
    );

    blocTest<SetupCubit, SetupState>(
      'setting the same text again does nothing',
      build: () => SetupCubit(withSeats(2, {0: 'Alex'})),
      act: (c) => c.setName(0, 'Alex'),
      expect: () => [],
    );

    test('a 13-character name is an error on its seat only', () {
      final s = withSeats(2, {1: 'ABCDEFGHIJKLM'});

      expect(s.errorsFor(0), isEmpty);
      expect(s.errorsFor(1), [
        isA<NameTooLong>().having((e) => e.length, 'length', 13),
      ]);
      expect(s.canStart, isFalse);
      expect(s.players, isNull);
    });

    test('a name equal to another seat\'s default is a duplicate on both', () {
      final s = withSeats(2, {0: 'player 2'});

      expect(s.errorsFor(0), [isA<DuplicateName>()]);
      expect(s.errorsFor(1), [isA<DuplicateName>()]);
      expect(s.nameErrors, hasLength(2));
      expect(s.canStart, isFalse);
    });

    blocTest<SetupCubit, SetupState>(
      'removing the seat that held the duplicate clears the error',
      build: () => SetupCubit(withSeats(3, {0: 'Kim', 2: 'kim'})),
      act: (c) => c.removePlayer(),
      verify: (c) {
        expect(c.state.nameErrors, isEmpty);
        expect(c.state.canStart, isTrue);
      },
    );

    blocTest<SetupCubit, SetupState>(
      'fixing the name makes the setup startable again',
      build: () => SetupCubit(withSeats(2, {0: 'Sam', 1: 'sam'})),
      act: (c) => c.setName(1, 'Kim'),
      verify: (c) => expect(c.state.canStart, isTrue),
    );
  });

  group('length and difficulty', () {
    blocTest<SetupCubit, SetupState>(
      'setLength(full) sets a target of 30',
      build: () => SetupCubit(),
      act: (c) => c.setLength(GameLength.full),
      expect: () => [
        isA<SetupState>().having((s) => s.length, 'length', GameLength.full),
      ],
      verify: (c) => expect(c.state.config.target, 30),
    );

    blocTest<SetupCubit, SetupState>(
      'setDifficulty(advanced) uses the Advanced weights',
      build: () => SetupCubit(),
      act: (c) => c.setDifficulty(Difficulty.advanced),
      expect: () => [
        isA<SetupState>().having(
          (s) => s.difficulty,
          'difficulty',
          Difficulty.advanced,
        ),
      ],
      verify: (c) => expect(
        c.state.config.weights.toString(),
        'DrawWeights(10/30/60)',
      ),
    );

    blocTest<SetupCubit, SetupState>(
      'setting the same length does nothing',
      build: () => SetupCubit(),
      act: (c) => c.setLength(GameLength.quickplay),
      expect: () => [],
    );

    blocTest<SetupCubit, SetupState>(
      'setting the same difficulty does nothing',
      build: () => SetupCubit(),
      act: (c) => c.setDifficulty(Difficulty.beginner),
      expect: () => [],
    );

    blocTest<SetupCubit, SetupState>(
      'changing them keeps the names',
      build: () => SetupCubit(withSeats(2, {0: 'Alex'})),
      act: (c) => c
        ..setLength(GameLength.full)
        ..setDifficulty(Difficulty.intermediate),
      verify: (c) => expect(c.state.names, ['Alex', '']),
    );
  });

  group('starting from a saved setup (step 10)', () {
    test('SetupCubit(state) starts from that state', () {
      final saved = SetupState(
        names: ['Alex', 'Sam', 'Kim'],
        length: GameLength.full,
        difficulty: Difficulty.intermediate,
      );
      final s = SetupCubit(saved).state;

      expect(s.names, ['Alex', 'Sam', 'Kim']);
      expect(s.length, GameLength.full);
      expect(s.difficulty, Difficulty.intermediate);
    });

    test('a setup outside the mode\'s limits throws (a bug, not input)', () {
      expect(() => withSeats(1), throwsArgumentError);
      expect(() => withSeats(9), throwsArgumentError);
    });
  });
}
