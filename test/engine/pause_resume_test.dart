// Spec §10 step 5, round 1 — pause, resume, end game (R2, R9, §4b U1, U2,
// U7). Written test-first. Undo (U3–U6) is round 2.

import 'package:flutter_test/flutter_test.dart';
import 'package:match_that/engine/game_state.dart';
import 'package:match_that/engine/turn_based_game.dart';

import '../helpers/game_helpers.dart';

void main() {
  group('pause (U1)', () {
    test('a new game is not paused', () {
      final (_, s) = startGame(config: timed());
      expect(s.paused, isFalse);
    });

    test('pause in the countdown freezes the phase and its time', () {
      final (game, start) = startGame(config: timed());
      final p = game.pause(game.tick(start, secs(1)));

      expect(p.paused, isTrue);
      expect(p.phase, GamePhase.countdown);
      expect(p.phaseRemaining, secs(2));
    });

    test('pause in attempting freezes the trick timer', () {
      final (game, start) = startGame(config: timed());
      final p = game.pause(game.tick(start, secs(13))); // 3 s countdown + 10 s

      expect(p.paused, isTrue);
      expect(p.phase, GamePhase.attempting);
      expect(p.phaseRemaining, secs(50));
      expect(p.currentTrick!.id, 'b0');
    });

    test('pause in a reveal freezes the reveal', () {
      final (game, start) = startGame(config: timed(countdown: Duration.zero));
      final reveal = game.tick(game.landed(start), ms(400));
      final p = game.pause(reveal);

      expect(p.paused, isTrue);
      expect(p.phase, GamePhase.reveal);
      expect(p.phaseRemaining, ms(600));
    });

    test('pause in gameOver is ignored', () {
      final (game, start) = startGame(config: instant(target: 1));
      final over = game.landed(start);
      expect(game.pause(over), same(over));
    });

    test('pausing twice changes nothing', () {
      final (game, start) = startGame(config: timed());
      final p = game.pause(start);
      expect(game.pause(p), same(p));
    });

    test('ticks while paused change nothing, however long', () {
      final (game, start) = startGame(config: timed());
      final p = game.pause(game.tick(start, secs(13)));
      expect(game.tick(p, const Duration(hours: 1)), same(p));
    });

    test('landed and missed are ignored while paused', () {
      final (game, start) = startGame(config: timed(countdown: Duration.zero));
      final p = game.pause(start);

      expect(game.landed(p), same(p));
      expect(game.missed(p), same(p));
    });
  });

  group('resume (U2)', () {
    /// A game paused in attempting with 42.5 s left on b0.
    (TurnBasedGame, GameState) pausedAt42500() {
      final (game, start) = startGame(config: timed());
      final playing = game.tick(start, ms(3000 + 17500));
      expect(playing.phaseRemaining, ms(42500));
      return (game, game.pause(playing));
    }

    test('from attempting: a countdown, then the trick with its time', () {
      final (game, p) = pausedAt42500();

      final resumed = game.resume(p);
      expect(resumed.paused, isFalse);
      expect(resumed.phase, GamePhase.countdown);
      expect(resumed.phaseRemaining, secs(3));

      final almost = game.tick(resumed, ms(2999));
      expect(almost.phase, GamePhase.countdown);
      expect(almost.phaseRemaining, ms(1));

      final back = game.tick(almost, ms(1));
      expect(back.phase, GamePhase.attempting);
      expect(back.phaseRemaining, ms(42500));
      expect(back.currentTrick!.id, 'b0');
      expect(back.currentPlayer.seat, 0);
    });

    test('scores, turn, trick and misses are unchanged by pause/resume', () {
      final (game, start) = startGame(players: 3, config: timed());
      // Countdown, p1 lands b0, b1's reveal, p2 misses b1.
      final landed = game.landed(game.tick(start, secs(3)));
      final attempt = game.missed(game.tick(landed, secs(1)));
      expect(attempt.missCount, 1);
      expect(attempt.currentPlayer.seat, 2);

      final back = game.tick(game.resume(game.pause(attempt)), secs(3));
      expect(summary(back), summary(attempt));
    });

    test(
      'from a reveal: a countdown, the rest of the reveal, a full trick',
      () {
        final (game, start) = startGame(config: timed());
        final reveal = game.tick(
          game.landed(game.tick(start, secs(3))),
          ms(400),
        );
        expect(reveal.phase, GamePhase.reveal);

        final resumed = game.resume(game.pause(reveal));
        expect(resumed.phase, GamePhase.countdown);
        expect(resumed.phaseRemaining, secs(3));

        final restOfReveal = game.tick(resumed, secs(3));
        expect(restOfReveal.phase, GamePhase.reveal);
        expect(restOfReveal.phaseRemaining, ms(600));
        expect(restOfReveal.currentTrick!.id, 'b1');

        final next = game.tick(restOfReveal, ms(600));
        expect(next.phase, GamePhase.attempting);
        expect(next.phaseRemaining, secs(60));
      },
    );

    test('from the game-start countdown: a full countdown, then full time', () {
      final (game, start) = startGame(config: timed());
      final p = game.pause(game.tick(start, secs(2))); // 1 s left

      final resumed = game.resume(p);
      expect(resumed.phase, GamePhase.countdown);
      expect(resumed.phaseRemaining, secs(3)); // full, not the 1 s left

      final playing = game.tick(resumed, secs(3));
      expect(playing.phase, GamePhase.attempting);
      expect(playing.phaseRemaining, secs(60));
    });

    test('paused during a resume countdown: a full countdown, then back to '
        'the originally paused phase and time', () {
      final (game, p) = pausedAt42500();

      final midCountdown = game.tick(game.resume(p), secs(2)); // 1 s left
      final again = game.resume(game.pause(midCountdown));
      expect(again.phase, GamePhase.countdown);
      expect(again.phaseRemaining, secs(3));

      final back = game.tick(again, secs(3));
      expect(back.phase, GamePhase.attempting);
      expect(back.phaseRemaining, ms(42500));
    });

    test('one tick through the resume countdown carries over (G3)', () {
      final (game, p) = pausedAt42500();
      final s = game.tick(game.resume(p), secs(5)); // 3 s countdown + 2 s

      expect(s.phase, GamePhase.attempting);
      expect(s.phaseRemaining, ms(40500));
    });

    test('a resume countdown into a trick that then times out (G3, G7)', () {
      final (game, p) = pausedAt42500();
      final s = game.tick(game.resume(p), ms(3000 + 42500 + 250));

      expect(s.lastOutcome, timedOut('b0'));
      expect(s.phase, GamePhase.reveal);
      expect(s.phaseRemaining, ms(750));
      expect(s.currentTrick!.id, 'b1');
    });

    test('with a 0 countdown, resume goes straight back', () {
      final (game, start) = startGame(config: timed(countdown: Duration.zero));

      final playing = game.tick(start, secs(10));
      final back = game.resume(game.pause(playing));
      expect(back.paused, isFalse);
      expect(back.phase, GamePhase.attempting);
      expect(back.phaseRemaining, secs(50));

      final reveal = game.tick(game.landed(back), ms(400));
      final backToReveal = game.resume(game.pause(reveal));
      expect(backToReveal.phase, GamePhase.reveal);
      expect(backToReveal.phaseRemaining, ms(600));
    });

    test('resume when not paused is ignored', () {
      final (game, start) = startGame(config: timed());
      expect(game.resume(start), same(start));

      final playing = game.tick(start, secs(3));
      expect(game.resume(playing), same(playing));

      final (game2, start2) = startGame(config: instant(target: 1));
      final over = game2.landed(start2);
      expect(game2.resume(over), same(over));
    });
  });

  group('end game (U7, R9)', () {
    test('while paused: gameOver, ended by players, scores kept', () {
      final (game, start) = startGame(players: 3);
      final s = game.pause(game.landed(start)); // p1 +3, p2 attempting b1

      final over = game.endGame(s);
      expect(over.phase, GamePhase.gameOver);
      expect(over.endReason, GameEndReason.endedByPlayers);
      expect(over.paused, isFalse);
      expect(over.phaseRemaining, Duration.zero);
      expect(over.scores, {'p1': 3, 'p2': 0, 'p3': 0});
      expect(over.landedCount, 1);
      expect(ids(over.winners), ['p1']);
    });

    test('a tie goes to sudden death instead of gameOver (S1)', () {
      final (game, start) = startGame(library: [trick('x', 2), trick('y', 2)]);
      final s = game.landed(game.landed(start)); // p1 +2, p2 +2

      final tied = game.endGame(game.pause(s));
      expect(tied.phase, isNot(GamePhase.gameOver));
      expect(tied.endReason, isNull);
      expect(ids(tied.winners), ['p1', 'p2']);
    });

    // A pause in the game-start countdown is always 0–0, a tie: see
    // sudden_death_test.dart.
    test('works from a pause in a reveal', () {
      final (game, start) = startGame(config: timed());
      final reveal = game.landed(game.tick(start, secs(3)));
      expect(reveal.phase, GamePhase.reveal);
      expect(
        game.endGame(game.pause(reveal)).endReason,
        GameEndReason.endedByPlayers,
      );
    });

    test('works from a pause during a resume countdown', () {
      final (game, start) = startGame(config: timed());
      // p1 +3 (so no tie), then 5 s into p2's trick.
      final playing = game.tick(
        game.landed(game.tick(start, secs(3))),
        secs(6),
      );
      final resuming = game.resume(game.pause(playing));

      final over = game.endGame(game.pause(resuming));
      expect(over.phase, GamePhase.gameOver);
      expect(over.endReason, GameEndReason.endedByPlayers);
    });

    test('ignored when not paused (it is a pause-menu action)', () {
      final (game, start) = startGame(config: timed());
      expect(game.endGame(start), same(start));

      final playing = game.tick(start, secs(3));
      expect(game.endGame(playing), same(playing));
    });

    test('ignored in gameOver', () {
      final (game, start) = startGame(config: instant(target: 1));
      final over = game.landed(start);
      expect(game.endGame(over), same(over));
    });

    test('after End game, ticks, taps, pause and resume change nothing', () {
      final (game, start) = startGame();
      final over = game.endGame(game.pause(game.landed(start))); // p1 leads

      expect(game.tick(over, secs(10)), same(over));
      expect(game.landed(over), same(over));
      expect(game.missed(over), same(over));
      expect(game.pause(over), same(over));
      expect(game.resume(over), same(over));
    });
  });

  group('immutability (G11)', () {
    test('pause, resume and endGame leave the previous state untouched', () {
      final (game, start) = startGame(config: timed());
      final playing = game.tick(start, secs(13));
      final before = summary(playing);

      final p = game.pause(playing);
      expect(playing.paused, isFalse);
      expect(summary(playing), before);

      final pBefore = summary(p);
      game.resume(p);
      game.endGame(p);
      expect(p.paused, isTrue);
      expect(summary(p), pBefore);
    });
  });
}
