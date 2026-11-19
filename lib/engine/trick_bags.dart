/// Trick draw state (spec T8–T11). Pure Dart, immutable.
library;

import 'dart:math';

import 'draw_weights.dart';
import 'trick.dart';

/// The outcome of [TrickBags.draw]. `sealed` means these are the only two
/// subclasses, so a `switch` over a [DrawResult] must handle both.
sealed class DrawResult {
  const DrawResult();
}

/// A trick was drawn. [bags] is the new state to use from now on.
final class Drawn extends DrawResult {
  const Drawn(this.trick, this.bags);

  final Trick trick;
  final TrickBags bags;

  @override
  String toString() => 'Drawn($trick)';
}

/// No tier is available (T11): the game should end as if by End game.
final class NoDrawableTricks extends DrawResult {
  const NoDrawableTricks();

  @override
  String toString() => 'NoDrawableTricks()';
}

/// One shuffle bag per difficulty tier, plus the permanently discarded tricks.
///
/// Immutable (T9b): [draw] and [discard] return a new [TrickBags] and leave
/// this one untouched, so undo can simply keep the old object.
class TrickBags {
  const TrickBags._(
    this._library,
    this._tierOf,
    this._bags,
    this._discardedIds,
    this.lastDrawnId,
  );

  /// A fresh state with every trick in its tier's bag.
  ///
  /// Throws [ArgumentError] if two tricks share an id.
  factory TrickBags(Iterable<Trick> library) {
    final tierOf = <String, Difficulty>{};
    final byTier = {for (final d in Difficulty.values) d: <Trick>[]};
    for (final trick in library) {
      if (tierOf.containsKey(trick.id)) {
        throw ArgumentError.value(trick.id, 'library', 'Duplicate trick id');
      }
      tierOf[trick.id] = trick.difficulty;
      byTier[trick.difficulty]!.add(trick);
    }
    final frozen = Map<Difficulty, List<Trick>>.unmodifiable({
      for (final entry in byTier.entries)
        entry.key: List<Trick>.unmodifiable(entry.value),
    });
    return TrickBags._(
      frozen,
      Map.unmodifiable(tierOf),
      frozen,
      const {},
      null,
    );
  }

  /// Every trick, by tier. Never changes during a game.
  final Map<Difficulty, List<Trick>> _library;

  /// Tier of every trick id in the library.
  final Map<String, Difficulty> _tierOf;

  /// Tricks not yet drawn in the current cycle (never includes discards).
  final Map<Difficulty, List<Trick>> _bags;

  final Set<String> _discardedIds;

  /// Id of the trick drawn most recently, in any tier (used by T9a).
  final String? lastDrawnId;

  /// Ids removed for the rest of the game (T10). Read-only.
  Set<String> get discardedIds => _discardedIds;

  /// How many tricks in [tier] are still waiting in this cycle's bag.
  int remainingInBag(Difficulty tier) => _bags[tier]!.length;

  /// How many tricks in [tier] have not been discarded.
  int drawableCount(Difficulty tier) => _drawable(tier).length;

  /// A tier is available if its weight is above 0 and it has at least one
  /// undiscarded trick (T11).
  bool isAvailable(Difficulty tier, DrawWeights weights) =>
      weights.weightOf(tier) > 0 && drawableCount(tier) > 0;

  /// Rolls a tier, then draws a trick from that tier's bag (T8, T9).
  ///
  /// Uses [random] exactly twice: `nextInt(total weight of available tiers)`
  /// for the tier, then `nextInt(candidate count)` for the trick.
  DrawResult draw(DrawWeights weights, Random random) {
    final available = [
      for (final tier in Difficulty.values)
        if (isAvailable(tier, weights)) tier,
    ];
    if (available.isEmpty) return const NoDrawableTricks();

    final tier = _rollTier(available, weights, random);

    var bag = _bags[tier]!;
    var candidates = bag;
    if (bag.isEmpty) {
      // Lazy reshuffle: refill with every undiscarded trick in the tier.
      // T9a: skip the trick drawn just before, unless it's the only one.
      bag = _drawable(tier);
      candidates = bag;
      if (bag.length > 1) {
        candidates = [
          for (final trick in bag)
            if (trick.id != lastDrawnId) trick,
        ];
      }
    }

    final picked = candidates[random.nextInt(candidates.length)];
    return Drawn(
      picked,
      _copyWith(
        bags: _replaceBag(tier, _without(bag, picked.id)),
        lastDrawnId: picked.id,
      ),
    );
  }

  /// Removes [trick] for the rest of the game, even across reshuffles (T10).
  ///
  /// Discarding the same trick twice is harmless. Throws [ArgumentError] if
  /// [trick] isn't in the library.
  TrickBags discard(Trick trick) {
    final tier = _tierOf[trick.id];
    if (tier == null) {
      throw ArgumentError.value(trick.id, 'trick', 'Not in the library');
    }
    if (_discardedIds.contains(trick.id)) return this;

    return _copyWith(
      bags: _replaceBag(tier, _without(_bags[tier]!, trick.id)),
      discardedIds: Set.unmodifiable({..._discardedIds, trick.id}),
    );
  }

  /// Maps a roll in `[0, total)` onto the available tiers, in tier order.
  /// Rolling only over available tiers is what redistributes the weight of
  /// unavailable ones proportionally (T11).
  static Difficulty _rollTier(
    List<Difficulty> available,
    DrawWeights weights,
    Random random,
  ) {
    final total = available.fold(
      0,
      (sum, tier) => sum + weights.weightOf(tier),
    );
    var roll = random.nextInt(total);
    for (final tier in available) {
      final weight = weights.weightOf(tier);
      if (roll < weight) return tier;
      roll -= weight;
    }
    throw StateError('unreachable: roll $roll outside total $total');
  }

  List<Trick> _drawable(Difficulty tier) => [
    for (final trick in _library[tier]!)
      if (!_discardedIds.contains(trick.id)) trick,
  ];

  static List<Trick> _without(List<Trick> bag, String id) => List.unmodifiable([
    for (final trick in bag)
      if (trick.id != id) trick,
  ]);

  Map<Difficulty, List<Trick>> _replaceBag(Difficulty tier, List<Trick> bag) =>
      Map.unmodifiable({..._bags, tier: bag});

  TrickBags _copyWith({
    Map<Difficulty, List<Trick>>? bags,
    Set<String>? discardedIds,
    String? lastDrawnId,
  }) => TrickBags._(
    _library,
    _tierOf,
    bags ?? _bags,
    discardedIds ?? _discardedIds,
    lastDrawnId ?? this.lastDrawnId,
  );

  @override
  String toString() =>
      'TrickBags(bags: ${{for (final tier in Difficulty.values) tier.name: remainingInBag(tier)}}, discarded: ${_discardedIds.length}, last: $lastDrawnId)';
}
