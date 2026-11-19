// Spec §10 step 3 — players (P1, P2, P3, P3a, P3b, P5). Written test-first.

import 'package:flutter_test/flutter_test.dart';
import 'package:match_that/engine/players.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// The players, or fails the test if the names were rejected.
List<Player> playersOf(PlayerSetupResult result) => switch (result) {
  PlayersReady(:final players) => players,
  InvalidNames(:final errors) => fail('expected players, got errors $errors'),
};

/// The errors, or fails the test if the names were accepted.
List<NameError> errorsOf(PlayerSetupResult result) => switch (result) {
  InvalidNames(:final errors) => errors,
  PlayersReady(:final players) => fail('expected errors, got $players'),
};

Matcher duplicate(int seat, List<int> otherSeats) => isA<DuplicateName>()
    .having((e) => e.seat, 'seat', seat)
    .having((e) => e.otherSeats, 'otherSeats', otherSeats);

Matcher tooLong(int seat, int length) => isA<NameTooLong>()
    .having((e) => e.seat, 'seat', seat)
    .having((e) => e.length, 'length', length);

List<String> namesOf(List<Player> players) => [for (final p in players) p.name];

const twelve = 'abcdefghijkl'; // 12 characters
const thirteen = 'abcdefghijklm'; // 13 characters

