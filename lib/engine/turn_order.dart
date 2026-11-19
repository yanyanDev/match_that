/// Turn order (spec P4, P5). Pure Dart, immutable.
library;

import 'dart:math';

/// Whose turn it is, among [seats], in setup order.
///
/// [seats] can be every player or a subset (sudden death, §3); either way
/// "next" follows setup order and wraps around (P5). Immutable: [advance]
/// returns a new [TurnOrder], so undo can keep the old one.
class TurnOrder {
  const TurnOrder._(this.seats, this.current);

  /// [seats] must be non-empty and strictly ascending (setup order, no
  /// duplicates), and [current] must be one of them. Throws [ArgumentError]
  /// otherwise.
  factory TurnOrder(List<int> seats, {required int current}) {
    if (seats.isEmpty) {
      throw ArgumentError.value(seats, 'seats', 'Must not be empty');
    }
    for (var i = 1; i < seats.length; i++) {
      if (seats[i] <= seats[i - 1]) {
        throw ArgumentError.value(
          seats,
          'seats',
          'Must be in setup order with no duplicates',
        );
      }
    }
    if (!seats.contains(current)) {
      throw ArgumentError.value(current, 'current', 'Not one of $seats');
    }
    return TurnOrder._(List.unmodifiable(seats), current);
  }

  /// Starts at a random seat (P4), using exactly one
  /// `random.nextInt(seats.length)` call. Also used for rematches.
  factory TurnOrder.randomStart(List<int> seats, Random random) {
    if (seats.isEmpty) {
      throw ArgumentError.value(seats, 'seats', 'Must not be empty');
    }
    return TurnOrder(seats, current: seats[random.nextInt(seats.length)]);
  }

  /// The seats taking turns, in setup order. Read-only.
  final List<int> seats;

  /// The seat whose turn it is.
  final int current;

  /// The seat that [advance] moves to.
  int get upNext => seats[(seats.indexOf(current) + 1) % seats.length];

  /// The next seat's turn, wrapping from the last seat back to the first.
  TurnOrder advance() => TurnOrder._(seats, upNext);

  @override
  String toString() => 'TurnOrder($seats, current: $current)';
}
