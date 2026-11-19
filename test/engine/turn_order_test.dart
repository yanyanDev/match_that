// Spec §10 step 3 — turn order (P4, P5). Written test-first.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:match_that/engine/turn_order.dart';

import '../helpers/fake_random.dart';

/// [n] advances starting from [order], including the start.
List<int> visit(TurnOrder order, int n) {
  final seats = <int>[];
  var state = order;
  for (var i = 0; i < n; i++) {
    seats.add(state.current);
    state = state.advance();
  }
  return seats;
}

void main() {
  group('P4: random first player', () {
    test('randomStart makes one nextInt(seat count) call', () {
      // FakeRandom throws if the scripted value doesn't fit nextInt(max).
      final order = TurnOrder.randomStart([0, 1, 2, 3], FakeRandom([2]));
      expect(order.current, 2);
      expect(
        () => TurnOrder.randomStart([0, 1, 2, 3], FakeRandom([4])),
        throwsStateError,
      );
    });

    test('randomStart on a subset picks among its seats', () {
      final order = TurnOrder.randomStart([1, 3], FakeRandom([1]));
      expect(order.current, 3);
    });

    test(
      'over 400 seeded starts, every one of 8 seats starts at least once',
      () {
        final seats = [for (var i = 0; i < 8; i++) i];
        final starters = {
          for (var seed = 0; seed < 400; seed++)
            TurnOrder.randomStart(seats, Random(seed)).current,
        };
        expect(starters, seats.toSet());
      },
    );
  });

  group('P5: turn advancement', () {
    test('advance goes in seat order and wraps around', () {
      expect(visit(TurnOrder([0, 1, 2], current: 0), 7), [0, 1, 2, 0, 1, 2, 0]);
    });

    test('upNext is the seat advance will move to', () {
      expect(TurnOrder([0, 1, 2], current: 1).upNext, 2);
      expect(TurnOrder([0, 1, 2], current: 2).upNext, 0);
    });

    test('a subset keeps setup order and skips missing seats', () {
      final seats = visit(TurnOrder([0, 2, 3], current: 2), 6);
      expect(seats, [2, 3, 0, 2, 3, 0]);
      expect(seats, isNot(contains(1)));
    });

    test('a one-seat order stays on that seat', () {
      final order = TurnOrder([4], current: 4);
      expect(order.upNext, 4);
      expect(visit(order, 3), [4, 4, 4]);
    });

    test('advance leaves the original unchanged (undo)', () {
      final order = TurnOrder([0, 1, 2], current: 0);
      final next = order.advance();
      expect(order.current, 0);
      expect(next.current, 1);
      expect(next.seats, [0, 1, 2]);
    });
  });

  group('validation', () {
    test('empty seats throw ArgumentError', () {
      expect(() => TurnOrder([], current: 0), throwsArgumentError);
      expect(
        () => TurnOrder.randomStart([], FakeRandom([0])),
        throwsArgumentError,
      );
    });

    test('duplicate seats throw ArgumentError', () {
      expect(() => TurnOrder([0, 0, 1], current: 0), throwsArgumentError);
    });

    test('seats out of setup order throw ArgumentError', () {
      expect(() => TurnOrder([2, 1], current: 1), throwsArgumentError);
    });

    test('current not in seats throws ArgumentError', () {
      expect(() => TurnOrder([0, 2], current: 1), throwsArgumentError);
    });
  });

  test('seats cannot be modified', () {
    final order = TurnOrder([0, 1], current: 0);
    expect(() => order.seats.add(2), throwsUnsupportedError);
  });
}
