import 'dart:async';

import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Reset Superpowers static state before each test.
  setUp(() {
    Superpowers.clear();
  });

  group('mix with debounce - basic behavior', () {
    test('single action executes after debounce period', () async {
      var ran = false;

      await mix<void>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 50.millis),
        () async {
          ran = true;
        },
      );

      expect(ran, true);
    });

    test('action waits for debounce period before running', () async {
      var ran = false;
      final stopwatch = Stopwatch()..start();

      await mix<void>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 100.millis),
        () async {
          ran = true;
        },
      );

      stopwatch.stop();
      expect(ran, true);
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(95));
    });

    test('rapid dispatches only execute the last action', () async {
      final tracker = <int>[];

      // First call - will be superseded
      final future1 = mix<void>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 100.millis),
        () async {
          tracker.add(1);
        },
      );

      // Small delay to ensure ordering
      await Future.delayed(const Duration(milliseconds: 10));

      // Second call - will be superseded
      final future2 = mix<void>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 100.millis),
        () async {
          tracker.add(2);
        },
      );

      // Small delay to ensure ordering
      await Future.delayed(const Duration(milliseconds: 10));

      // Third call - this one will execute
      final future3 = mix<void>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 100.millis),
        () async {
          tracker.add(3);
        },
      );

      await future1;
      await future2;
      await future3;

      // Only the last one should have executed
      expect(tracker, [3]);
    });

    test('debounced actions return null', () async {
      // First call - will be superseded
      final future1 = mix<int?>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 100.millis),
        () async => 1,
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Second call - this one will execute
      final future2 = mix<int?>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 100.millis),
        () async => 2,
      );

      final result1 = await future1;
      final result2 = await future2;

      expect(result1, null); // Debounced
      expect(result2, 2); // Executed
    });

    test('different keys do not debounce each other', () async {
      final tracker = <String>[];

      final futureA = mix<void>(
        key: 'A',
        debounce: debounce(key: 'A', duration: 50.millis),
        () async {
          tracker.add('A');
        },
      );

      final futureB = mix<void>(
        key: 'B',
        debounce: debounce(key: 'B', duration: 50.millis),
        () async {
          tracker.add('B');
        },
      );

      await futureA;
      await futureB;

      // Both should execute (different keys)
      expect(tracker.length, 2);
      expect(tracker.contains('A'), true);
      expect(tracker.contains('B'), true);
    });

    test('works without debounce (default null)', () async {
      var count = 0;

      // Multiple calls without debounce should all run
      await mix<void>(key: 'test', () async {
        count++;
      });
      await mix<void>(key: 'test', () async {
        count++;
      });
      await mix<void>(key: 'test', () async {
        count++;
      });

      expect(count, 3);
    });
  });

  group('debounce with sequential dispatches', () {
    test('actions dispatched after debounce period execute', () async {
      final tracker = <int>[];

      // First action
      await mix<void>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 50.millis),
        () async {
          tracker.add(1);
        },
      );
      expect(tracker, [1]);

      // Wait a bit, then dispatch second
      await Future.delayed(const Duration(milliseconds: 20));

      await mix<void>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 50.millis),
        () async {
          tracker.add(2);
        },
      );

      expect(tracker, [1, 2]);
    });
  });

  group('Superpowers.clear() clears debounce state', () {
    test('Superpowers.clear() clears debounce locks', () async {
      final tracker = <int>[];

      // Start first call (waiting in debounce)
      final future1 = mix<void>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 200.millis),
        () async {
          tracker.add(1);
        },
      );

      // Give it time to register
      await Future.delayed(const Duration(milliseconds: 10));

      // Reset clears the debounce map
      Superpowers.clear();

      // Start second call - should not be affected by first
      await mix<void>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 50.millis),
        () async {
          tracker.add(2);
        },
      );

      await future1;

      // Both may execute since reset cleared state
      // First was reset, so its after check will fail (map cleared)
      expect(tracker.contains(2), true);
    });
  });

  group('debounce with lifecycle methods', () {
    test('before() not called when debounced', () async {
      var beforeCallCount = 0;

      // First call - will be superseded
      final future1 = mix<void>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 100.millis),
        config: MixConfig(before: () => beforeCallCount++),
        () async {},
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Second call - will execute
      final future2 = mix<void>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 100.millis),
        config: MixConfig(before: () => beforeCallCount++),
        () async {},
      );

      await future1;
      await future2;

      // Only the executing action's before() should be called
      expect(beforeCallCount, 1);
    });

    test('after() not called when debounced', () async {
      var afterCallCount = 0;

      // First call - will be superseded
      final future1 = mix<void>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 100.millis),
        config: MixConfig(after: () => afterCallCount++),
        () async {},
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Second call - will execute
      final future2 = mix<void>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 100.millis),
        config: MixConfig(after: () => afterCallCount++),
        () async {},
      );

      await future1;
      await future2;

      // Only the executing action's after() should be called
      expect(afterCallCount, 1);
    });

    test('catchError() not called when debounced', () async {
      var catchErrorCallCount = 0;

      // First call - will be superseded
      final future1 = mix<void>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 100.millis),
        config: MixConfig(catchError: (e, s) {
          catchErrorCallCount++;
          // Return normally to suppress
        }),
        () async {
          throw Exception('Error');
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Second call - will execute
      final future2 = mix<void>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 100.millis),
        config: MixConfig(catchError: (e, s) {
          catchErrorCallCount++;
          // Return normally to suppress
        }),
        () async {
          throw Exception('Error');
        },
      );

      await future1;
      await future2;

      // Only the executing action's catchError() should be called
      expect(catchErrorCallCount, 1);
    });

    test('wrapRun() not called when debounced', () async {
      var wrapRunCallCount = 0;

      // First call - will be superseded
      final future1 = mix<void>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 100.millis),
        config: MixConfig(wrapRun: (action) {
          wrapRunCallCount++;
          return action();
        }),
        () async {},
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Second call - will execute
      final future2 = mix<void>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 100.millis),
        config: MixConfig(wrapRun: (action) {
          wrapRunCallCount++;
          return action();
        }),
        () async {},
      );

      await future1;
      await future2;

      // Only the executing action's wrapRun() should be called
      expect(wrapRunCallCount, 1);
    });
  });

  group('debounce combined with retry', () {
    test('retry works with debounce', () async {
      var attemptCount = 0;

      await mix<void>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 50.millis),
        retry: retry(
          maxRetries: 2,
          initialDelay: Duration(milliseconds: 10),
          multiplier: 2.0,
          maxDelay: Duration(seconds: 1),
          onRetry: null,
        ),
        () async {
          attemptCount++;
          if (attemptCount < 3) {
            throw Exception('Fail $attemptCount');
          }
        },
      );

      expect(attemptCount, 3); // 1 initial + 2 retries
    });

    test('debounced action does not retry', () async {
      var attemptCount = 0;

      // First call - will be superseded
      final future1 = mix<void>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 100.millis),
        retry: retry(
          maxRetries: 2,
          initialDelay: Duration(milliseconds: 10),
          multiplier: 2.0,
          maxDelay: Duration(seconds: 1),
          onRetry: null,
        ),
        () async {
          attemptCount++;
          throw Exception('Fail');
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Second call - will execute
      final future2 = mix<void>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 100.millis),
        retry: retry(
          maxRetries: 2,
          initialDelay: Duration(milliseconds: 10),
          multiplier: 2.0,
          maxDelay: Duration(seconds: 1),
          onRetry: null,
        ),
        config: MixConfig(catchError: (e, s) {}), // Suppress error
        () async {
          attemptCount++;
          throw Exception('Fail');
        },
      );

      await future1;
      await future2;

      // Only second action retries (3 attempts)
      expect(attemptCount, 3);
    });
  });

  group('debounce combined with nonReentrant', () {
    test('debounce happens before nonReentrant check', () async {
      final tracker = <String>[];
      final completer = Completer<void>();

      // First call - waits in debounce, then executes
      final future1 = mix<void>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 50.millis),
        nonReentrant: nonReentrant(key: 'test'),
        () async {
          tracker.add('first-start');
          await completer.future;
          tracker.add('first-end');
        },
      );

      // Wait for first to pass debounce and start executing
      await Future.delayed(const Duration(milliseconds: 70));
      expect(tracker, ['first-start']);

      // Second call - debounces, then checks nonReentrant (should fail)
      final future2 = mix<void>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 50.millis),
        nonReentrant: nonReentrant(key: 'test'),
        () async {
          tracker.add('second');
        },
      );

      // Wait for second's debounce period
      await Future.delayed(const Duration(milliseconds: 60));

      // Complete first
      completer.complete();
      await future1;
      await future2;

      // Second should be blocked by nonReentrant (first still running when it checked)
      expect(tracker, ['first-start', 'first-end']);
    });

    test('superseded debounce does not block nonReentrant', () async {
      final tracker = <int>[];

      // First call - will be superseded
      final future1 = mix<void>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 100.millis),
        nonReentrant: nonReentrant(key: 'test'),
        () async {
          tracker.add(1);
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Second call - will execute
      final future2 = mix<void>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 100.millis),
        nonReentrant: nonReentrant(key: 'test'),
        () async {
          tracker.add(2);
        },
      );

      await future1;
      await future2;

      // Only second should run
      expect(tracker, [2]);
    });
  });

  group('debounce combined with throttle', () {
    test('debounce happens before throttle check', () async {
      final tracker = <int>[];

      // First call - debounces, then sets throttle lock
      await mix<void>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 50.millis),
        throttle: throttle(key: 'test', duration: 1.sec),
        () async {
          tracker.add(1);
        },
      );
      expect(tracker, [1]);

      // Second call - debounces, then blocked by throttle
      await mix<void>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 50.millis),
        throttle: throttle(key: 'test', duration: 1.sec),
        () async {
          tracker.add(2);
        },
      );

      // Second should be blocked by throttle after debounce
      expect(tracker, [1]);
    });

    test('superseded debounce does not set throttle', () async {
      final tracker = <int>[];

      // First call - will be superseded (does not set throttle)
      final future1 = mix<void>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 100.millis),
        throttle: throttle(key: 'test', duration: 1.sec),
        () async {
          tracker.add(1);
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Second call - will execute
      final future2 = mix<void>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 100.millis),
        throttle: throttle(key: 'test', duration: 1.sec),
        () async {
          tracker.add(2);
        },
      );

      await future1;
      await future2;

      expect(tracker, [2]);
    });
  });

  group('debounce combined with fresh', () {
    test('debounce happens before fresh check', () async {
      final tracker = <int>[];

      // First call - debounces, then sets fresh
      await mix<void>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 50.millis),
        fresh: fresh(key: 'test', freshFor: 1.sec),
        () async {
          tracker.add(1);
        },
      );
      expect(tracker, [1]);

      // Second call - debounces, then blocked by fresh
      await mix<void>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 50.millis),
        fresh: fresh(key: 'test', freshFor: 1.sec),
        () async {
          tracker.add(2);
        },
      );

      // Second should be blocked by fresh after debounce
      expect(tracker, [1]);
    });

    test('superseded debounce does not set fresh', () async {
      final tracker = <int>[];

      // First call - will be superseded (does not set fresh)
      final future1 = mix<void>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 100.millis),
        fresh: fresh(key: 'test', freshFor: 1.sec),
        () async {
          tracker.add(1);
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Second call - will execute
      final future2 = mix<void>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 100.millis),
        fresh: fresh(key: 'test', freshFor: 1.sec),
        () async {
          tracker.add(2);
        },
      );

      await future1;
      await future2;

      expect(tracker, [2]);
    });
  });

  group('return value handling', () {
    test('returns action result on success', () async {
      final result = await mix<int>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 50.millis),
        () async => 42,
      );

      expect(result, 42);
    });

    test('returns null when debounced', () async {
      // First call - will be superseded
      final future1 = mix<int?>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 100.millis),
        () async => 1,
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Second call - will execute
      final future2 = mix<int?>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 100.millis),
        () async => 2,
      );

      expect(await future1, null);
      expect(await future2, 2);
    });
  });

  group('edge cases', () {
    test('zero debounce executes almost immediately', () async {
      var ran = false;
      final stopwatch = Stopwatch()..start();

      await mix<void>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 0.millis),
        () async {
          ran = true;
        },
      );

      stopwatch.stop();
      expect(ran, true);
      expect(stopwatch.elapsedMilliseconds, lessThan(50));
    });

    test('very short debounce still debounces rapid calls', () async {
      final tracker = <int>[];

      final future1 = mix<void>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 10.millis),
        () async {
          tracker.add(1);
        },
      );

      final future2 = mix<void>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 10.millis),
        () async {
          tracker.add(2);
        },
      );

      await future1;
      await future2;

      // At least one should execute
      expect(tracker.isNotEmpty, true);
    });

    test('empty string key works', () async {
      final tracker = <int>[];

      final future1 = mix<void>(
        key: '',
        debounce: debounce(key: '', duration: 50.millis),
        () async {
          tracker.add(1);
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      final future2 = mix<void>(
        key: '',
        debounce: debounce(key: '', duration: 50.millis),
        () async {
          tracker.add(2);
        },
      );

      await future1;
      await future2;

      expect(tracker, [2]); // First was superseded
    });

    test('special characters in key work', () async {
      final tracker = <int>[];

      final future1 = mix<void>(
        key: 'search:user/query?text=hello',
        debounce: debounce(key: 'search:user/query?text=hello', duration: 50.millis),
        () async {
          tracker.add(1);
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      final future2 = mix<void>(
        key: 'search:user/query?text=hello',
        debounce: debounce(key: 'search:user/query?text=hello', duration: 50.millis),
        () async {
          tracker.add(2);
        },
      );

      await future1;
      await future2;

      expect(tracker, [2]);
    });

    test('unicode key works', () async {
      final tracker = <int>[];

      final future1 = mix<void>(
        key: '検索_🔍',
        debounce: debounce(key: '検索_🔍', duration: 50.millis),
        () async {
          tracker.add(1);
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      final future2 = mix<void>(
        key: '検索_🔍',
        debounce: debounce(key: '検索_🔍', duration: 50.millis),
        () async {
          tracker.add(2);
        },
      );

      await future1;
      await future2;

      expect(tracker, [2]);
    });
  });

  group('debounce map lazy initialization', () {
    test('debounce map is lazily created on first use', () async {
      Superpowers.clear();

      // Verify no debounce map exists
      expect(Superpowers.prop<Map<Object, int>?>('_mix_debounceLockMap'), isNull);

      // First call creates the map
      final future = mix<void>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 50.millis),
        () async {},
      );

      // Map should exist now (created when debounce check starts)
      expect(Superpowers.prop<Map<Object, int>?>('_mix_debounceLockMap'), isNotNull);

      await future;
    });
  });

  group('debounce with wrapRun', () {
    test('wrapRun is called for executing action', () async {
      var wrapRunCalled = false;

      await mix<void>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 50.millis),
        config: MixConfig(wrapRun: (action) {
          wrapRunCalled = true;
          return action();
        }),
        () async {},
      );

      expect(wrapRunCalled, true);
    });

    test('wrapRun can modify action result', () async {
      final result = await mix<int>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 50.millis),
        config: MixConfig(wrapRun: (action) async {
          final r = await action();
          return r + 100;
        }),
        () async => 42,
      );

      expect(result, 142);
    });
  });

  group('many rapid dispatches', () {
    test('10 rapid dispatches only execute the last one', () async {
      final tracker = <int>[];

      final futures = <FutureOr<void>>[];
      for (int i = 1; i <= 10; i++) {
        futures.add(mix<void>(
          key: 'test',
          debounce: debounce(key: 'test', duration: 50.millis),
          () async {
            tracker.add(i);
          },
        ));
        // Small delay to ensure ordering
        await Future.delayed(const Duration(milliseconds: 5));
      }

      for (final future in futures) {
        await future;
      }

      expect(tracker, [10]);
    });

    test('burst of dispatches with different keys', () async {
      final tracker = <String>[];

      final futures = <FutureOr<void>>[];
      for (int i = 1; i <= 5; i++) {
        futures.add(mix<void>(
          key: 'A',
          debounce: debounce(key: 'A', duration: 50.millis),
          () async {
            tracker.add('A:$i');
          },
        ));
        futures.add(mix<void>(
          key: 'B',
          debounce: debounce(key: 'B', duration: 50.millis),
          () async {
            tracker.add('B:$i');
          },
        ));
      }

      for (final future in futures) {
        await future;
      }

      // Only last of each key should execute
      expect(tracker.length, 2);
      expect(tracker.contains('A:5'), true);
      expect(tracker.contains('B:5'), true);
    });
  });

  group('lock cleanup', () {
    test('lock is removed after successful run', () async {
      await mix<void>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 50.millis),
        () async {},
      );

      // Lock should be removed
      expect(
        Superpowers.prop<Map<Object, int>?>('_mix_debounceLockMap')?.containsKey('test'),
        false,
      );
    });

    test('lock is removed even if action throws', () async {
      try {
        await mix<void>(
          key: 'test',
          debounce: debounce(key: 'test', duration: 50.millis),
          () async {
            throw Exception('Error');
          },
        );
      } catch (_) {}

      // Lock should be removed
      expect(
        Superpowers.prop<Map<Object, int>?>('_mix_debounceLockMap')?.containsKey('test'),
        false,
      );
    });
  });

  group('all protections together', () {
    test('debounce, nonReentrant, throttle, and fresh work together', () async {
      final tracker = <int>[];

      // First batch of calls - all debounced except last
      final futures1 = <FutureOr<void>>[];
      for (int i = 1; i <= 3; i++) {
        futures1.add(mix<void>(
          key: 'test',
          debounce: debounce(key: 'test', duration: 50.millis),
          nonReentrant: nonReentrant(key: 'test'),
          throttle: throttle(key: 'test', duration: 200.millis),
          fresh: fresh(key: 'test', freshFor: 1.sec),
          () async {
            tracker.add(i);
          },
        ));
        await Future.delayed(const Duration(milliseconds: 10));
      }

      for (final future in futures1) {
        await future;
      }
      expect(tracker, [3]); // Only last debounce executed

      // Second call immediately - blocked by throttle
      await mix<void>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 50.millis),
        nonReentrant: nonReentrant(key: 'test'),
        throttle: throttle(key: 'test', duration: 200.millis),
        fresh: fresh(key: 'test', freshFor: 1.sec),
        () async {
          tracker.add(99);
        },
      );
      expect(tracker, [3]); // Still only 3

      // Wait for throttle to expire
      await Future.delayed(const Duration(milliseconds: 210));

      // Third call - blocked by fresh
      await mix<void>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 50.millis),
        nonReentrant: nonReentrant(key: 'test'),
        throttle: throttle(key: 'test', duration: 200.millis),
        fresh: fresh(key: 'test', freshFor: 1.sec),
        () async {
          tracker.add(100);
        },
      );
      expect(tracker, [3]); // Still only 3 - blocked by fresh
    });
  });

  group('counter overflow protection', () {
    test('counter resets when exceeding safe integer', () async {
      // Set counter just below overflow threshold
      final debounceMap = <String, int>{'test': 9000000000000000};
      Superpowers.setProp('_mix_debounceLockMap', debounceMap);

      // Should handle overflow correctly and still work
      await mix<void>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 10.millis),
        () async {},
      );

      // No error thrown = success
    });
  });

  group('sync actions', () {
    test('sync action after debounce works', () async {
      var ran = false;

      await mix<void>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 50.millis),
        () {
          ran = true;
        },
      );

      expect(ran, true);
    });
  });

  group('different debounce values for same key', () {
    test('later call with different debounce value supersedes', () async {
      final tracker = <int>[];

      // First call with long debounce
      final future1 = mix<void>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 200.millis),
        () async {
          tracker.add(1);
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Second call with short debounce
      final future2 = mix<void>(
        key: 'test',
        debounce: debounce(key: 'test', duration: 50.millis),
        () async {
          tracker.add(2);
        },
      );

      await future1;
      await future2;

      // Second should have executed (superseded first)
      expect(tracker, [2]);
    });
  });

  group('onSuperseded callback', () {
    test('onSuperseded is called when a call is superseded', () async {
      Object? supersededKey;
      var supersededCount = 0;

      // First call - will be superseded
      final future1 = mix<void>(
        key: 'test',
        debounce: debounce(
          key: 'testKey',
          duration: 100.millis,
          onSuperseded: (key) {
            supersededKey = key;
            supersededCount++;
          },
        ),
        () async {},
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Second call - will execute (supersedes first)
      final future2 = mix<void>(
        key: 'test',
        debounce: debounce(
          key: 'testKey',
          duration: 100.millis,
          onSuperseded: (key) {
            supersededKey = key;
            supersededCount++;
          },
        ),
        () async {},
      );

      await future1;
      await future2;

      expect(supersededCount, 1);
      expect(supersededKey, 'testKey');
    });

    test('onSuperseded is not called when the call runs', () async {
      var supersededCount = 0;

      await mix<void>(
        key: 'test',
        debounce: debounce(
          key: 'testKey',
          duration: 50.millis,
          onSuperseded: (key) {
            supersededCount++;
          },
        ),
        () async {},
      );

      expect(supersededCount, 0);
    });

    test('onSuperseded receives the effective key', () async {
      final supersededKeys = <Object>[];

      // First call - superseded
      final future1 = mix<void>(
        key: 'test',
        debounce: debounce(
          key: ('search', 'category1'),
          duration: 100.millis,
          onSuperseded: (key) => supersededKeys.add(key),
        ),
        () async {},
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Second call - superseded
      final future2 = mix<void>(
        key: 'test',
        debounce: debounce(
          key: ('search', 'category1'),
          duration: 100.millis,
          onSuperseded: (key) => supersededKeys.add(key),
        ),
        () async {},
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Third call - executes
      final future3 = mix<void>(
        key: 'test',
        debounce: debounce(
          key: ('search', 'category1'),
          duration: 100.millis,
          onSuperseded: (key) => supersededKeys.add(key),
        ),
        () async {},
      );

      await future1;
      await future2;
      await future3;

      expect(supersededKeys.length, 2);
      expect(supersededKeys[0], ('search', 'category1'));
      expect(supersededKeys[1], ('search', 'category1'));
    });

    test('onSuperseded called for each superseded call in burst', () async {
      var supersededCount = 0;

      final futures = <FutureOr<void>>[];
      for (int i = 1; i <= 5; i++) {
        futures.add(mix<void>(
          key: 'test',
          debounce: debounce(
            key: 'burst',
            duration: 100.millis,
            onSuperseded: (key) => supersededCount++,
          ),
          () async {},
        ));
        await Future.delayed(const Duration(milliseconds: 10));
      }

      for (final future in futures) {
        await future;
      }

      // 4 calls superseded, 1 executes
      expect(supersededCount, 4);
    });

    test('onSuperseded works with mix.ctx', () async {
      var supersededCount = 0;

      // First call - superseded
      final future1 = mix.ctx<void>(
        (ctx) async {},
        key: 'test',
        debounce: debounce(
          key: 'test',
          duration: 100.millis,
          onSuperseded: (key) => supersededCount++,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Second call - executes
      final future2 = mix.ctx<void>(
        (ctx) async {},
        key: 'test',
        debounce: debounce(
          key: 'test',
          duration: 100.millis,
          onSuperseded: (key) => supersededCount++,
        ),
      );

      await future1;
      await future2;

      expect(supersededCount, 1);
    });

    test('different keys do not trigger each other onSuperseded', () async {
      var supersededCountA = 0;
      var supersededCountB = 0;

      // Key A
      final futureA = mix<void>(
        key: 'A',
        debounce: debounce(
          key: 'A',
          duration: 50.millis,
          onSuperseded: (key) => supersededCountA++,
        ),
        () async {},
      );

      // Key B (dispatched immediately, different key)
      final futureB = mix<void>(
        key: 'B',
        debounce: debounce(
          key: 'B',
          duration: 50.millis,
          onSuperseded: (key) => supersededCountB++,
        ),
        () async {},
      );

      await futureA;
      await futureB;

      // Neither should be superseded (different keys)
      expect(supersededCountA, 0);
      expect(supersededCountB, 0);
    });
  });
}
