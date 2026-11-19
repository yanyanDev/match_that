// Spec §10 step 2 — Trick bags (T8, T9, T9a, T9b, T10, T11). Written test-first.

import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:match_that/engine/draw_weights.dart';
import 'package:match_that/engine/trick.dart';
import 'package:match_that/engine/trick_bags.dart';
import 'package:match_that/engine/trick_parser.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Trick trick(String id, Difficulty tier) => Trick(
  id: id,
  name: id,
  trick: id,
  stance: Stance.regular,
  modifier: null,
  points: 1,
  difficulty: tier,
);

/// [n] tricks in one tier, ids `<prefix>0`, `<prefix>1`, …
List<Trick> tier(String prefix, int n, Difficulty difficulty) => [
  for (var i = 0; i < n; i++) trick('$prefix$i', difficulty),
];

final onlyBeginner = DrawWeights(beginner: 1, intermediate: 0, advanced: 0);

/// A `Random` that returns scripted `nextInt` values, in order.
///
/// The bags call `nextInt(totalAvailableWeight)` for the tier roll, then
/// `nextInt(candidateCount)` for the trick.
class FakeRandom implements Random {
  FakeRandom(this._ints);

  final List<int> _ints;
  int _next = 0;

  @override
  int nextInt(int max) {
    final value = _ints[_next++];
    if (value >= max) {
      throw StateError('scripted $value is out of range for nextInt($max)');
    }
    return value;
  }

  @override
  double nextDouble() => throw UnimplementedError();

  @override
  bool nextBool() => throw UnimplementedError();
}

/// Draws once and fails the test unless a trick came back.
Drawn drawOk(TrickBags bags, DrawWeights weights, Random random) {
  final result = bags.draw(weights, random);
  if (result is! Drawn) fail('expected a trick, got $result');
  return result;
}

/// Draws [n] times, threading the new state through. Returns the tricks drawn
/// and the final state.
(List<Trick>, TrickBags) drawMany(
  TrickBags bags,
  DrawWeights weights,
  Random random,
  int n,
) {
  final drawn = <Trick>[];
  var state = bags;
  for (var i = 0; i < n; i++) {
    final result = drawOk(state, weights, random);
    drawn.add(result.trick);
    state = result.bags;
  }
  return (drawn, state);
}

List<String> ids(Iterable<Trick> tricks) => [for (final t in tricks) t.id];