void main() {
  group('P1: GameMode player limits', () {
    test('turn-based allows 2–8 players', () {
      expect(GameMode.turnBased.minPlayers, 2);
      expect(GameMode.turnBased.maxPlayers, 8);
      expect(GameMode.turnBased.allows(1), isFalse);
      expect(GameMode.turnBased.allows(2), isTrue);
      expect(GameMode.turnBased.allows(8), isTrue);
      expect(GameMode.turnBased.allows(9), isFalse);
    });

    test('rush allows 2–4 players', () {
      expect(GameMode.rush.minPlayers, 2);
      expect(GameMode.rush.maxPlayers, 4);
      expect(GameMode.rush.allows(1), isFalse);
      expect(GameMode.rush.allows(4), isTrue);
      expect(GameMode.rush.allows(5), isFalse);
    });
  });

  group('P3b: PlayerColor palette', () {
    test('has exactly 8 colors', () {
      expect(PlayerColor.values, hasLength(8));
    });

    test('forSeat maps seat 0 to color1 and seat 7 to color8', () {
      expect(PlayerColor.forSeat(0), PlayerColor.color1);
      expect(PlayerColor.forSeat(7), PlayerColor.color8);
    });

    test('forSeat outside 0..7 throws ArgumentError', () {
      expect(() => PlayerColor.forSeat(-1), throwsArgumentError);
      expect(() => PlayerColor.forSeat(8), throwsArgumentError);
    });
  });

  group('P3 / P3a: names', () {
    test('defaultPlayerName is 1-based', () {
      expect(defaultPlayerName(0), 'Player 1');
      expect(defaultPlayerName(7), 'Player 8');
    });

    test('all-blank names become Player 1…N', () {
      final players = playersOf(buildPlayers(GameMode.turnBased, ['', '', '']));
      expect(namesOf(players), ['Player 1', 'Player 2', 'Player 3']);
    });

    test('names are trimmed', () {
      final players = playersOf(
        buildPlayers(GameMode.turnBased, ['  Ana  ', 'Bo']),
      );
      expect(namesOf(players), ['Ana', 'Bo']);
    });

    test('a whitespace-only name becomes that seat\'s default', () {
      final players = playersOf(
        buildPlayers(GameMode.turnBased, ['Ana', '   ']),
      );
      expect(namesOf(players), ['Ana', 'Player 2']);
    });
  });

  group('P3b / P5: seats, colors, ids', () {
    test('seats are 0…N-1 and colors follow the seat', () {
      final players = playersOf(buildPlayers(GameMode.turnBased, ['', '', '']));
      expect([for (final p in players) p.seat], [0, 1, 2]);
      expect(
        [for (final p in players) p.color],
        [PlayerColor.color1, PlayerColor.color2, PlayerColor.color3],
      );
    });

    test('ids are unique and do not depend on the name', () {
      final a = playersOf(buildPlayers(GameMode.turnBased, ['Ana', 'Bo']));
      final b = playersOf(buildPlayers(GameMode.turnBased, ['', 'Zed']));
      expect([for (final p in a) p.id], ['p1', 'p2']);
      expect([for (final p in b) p.id], ['p1', 'p2']);
    });
  });

  group('P3a: max 12 characters', () {
    test('12 characters is accepted', () {
      final players = playersOf(buildPlayers(GameMode.turnBased, [twelve, '']));
      expect(players.first.name, twelve);
    });

    test('13 characters is NameTooLong', () {
      expect(errorsOf(buildPlayers(GameMode.turnBased, ['', thirteen])), [
        tooLong(1, 13),
      ]);
    });

    test('length is measured after trimming', () {
      final players = playersOf(
        buildPlayers(GameMode.turnBased, ['   $twelve   ', '']),
      );
      expect(players.first.name, twelve);
    });

    test('characters are counted as code points (emoji count as 1)', () {
      final ok = '👍' * maxNameLength;
      expect(
        playersOf(buildPlayers(GameMode.turnBased, [ok, ''])).first.name,
        ok,
      );
      expect(errorsOf(buildPlayers(GameMode.turnBased, ['$ok👍', ''])), [
        tooLong(0, 13),
      ]);
    });
  });

  group('P3a: duplicates are blocked', () {
    test('an exact duplicate flags both seats', () {
      expect(errorsOf(buildPlayers(GameMode.turnBased, ['Ana', 'Bo', 'Ana'])), [
        duplicate(0, [2]),
        duplicate(2, [0]),
      ]);
    });

    test('comparison is case-insensitive', () {
      expect(errorsOf(buildPlayers(GameMode.turnBased, ['ana', 'ANA'])), [
        duplicate(0, [1]),
        duplicate(1, [0]),
      ]);
    });

    test('comparison is after trimming', () {
      expect(errorsOf(buildPlayers(GameMode.turnBased, [' Ana', 'Ana '])), [
        duplicate(0, [1]),
        duplicate(1, [0]),
      ]);
    });

    test('a typed name equal to another seat\'s default clashes', () {
      expect(errorsOf(buildPlayers(GameMode.turnBased, ['player 2', ''])), [
        duplicate(0, [1]),
        duplicate(1, [0]),
      ]);
    });

    test('typing your own seat\'s default is fine', () {
      final players = playersOf(
        buildPlayers(GameMode.turnBased, ['Player 1', '']),
      );
      expect(namesOf(players), ['Player 1', 'Player 2']);
    });

    test('a three-way clash lists both other seats for each', () {
      expect(
        errorsOf(buildPlayers(GameMode.turnBased, ['Ana', 'ana', 'Bo', 'ANA'])),
        [
          duplicate(0, [1, 3]),
          duplicate(1, [0, 3]),
          duplicate(3, [0, 1]),
        ],
      );
    });
  });

  test('all errors are reported at once, sorted by seat', () {
    expect(
      errorsOf(buildPlayers(GameMode.turnBased, ['Ana', thirteen, 'ana'])),
      [
        duplicate(0, [2]),
        tooLong(1, 13),
        duplicate(2, [0]),
      ],
    );
  });

  group('P1 / P2: player count follows the mode', () {
    test('wrong counts throw ArgumentError', () {
      expect(() => buildPlayers(GameMode.turnBased, ['']), throwsArgumentError);
      expect(
        () => buildPlayers(GameMode.turnBased, List.filled(9, '')),
        throwsArgumentError,
      );
      expect(
        () => buildPlayers(GameMode.rush, List.filled(5, '')),
        throwsArgumentError,
      );
    });

    test('the largest valid counts are ready', () {
      expect(
        playersOf(buildPlayers(GameMode.turnBased, List.filled(8, ''))),
        hasLength(8),
      );
      expect(
        playersOf(buildPlayers(GameMode.rush, List.filled(4, ''))),
        hasLength(4),
      );
    });
  });

  test('PlayersReady.players cannot be modified', () {
    final players = playersOf(buildPlayers(GameMode.turnBased, ['', '']));
    expect(() => players.removeLast(), throwsUnsupportedError);
  });
}
