import 'dart:math';

/// A `Random` that returns scripted `nextInt` values, in order.
///
/// Throws [StateError] if a scripted value doesn't fit the requested range,
/// so a test can check which `max` the code asked for. `nextDouble` and
/// `nextBool` throw, so a change to how the engine uses randomness fails
/// loudly instead of silently.
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

/// A `Random` whose `nextInt` always returns 0.
///
/// With it, the game starts at the first seat and tricks come out of a bag
/// in library order, so a test can follow along without scripting every
/// call.
class ZeroRandom implements Random {
  @override
  int nextInt(int max) => 0;

  @override
  double nextDouble() => throw UnimplementedError();

  @override
  bool nextBool() => throw UnimplementedError();
}