void main() {
  final beginners = tier('b', 20, Difficulty.beginner);
  final intermediates = tier('i', 20, Difficulty.intermediate);
  final advanceds = tier('a', 20, Difficulty.advanced);
  final fullLibrary = [...beginners, ...intermediates, ...advanceds];

  group('construction', () {
    test('duplicate ids throw ArgumentError', () {
      expect(
        () => TrickBags([
          trick('x', Difficulty.beginner),
          trick('x', Difficulty.advanced),
        ]),
        throwsArgumentError,
      );
    });

    test('a fresh state has every trick in its bag and nothing discarded', () {
      final bags = TrickBags(fullLibrary);
      for (final d in Difficulty.values) {
        expect(bags.remainingInBag(d), 20);
        expect(bags.drawableCount(d), 20);
      }
      expect(bags.discardedIds, isEmpty);
      expect(bags.lastDrawnId, isNull);
    });
  });

  group('T8: weighted tier roll', () {
    final library = [
      trick('b0', Difficulty.beginner),
      trick('i0', Difficulty.intermediate),
      trick('a0', Difficulty.advanced),
    ];
    final weights = DrawWeights(beginner: 80, intermediate: 20, advanced: 0);

    test('roll 79 of 100 picks beginner', () {
      final result = drawOk(TrickBags(library), weights, FakeRandom([79, 0]));
      expect(result.trick.difficulty, Difficulty.beginner);
    });

    test('roll 80 of 100 picks intermediate', () {
      final result = drawOk(TrickBags(library), weights, FakeRandom([80, 0]));
      expect(result.trick.difficulty, Difficulty.intermediate);
    });

    test('80/20/0 over 10,000 draws is about 80% beginner, never advanced', () {
      final (drawn, _) = drawMany(
        TrickBags(fullLibrary),
        weights,
        Random(42),
        10000,
      );
      final beginnerShare =
          drawn.where((t) => t.difficulty == Difficulty.beginner).length /
          drawn.length;
      expect(beginnerShare, inInclusiveRange(0.77, 0.83));
      expect(drawn.where((t) => t.difficulty == Difficulty.advanced), isEmpty);
    });
  });

  group('T9: one shuffle bag per tier', () {
    final ten = tier('b', 10, Difficulty.beginner);

    test('N draws from a tier of N return each trick exactly once', () {
      final (drawn, after) = drawMany(
        TrickBags(ten),
        onlyBeginner,
        Random(1),
        10,
      );
      expect(ids(drawn).toSet(), ids(ten).toSet());
      expect(after.remainingInBag(Difficulty.beginner), 0);
    });

    test('after a reshuffle the next N draws are again the whole tier', () {
      final (drawn, _) = drawMany(TrickBags(ten), onlyBeginner, Random(1), 20);
      expect(ids(drawn.sublist(10)).toSet(), ids(ten).toSet());
    });

    test('same seed gives the same order', () {
      final (a, _) = drawMany(TrickBags(ten), onlyBeginner, Random(5), 10);
      final (b, _) = drawMany(TrickBags(ten), onlyBeginner, Random(5), 10);
      expect(ids(a), ids(b));
    });

    test('different seeds give different orders (it really shuffles)', () {
      final (a, _) = drawMany(TrickBags(ten), onlyBeginner, Random(1), 10);
      final (b, _) = drawMany(TrickBags(ten), onlyBeginner, Random(2), 10);
      expect(ids(a), isNot(ids(b)));
    });
  });

  group('T9a: no repeat across a reshuffle', () {
    test('tier of 3, seeds 0–199: first draw after reshuffle differs', () {
      final three = tier('b', 3, Difficulty.beginner);
      for (var seed = 0; seed < 200; seed++) {
        final (drawn, _) = drawMany(
          TrickBags(three),
          onlyBeginner,
          Random(seed),
          30,
        );
        for (var i = 3; i < drawn.length; i += 3) {
          expect(
            drawn[i].id,
            isNot(drawn[i - 1].id),
            reason: 'seed $seed, draw $i',
          );
        }
      }
    });

    test('tier of 2 strictly alternates', () {
      final (drawn, _) = drawMany(
        TrickBags(tier('b', 2, Difficulty.beginner)),
        onlyBeginner,
        Random(3),
        20,
      );
      for (var i = 1; i < drawn.length; i++) {
        expect(drawn[i].id, isNot(drawn[i - 1].id), reason: 'draw $i');
      }
    });

    test('exception: the only trick left in a tier may repeat', () {
      final two = tier('b', 2, Difficulty.beginner);
      final bags = TrickBags(two).discard(two[1]);
      final (drawn, _) = drawMany(bags, onlyBeginner, Random(0), 3);
      expect(ids(drawn), ['b0', 'b0', 'b0']);
    });
  });

  group('T9b: immutable state', () {
    test('draw leaves the original unchanged (undo scenario)', () {
      final bags = TrickBags(beginners);
      final first = drawOk(bags, onlyBeginner, Random(7));
      final again = drawOk(bags, onlyBeginner, Random(7));

      expect(again.trick.id, first.trick.id);
      expect(bags.remainingInBag(Difficulty.beginner), 20);
      expect(bags.lastDrawnId, isNull);
      expect(first.bags.remainingInBag(Difficulty.beginner), 19);
      expect(first.bags.lastDrawnId, first.trick.id);
    });

    test('discard leaves the original unchanged', () {
      final bags = TrickBags(beginners);
      final after = bags.discard(beginners[0]);

      expect(bags.discardedIds, isEmpty);
      expect(bags.drawableCount(Difficulty.beginner), 20);
      expect(after.discardedIds, {'b0'});
    });

    test('discardedIds cannot be mutated from outside', () {
      final bags = TrickBags(beginners).discard(beginners[0]);
      expect(() => bags.discardedIds.add('b1'), throwsUnsupportedError);
    });
  });

  group('T10: discards are permanent', () {
    final four = tier('b', 4, Difficulty.beginner);

    test('a discarded trick never comes back across reshuffles', () {
      final first = drawOk(TrickBags(four), onlyBeginner, Random(9));
      final bags = first.bags.discard(first.trick);
      final (drawn, _) = drawMany(bags, onlyBeginner, Random(9), 50);
      expect(ids(drawn), isNot(contains(first.trick.id)));
    });

    test('discarding a trick still in the bag removes it from the bag too', () {
      final bags = TrickBags(four).discard(four[2]);
      expect(bags.remainingInBag(Difficulty.beginner), 3);
      expect(bags.drawableCount(Difficulty.beginner), 3);
      final (drawn, _) = drawMany(bags, onlyBeginner, Random(4), 3);
      expect(ids(drawn).toSet(), {'b0', 'b1', 'b3'});
    });

    test('discard is idempotent', () {
      final once = TrickBags(four).discard(four[0]);
      final twice = once.discard(four[0]);
      expect(twice.discardedIds, {'b0'});
      expect(twice.drawableCount(Difficulty.beginner), 3);
      expect(twice.remainingInBag(Difficulty.beginner), 3);
    });

    test('discarding a trick not in the library throws ArgumentError', () {
      expect(
        () => TrickBags(four).discard(trick('nope', Difficulty.beginner)),
        throwsArgumentError,
      );
    });
  });

  group('T11: availability and redistribution', () {
    test('a landed (not discarded) trick returns after the bag cycles', () {
      final three = tier('b', 3, Difficulty.beginner);
      final (drawn, _) = drawMany(
        TrickBags(three),
        onlyBeginner,
        Random(11),
        6,
      );
      expect(ids(drawn.sublist(3)), contains(drawn.first.id));
    });

    test('a weight-0 tier is never drawn even though it has tricks', () {
      final weights = DrawWeights(beginner: 1, intermediate: 1, advanced: 0);
      final bags = TrickBags(fullLibrary);
      expect(bags.isAvailable(Difficulty.advanced, weights), isFalse);
      final (drawn, _) = drawMany(bags, weights, Random(12), 500);
      expect(drawn.where((t) => t.difficulty == Difficulty.advanced), isEmpty);
    });

    test(
      'an all-discarded tier is unavailable; its weight moves elsewhere',
      () {
        final weights = DrawWeights(
          beginner: 80,
          intermediate: 20,
          advanced: 0,
        );
        var bags = TrickBags(fullLibrary);
        for (final t in beginners) {
          bags = bags.discard(t);
        }
        expect(bags.isAvailable(Difficulty.beginner, weights), isFalse);
        final (drawn, _) = drawMany(bags, weights, Random(13), 200);
        expect(
          drawn.every((t) => t.difficulty == Difficulty.intermediate),
          isTrue,
        );
      },
    );

    group('redistribution is proportional (10/30/60, beginner gone)', () {
      final weights = DrawWeights(beginner: 10, intermediate: 30, advanced: 60);
      final library = [
        trick('b0', Difficulty.beginner),
        trick('i0', Difficulty.intermediate),
        trick('a0', Difficulty.advanced),
      ];
      final bags = TrickBags(library).discard(library[0]);

      // Total available weight is 90; FakeRandom throws if nextInt(max) is
      // called with a max that the scripted value doesn't fit.
      test('roll 29 of 90 picks intermediate', () {
        expect(drawOk(bags, weights, FakeRandom([29, 0])).trick.id, 'i0');
      });

      test('roll 30 of 90 picks advanced', () {
        expect(drawOk(bags, weights, FakeRandom([30, 0])).trick.id, 'a0');
      });

      test('the roll is over 90, not 100', () {
        expect(() => bags.draw(weights, FakeRandom([90, 0])), throwsStateError);
      });
    });

    test('a tier with no tricks in the library is unavailable', () {
      final weights = DrawWeights.defaultsFor(Difficulty.intermediate);
      final bags = TrickBags(intermediates);
      expect(bags.isAvailable(Difficulty.beginner, weights), isFalse);
      expect(bags.isAvailable(Difficulty.advanced, weights), isFalse);
      expect(bags.isAvailable(Difficulty.intermediate, weights), isTrue);
      final (drawn, _) = drawMany(bags, weights, Random(14), 100);
      expect(
        drawn.every((t) => t.difficulty == Difficulty.intermediate),
        isTrue,
      );
    });

    test('an empty bag with undiscarded tricks is still available', () {
      final two = tier('b', 2, Difficulty.beginner);
      final (_, emptied) = drawMany(
        TrickBags(two),
        onlyBeginner,
        Random(15),
        2,
      );
      expect(emptied.remainingInBag(Difficulty.beginner), 0);
      expect(emptied.isAvailable(Difficulty.beginner, onlyBeginner), isTrue);
      expect(emptied.draw(onlyBeginner, Random(15)), isA<Drawn>());
    });

    test('all tricks discarded → NoDrawableTricks', () {
      final two = tier('b', 2, Difficulty.beginner);
      final bags = TrickBags(two).discard(two[0]).discard(two[1]);
      expect(bags.draw(onlyBeginner, Random(16)), isA<NoDrawableTricks>());
    });

    test('only weight-0 tiers have tricks left → NoDrawableTricks', () {
      var bags = TrickBags(fullLibrary);
      for (final t in beginners) {
        bags = bags.discard(t);
      }
      expect(bags.draw(onlyBeginner, Random(17)), isA<NoDrawableTricks>());
    });

    test('an empty library → NoDrawableTricks', () {
      expect(
        TrickBags(const []).draw(onlyBeginner, Random(18)),
        isA<NoDrawableTricks>(),
      );
    });
  });

  group('smoke: real assets/tricks.json', () {
    final library = parseTricks(File('assets/tricks.json').readAsStringSync())
        .tricks;

    for (final difficulty in Difficulty.values) {
      test('1,000 draws with ${difficulty.name} defaults never run dry', () {
        final weights = DrawWeights.defaultsFor(difficulty);
        final (drawn, _) = drawMany(
          TrickBags(library),
          weights,
          Random(difficulty.index),
          1000,
        );
        expect(drawn, hasLength(1000));
      });
    }
  });
}
