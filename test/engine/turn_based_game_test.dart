// Spec §10 step 4 — trick lifecycle, Default mode (R1, R5–R8, §4a G1–G11).
// Written test-first. Round 1: countdown and reveal are 0, no ticks.
// Round 2: tick — phases, the trick timer, expiry, leftover time, ignored
// input, and a whole scripted game.

import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:match_that/engine/draw_weights.dart';
import 'package:match_that/engine/game_config.dart';
import 'package:match_that/engine/game_state.dart';
import 'package:match_that/engine/trick.dart';
import 'package:match_that/engine/trick_parser.dart';
import 'package:match_that/engine/turn_based_game.dart';

import '../helpers/fake_random.dart';
import '../helpers/game_helpers.dart';

void main() {
  // -------------------------------------------------------------------------
  // Round 1
  // -------------------------------------------------------------------------

  group('start', () {
    test('random first player, zero scores, first trick drawn, attempting', () {
      // Random: nextInt(4) = seat 2, then nextInt(1) tier, nextInt(3) trick.
      final (_, s) = startGame(players: 4, random: FakeRandom([2, 0, 0]));

      expect(s.phase, GamePhase.attempting); // countdown 0 is skipped
      expect(s.currentPlayer.seat, 2);
      expect(s.upNext.seat, 3);
      expect(s.scores, {'p1': 0, 'p2': 0, 'p3': 0, 'p4': 0});
      expect(s.landedCount, 0);
      expect(s.missCount, 0);
      expect(s.currentTrick!.id, 'b0');
      expect(s.phaseRemaining, const Duration(seconds: 60));
      expect(s.lastOutcome, isNull);
      expect(s.endReason, isNull);
    });

    test('throws for a player count outside Default mode limits (P1)', () {
      final game = TurnBasedGame(
        config: instant(),
        library: library3,
        random: ZeroRandom(),
      );
      expect(() => game.start(makePlayers(1)), throwsArgumentError);
      expect(() => game.start(makePlayers(9)), throwsArgumentError);
    });

    test('nothing drawable at start ends the game (G9, T11)', () {
      final (_, s) = startGame(
        config: instant(
          weights: DrawWeights(beginner: 0, intermediate: 0, advanced: 1),
        ),
      );
      expect(s.phase, GamePhase.gameOver);
      expect(s.endReason, GameEndReason.noDrawableTricks);
      expect(s.currentTrick, isNull);
    });
  });

  group('landed (R6, R7, G5)', () {
    test('awards points to the current player and moves to the next trick', () {
      final (game, start) = startGame(players: 3);
      final s = game.landed(start);

      expect(s.scores, {'p1': 3, 'p2': 0, 'p3': 0});
      expect(s.landedCount, 1);
      expect(s.currentPlayer.seat, 1);
      expect(s.currentTrick!.id, 'b1');
      expect(s.missCount, 0);
      expect(s.phase, GamePhase.attempting);
      expect(s.lastOutcome, landedBy('b0', 'p1', 3));
    });

    test(
      'after a miss, the lander scores and the player after them is next',
      () {
        final (game, start) = startGame(players: 3);
        final s = game.landed(game.missed(start)); // p1 misses, p2 lands

        expect(s.scores, {'p1': 0, 'p2': 3, 'p3': 0});
        expect(s.currentPlayer.seat, 2);
        expect(s.missCount, 0);
      },
    );

    test('a landed trick is not discarded and comes back (T11)', () {
      final (game, start) = startGame(library: [trick('only', 4)]);
      final s = game.landed(start);

      expect(s.bags.discardedIds, isEmpty);
      expect(s.currentTrick!.id, 'only');
    });
  });

  group('missed (R1, R5, G6)', () {
    test('a miss advances the turn and keeps the same trick', () {
      final (game, start) = startGame(players: 2);
      final s = game.missed(start);

      expect(s.missCount, 1);
      expect(s.currentPlayer.seat, 1);
      expect(s.currentTrick!.id, 'b0');
      expect(s.scores, {'p1': 0, 'p2': 0});
      expect(s.phase, GamePhase.attempting);
      expect(s.lastOutcome, isNull);
    });

    test('2 players: the 4th miss discards the trick (miss out)', () {
      final (game, start) = startGame(players: 2);

      final three = times(3, start, game.missed);
      expect(three.currentTrick!.id, 'b0');
      expect(three.missCount, 3);
      expect(three.currentPlayer.seat, 1);

      final four = game.missed(three);
      expect(four.currentTrick!.id, 'b1');
      expect(four.missCount, 0);
      expect(four.bags.discardedIds, {'b0'});
      expect(four.lastOutcome, missedOut('b0'));
      expect(four.currentPlayer.seat, 0); // next in order after seat 1 (R7)
      expect(four.phase, GamePhase.attempting);
    });

    test('3 players: the limit is 6 misses, not 4', () {
      final (game, start) = startGame(players: 3);
      expect(start.missLimit, 6);

      final five = times(5, start, game.missed);
      expect(five.currentTrick!.id, 'b0');
      expect(five.missCount, 5);

      final six = game.missed(five);
      expect(six.currentTrick!.id, 'b1');
      expect(six.lastOutcome, missedOut('b0'));
    });

    test(
      'a missed-out trick never comes back, even after reshuffles (T10)',
      () {
        final (game, start) = startGame(
          library: [trick('a', 1), trick('b', 2)],
          config: instant(target: 100),
        );
        var s = times(4, start, game.missed); // miss out 'a'
        for (var i = 0; i < 5; i++) {
          expect(s.currentTrick!.id, 'b');
          s = game.landed(s);
        }
      },
    );

    test('missed-out tricks do not count toward the target (R8)', () {
      final (game, start) = startGame(config: instant(target: 1));
      final s = times(4, start, game.missed);

      expect(s.landedCount, 0);
      expect(s.phase, GamePhase.attempting);
    });
  });

  group('game over (R8, G5, G9)', () {
    test('reaching the target ends the game without a new draw', () {
      final (game, start) = startGame(config: instant(target: 2));
      final one = game.landed(start);
      final over = game.landed(one);

      expect(over.phase, GamePhase.gameOver);
      expect(over.endReason, GameEndReason.targetReached);
      expect(over.landedCount, 2);
      expect(over.scores, {'p1': 3, 'p2': 5});
      expect(over.lastOutcome, landedBy('b1', 'p2', 5));
      expect(over.bags, same(one.bags)); // nothing drawn
    });

    test('missing out the last drawable trick ends the game', () {
      final (game, start) = startGame(library: [trick('only', 4)]);
      final s = times(4, start, game.missed);

      expect(s.phase, GamePhase.gameOver);
      expect(s.endReason, GameEndReason.noDrawableTricks);
      expect(s.lastOutcome, missedOut('only'));
      expect(s.currentTrick, isNull);
    });
  });

  group('winners (G10)', () {
    test('a single leader wins', () {
      final (game, start) = startGame(players: 3, config: instant(target: 1));
      final over = game.landed(start);
      expect(over.phase, GamePhase.gameOver);
      expect(ids(over.winners), ['p1']);
    });

    test('a tie lists every tied player, in seat order, and goes to sudden '
        'death instead of gameOver (S1)', () {
      // 3 players, seat 2 starts: p3 lands 2, then p1 lands 2. The last two
      // values are sudden death's first draw.
      final (game, start) = startGame(
        players: 3,
        library: [trick('x', 2), trick('y', 2)],
        config: instant(target: 2),
        random: FakeRandom([2, 0, 0, 0, 0, 0, 0]),
      );
      final tied = game.landed(game.landed(start));

      expect(tied.phase, isNot(GamePhase.gameOver));
      expect(tied.endReason, isNull);
      expect(tied.scores, {'p1': 2, 'p2': 0, 'p3': 2});
      expect(ids(tied.winners), ['p1', 'p3']);
    });

    test('with no points scored, everyone is tied', () {
      final (_, s) = startGame(
        players: 3,
        config: instant(
          weights: DrawWeights(beginner: 0, intermediate: 0, advanced: 1),
        ),
      );
      expect(ids(s.winners), ['p1', 'p2', 'p3']);
    });
  });

  group('immutability (G11)', () {
    test('inputs leave the previous state untouched', () {
      final (game, start) = startGame();
      game.landed(start);
      game.missed(start);

      expect(start.scores, {'p1': 0, 'p2': 0});
      expect(start.landedCount, 0);
      expect(start.missCount, 0);
      expect(start.currentTrick!.id, 'b0');
      expect(start.turnOrder.current, 0);
    });

    test('players and scores are read-only', () {
      final (_, s) = startGame();
      expect(() => s.scores['p1'] = 99, throwsUnsupportedError);
      expect(() => s.players.removeLast(), throwsUnsupportedError);
    });
  });

  group('GameConfig (G1)', () {
    test('rejects invalid values', () {
      GameConfig make({
        int target = 10,
        Duration trickTime = const Duration(seconds: 60),
        Duration countdown = Duration.zero,
        Duration reveal = Duration.zero,
      }) => GameConfig(
        target: target,
        weights: onlyBeginner,
        trickTime: trickTime,
        countdown: countdown,
        reveal: reveal,
      );

      expect(() => make(target: 0), throwsArgumentError);
      expect(() => make(trickTime: Duration.zero), throwsArgumentError);
      expect(
        () => make(countdown: const Duration(milliseconds: -1)),
        throwsArgumentError,
      );
      expect(
        () => make(reveal: const Duration(milliseconds: -1)),
        throwsArgumentError,
      );
      expect(make, returnsNormally); // 0 countdown and reveal are allowed
    });

    test('forSetup uses the spec defaults', () {
      expect(GameLength.quickplay.target, 10);
      expect(GameLength.full.target, 30);

      final c = GameConfig.forSetup(Difficulty.intermediate, GameLength.full);
      expect(c.target, 30);
      expect(c.trickTime, const Duration(seconds: 60));
      expect(c.countdown, const Duration(seconds: 3));
      expect(c.reveal, const Duration(seconds: 1));
      expect(
        [c.weights.beginner, c.weights.intermediate, c.weights.advanced],
        [20, 60, 20],
      );
    });
  });

  // -------------------------------------------------------------------------
  // Round 2
  // -------------------------------------------------------------------------

  group('countdown and phases (G2, G3)', () {
    test('start is in countdown with config.countdown left', () {
      final (_, s) = startGame(config: timed());

      expect(s.phase, GamePhase.countdown);
      expect(s.phaseRemaining, secs(3));
      expect(s.currentTrick!.id, 'b0'); // drawn already, hidden by the UI
    });

    test('ticks reduce the countdown; the trick timer has not started', () {
      final (game, start) = startGame(config: timed());

      final s = game.tick(start, ms(2999));
      expect(s.phase, GamePhase.countdown);
      expect(s.phaseRemaining, ms(1));

      final playing = game.tick(s, ms(1));
      expect(playing.phase, GamePhase.attempting);
      expect(playing.phaseRemaining, secs(60)); // full time, nothing used
    });

    test('many small ticks add up like one big one', () {
      final (game, start) = startGame(config: timed());
      final s = times(3, start, (s) => game.tick(s, secs(1)));

      expect(s.phase, GamePhase.attempting);
      expect(s.phaseRemaining, secs(60));
    });

    test('a tick that brings a phase to exactly 0 ends it', () {
      final (game, start) = startGame(config: timed());

      // Countdown: 3 s → 0 → attempting.
      final playing = game.tick(start, secs(3));
      expect(playing.phase, GamePhase.attempting);

      // Reveal: 1 s → 0 → attempting.
      final reveal = game.landed(playing);
      expect(reveal.phase, GamePhase.reveal);
      final next = game.tick(reveal, secs(1));
      expect(next.phase, GamePhase.attempting);
      expect(next.phaseRemaining, secs(60));

      // Trick timer: 60 s → 0 → expired.
      expect(game.tick(next, secs(60)).lastOutcome, timedOut('b1'));
    });
  });

  group('trick timer (§4, G6, G7)', () {
    test('ticks in attempting reduce the time left', () {
      final (game, start) = startGame(config: timed(countdown: Duration.zero));

      final s = game.tick(start, secs(1));
      expect(s.phase, GamePhase.attempting);
      expect(s.phaseRemaining, secs(59));
      expect(game.tick(s, ms(250)).phaseRemaining, ms(58750));
    });

    test('a miss does not reset the clock', () {
      final (game, start) = startGame(config: timed(countdown: Duration.zero));

      final s = game.missed(game.tick(start, secs(10)));
      expect(s.phaseRemaining, secs(50));
      expect(s.missCount, 1);
      expect(s.currentTrick!.id, 'b0');
      expect(game.tick(s, secs(5)).phaseRemaining, secs(45));
    });

    test(
      'after a landing and its reveal, the new trick gets the full time',
      () {
        final (game, start) = startGame(
          config: timed(countdown: Duration.zero),
        );

        final reveal = game.landed(game.tick(start, secs(20)));
        expect(reveal.phase, GamePhase.reveal);
        expect(reveal.phaseRemaining, secs(1));
        expect(reveal.currentTrick!.id, 'b1');
        expect(reveal.currentPlayer.seat, 1); // reveal is in the next color

        final s = game.tick(reveal, secs(1));
        expect(s.phase, GamePhase.attempting);
        expect(s.phaseRemaining, secs(60));
      },
    );

    test(
      'expiry: TimedOut, discarded, misses reset, turn advances, reveal',
      () {
        final (game, start) = startGame(
          players: 3,
          config: timed(countdown: Duration.zero),
        );
        final afterMiss = game.missed(start); // p1 misses → p2's turn, 1 miss

        final s = game.tick(afterMiss, secs(60));
        expect(s.lastOutcome, timedOut('b0'));
        expect(s.bags.discardedIds, {'b0'});
        expect(s.missCount, 0);
        expect(s.currentPlayer.seat, 2); // advances from p2, whose turn it was
        expect(s.phase, GamePhase.reveal);
        expect(s.phaseRemaining, secs(1));
        expect(s.currentTrick!.id, 'b1');
        expect(s.scores, {'p1': 0, 'p2': 0, 'p3': 0});
        expect(s.landedCount, 0);
      },
    );

    test('expiry with a 0 reveal goes straight to the next trick', () {
      final (game, start) = startGame(); // instant config
      final s = game.tick(start, secs(60));

      expect(s.lastOutcome, timedOut('b0'));
      expect(s.phase, GamePhase.attempting);
      expect(s.phaseRemaining, secs(60));
      expect(s.currentTrick!.id, 'b1');
      expect(s.currentPlayer.seat, 1);
    });

    test('expiry when nothing is drawable ends the game (G9)', () {
      final (game, start) = startGame(library: [trick('only', 4)]);
      final s = game.tick(start, secs(60));

      expect(s.phase, GamePhase.gameOver);
      expect(s.endReason, GameEndReason.noDrawableTricks);
      expect(s.lastOutcome, timedOut('only'));
      expect(s.currentTrick, isNull);
    });
  });

  group('leftover time carries over (G3)', () {
    test('countdown: a 3.5 s tick leaves 59.5 s on the trick', () {
      final (game, start) = startGame(config: timed());
      final s = game.tick(start, ms(3500));

      expect(s.phase, GamePhase.attempting);
      expect(s.phaseRemaining, ms(59500));
    });

    test('reveal: a 1.5 s tick during a 1 s reveal leaves 59.5 s', () {
      final (game, start) = startGame(config: timed(countdown: Duration.zero));
      final s = game.tick(game.landed(start), ms(1500));

      expect(s.phase, GamePhase.attempting);
      expect(s.phaseRemaining, ms(59500));
      expect(s.currentTrick!.id, 'b1');
    });

    test('one long tick: end of a reveal, a full timeout, the next reveal', () {
      final (game, start) = startGame(
        players: 3,
        config: timed(countdown: Duration.zero),
      );
      final reveal = game.landed(start); // p1 lands b0; reveal of b1 for p2

      // 1 s reveal + 60 s for b1 (times out) + 0.5 s of b2's reveal.
      final s = game.tick(reveal, ms(61500));
      expect(s.phase, GamePhase.reveal);
      expect(s.phaseRemaining, ms(500));
      expect(s.lastOutcome, timedOut('b1'));
      expect(s.bags.discardedIds, {'b1'});
      expect(s.currentTrick!.id, 'b2');
      expect(s.currentPlayer.seat, 2);
      expect(s.scores, {'p1': 3, 'p2': 0, 'p3': 0});
    });

    test(
      'one long tick gives the same state as the same time in small ticks',
      () {
        final (game, start) = startGame(
          players: 3,
          config: timed(countdown: Duration.zero),
        );
        final reveal = game.landed(start);

        final once = game.tick(reveal, ms(61500));
        final split = times(123, reveal, (s) => game.tick(s, ms(500)));
        expect(summary(split), summary(once));
      },
    );

    test(
      'a 1-hour tick ends in gameOver once tricks run out',
      () {
        final (game, start) = startGame(config: timed());
        final s = game.tick(start, const Duration(hours: 1));

        expect(s.phase, GamePhase.gameOver);
        expect(s.endReason, GameEndReason.noDrawableTricks);
        expect(s.bags.discardedIds, {'b0', 'b1', 'b2'});
        expect(s.lastOutcome, timedOut('b2'));
        expect(s.landedCount, 0);
      },
      timeout: const Timeout(Duration(seconds: 5)), // fails, not hangs
    );

    test('a 1-hour tick with 0 countdown and 0 reveal also ends', () {
      final (game, start) = startGame(); // instant config
      final s = game.tick(start, const Duration(hours: 1));

      expect(s.phase, GamePhase.gameOver);
      expect(s.bags.discardedIds, {'b0', 'b1', 'b2'});
    }, timeout: const Timeout(Duration(seconds: 5)));
  });

  group('ignored input (G4)', () {
    test('landed and missed are ignored during the countdown', () {
      final (game, s) = startGame(config: timed());
      expect(game.landed(s), same(s));
      expect(game.missed(s), same(s));
    });

    test('landed and missed are ignored during a reveal', () {
      final (game, start) = startGame(config: timed(countdown: Duration.zero));
      final s = game.landed(start);
      expect(s.phase, GamePhase.reveal);

      expect(game.landed(s), same(s));
      expect(game.missed(s), same(s));
    });

    test('landed and missed are ignored after a tick expired the trick', () {
      final (game, start) = startGame(config: timed(countdown: Duration.zero));
      final s = game.tick(start, secs(60));
      expect(s.lastOutcome, timedOut('b0'));

      expect(game.landed(s), same(s));
      expect(game.missed(s), same(s));
    });

    test('landed and missed are ignored in gameOver', () {
      final (game, start) = startGame(config: instant(target: 1));
      final s = game.landed(start);
      expect(s.phase, GamePhase.gameOver);

      expect(game.landed(s), same(s));
      expect(game.missed(s), same(s));
    });

    test('ticks in gameOver change nothing', () {
      final (game, start) = startGame(config: instant(target: 1));
      final s = game.landed(start);
      expect(game.tick(s, secs(10)), same(s));
    });

    test('a negative elapsed throws', () {
      final (game, s) = startGame(config: timed());
      expect(() => game.tick(s, ms(-1)), throwsArgumentError);
    });

    test('a zero elapsed changes nothing', () {
      final (game, countdown) = startGame(config: timed());
      expect(game.tick(countdown, Duration.zero), same(countdown));

      final playing = game.tick(countdown, secs(3));
      expect(game.tick(playing, Duration.zero), same(playing));
    });
  });

  group('outcome and immutability (G8, G11)', () {
    test('during a reveal, lastOutcome says how the previous trick ended', () {
      final (game, start) = startGame(config: timed(countdown: Duration.zero));

      final landed = game.landed(start);
      expect(landed.phase, GamePhase.reveal);
      expect(landed.lastOutcome, landedBy('b0', 'p1', 3));

      final timeout = game.tick(landed, secs(61)); // reveal, then b1 expires
      expect(timeout.phase, GamePhase.reveal);
      expect(timeout.lastOutcome, timedOut('b1'));

      final playing = game.tick(timeout, secs(1));
      final missOut = times(4, playing, game.missed);
      expect(missOut.phase, GamePhase.reveal);
      expect(missOut.lastOutcome, missedOut('b2'));
    });

    test('lastOutcome is kept while the next trick is attempted', () {
      final (game, start) = startGame(config: timed(countdown: Duration.zero));
      final s = game.tick(game.landed(start), secs(1));

      expect(s.phase, GamePhase.attempting);
      expect(s.lastOutcome, landedBy('b0', 'p1', 3));
    });

    test('tick leaves the previous state unchanged', () {
      final (game, start) = startGame(config: timed());
      final before = summary(start);
      game.tick(start, secs(3)); // ends the countdown
      expect(summary(start), before);

      final playing = game.tick(start, secs(3));
      final beforePlaying = summary(playing);
      game.tick(playing, secs(60)); // expires the trick
      expect(summary(playing), beforePlaying);
    });
  });

  group('whole game: scripted Quickplay', () {
    final realLibrary = parseTricks(
      File('assets/tricks.json').readAsStringSync(),
    ).tricks;

    /// Plays a full Quickplay game (real defaults and real library) with a
    /// fixed script, repeated until gameOver. Returns the final state and
    /// every outcome, in order.
    (GameState, List<TrickOutcome>) play(int seed) {
      final game = TurnBasedGame(
        config: GameConfig.forSetup(
          Difficulty.intermediate,
          GameLength.quickplay,
        ),
        library: realLibrary,
        random: Random(seed),
      );
      // Each pass: end the countdown/reveal, a miss then a landing, a
      // miss-out (4 misses with 2 players), then a full timeout.
      final script = <GameState Function(GameState)>[
        (s) => game.tick(s, secs(3)),
        game.missed,
        game.landed,
        (s) => game.tick(s, secs(1)),
        game.missed,
        game.missed,
        game.missed,
        game.missed,
        (s) => game.tick(s, secs(1)),
        (s) => game.tick(s, secs(60)),
      ];

      var s = game.start(makePlayers(2));
      final outcomes = <TrickOutcome>[];
      for (var step = 0; s.phase != GamePhase.gameOver; step++) {
        if (step > 10000) fail('the game never ended');
        final before = s.lastOutcome;
        s = script[step % script.length](s);
        final after = s.lastOutcome;
        if (after != null && !identical(after, before)) outcomes.add(after);
      }
      return (s, outcomes);
    }

    test('reaches the target with every kind of outcome', () {
      final (end, outcomes) = play(2026);

      expect(end.endReason, GameEndReason.targetReached);
      expect(end.landedCount, 10);
      expect(outcomes.whereType<LandedBy>(), hasLength(10));
      expect(outcomes.whereType<MissedOut>(), hasLength(9));
      expect(outcomes.whereType<TimedOut>(), hasLength(9));
      expect(end.bags.discardedIds, hasLength(18));

      final pointsLanded = outcomes.whereType<LandedBy>().fold(
        0,
        (sum, o) => sum + o.points,
      );
      expect(end.scores.values.fold(0, (a, b) => a + b), pointsLanded);
    });

    test('the same seed and script give the same game', () {
      final (endA, outcomesA) = play(2026);
      final (endB, outcomesB) = play(2026);

      expect(summary(endB), summary(endA));
      expect(
        [for (final o in outcomesB) o.toString()],
        [for (final o in outcomesA) o.toString()],
      );
    });
  });
}
