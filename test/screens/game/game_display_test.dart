// Spec §10 step 8b — Game screen display logic (§4a G3, G8; §3 S4; §7 D4).
// Written test-first.
//
// These are the Game screen's decisions that don't need widgets: how time is
// shown, what the reveal says, and when a part of the screen needs to
// rebuild (`buildWhen`). Plain `test`s over real engine states.

import 'package:flutter_test/flutter_test.dart';
import 'package:match_that/engine/game_state.dart';
import 'package:match_that/screens/game/game_display.dart';

import '../../helpers/game_helpers.dart';

void main() {
  group('secondsUp (G3: rounded up to whole seconds)', () {
    test('0 shows 0', () => expect(secondsUp(Duration.zero), 0));
    test('1 ms shows 1', () => expect(secondsUp(ms(1)), 1));
    test('0.1 s shows 1', () => expect(secondsUp(ms(100)), 1));
    test('exactly 1 s shows 1', () => expect(secondsUp(ms(1000)), 1));
    test('1.001 s shows 2', () => expect(secondsUp(ms(1001)), 2));
    test('59.9 s shows 60', () => expect(secondsUp(ms(59900)), 60));
    test('60 s shows 60', () => expect(secondsUp(secs(60)), 60));
    test('negative shows 0', () => expect(secondsUp(ms(-5)), 0));
  });

  group('barStep (0–100, rounded up like the seconds)', () {
    test('full time is 100', () => expect(barStep(secs(60), secs(60)), 100));
    test('no time is 0', () => expect(barStep(Duration.zero, secs(60)), 0));
    test('half is 50', () => expect(barStep(secs(30), secs(60)), 50));
    test('59.95 of 60 s is still 100', () {
      expect(barStep(ms(59950), secs(60)), 100);
    });
    test('59.4 of 60 s is 99', () => expect(barStep(ms(59400), secs(60)), 99));
    test('never above 100 or below 0', () {
      expect(barStep(secs(61), secs(60)), 100);
      expect(barStep(ms(-1), secs(60)), 0);
    });
  });

  group(
    'timerChanged (D4: rebuild the timer only when it looks different)',
    () {
      final (game, start) = startGame(config: timed());
      final playing = toPlay(game, start); // attempting, 60 s left
      final trickTime = secs(60);

      test('a 50 ms tick at 60 s changes nothing visible', () {
        final next = game.tick(playing, ms(50));
        expect(timerChanged(playing, next, trickTime), isFalse);
      });

      test('crossing a whole second (59.05 → 58.95 s) rebuilds', () {
        final a = game.tick(playing, ms(950)); // 59.05 s
        final b = game.tick(a, ms(100)); // 58.95 s
        expect(timerChanged(a, b, trickTime), isTrue);
      });

      test('a new bar step in the same second (59.5 → 59.3 s) rebuilds', () {
        final a = game.tick(playing, ms(500)); // 59.5 s: step 100
        final b = game.tick(a, ms(200)); // 59.3 s: step 99, still "60"
        expect(timerChanged(a, b, trickTime), isTrue);
      });
    },
  );

  group('screenChanged (D4: the rest of the screen ignores clock ticks)', () {
    final config = timed();
    final (game, start) = startGame(config: config); // countdown, 3 s
    final playing = toPlay(game, start);

    test('a tick while attempting does not rebuild', () {
      expect(
        screenChanged(playing, game.tick(playing, ms(100)), config),
        isFalse,
      );
    });

    test('a call rebuilds', () {
      expect(screenChanged(playing, game.missed(playing), config), isTrue);
      expect(screenChanged(playing, game.landed(playing), config), isTrue);
    });

    test('pause and resume rebuild', () {
      final paused = game.pause(playing);
      expect(screenChanged(playing, paused, config), isTrue);
      expect(screenChanged(paused, game.resume(paused), config), isTrue);
    });

    test('a phase change rebuilds (countdown → attempting)', () {
      expect(screenChanged(start, playing, config), isTrue);
    });

    test('countdown: same digit does not rebuild, a new digit does', () {
      final a = game.tick(start, ms(400)); // 2.6 s: shows 3
      expect(screenChanged(start, a, config), isFalse);
      final b = game.tick(a, ms(200)); // 2.4 s: shows 3
      expect(screenChanged(a, b, config), isFalse);
      final c = game.tick(start, ms(1100)); // 1.9 s: shows 2
      expect(screenChanged(start, c, config), isTrue);
    });

    test(
      'reveal: rebuilds once, when it switches from outcome to NEW TRICK',
      () {
        final reveal = game.landed(playing); // reveal, 1 s left
        final early = game.tick(reveal, ms(300)); // 0.7 s: outcome
        final late = game.tick(early, ms(300)); // 0.4 s: NEW TRICK
        expect(screenChanged(reveal, early, config), isFalse);
        expect(screenChanged(early, late, config), isTrue);
      },
    );
  });

  group('revealShowsOutcome (first half of the reveal)', () {
    final config = timed(); // reveal 1 s
    final (game, start) = startGame(config: config);
    final reveal = game.landed(toPlay(game, start)); // 1000 ms left

    test('true from 1000 ms down to 501 ms left', () {
      expect(revealShowsOutcome(reveal, config.reveal), isTrue);
      expect(
        revealShowsOutcome(game.tick(reveal, ms(499)), config.reveal),
        isTrue,
      );
    });

    test('false from 500 ms left: NEW TRICK', () {
      expect(
        revealShowsOutcome(game.tick(reveal, ms(500)), config.reveal),
        isFalse,
      );
      expect(
        revealShowsOutcome(game.tick(reveal, ms(999)), config.reveal),
        isFalse,
      );
    });

    test('false outside the reveal', () {
      expect(revealShowsOutcome(start, config.reveal), isFalse);
    });
  });

  group('outcomeText (G8, S4)', () {
    final players = makePlayers(3); // P1, P2, P3 (ids p1…p3)
    final t = trick('t0', 3);

    test('landed: +points and the name, upper-case', () {
      expect(
        outcomeText(
          LandedBy(t, playerId: 'p2', points: 3),
          players,
          suddenDeath: false,
        ),
        '+3 P2',
      );
    });

    test("timed out: TIME'S UP", () {
      expect(
        outcomeText(TimedOut(t), players, suddenDeath: false),
        "TIME'S UP",
      );
    });

    test('missed out: MISSED OUT', () {
      expect(
        outcomeText(MissedOut(t), players, suddenDeath: false),
        'MISSED OUT',
      );
    });

    test(
      'sudden death, everyone missed: NOBODY LANDED (nobody is out, S4)',
      () {
        expect(
          outcomeText(MissedOut(t), players, suddenDeath: true),
          'NOBODY LANDED',
        );
      },
    );

    test('sudden death, everyone landed: NOBODY OUT', () {
      expect(
        outcomeText(RoundEnded(t, outIds: []), players, suddenDeath: true),
        'NOBODY OUT',
      );
    });

    test('sudden death, one out: P2 IS OUT', () {
      expect(
        outcomeText(RoundEnded(t, outIds: ['p2']), players, suddenDeath: true),
        'P2 IS OUT',
      );
    });

    test('sudden death, two out: P1 & P3 ARE OUT', () {
      expect(
        outcomeText(
          RoundEnded(t, outIds: ['p1', 'p3']),
          players,
          suddenDeath: true,
        ),
        'P1 & P3 ARE OUT',
      );
    });

    test('sudden death, three out: P1, P2 & P3 ARE OUT', () {
      expect(
        outcomeText(
          RoundEnded(t, outIds: ['p1', 'p2', 'p3']),
          players,
          suddenDeath: true,
        ),
        'P1, P2 & P3 ARE OUT',
      );
    });
  });
}
