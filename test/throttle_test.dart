import 'dart:async';

import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Reset Superpowers static state before each test.
  setUp(() {
    Superpowers.clear();
  });

  group('mix with throttle - basic behavior', () {
    test('allows first call to run', () async {
      var ran = false;

      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec),
        () async {
          ran = true;
        },
      );

      expect(ran, true);
    });

    test('aborts call within throttle period', () async {
      var firstRan = false;
      var secondRan = false;

      // First call runs
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec),
        () async {
          firstRan = true;
        },
      );
      expect(firstRan, true);

      // Second call is aborted (still within throttle period)
      final result2 = await mix<int?>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec),
        () async {
          secondRan = true;
          return 42;
        },
      );

      expect(result2, null);
      expect(secondRan, false);
    });

    test('allows call after throttle period expires', () async {
      var count = 0;

      // First call
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 50.millis),
        () async {
          count++;
        },
      );
      expect(count, 1);

      // Wait for throttle to expire
      await Future.delayed(const Duration(milliseconds: 60));

      // Second call should run
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 50.millis),
        () async {
          count++;
        },
      );
      expect(count, 2);
    });

    test('different keys have separate throttle', () async {
      var countA = 0;
      var countB = 0;

      await mix<void>(
        key: 'A',
        throttle: throttle(key: 'A', duration: 1.sec),
        () async {
          countA++;
        },
      );
      expect(countA, 1);

      // Different key should run
      await mix<void>(
        key: 'B',
        throttle: throttle(key: 'B', duration: 1.sec),
        () async {
          countB++;
        },
      );
      expect(countB, 1);

      // Same key 'A' should be aborted
      await mix<void>(
        key: 'A',
        throttle: throttle(key: 'A', duration: 1.sec),
        () async {
          countA++;
        },
      );
      expect(countA, 1); // Still 1
    });

    test('works without throttle (default null)', () async {
      var count = 0;

      // Multiple calls without throttle should all run
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

    test('multiple rapid dispatches only execute first', () async {
      var count = 0;

      // First call
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 200.millis),
        () async {
          count++;
        },
      );

      // Rapid subsequent calls
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 200.millis),
        () async {
          count++;
        },
      );
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 200.millis),
        () async {
          count++;
        },
      );
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 200.millis),
        () async {
          count++;
        },
      );

      expect(count, 1); // Only first ran
    });
  });

  group('throttle error handling', () {
    test('lock is NOT removed on error by default', () async {
      var secondRan = false;

      // First call fails
      try {
        await mix<void>(
          key: 'test',
          throttle: throttle(key: 'test', duration: 1.sec),
          () async {
            throw Exception('First failed');
          },
        );
      } catch (_) {
        // Expected
      }

      // Second call should still be throttled (lock not removed)
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec),
        () async {
          secondRan = true;
        },
      );

      expect(secondRan, false);
    });

    test('lock is removed on error when removeLockOnError is true', () async {
      var secondRan = false;

      // First call fails with removeLockOnError
      try {
        await mix<void>(
          key: 'test',
          throttle: throttle(key: 'test', duration: 1.sec, removeLockOnError: true),
          () async {
            throw Exception('First failed');
          },
        );
      } catch (_) {
        // Expected
      }

      // Second call should run (lock was removed)
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec, removeLockOnError: true),
        () async {
          secondRan = true;
        },
      );

      expect(secondRan, true);
    });

    test('removeLockOnError=false keeps lock on error', () async {
      var secondRan = false;

      // First call fails
      try {
        await mix<void>(
          key: 'test',
          throttle: throttle(key: 'test', duration: 1.sec, removeLockOnError: false),
          () async {
            throw Exception('First failed');
          },
        );
      } catch (_) {
        // Expected
      }

      // Second call should be throttled
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec, removeLockOnError: false),
        () async {
          secondRan = true;
        },
      );

      expect(secondRan, false);
    });

    test('removeLockOnError=true does NOT remove lock on success', () async {
      var count = 0;

      // First call succeeds with removeLockOnError=true
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec, removeLockOnError: true),
        () async {
          count++;
        },
      );
      expect(count, 1);

      // Second call should still be throttled (success doesn't remove lock)
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec, removeLockOnError: true),
        () async {
          count++;
        },
      );

      expect(count, 1); // Still 1
    });
  });

  group('Superpowers.clear() clears throttle state', () {
    test('Superpowers.clear() clears throttle locks', () async {
      var count = 0;

      // First call
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 5.sec),
        () async {
          count++;
        },
      );
      expect(count, 1);

      // Reset Superpowers state
      Superpowers.clear();

      // Second call should run (throttle was cleared)
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 5.sec),
        () async {
          count++;
        },
      );
      expect(count, 2);
    });

    test('Superpowers.clear() clears multiple throttle keys', () async {
      // Set up multiple throttle keys
      await mix<void>(
        key: 'A',
        throttle: throttle(key: 'A', duration: 5.sec),
        () async {},
      );
      await mix<void>(
        key: 'B',
        throttle: throttle(key: 'B', duration: 5.sec),
        () async {},
      );
      await mix<void>(
        key: 'C',
        throttle: throttle(key: 'C', duration: 5.sec),
        () async {},
      );

      // Reset
      Superpowers.clear();

      // All should run now
      var count = 0;
      await mix<void>(
        key: 'A',
        throttle: throttle(key: 'A', duration: 5.sec),
        () async {
          count++;
        },
      );
      await mix<void>(
        key: 'B',
        throttle: throttle(key: 'B', duration: 5.sec),
        () async {
          count++;
        },
      );
      await mix<void>(
        key: 'C',
        throttle: throttle(key: 'C', duration: 5.sec),
        () async {
          count++;
        },
      );

      expect(count, 3);
    });
  });

  group('throttle with lifecycle methods', () {
    test('before() not called when aborted by throttle', () async {
      var beforeCallCount = 0;

      // First call
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec),
        config: MixConfig(before: () => beforeCallCount++),
        () async {},
      );
      expect(beforeCallCount, 1);

      // Second call - should be aborted, before() should NOT be called
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec),
        config: MixConfig(before: () => beforeCallCount++),
        () async {},
      );
      expect(beforeCallCount, 1); // Still 1
    });

    test('after() not called when aborted by throttle', () async {
      var afterCallCount = 0;

      // First call
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec),
        config: MixConfig(after: () => afterCallCount++),
        () async {},
      );
      expect(afterCallCount, 1);

      // Second call - should be aborted, after() should NOT be called
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec),
        config: MixConfig(after: () => afterCallCount++),
        () async {},
      );
      expect(afterCallCount, 1); // Still 1
    });

    test('catchError() not called when aborted by throttle', () async {
      var catchErrorCallCount = 0;

      // First call
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec),
        config: MixConfig(catchError: (e, s) {
          catchErrorCallCount++;
          throw e;
        }),
        () async {},
      );

      // Second call - should be aborted, catchError() should NOT be called
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec),
        config: MixConfig(catchError: (e, s) {
          catchErrorCallCount++;
          throw e;
        }),
        () async {
          throw Exception('Should not run');
        },
      );

      expect(catchErrorCallCount, 0);
    });

    test('wrapRun() not called when aborted by throttle', () async {
      var wrapRunCallCount = 0;

      // First call
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec),
        config: MixConfig(wrapRun: (action) {
          wrapRunCallCount++;
          return action();
        }),
        () async {},
      );
      expect(wrapRunCallCount, 1);

      // Second call - should be aborted, wrapRun() should NOT be called
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec),
        config: MixConfig(wrapRun: (action) {
          wrapRunCallCount++;
          return action();
        }),
        () async {},
      );
      expect(wrapRunCallCount, 1); // Still 1
    });
  });

  group('throttle combined with retry', () {
    test('retry works with throttle', () async {
      var attemptCount = 0;

      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec),
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

    test('throttle lock remains after all retries exhausted (default)', () async {
      var secondRan = false;

      // First call fails after retries
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec),
        retry: retry(
          maxRetries: 1,
          initialDelay: Duration(milliseconds: 10),
          multiplier: 2.0,
          maxDelay: Duration(seconds: 1),
          onRetry: null,
        ),
        config: MixConfig(catchError: (e, s) {}), // Suppress error
        () async {
          throw Exception('Always fails');
        },
      );

      // Second call should be throttled (lock not removed)
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec),
        () async {
          secondRan = true;
        },
      );

      expect(secondRan, false);
    });

    test('throttle lock removed after retries exhausted with removeLockOnError', () async {
      var secondRan = false;

      // First call fails after retries
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec, removeLockOnError: true),
        retry: retry(
          maxRetries: 1,
          initialDelay: Duration(milliseconds: 10),
          multiplier: 2.0,
          maxDelay: Duration(seconds: 1),
          onRetry: null,
        ),
        config: MixConfig(catchError: (e, s) {}), // Suppress error
        () async {
          throw Exception('Always fails');
        },
      );

      // Second call should run (lock was removed)
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec, removeLockOnError: true),
        () async {
          secondRan = true;
        },
      );

      expect(secondRan, true);
    });

    test('successful retry keeps throttle lock', () async {
      var attemptCount = 0;
      var secondRan = false;

      // First call succeeds on retry
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec),
        retry: retry(
          maxRetries: 2,
          initialDelay: Duration(milliseconds: 10),
          multiplier: 2.0,
          maxDelay: Duration(seconds: 1),
          onRetry: null,
        ),
        () async {
          attemptCount++;
          if (attemptCount < 2) {
            throw Exception('Fail once');
          }
        },
      );
      expect(attemptCount, 2);

      // Second call should be throttled (first succeeded)
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec),
        () async {
          secondRan = true;
        },
      );

      expect(secondRan, false);
    });
  });

  group('throttle combined with nonReentrant', () {
    test('both throttle and nonReentrant work together', () async {
      final completer = Completer<void>();
      var count = 0;

      // Start first call (blocked by completer)
      final future1 = mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec),
        nonReentrant: nonReentrant(key: 'test'),
        () async {
          count++;
          await completer.future;
        },
      );

      // Give first call time to start
      await Future.delayed(const Duration(milliseconds: 10));

      // Second call should be aborted by nonReentrant (still running)
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec),
        nonReentrant: nonReentrant(key: 'test'),
        () async {
          count++;
        },
      );
      expect(count, 1);

      // Complete first call
      completer.complete();
      await future1;

      // Third call should be aborted by throttle (completed successfully)
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec),
        nonReentrant: nonReentrant(key: 'test'),
        () async {
          count++;
        },
      );
      expect(count, 1); // Still 1 - aborted by throttle
    });

    test('nonReentrant check happens before throttle check', () async {
      final completer = Completer<void>();
      var count = 0;

      // First call sets throttle and is running
      final future1 = mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec),
        nonReentrant: nonReentrant(key: 'test'),
        () async {
          count++;
          await completer.future;
        },
      );

      // Give first call time to start
      await Future.delayed(const Duration(milliseconds: 10));

      // Second call is aborted by nonReentrant (before throttle check)
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec),
        nonReentrant: nonReentrant(key: 'test'),
        () async {
          count++;
        },
      );

      // Complete first
      completer.complete();
      await future1;

      expect(count, 1);
    });

    test('nonReentrant releases on failure but throttle remains (default)', () async {
      var count = 0;

      // First call fails
      try {
        await mix<void>(
          key: 'test',
          throttle: throttle(key: 'test', duration: 1.sec),
          nonReentrant: nonReentrant(key: 'test'),
          () async {
            throw Exception('Failed');
          },
        );
      } catch (_) {
        // Expected
      }

      // Second call should be aborted by throttle (not nonReentrant)
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec),
        nonReentrant: nonReentrant(key: 'test'),
        () async {
          count++;
        },
      );

      expect(count, 0); // Throttle blocks it
    });
  });

  group('throttle combined with fresh', () {
    test('throttle and fresh work together', () async {
      var count = 0;

      // First call sets both throttle and fresh
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 100.millis),
        fresh: fresh(key: 'test', freshFor: 1.sec),
        () async {
          count++;
        },
      );
      expect(count, 1);

      // Second call should be aborted by throttle (before fresh check)
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 100.millis),
        fresh: fresh(key: 'test', freshFor: 1.sec),
        () async {
          count++;
        },
      );
      expect(count, 1);

      // Wait for throttle to expire
      await Future.delayed(const Duration(milliseconds: 110));

      // Third call should be aborted by fresh (throttle expired)
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 100.millis),
        fresh: fresh(key: 'test', freshFor: 1.sec),
        () async {
          count++;
        },
      );
      expect(count, 1);
    });

    test('throttle check happens before fresh check', () async {
      var count = 0;

      // First call
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec),
        fresh: fresh(key: 'test', freshFor: 100.millis),
        () async {
          count++;
        },
      );
      expect(count, 1);

      // Fresh would have expired, but throttle still blocks
      await Future.delayed(const Duration(milliseconds: 110));

      // Still blocked by throttle
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec),
        fresh: fresh(key: 'test', freshFor: 100.millis),
        () async {
          count++;
        },
      );
      expect(count, 1);
    });

    test('fresh rolls back on error but throttle remains (default)', () async {
      var count = 0;

      // First call fails
      try {
        await mix<void>(
          key: 'test',
          throttle: throttle(key: 'test', duration: 1.sec),
          fresh: fresh(key: 'test', freshFor: 1.sec),
          () async {
            throw Exception('Failed');
          },
        );
      } catch (_) {
        // Expected
      }

      // Second call should be aborted by throttle (not fresh - it rolled back)
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec),
        fresh: fresh(key: 'test', freshFor: 1.sec),
        () async {
          count++;
        },
      );

      expect(count, 0);
    });

    test('different keys for throttle and fresh', () async {
      var count = 0;

      // First call with throttle key 'throttleA' and fresh key 'freshA'
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'throttleA', duration: 100.millis),
        fresh: fresh(key: 'freshA', freshFor: 1.sec),
        () async {
          count++;
        },
      );
      expect(count, 1);

      // Wait for throttle to expire
      await Future.delayed(const Duration(milliseconds: 110));

      // Different throttle key but same fresh key - blocked by fresh
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'throttleB', duration: 100.millis),
        fresh: fresh(key: 'freshA', freshFor: 1.sec),
        () async {
          count++;
        },
      );
      expect(count, 1);
    });
  });

  group('return value handling', () {
    test('returns action result on success', () async {
      final result = await mix<int>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec),
        () async => 42,
      );

      expect(result, 42);
    });

    test('returns null when aborted by throttle', () async {
      // First call
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec),
        () async {},
      );

      // Second call is aborted
      final result = await mix<int?>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec),
        () async => 100,
      );

      expect(result, null);
    });
  });

  group('async actions', () {
    test('throttle is set before async action completes', () async {
      final completer = Completer<void>();
      var firstStarted = false;
      var secondRan = false;

      // Start first action (waiting on completer)
      final future1 = mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec),
        () async {
          firstStarted = true;
          await completer.future;
        },
      );

      // Give first call time to start
      await Future.delayed(const Duration(milliseconds: 10));
      expect(firstStarted, true);

      // Second action should be aborted (throttle already set)
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec),
        () async {
          secondRan = true;
        },
      );
      expect(secondRan, false);

      // Complete first action
      completer.complete();
      await future1;
    });

    test('multiple async actions with different keys can run concurrently', () async {
      final completerA = Completer<void>();
      final completerB = Completer<void>();
      var countA = 0;
      var countB = 0;

      // Start first action with key 'A'
      final futureA = mix<void>(
        key: 'A',
        throttle: throttle(key: 'A', duration: 1.sec),
        () async {
          countA++;
          await completerA.future;
        },
      );

      // Start second action with key 'B'
      final futureB = mix<void>(
        key: 'B',
        throttle: throttle(key: 'B', duration: 1.sec),
        () async {
          countB++;
          await completerB.future;
        },
      );

      // Give calls time to start
      await Future.delayed(const Duration(milliseconds: 10));

      // Both should have started
      expect(countA, 1);
      expect(countB, 1);

      // Complete both
      completerA.complete();
      completerB.complete();
      await futureA;
      await futureB;
    });
  });

  group('sync actions', () {
    test('sync throttle action completes immediately', () async {
      var ran = false;

      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec),
        () {
          ran = true;
        },
      );

      expect(ran, true);
    });

    test('sync action sets throttle correctly', () async {
      var count = 0;

      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec),
        () {
          count++;
        },
      );

      // Second call should be aborted
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec),
        () {
          count++;
        },
      );

      expect(count, 1);
    });
  });

  group('pruning expired locks', () {
    test('expired locks are pruned after action completes', () async {
      // First action with short throttle
      await mix<void>(
        key: 'shortKey',
        throttle: throttle(key: 'shortKey', duration: 50.millis),
        () async {},
      );

      // Wait for expiry
      await Future.delayed(const Duration(milliseconds: 60));

      // Second action triggers pruning
      await mix<void>(
        key: 'otherKey',
        throttle: throttle(key: 'otherKey', duration: 1.sec),
        () async {},
      );

      // Verify shortKey was pruned by running again - should succeed
      var ran = false;
      await mix<void>(
        key: 'shortKey',
        throttle: throttle(key: 'shortKey', duration: 50.millis),
        () async {
          ran = true;
        },
      );

      expect(ran, true);
    });
  });

  group('edge cases', () {
    test('exact expiry time is treated as expired', () async {
      var count = 0;

      // Use very short throttle
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 50.millis),
        () async {
          count++;
        },
      );
      expect(count, 1);

      // Wait exactly until expiry
      await Future.delayed(const Duration(milliseconds: 50));

      // Should be able to run - isAfter(now) returns false when now >= expiresAt
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 50.millis),
        () async {
          count++;
        },
      );

      expect(count, 2);
    });

    test('throttle of 0 allows immediate re-dispatch', () async {
      var count = 0;

      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 0.millis),
        () async {
          count++;
        },
      );
      expect(count, 1);

      // Second call should also run (throttle: 0 expires immediately)
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 0.millis),
        () async {
          count++;
        },
      );
      expect(count, 2);
    });

    test('very long throttle works correctly', () async {
      var count = 0;

      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: Duration(hours: 1)), // 1 hour
        () async {
          count++;
        },
      );
      expect(count, 1);

      // Should be aborted
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: Duration(hours: 1)),
        () async {
          count++;
        },
      );
      expect(count, 1);
    });

    test('empty string key works', () async {
      var count = 0;

      await mix<void>(
        key: '',
        throttle: throttle(key: '', duration: 1.sec),
        () async {
          count++;
        },
      );

      await mix<void>(
        key: '',
        throttle: throttle(key: '', duration: 1.sec),
        () async {
          count++;
        },
      );

      expect(count, 1); // Second should be aborted
    });

    test('special characters in key work', () async {
      var count = 0;

      await mix<void>(
        key: 'user:123/action?type=refresh',
        throttle: throttle(key: 'user:123/action?type=refresh', duration: 1.sec),
        () async {
          count++;
        },
      );

      await mix<void>(
        key: 'user:123/action?type=refresh',
        throttle: throttle(key: 'user:123/action?type=refresh', duration: 1.sec),
        () async {
          count++;
        },
      );

      expect(count, 1); // Second should be aborted
    });

    test('unicode key works', () async {
      var count = 0;

      await mix<void>(
        key: '用户_データ_🎉',
        throttle: throttle(key: '用户_データ_🎉', duration: 1.sec),
        () async {
          count++;
        },
      );

      await mix<void>(
        key: '用户_データ_🎉',
        throttle: throttle(key: '用户_データ_🎉', duration: 1.sec),
        () async {
          count++;
        },
      );

      expect(count, 1); // Second should be aborted
    });
  });

  group('throttle map lazy initialization', () {
    test('throttle map is lazily created on first use', () async {
      Superpowers.clear();

      // Verify no throttle map exists
      expect(Superpowers.prop<Map<Object, DateTime>?>('_mix_throttleLockMap'), isNull);

      // First call creates the map
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec),
        () async {},
      );

      // Now map should exist
      expect(Superpowers.prop<Map<Object, DateTime>?>('_mix_throttleLockMap'), isNotNull);
    });
  });

  group('throttle with wrapRun', () {
    test('wrapRun is called for throttle action', () async {
      var wrapRunCalled = false;

      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec),
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
        throttle: throttle(key: 'test', duration: 1.sec),
        config: MixConfig(wrapRun: (action) async {
          final r = await action();
          return r + 100;
        }),
        () async => 42,
      );

      expect(result, 142);
    });

    test('wrapRun error respects removeLockOnError', () async {
      var secondRan = false;

      // First call's wrapRun throws, with removeLockOnError=true
      try {
        await mix<void>(
          key: 'test',
          throttle: throttle(key: 'test', duration: 1.sec, removeLockOnError: true),
          config: MixConfig(wrapRun: (action) {
            throw Exception('WrapRun failed');
          }),
          () async {},
        );
      } catch (_) {
        // Expected
      }

      // Second call should run (lock was removed)
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec, removeLockOnError: true),
        () async {
          secondRan = true;
        },
      );

      expect(secondRan, true);
    });
  });

  group('stress tests', () {
    test('many different keys can be tracked', () async {
      // Create 100 different throttle keys
      for (var i = 0; i < 100; i++) {
        await mix<void>(
          key: 'key_$i',
          throttle: throttle(key: 'key_$i', duration: 5.sec),
          () async {},
        );
      }

      // All should be throttled, second calls should be aborted
      var ranCount = 0;
      for (var i = 0; i < 100; i++) {
        await mix<void>(
          key: 'key_$i',
          throttle: throttle(key: 'key_$i', duration: 5.sec),
          () async {
            ranCount++;
          },
        );
      }

      expect(ranCount, 0); // All should have been aborted
    });

    test('rapid sequential calls to same key', () async {
      var count = 0;

      // First call
      await mix<void>(
        key: 'rapid',
        throttle: throttle(key: 'rapid', duration: 1.sec),
        () async {
          count++;
        },
      );

      // 50 rapid calls
      for (var i = 0; i < 50; i++) {
        await mix<void>(
          key: 'rapid',
          throttle: throttle(key: 'rapid', duration: 1.sec),
          () async {
            count++;
          },
        );
      }

      expect(count, 1); // Only first should have run
    });
  });

  group('chained throttle behavior', () {
    test('throttle resets after expiry allowing new sequence', () async {
      var count = 0;

      // First sequence
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 30.millis),
        () async {
          count++;
        },
      );
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 30.millis),
        () async {
          count++;
        },
      ); // Throttled
      expect(count, 1);

      // Wait for expiry
      await Future.delayed(const Duration(milliseconds: 40));

      // Second sequence - should start fresh
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 30.millis),
        () async {
          count++;
        },
      );
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 30.millis),
        () async {
          count++;
        },
      ); // Throttled again
      expect(count, 2);

      // Wait and dispatch one more
      await Future.delayed(const Duration(milliseconds: 40));
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 30.millis),
        () async {
          count++;
        },
      );
      expect(count, 3);
    });
  });

  group('all three protections together', () {
    test('nonReentrant, throttle, and fresh all work together', () async {
      final completer = Completer<void>();
      var count = 0;

      // Start first call (blocked by completer)
      final future1 = mix<void>(
        key: 'test',
        nonReentrant: nonReentrant(key: 'test'),
        throttle: throttle(key: 'test', duration: 100.millis),
        fresh: fresh(key: 'test', freshFor: 1.sec),
        () async {
          count++;
          await completer.future;
        },
      );

      // Give first call time to start
      await Future.delayed(const Duration(milliseconds: 10));

      // Second call blocked by nonReentrant
      await mix<void>(
        key: 'test',
        nonReentrant: nonReentrant(key: 'test'),
        throttle: throttle(key: 'test', duration: 100.millis),
        fresh: fresh(key: 'test', freshFor: 1.sec),
        () async {
          count++;
        },
      );
      expect(count, 1);

      // Complete first call
      completer.complete();
      await future1;

      // Third call blocked by throttle
      await mix<void>(
        key: 'test',
        nonReentrant: nonReentrant(key: 'test'),
        throttle: throttle(key: 'test', duration: 100.millis),
        fresh: fresh(key: 'test', freshFor: 1.sec),
        () async {
          count++;
        },
      );
      expect(count, 1);

      // Wait for throttle to expire
      await Future.delayed(const Duration(milliseconds: 110));

      // Fourth call blocked by fresh
      await mix<void>(
        key: 'test',
        nonReentrant: nonReentrant(key: 'test'),
        throttle: throttle(key: 'test', duration: 100.millis),
        fresh: fresh(key: 'test', freshFor: 1.sec),
        () async {
          count++;
        },
      );
      expect(count, 1);
    });
  });

  group('ignoreThrottle parameter', () {
    test('ignoreThrottle bypasses throttle check', () async {
      var count = 0;

      // First call - sets throttle lock
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec),
        () async {
          count++;
        },
      );
      expect(count, 1);

      // Second call with ignoreThrottle: true - should run despite lock
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec, ignoreThrottle: true),
        () async {
          count++;
        },
      );
      expect(count, 2);
    });

    test('ignoreThrottle: true sets new lock after running', () async {
      var count = 0;

      // First call - sets throttle lock
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec),
        () async {
          count++;
        },
      );
      expect(count, 1);

      // Second call with ignoreThrottle: true - runs and resets lock
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec, ignoreThrottle: true),
        () async {
          count++;
        },
      );
      expect(count, 2);

      // Third call without ignoreThrottle - should still be blocked by new lock
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec),
        () async {
          count++;
        },
      );
      expect(count, 2);
    });

    test('ignoreThrottle: false behaves same as null', () async {
      var count = 0;

      // First call - sets throttle lock
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec),
        () async {
          count++;
        },
      );
      expect(count, 1);

      // Second call with ignoreThrottle: false - should be blocked
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec, ignoreThrottle: false),
        () async {
          count++;
        },
      );
      expect(count, 1);
    });

    test('ignoreThrottle works when no existing lock', () async {
      var count = 0;

      // Call with ignoreThrottle: true when no lock exists
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec, ignoreThrottle: true),
        () async {
          count++;
        },
      );
      expect(count, 1);
    });

    test('ignoreThrottle: true respects removeLockOnError on failure', () async {
      var secondRan = false;

      // First call with ignoreThrottle: true fails
      try {
        await mix<void>(
          key: 'test',
          throttle: throttle(key: 'test', duration: 1.sec, removeLockOnError: true, ignoreThrottle: true),
          () async {
            throw Exception('Failed');
          },
        );
      } catch (_) {
        // Expected
      }

      // Second call should run (lock was removed on error)
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec),
        () async {
          secondRan = true;
        },
      );
      expect(secondRan, true);
    });

    test('ignoreThrottle: true with different throttle durations', () async {
      var count = 0;

      // First call with long throttle
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 5.sec),
        () async {
          count++;
        },
      );
      expect(count, 1);

      // Second call with short throttle and ignoreThrottle - should run and set short lock
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 50.millis, ignoreThrottle: true),
        () async {
          count++;
        },
      );
      expect(count, 2);

      // Third call immediately - still blocked by short lock
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 50.millis),
        () async {
          count++;
        },
      );
      expect(count, 2);

      // Wait for short lock to expire
      await Future.delayed(const Duration(milliseconds: 60));

      // Fourth call should run
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 50.millis),
        () async {
          count++;
        },
      );
      expect(count, 3);
    });
  });

  group('removeThrottleLock function', () {
    test('removeThrottleLock removes specific lock', () async {
      var count = 0;

      // Set throttle lock
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 5.sec),
        () async {
          count++;
        },
      );
      expect(count, 1);

      // Remove the lock
      removeThrottleLock('test');

      // Next call should run
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 5.sec),
        () async {
          count++;
        },
      );
      expect(count, 2);
    });

    test('removeThrottleLock only removes specified key', () async {
      var countA = 0;
      var countB = 0;

      // Set throttle locks for both keys
      await mix<void>(
        key: 'A',
        throttle: throttle(key: 'A', duration: 5.sec),
        () async {
          countA++;
        },
      );
      await mix<void>(
        key: 'B',
        throttle: throttle(key: 'B', duration: 5.sec),
        () async {
          countB++;
        },
      );
      expect(countA, 1);
      expect(countB, 1);

      // Remove only key 'A'
      removeThrottleLock('A');

      // Key 'A' should run
      await mix<void>(
        key: 'A',
        throttle: throttle(key: 'A', duration: 5.sec),
        () async {
          countA++;
        },
      );
      expect(countA, 2);

      // Key 'B' should still be blocked
      await mix<void>(
        key: 'B',
        throttle: throttle(key: 'B', duration: 5.sec),
        () async {
          countB++;
        },
      );
      expect(countB, 1);
    });

    test('removeThrottleLock is safe when key does not exist', () async {
      // Should not throw
      removeThrottleLock('nonexistent');
    });

    test('removeThrottleLock can be called from another action', () async {
      var refreshCount = 0;

      // Set throttle lock for refresh
      await mix<void>(
        key: 'refresh',
        throttle: throttle(key: 'refresh', duration: 5.sec),
        () async {
          refreshCount++;
        },
      );
      expect(refreshCount, 1);

      // User action clears throttle lock
      await mix<void>(key: 'clear', () async {
        removeThrottleLock('refresh');
      });

      // Refresh should run now
      await mix<void>(
        key: 'refresh',
        throttle: throttle(key: 'refresh', duration: 5.sec),
        () async {
          refreshCount++;
        },
      );
      expect(refreshCount, 2);
    });
  });

  group('removeAllThrottleLocks function', () {
    test('removeAllThrottleLocks removes all locks', () async {
      var countA = 0;
      var countB = 0;
      var countC = 0;

      // Set multiple throttle locks
      await mix<void>(
        key: 'A',
        throttle: throttle(key: 'A', duration: 5.sec),
        () async {
          countA++;
        },
      );
      await mix<void>(
        key: 'B',
        throttle: throttle(key: 'B', duration: 5.sec),
        () async {
          countB++;
        },
      );
      await mix<void>(
        key: 'C',
        throttle: throttle(key: 'C', duration: 5.sec),
        () async {
          countC++;
        },
      );

      // Remove all locks
      removeAllThrottleLocks();

      // All should run now
      await mix<void>(
        key: 'A',
        throttle: throttle(key: 'A', duration: 5.sec),
        () async {
          countA++;
        },
      );
      await mix<void>(
        key: 'B',
        throttle: throttle(key: 'B', duration: 5.sec),
        () async {
          countB++;
        },
      );
      await mix<void>(
        key: 'C',
        throttle: throttle(key: 'C', duration: 5.sec),
        () async {
          countC++;
        },
      );

      expect(countA, 2);
      expect(countB, 2);
      expect(countC, 2);
    });

    test('removeAllThrottleLocks is safe when no locks exist', () async {
      Superpowers.clear();

      // Should not throw
      removeAllThrottleLocks();
    });

    test('removeAllThrottleLocks can be called from logout action', () async {
      var loadCount = 0;
      var syncCount = 0;

      // Set multiple throttle locks
      await mix<void>(
        key: 'loadData',
        throttle: throttle(key: 'loadData', duration: 5.sec),
        () async {
          loadCount++;
        },
      );
      await mix<void>(
        key: 'syncData',
        throttle: throttle(key: 'syncData', duration: 5.sec),
        () async {
          syncCount++;
        },
      );

      // Logout action clears all locks
      await mix<void>(key: 'logout', () async {
        // Simulating logout
        removeAllThrottleLocks();
      });

      // After login, all actions should be able to run
      await mix<void>(
        key: 'loadData',
        throttle: throttle(key: 'loadData', duration: 5.sec),
        () async {
          loadCount++;
        },
      );
      await mix<void>(
        key: 'syncData',
        throttle: throttle(key: 'syncData', duration: 5.sec),
        () async {
          syncCount++;
        },
      );

      expect(loadCount, 2);
      expect(syncCount, 2);
    });
  });

  group('onThrottled callback', () {
    test('onThrottled is called when a call is throttled', () async {
      Object? throttledKey;
      Duration? throttledRemaining;
      var throttledCount = 0;

      // First call - runs
      await mix<void>(
        key: 'test',
        throttle: throttle(
          key: 'testKey',
          duration: 1.sec,
          onThrottled: (key, remaining) {
            throttledKey = key;
            throttledRemaining = remaining;
            throttledCount++;
          },
        ),
        () async {},
      );

      expect(throttledCount, 0); // Not throttled

      // Second call - should be throttled
      await mix<void>(
        key: 'test',
        throttle: throttle(
          key: 'testKey',
          duration: 1.sec,
          onThrottled: (key, remaining) {
            throttledKey = key;
            throttledRemaining = remaining;
            throttledCount++;
          },
        ),
        () async {},
      );

      expect(throttledCount, 1);
      expect(throttledKey, 'testKey');
      expect(throttledRemaining, isNotNull);
      expect(throttledRemaining!.inMilliseconds, greaterThan(0));
      expect(throttledRemaining!.inMilliseconds, lessThanOrEqualTo(1000));
    });

    test('onThrottled is not called when the call runs', () async {
      var throttledCount = 0;

      await mix<void>(
        key: 'test',
        throttle: throttle(
          key: 'testKey',
          duration: 1.sec,
          onThrottled: (key, remaining) {
            throttledCount++;
          },
        ),
        () async {},
      );

      expect(throttledCount, 0);
    });

    test('onThrottled receives accurate remaining time', () async {
      Duration? firstRemaining;
      Duration? secondRemaining;

      // First call sets throttle
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 500.millis),
        () async {},
      );

      // Immediate second call
      await mix<void>(
        key: 'test',
        throttle: throttle(
          key: 'test',
          duration: 500.millis,
          onThrottled: (key, remaining) {
            firstRemaining = remaining;
          },
        ),
        () async {},
      );

      // Wait 200ms
      await Future.delayed(const Duration(milliseconds: 200));

      // Third call after 200ms
      await mix<void>(
        key: 'test',
        throttle: throttle(
          key: 'test',
          duration: 500.millis,
          onThrottled: (key, remaining) {
            secondRemaining = remaining;
          },
        ),
        () async {},
      );

      expect(firstRemaining, isNotNull);
      expect(secondRemaining, isNotNull);
      // Second remaining should be less than first (about 200ms less)
      expect(secondRemaining!.inMilliseconds, lessThan(firstRemaining!.inMilliseconds));
    });

    test('onThrottled receives the effective key', () async {
      final throttledKeys = <Object>[];

      // First call
      await mix<void>(
        key: 'test',
        throttle: throttle(key: ('refresh', 'user123'), duration: 1.sec),
        () async {},
      );

      // Second call
      await mix<void>(
        key: 'test',
        throttle: throttle(
          key: ('refresh', 'user123'),
          duration: 1.sec,
          onThrottled: (key, remaining) => throttledKeys.add(key),
        ),
        () async {},
      );

      // Third call
      await mix<void>(
        key: 'test',
        throttle: throttle(
          key: ('refresh', 'user123'),
          duration: 1.sec,
          onThrottled: (key, remaining) => throttledKeys.add(key),
        ),
        () async {},
      );

      expect(throttledKeys.length, 2);
      expect(throttledKeys[0], ('refresh', 'user123'));
      expect(throttledKeys[1], ('refresh', 'user123'));
    });

    test('onThrottled works with sync mix', () async {
      var throttledCount = 0;

      // First call
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec),
        () {},
      );

      // Second call should be throttled
      await mix<void>(
        key: 'test',
        throttle: throttle(
          key: 'test',
          duration: 1.sec,
          onThrottled: (key, remaining) => throttledCount++,
        ),
        () {},
      );

      expect(throttledCount, 1);
    });

    test('onThrottled works with mix.ctx', () async {
      var throttledCount = 0;

      // First call
      await mix.ctx<void>(
        (ctx) async {},
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec),
      );

      // Second call should be throttled
      await mix.ctx<void>(
        (ctx) async {},
        key: 'test',
        throttle: throttle(
          key: 'test',
          duration: 1.sec,
          onThrottled: (key, remaining) => throttledCount++,
        ),
      );

      expect(throttledCount, 1);
    });

    test('onThrottled is not called when ignoreThrottle is true', () async {
      var throttledCount = 0;

      // First call
      await mix<void>(
        key: 'test',
        throttle: throttle(key: 'test', duration: 1.sec),
        () async {},
      );

      // Second call with ignoreThrottle - should run, not trigger callback
      await mix<void>(
        key: 'test',
        throttle: throttle(
          key: 'test',
          duration: 1.sec,
          ignoreThrottle: true,
          onThrottled: (key, remaining) => throttledCount++,
        ),
        () async {},
      );

      expect(throttledCount, 0);
    });
  });
}
