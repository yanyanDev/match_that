// Spec §10 step 6, round 1 — sudden death: trigger, rounds, elimination,
// rotation and running out of tricks (§3 S1–S6, S9). Written test-first.
//
// Who is still in = turnOrder.seats (a subset TurnOrder, P5). Who has called
// this round = suddenDeath.landed ∪ suddenDeath.missed. Who started the
// round = suddenDeath.roundStarter.
//
// All games use ZeroRandom: seat 0 starts and tricks come out in library
// order (t0, t1, …).

import 'package:flutter_test/flutter_test.dart';
import 'package:match_that/engine/game_state.dart';

import '../helpers/game_helpers.dart';

void main() {
  group('S1: trigger', () {
    test('a tie at the target starts sudden death instead of gameOver', () {
      final (_, sd) = tiedGame();

      expect(sd.phase, isNot(GamePhase.gameOver));
      expect(sd.endReason, isNull);
      expect(sd.inSuddenDeath, isTrue);
      expect(ids(sd.remainingPlayers), ['p1', 'p2']);
      expect(sd.suddenDeath!.roundStarter, 0);
      expect(sd.suddenDeath!.landed, isEmpty);
      expect(sd.suddenDeath!.missed, isEmpty);
      expect(sd.scores, {'p1': 1, 'p2': 1}); // kept as they were
      expect(sd.landedCount, 2);
      expect(sd.currentTrick!.id, 't2'); // drawn from the game's bags (S5)
    });

    test('only the tied players are in', () {
      // 3 players: p1 and p2 land, p3 never scores.
      final (game, start) = startGame(
        players: 3,
        library: equalLibrary(6),
        config: instant(target: 2),
      );
      final sd = play(game, start, 'LL');

      expect(sd.inSuddenDeath, isTrue);
      expect(sd.turnOrder.seats, [0, 1]);
      expect(ids(sd.remainingPlayers), ['p1', 'p2']);
    });

    test('End game with a tie starts sudden death with a fresh trick, not '
        'paused, undo cleared', () {
      final (game, start) = startGame(library: equalLibrary(6));
      final s = play(game, start, 'LL'); // 1–1, target 10; p1 on t2
      expect(s.currentTrick!.id, 't2');

      final sd = game.endGame(game.pause(s));
      expect(sd.inSuddenDeath, isTrue);
      expect(sd.endReason, isNull);
      expect(sd.paused, isFalse);
      expect(sd.canUndo, isFalse);
      expect(sd.beforeLastCall, isNull); // End game clears the undo (U4)
      expect(ids(sd.remainingPlayers), ['p1', 'p2']);
      expect(sd.currentTrick!.id, 't3'); // fresh trick
      expect(sd.bags.discardedIds, isEmpty); // t2 is not discarded
    });

    test('End game at 0–0 starts sudden death among everyone', () {
      final (game, start) = startGame(players: 3, library: equalLibrary(6));

      final sd = game.endGame(game.pause(start));
      expect(sd.inSuddenDeath, isTrue);
      expect(ids(sd.remainingPlayers), ['p1', 'p2', 'p3']);
    });

    test('nothing drawable during normal play with a tie: shared win, no '
        'sudden death (G9)', () {
      final (game, start) = startGame(library: [trick('only', 1)]);
      final over = play(game, start, 'MMMM'); // miss-out, nothing left

      expect(over.phase, GamePhase.gameOver);
      expect(over.endReason, GameEndReason.noDrawableTricks);
      expect(over.suddenDeath, isNull);
      expect(ids(over.winners), ['p1', 'p2']);
    });
  });

  group('S2: countdown, then a reveal before each later round', () {
    final timedTie = timed(target: 2);

    test('sudden death starts with the countdown; taps are ignored in it', () {
      final (game, sd) = tiedGame(config: timedTie);

      expect(sd.phase, GamePhase.countdown);
      expect(sd.phaseRemaining, secs(3));
      expect(sd.resumeTo, isNull);
      expect(game.landed(sd), same(sd));
      expect(game.missed(sd), same(sd));

      final playing = game.tick(sd, secs(3));
      expect(playing.phase, GamePhase.attempting);
      expect(playing.phaseRemaining, Duration.zero); // no timer (S3)
    });

    test('with a 0 countdown it goes straight to attempting', () {
      final (_, sd) = tiedGame();
      expect(sd.phase, GamePhase.attempting);
      expect(sd.phaseRemaining, Duration.zero);
    });

    test("round 2's trick gets the reveal", () {
      final (game, sd) = tiedGame(config: timedTie);
      final round2 = play(game, sd, 'LL'); // both land: nobody out

      expect(round2.phase, GamePhase.reveal);
      expect(round2.phaseRemaining, secs(1));
      expect(round2.currentTrick!.id, 't3');

      final playing = game.tick(round2, secs(1));
      expect(playing.phase, GamePhase.attempting);
      expect(playing.phaseRemaining, Duration.zero);
    });
  });

  group('S3: one call each, same trick, no timer, no miss limit', () {
    test('ticks in attempting change nothing', () {
      final (game, sd) = tiedGame();

      final later = game.tick(sd, const Duration(minutes: 10));
      expect(later, same(sd));
      expect(later.trickClock, sd.trickClock);
    });

    test('a landing keeps the same trick and passes the turn, no reveal, no '
        'points', () {
      final (game, sd) = tiedGame();
      final s = game.landed(sd);

      expect(s.phase, GamePhase.attempting);
      expect(s.currentTrick!.id, 't2');
      expect(s.currentPlayer.id, 'p2');
      expect(s.suddenDeath!.landed, {0});
      expect(s.suddenDeath!.missed, isEmpty);
      expect(s.suddenDeath!.roundStarter, 0);
      expect(s.scores, {'p1': 1, 'p2': 1});
      expect(s.landedCount, 2);
    });

    test('a miss keeps the same trick and passes the turn', () {
      final (game, sd) = tiedGame();
      final s = game.missed(sd);

      expect(s.currentTrick!.id, 't2');
      expect(s.currentPlayer.id, 'p2');
      expect(s.suddenDeath!.missed, {0});
      expect(s.missCount, 0);
    });

    test('the miss limit never applies: rounds of misses only end at the '
        'round end', () {
      final (game, sd) = tiedGame();
      // Normal play's limit would be 2 × 2 = 4 misses.
      final s = play(game, sd, 'MMMMMM'); // three rounds, nobody out

      expect(s.missCount, 0);
      expect(s.inSuddenDeath, isTrue);
      expect(s.bags.discardedIds, {'t2', 't3', 't4'});
      expect(s.currentTrick!.id, 't5');
    });
  });

  group('S4: end of a round', () {
    test('one lands, one misses: the lander wins on scores that still tie', () {
      final (game, sd) = tiedGame();
      final over = play(game, sd, 'LM');

      expect(over.phase, GamePhase.gameOver);
      expect(over.endReason, GameEndReason.suddenDeathWon);
      expect(over.phaseRemaining, Duration.zero);
      expect(over.inSuddenDeath, isFalse);
      expect(over.scores, {'p1': 1, 'p2': 1});
      expect(ids(over.winners), ['p1']);
    });

    test('a miss then a landing: the second player wins', () {
      final (game, sd) = tiedGame();
      final over = play(game, sd, 'ML');

      expect(over.endReason, GameEndReason.suddenDeathWon);
      expect(ids(over.winners), ['p2']);
    });

    test('nobody landed: nobody is out, the trick is discarded (T10)', () {
      final (game, sd) = tiedGame();
      final s = play(game, sd, 'MM');

      expect(s.inSuddenDeath, isTrue);
      expect(ids(s.remainingPlayers), ['p1', 'p2']);
      expect(s.lastOutcome, missedOut('t2'));
      expect(s.bags.discardedIds, {'t2'});
      expect(s.currentTrick!.id, 't3');
      expect(s.suddenDeath!.landed, isEmpty);
      expect(s.suddenDeath!.missed, isEmpty);
    });

    test('everyone landed: nobody is out, the trick is not discarded', () {
      final (game, sd) = tiedGame();
      final s = play(game, sd, 'LL');

      expect(ids(s.remainingPlayers), ['p1', 'p2']);
      expect(s.lastOutcome, roundEnded('t2', []));
      expect(s.bags.discardedIds, isEmpty);
      expect(s.currentTrick!.id, 't3');
      expect(s.suddenDeath!.landed, isEmpty);
    });

    test('3 players: two land, one misses → round 2 with the two', () {
      final (game, sd) = allTied(3);
      final s = play(game, sd, 'LML'); // p1 L, p2 M, p3 L

      expect(s.inSuddenDeath, isTrue);
      expect(s.turnOrder.seats, [0, 2]);
      expect(ids(s.remainingPlayers), ['p1', 'p3']);
      expect(s.lastOutcome, roundEnded('t3', ['p2'])); // t0–t2 drawn before
      expect(s.scores, {'p1': 1, 'p2': 1, 'p3': 1});
    });

    test('the winner of a 3-player sudden death is decided in round 2', () {
      final (game, sd) = allTied(3);
      final over = play(
        game,
        sd,
        'LML'
        'LM',
      ); // round 2: p3 L, p1 M

      expect(over.endReason, GameEndReason.suddenDeathWon);
      expect(ids(over.winners), ['p3']);
    });
  });

  group('S6: who starts', () {
    test('round 1 after a deciding landing: the first tied player after the '
        'lander; the lander goes last', () {
      // 3 players: p1 M, p2 M, p3 L, p1 L → p1 and p3 tie on 1.
      final (game, start) = startGame(
        players: 3,
        library: equalLibrary(6),
        config: instant(target: 2),
      );
      final sd = play(game, start, 'MMLL');

      expect(sd.turnOrder.seats, [0, 2]);
      expect(sd.currentPlayer.id, 'p3');
      expect(sd.suddenDeath!.roundStarter, 2);
      expect(game.missed(sd).currentPlayer.id, 'p1');
    });

    test('round 1 after End game: the current player starts if tied', () {
      // p1 misses: p2's turn, everyone on 0.
      final (game, start) = startGame(players: 3, library: equalLibrary(6));
      final sd = game.endGame(game.pause(play(game, start, 'M')));

      expect(sd.currentPlayer.id, 'p2');
      expect(sd.suddenDeath!.roundStarter, 1);
    });

    test('round 1 after End game: otherwise the next tied player after the '
        'current one', () {
      // p1 M, p2 L, p3 L: p1's turn, but only p2 and p3 are tied on 1.
      final (game, start) = startGame(players: 3, library: equalLibrary(6));
      final sd = game.endGame(game.pause(play(game, start, 'MLL')));

      expect(sd.turnOrder.seats, [1, 2]);
      expect(sd.currentPlayer.id, 'p2');
    });

    test('each later round starts with the next remaining player after the '
        'previous starter, wrapping', () {
      final (game, sd) = tiedGame(); // p1 starts round 1
      final round2 = play(game, sd, 'LL');
      expect(round2.currentPlayer.id, 'p2');
      expect(round2.suddenDeath!.roundStarter, 1);

      final round3 = play(game, round2, 'LL');
      expect(round3.currentPlayer.id, 'p1');
      expect(round3.suddenDeath!.roundStarter, 0);
    });

    test('a knocked-out starter is skipped, and so are other knocked-out '
        'players', () {
      // 4-way tie, p1 starts: p1 M, p2 M, p3 L, p4 L.
      final (game, sd) = allTied(4);
      expect(sd.currentPlayer.id, 'p1');
      final round2 = play(game, sd, 'MMLL');

      expect(round2.turnOrder.seats, [2, 3]);
      expect(round2.currentPlayer.id, 'p3');
      expect(round2.suddenDeath!.roundStarter, 2);
    });
  });

  group('S9: nothing drawable during sudden death', () {
    test('gameOver with a shared win among the players still in', () {
      // 3-way tie on t0–t2; sudden death draws t0.
      final (game, sd) = allTied(3, tricks: 3);
      expect(sd.currentTrick!.id, 't0');
      // Round 1: p1 L, p2 L, p3 M → p3 out, t1 drawn. Then three rounds of
      // misses discard t1, t2 and t0, and nothing is left.
      final over = play(
        game,
        sd,
        'LLM'
        'MM'
        'MM'
        'MM',
      );

      expect(over.phase, GamePhase.gameOver);
      expect(over.endReason, GameEndReason.noDrawableTricks);
      expect(over.currentTrick, isNull);
      expect(over.lastOutcome, missedOut('t0'));
      expect(ids(over.winners), ['p1', 'p2']);
      expect(over.canUndo, isFalse);
    });
  });
}
