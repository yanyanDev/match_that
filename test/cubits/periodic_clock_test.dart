// Spec §10 step 7, round 2 — the production clock (§4c A1).
// Written test-first.
//
// These use real time, so they compare the clock with a Stopwatch of the
// test's own instead of exact numbers: the machine running the tests may be
// slow, and Future.delayed may wake up late.

import 'package:flutter_test/flutter_test.dart';
import 'package:match_that/cubits/game_clock.dart';

Duration ms(int n) => Duration(milliseconds: n);

Duration sum(List<Duration> ticks) =>
    ticks.fold(Duration.zero, (a, b) => a + b);

Future<void> wait(int millis) => Future<void>.delayed(ms(millis));

void main() {
  test('sends the measured time since the last tick, until stopped', () async {
    final clock = PeriodicClock();
    final ticks = <Duration>[];
    final window = Stopwatch();

    expect(clock.isRunning, isFalse);
    window.start();
    clock.start(ticks.add);
    expect(clock.isRunning, isTrue);

    await wait(350);
    clock.stop();
    window.stop();
    expect(clock.isRunning, isFalse);

    expect(ticks.length, greaterThanOrEqualTo(2)); // about every 100 ms
    expect(sum(ticks), greaterThanOrEqualTo(ms(200)));
    // Never more than really passed; at most one ~100 ms tick unsent.
    expect(sum(ticks), lessThanOrEqualTo(window.elapsed));

    final count = ticks.length;
    await wait(250);
    expect(ticks, hasLength(count)); // nothing after stop
  });

  test('time while stopped is not sent after a restart', () async {
    final clock = PeriodicClock();
    final ticks = <Duration>[];

    clock.start(ticks.add);
    await wait(150);
    clock.stop();
    final before = ticks.length;

    await wait(600); // "paused"
    final window = Stopwatch()..start();
    clock.start(ticks.add);
    await wait(250);
    clock.stop();
    window.stop();

    final after = ticks.sublist(before);
    expect(after, isNotEmpty);
    // The 600 ms while stopped is not in it.
    expect(sum(after), lessThanOrEqualTo(window.elapsed));
  });

  test('stop when stopped and start when running do nothing', () async {
    final clock = PeriodicClock();
    final ticks = <Duration>[];
    final window = Stopwatch()..start();

    clock.stop();
    clock.start(ticks.add);
    clock.start(ticks.add); // would double the ticks if it started again
    await wait(250);
    clock.stop();
    window.stop();

    expect(sum(ticks), lessThanOrEqualTo(window.elapsed));
  });
}
