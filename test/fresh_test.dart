import 'dart:async';

import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Reset Superpowers static state before each test.
  setUp(() {
    Superpowers.clear();
  });

  group('mix with fresh - basic behavior', () {
    test('allows first call to run', () async {
      var ran = false;

      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 1.sec),
        () async {
          ran = true;
        },
      );

      expect(ran, true);
    });

    test('aborts call while still fresh', () async {
      var firstRan = false;
      var secondRan = false;

      // First call runs
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 1.sec),
        () async {
          firstRan = true;
        },
      );
      expect(firstRan, true);

      // Second call is aborted (still fresh)
      final result2 = await mix<int?>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 1.sec),
        () async {
          secondRan = true;
          return 42;
        },
      );

      expect(result2, null);
      expect(secondRan, false);
    });

    test('allows call after freshness expires', () async {
      var count = 0;

      // First call
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 50.millis, ignoreFresh: null),
        // 50ms freshness
        () async {
          count++;
        },
      );
      expect(count, 1);

      // Wait for freshness to expire
      await Future.delayed(const Duration(milliseconds: 60));

      // Second call should run
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 50.millis, ignoreFresh: null),
        () async {
          count++;
        },
      );
      expect(count, 2);
    });

    test('different keys have separate freshness', () async {
      var countA = 0;
      var countB = 0;

      await mix<void>(
        key: '',
        fresh: fresh(key: 'A', freshFor: 1000.sec, ignoreFresh: null),
        () async {
          countA++;
        },
      );
      expect(countA, 1);

      // Different key should run
      await mix<void>(
        key: '',
        fresh: fresh(key: 'B', freshFor: 1000.sec, ignoreFresh: null),
        () async {
          countB++;
        },
      );
      expect(countB, 1);

      // Same key 'A' should be aborted
      await mix<void>(
        key: '',
        fresh: fresh(key: 'A', freshFor: 1000.sec, ignoreFresh: null),
        () async {
          countA++;
        },
      );
      expect(countA, 1); // Still 1
    });

    test('works without fresh (default null)', () async {
      var count = 0;

      // Multiple calls without fresh should all run
      await mix<void>(key: '', () async {
        count++;
      });
      await mix<void>(key: '', () async {
        count++;
      });
      await mix<void>(key: '', () async {
        count++;
      });

      expect(count, 3);
    });
  });

  group('fresh error rollback', () {
    test('rolls back freshness when action fails', () async {
      var secondRan = false;

      // First call fails
      try {
        await mix<void>(
          key: '',
          fresh: fresh(key: 'test', freshFor: 1.sec),
          () async {
            throw Exception('First failed');
          },
        );
      } catch (_) {
        // Expected
      }

      // Second call should run (freshness was rolled back)
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 1.sec),
        () async {
          secondRan = true;
        },
      );

      expect(secondRan, true);
    });

    test('preserves previous freshness on failure if was fresh before',
        () async {
      var count = 0;

      // First successful action with long freshness
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 5.sec, ignoreFresh: null),
        () async {
          count++;
        },
      );
      expect(count, 1);

      // Second call should be aborted (still fresh)
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 5.sec, ignoreFresh: null),
        () async {
          count++;
        },
      );
      expect(count, 1); // Still 1
    });

    test('rollback only happens if our expiry is still in the map', () async {
      final completer1 = Completer<void>();
      var count = 0;

      // Start first call that will fail eventually
      final future1 = mix<void>(
        key: '',
        fresh: fresh(key: 'test', freshFor: 5.sec, ignoreFresh: null),
        () async {
          await completer1.future;
          throw Exception('First failed');
        },
      );

      // Give first call time to start
      await Future.delayed(const Duration(milliseconds: 10));

      // Reset Superpowers to clear the fresh map
      Superpowers.clear();

      // Start a new fresh action with same key (this sets a new expiry)
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 5.sec, ignoreFresh: null),
        () async {
          count++;
        },
      );
      expect(count, 1);

      // Complete first call (it fails)
      completer1.complete();
      try {
        await future1;
      } catch (_) {
        // Expected
      }

      // Third call should be aborted (fresh from second call, not rolled back by first)
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 5.sec, ignoreFresh: null),
        () async {
          count++;
        },
      );
      expect(count, 1); // Still 1
    });

    test('rollback happens when catchError suppresses error', () async {
      var secondRan = false;

      // First call fails but error is suppressed
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 1.sec),
        config: MixConfig(catchError: (e, s) {}), // Suppress error
        () async {
          throw Exception('First failed');
        },
      );

      // Second call should run (freshness was rolled back)
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 1.sec),
        () async {
          secondRan = true;
        },
      );

      expect(secondRan, true);
    });

    test('rollback happens when catchError converts to UserException', () async {
      var secondRan = false;

      // First call fails with UserException
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 1.sec),
        config: MixConfig(catchError: (e, s) => throw UserException('User error')),
        () async {
          throw Exception('First failed');
        },
      );

      // Second call should run (freshness was rolled back)
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 1.sec),
        () async {
          secondRan = true;
        },
      );

      expect(secondRan, true);
    });
  });

  group('Superpowers.clear() clears fresh state', () {
    test('Superpowers.clear() clears freshness', () async {
      var count = 0;

      // First call
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 5.sec, ignoreFresh: null),
        () async {
          count++;
        },
      );
      expect(count, 1);

      // Reset Superpowers state
      Superpowers.clear();

      // Second call should run (freshness was cleared)
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 5.sec, ignoreFresh: null),
        () async {
          count++;
        },
      );
      expect(count, 2);
    });

    test('Superpowers.clear() clears multiple fresh keys', () async {
      // Set up multiple fresh keys
      await mix<void>(
        key: '',
        fresh: fresh(key: 'A', freshFor: 5.sec, ignoreFresh: null),
        () async {},
      );
      await mix<void>(
        key: '',
        fresh: fresh(key: 'B', freshFor: 5.sec, ignoreFresh: null),
        () async {},
      );
      await mix<void>(
        key: '',
        fresh: fresh(key: 'C', freshFor: 5.sec, ignoreFresh: null),
        () async {},
      );

      // Reset
      Superpowers.clear();

      // All should run now
      var count = 0;
      await mix<void>(
        key: '',
        fresh: fresh(key: 'A', freshFor: 5.sec, ignoreFresh: null),
        () async {
          count++;
        },
      );
      await mix<void>(
        key: '',
        fresh: fresh(key: 'B', freshFor: 5.sec, ignoreFresh: null),
        () async {
          count++;
        },
      );
      await mix<void>(
        key: '',
        fresh: fresh(key: 'C', freshFor: 5.sec, ignoreFresh: null),
        () async {
          count++;
        },
      );

      expect(count, 3);
    });
  });

  group('fresh with lifecycle methods', () {
    test('before() not called when aborted by fresh', () async {
      var beforeCallCount = 0;

      // First call
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 1.sec),
        config: MixConfig(before: () => beforeCallCount++),
        () async {},
      );
      expect(beforeCallCount, 1);

      // Second call - should be aborted, before() should NOT be called
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 1.sec),
        config: MixConfig(before: () => beforeCallCount++),
        () async {},
      );
      expect(beforeCallCount, 1); // Still 1
    });

    test('after() not called when aborted by fresh', () async {
      var afterCallCount = 0;

      // First call
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 1.sec),
        config: MixConfig(after: () => afterCallCount++),
        () async {},
      );
      expect(afterCallCount, 1);

      // Second call - should be aborted, after() should NOT be called
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 1.sec),
        config: MixConfig(after: () => afterCallCount++),
        () async {},
      );
      expect(afterCallCount, 1); // Still 1
    });

    test('catchError() not called when aborted by fresh', () async {
      var catchErrorCallCount = 0;

      // First call
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 1.sec),
        config: MixConfig(catchError: (e, s) {
          catchErrorCallCount++;
          throw e;
        }),
        () async {},
      );

      // Second call - should be aborted, catchError() should NOT be called
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 1.sec),
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

    test('wrapRun() not called when aborted by fresh', () async {
      var wrapRunCallCount = 0;

      // First call
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 1.sec),
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
        fresh: fresh(key: 'test', freshFor: 1.sec),
        config: MixConfig(wrapRun: (action) {
          wrapRunCallCount++;
          return action();
        }),
        () async {},
      );
      expect(wrapRunCallCount, 1); // Still 1
    });

    test('before() failure triggers fresh rollback', () async {
      var secondRan = false;

      // First call's before() fails
      try {
        await mix<void>(
          key: '',
          fresh: fresh(key: 'test', freshFor: 1.sec),
          config: MixConfig(before: () {
            throw Exception('Before failed');
          }),
          () async {},
        );
      } catch (_) {
        // Expected
      }

      // Second call should run (freshness was rolled back)
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 1.sec),
        () async {
          secondRan = true;
        },
      );

      expect(secondRan, true);
    });
  });

  group('fresh combined with retry', () {
    test('retry works with fresh', () async {
      var attemptCount = 0;

      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 1.sec),
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

    test('fresh rollback happens after all retries exhausted', () async {
      var secondRan = false;

      // First call fails after retries
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 1.sec),
        retry: retry(
          maxRetries: 1,
          initialDelay: Duration(milliseconds: 10),
          multiplier: 2.0,
          maxDelay: Duration(seconds: 1),
          onRetry: null,
        ),
        config: MixConfig(catchError: (e, s) {}),
        // Suppress error
        () async {
          throw Exception('Always fails');
        },
      );

      // Second call should run (freshness was rolled back after failure)
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 1.sec),
        () async {
          secondRan = true;
        },
      );

      expect(secondRan, true);
    });

    test('successful retry keeps freshness', () async {
      var attemptCount = 0;
      var secondRan = false;

      // First call succeeds on retry
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 1.sec),
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

      // Second call should be aborted (first succeeded, still fresh)
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 1.sec),
        () async {
          secondRan = true;
        },
      );

      expect(secondRan, false);
    });

    test('onRetry callback is called during fresh action retries', () async {
      var retryCount = 0;

      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 1.sec),
        retry: retry(
          maxRetries: 2,
          initialDelay: Duration(milliseconds: 10),
          multiplier: 2.0,
          maxDelay: Duration(seconds: 1),
          onRetry: (attempt, delay, error, stack) {
            retryCount = attempt;
          },
        ),
        () async {
          if (retryCount < 2) {
            throw Exception('Retry me');
          }
        },
      );

      expect(retryCount, 2);
    });
  });

  group('fresh combined with nonReentrant', () {
    test('both fresh and nonReentrant work together', () async {
      final completer = Completer<void>();
      var count = 0;

      // Start first call (blocked by completer)
      final future1 = mix<void>(
        key: '',
        fresh: fresh(key: 'test', freshFor: 1.sec),
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
        fresh: fresh(key: 'test', freshFor: 1.sec),
        nonReentrant: nonReentrant(key: 'test'),
        () async {
          count++;
        },
      );
      expect(count, 1);

      // Complete first call
      completer.complete();
      await future1;

      // Third call should be aborted by fresh (completed successfully)
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 1.sec),
        nonReentrant: nonReentrant(key: 'test'),
        () async {
          count++;
        },
      );
      expect(count, 1); // Still 1 - aborted by fresh
    });

    test('nonReentrant check happens before fresh check', () async {
      final completer = Completer<void>();
      var count = 0;

      // First call sets fresh and is running
      final future1 = mix<void>(
        key: '',
        fresh: fresh(key: 'test', freshFor: 1.sec),
        nonReentrant: nonReentrant(key: 'test'),
        () async {
          count++;
          await completer.future;
        },
      );

      // Give first call time to start
      await Future.delayed(const Duration(milliseconds: 10));

      // Second call is aborted by nonReentrant (before fresh check)
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 1.sec),
        nonReentrant: nonReentrant(key: 'test'),
        () async {
          count++;
        },
      );

      // Complete first
      completer.complete();
      await future1;

      // nonReentrant is released, but fresh is still active
      expect(count, 1);
    });

    test('different keys for fresh and nonReentrant', () async {
      final completer = Completer<void>();
      var count = 0;

      // First call with fresh key 'freshA' and nonReentrant key 'nrA'
      final future1 = mix<void>(
        key: '',
        fresh: fresh(key: 'freshA', freshFor: 1000.sec, ignoreFresh: null),
        nonReentrant: nonReentrant(key: 'nrA'),
        () async {
          count++;
          await completer.future;
        },
      );

      // Give first call time to start
      await Future.delayed(const Duration(milliseconds: 10));

      // Second call with same fresh key but different nonReentrant key
      // Should NOT be blocked by nonReentrant, but IS blocked by fresh
      await mix<void>(
        key: '',
        fresh: fresh(key: 'freshA', freshFor: 1000.sec, ignoreFresh: null),
        nonReentrant: nonReentrant(key: 'nrB'),
        () async {
          count++;
        },
      );
      expect(count, 1); // Blocked by fresh check

      // Complete first
      completer.complete();
      await future1;
    });

    test('nonReentrant releases on failure but fresh rolls back', () async {
      final completer = Completer<void>();
      var count = 0;

      // First call will fail
      try {
        await mix<void>(
          key: '',
          fresh: fresh(key: 'test', freshFor: 1.sec),
          nonReentrant: nonReentrant(key: 'test'),
          () async {
            throw Exception('Failed');
          },
        );
      } catch (_) {
        // Expected
      }

      // Second call should run - both nonReentrant released AND fresh rolled back
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 1.sec),
        nonReentrant: nonReentrant(key: 'test'),
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
        key: '',
        fresh: fresh(key: 'test', freshFor: 1.sec),
        () async => 42,
      );

      expect(result, 42);
    });

    test('returns null when aborted by fresh', () async {
      // First call
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 1.sec),
        () async {},
      );

      // Second call is aborted
      final result = await mix<int?>(
        key: '',
        fresh: fresh(key: 'test', freshFor: 1.sec),
        () async => 100,
      );

      expect(result, null);
    });

    test('returns correct type when aborted', () async {
      // First call
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 1.sec),
        () async {},
      );

      // Second call with String return type
      final result = await mix<String?>(
        key: '',
        fresh: fresh(key: 'test', freshFor: 1.sec),
        () async => 'hello',
      );

      expect(result, null);
    });

    test('returns action result after retries succeed', () async {
      var attempts = 0;
      final result = await mix<int>(
        key: '',
        fresh: fresh(key: 'test', freshFor: 1.sec),
        retry: retry(
          maxRetries: 2,
          initialDelay: Duration(milliseconds: 10),
          multiplier: 2.0,
          maxDelay: Duration(seconds: 1),
          onRetry: null,
        ),
        () async {
          attempts++;
          if (attempts < 2) {
            throw Exception('Fail');
          }
          return 99;
        },
      );

      expect(result, 99);
    });
  });

  group('async actions', () {
    test('freshness is set before async action completes', () async {
      final completer = Completer<void>();
      var firstStarted = false;
      var secondRan = false;

      // Start first action (waiting on completer)
      final future1 = mix<void>(
        key: '',
        fresh: fresh(key: 'test', freshFor: 1.sec),
        () async {
          firstStarted = true;
          await completer.future;
        },
      );

      // Give first call time to start
      await Future.delayed(const Duration(milliseconds: 10));
      expect(firstStarted, true);

      // Second action should be aborted (freshness already set)
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 1.sec),
        () async {
          secondRan = true;
        },
      );
      expect(secondRan, false);

      // Complete first action
      completer.complete();
      await future1;
    });

    test('multiple async actions with different keys can run concurrently',
        () async {
      final completerA = Completer<void>();
      final completerB = Completer<void>();
      var countA = 0;
      var countB = 0;

      // Start first action with key 'A'
      final futureA = mix<void>(
        key: '',
        fresh: fresh(key: 'A', freshFor: 1000.sec, ignoreFresh: null),
        () async {
          countA++;
          await completerA.future;
        },
      );

      // Start second action with key 'B'
      final futureB = mix<void>(
        key: '',
        fresh: fresh(key: 'B', freshFor: 1000.sec, ignoreFresh: null),
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
    test('sync fresh action completes immediately', () async {
      var ran = false;

      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 1.sec),
        () {
          ran = true;
        },
      );

      expect(ran, true);
    });

    test('sync fresh action sets freshness correctly', () async {
      var count = 0;

      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 1.sec),
        () {
          count++;
        },
      );

      // Second call should be aborted
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 1.sec),
        () {
          count++;
        },
      );

      expect(count, 1);
    });
  });

  group('parameterized keys', () {
    test('different params allow concurrent freshness', () async {
      var countA = 0;
      var countB = 0;

      await mix<void>(
        key: '',
        fresh: fresh(key: 'loadUser_A', freshFor: 1000.sec, ignoreFresh: null),
        () async {
          countA++;
        },
      );

      await mix<void>(
        key: '',
        fresh: fresh(key: 'loadUser_B', freshFor: 1000.sec, ignoreFresh: null),
        () async {
          countB++;
        },
      );

      // Both should run (different keys)
      expect(countA, 1);
      expect(countB, 1);
    });

    test('same params share freshness', () async {
      var count = 0;

      await mix<void>(
        key: '',
        fresh: fresh(key: 'loadUser_A', freshFor: 1000.sec, ignoreFresh: null),
        () async {
          count++;
        },
      );

      await mix<void>(
        key: '',
        fresh: fresh(key: 'loadUser_A', freshFor: 1000.sec, ignoreFresh: null),
        () async {
          count++;
        },
      );

      // Second should be aborted (same key)
      expect(count, 1);
    });

    test('parameterized keys with integer values', () async {
      var count1 = 0;
      var count2 = 0;

      await mix<void>(
        key: '',
        fresh: fresh(key: 'item_123', freshFor: 1000.sec, ignoreFresh: null),
        () async {
          count1++;
        },
      );

      await mix<void>(
        key: '',
        fresh: fresh(key: 'item_456', freshFor: 1000.sec, ignoreFresh: null),
        () async {
          count2++;
        },
      );

      // Both should run
      expect(count1, 1);
      expect(count2, 1);

      // Same key should be aborted
      await mix<void>(
        key: '',
        fresh: fresh(key: 'item_123', freshFor: 1000.sec, ignoreFresh: null),
        () async {
          count1++;
        },
      );

      expect(count1, 1); // Still 1
    });
  });

  group('pruning expired keys', () {
    test('expired keys are pruned after action completes', () async {
      // First action with short freshness
      await mix<void>(
        key: '',
        fresh: fresh(key: 'shortKey', freshFor: 50.millis, ignoreFresh: null),
        () async {},
      );

      // Wait for expiry
      await Future.delayed(const Duration(milliseconds: 60));

      // Second action triggers pruning
      await mix<void>(
        key: '',
        fresh: fresh(key: 'otherKey', freshFor: 1000.sec, ignoreFresh: null),
        () async {},
      );

      // Verify shortKey was pruned by running again - should succeed
      var ran = false;
      await mix<void>(
        key: '',
        fresh: fresh(key: 'shortKey', freshFor: 50.millis, ignoreFresh: null),
        () async {
          ran = true;
        },
      );

      expect(ran, true);
    });
  });

  group('multiple concurrent calls', () {
    test('only first of three concurrent calls runs (same key)', () async {
      final completer = Completer<void>();
      var count = 0;

      // Start first call (blocked by completer)
      final future1 = mix<void>(
        key: '',
        fresh: fresh(key: 'test', freshFor: 5.sec, ignoreFresh: null),
        () async {
          count++;
          await completer.future;
        },
      );

      // Give first call time to start
      await Future.delayed(const Duration(milliseconds: 10));

      // Try second and third while first is running (both should be aborted)
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 5.sec, ignoreFresh: null),
        () async {
          count++;
        },
      );

      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 5.sec, ignoreFresh: null),
        () async {
          count++;
        },
      );

      expect(count, 1); // Only first ran

      // Complete first
      completer.complete();
      await future1;
    });

    test('calls after completion are still aborted (within freshFor)',
        () async {
      var count = 0;

      // First call completes
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 5.sec, ignoreFresh: null),
        () async {
          count++;
        },
      );
      expect(count, 1);

      // Multiple subsequent calls should all be aborted
      for (var i = 0; i < 5; i++) {
        await mix<void>(
          key: '',
          fresh: fresh(key: 'test', freshFor: 5.sec, ignoreFresh: null),
          () async {
            count++;
          },
        );
      }

      expect(count, 1); // Still just 1
    });
  });

  group(
      'concurrent action does not rollback if another action overwrote expiry',
      () {
    test('failing action does not rollback if expiry was overwritten',
        () async {
      final completer1 = Completer<void>();
      var count = 0;

      // First action will fail eventually
      final future1 = mix<void>(
        key: '',
        fresh: fresh(key: 'test', freshFor: 5.sec, ignoreFresh: null),
        () async {
          await completer1.future;
          throw Exception('First failed');
        },
      );

      // Give first call time to set the expiry
      await Future.delayed(const Duration(milliseconds: 10));

      // Reset and start new action with same key (overwrites expiry)
      Superpowers.clear();
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 5.sec, ignoreFresh: null),
        () async {
          count++;
        },
      );
      expect(count, 1);

      // Complete first action (it fails)
      completer1.complete();
      try {
        await future1;
      } catch (_) {
        // Expected
      }

      // Third call should be aborted (fresh from second, first didn't rollback)
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 5.sec, ignoreFresh: null),
        () async {
          count++;
        },
      );

      expect(count, 1); // Still 1
    });
  });

  group('edge cases', () {
    test('exact expiry time is treated as expired', () async {
      var count = 0;

      // Use very short freshness
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 50.millis, ignoreFresh: null),
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
        fresh: fresh(key: 'test', freshFor: 50.millis, ignoreFresh: null),
        () async {
          count++;
        },
      );

      expect(count, 2);
    });

    test('freshFor of 0 means immediately stale', () async {
      var count = 0;

      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 0.millis, ignoreFresh: null),
        () async {
          count++;
        },
      );
      expect(count, 1);

      // Second call should also run (freshFor: 0 expires immediately)
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 0.millis, ignoreFresh: null),
        () async {
          count++;
        },
      );
      expect(count, 2);
    });

    test('very long freshFor works correctly', () async {
      var count = 0;

      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 3600.sec, ignoreFresh: null),
        // 1 hour
        () async {
          count++;
        },
      );
      expect(count, 1);

      // Should be aborted
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 3600.sec, ignoreFresh: null),
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
        fresh: fresh(key: '', freshFor: 1000.sec, ignoreFresh: null),
        () async {
          count++;
        },
      );

      await mix<void>(
        key: '',
        fresh: fresh(key: '', freshFor: 1000.sec, ignoreFresh: null),
        () async {
          count++;
        },
      );

      expect(count, 1); // Second should be aborted
    });

    test('special characters in key work', () async {
      var count = 0;

      await mix<void>(
        key: '',
        fresh: fresh(
            key: 'user:123/profile?full=true',
            freshFor: 1000.sec,
            ignoreFresh: null),
        () async {
          count++;
        },
      );

      await mix<void>(
        key: '',
        fresh: fresh(
            key: 'user:123/profile?full=true',
            freshFor: 1000.sec,
            ignoreFresh: null),
        () async {
          count++;
        },
      );

      expect(count, 1); // Second should be aborted
    });

    test('unicode key works', () async {
      var count = 0;

      await mix<void>(
        key: '',
        fresh: fresh(key: '用户_データ_🎉', freshFor: 1000.sec, ignoreFresh: null),
        () async {
          count++;
        },
      );

      await mix<void>(
        key: '',
        fresh: fresh(key: '用户_データ_🎉', freshFor: 1000.sec, ignoreFresh: null),
        () async {
          count++;
        },
      );

      expect(count, 1); // Second should be aborted
    });

    test('first action with no expiry runs', () async {
      // This tests the null check for previous expiry
      Superpowers.clear(); // Ensure clean state

      var ran = false;
      await mix<void>(
        key: '',
        fresh: fresh(key: 'brandNew', freshFor: 1000.sec, ignoreFresh: null),
        () async {
          ran = true;
        },
      );

      expect(ran, true);
    });

    test('different freshFor values for same key', () async {
      var count = 0;

      // First call with short freshness
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 50.millis, ignoreFresh: null),
        () async {
          count++;
        },
      );
      expect(count, 1);

      // Second call with longer freshness (but key is already fresh)
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 5.sec, ignoreFresh: null),
        () async {
          count++;
        },
      );
      expect(count, 1); // Still aborted

      // Wait for first's freshness to expire
      await Future.delayed(const Duration(milliseconds: 60));

      // Now should run (first's 50ms expired)
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 5.sec, ignoreFresh: null),
        () async {
          count++;
        },
      );
      expect(count, 2);
    });
  });

  group('fresh map lazy initialization', () {
    test('fresh map is lazily created on first use', () async {
      Superpowers.clear();

      // Verify no fresh map exists
      expect(Superpowers.prop<Map<Object, DateTime>?>('_mix_freshKeyMap'), isNull);

      // First call creates the map
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 1.sec),
        () async {},
      );

      // Now map should exist
      expect(Superpowers.prop<Map<Object, DateTime>?>('_mix_freshKeyMap'), isNotNull);
    });
  });

  group('fresh with wrapRun', () {
    test('wrapRun is called for fresh action', () async {
      var wrapRunCalled = false;

      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 1.sec),
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
        key: '',
        fresh: fresh(key: 'test', freshFor: 1.sec),
        config: MixConfig(wrapRun: (action) async {
          final r = await action();
          return r + 100;
        }),
        () async => 42,
      );

      expect(result, 142);
    });

    test('wrapRun error triggers fresh rollback', () async {
      var secondRan = false;

      // First call's wrapRun throws
      try {
        await mix<void>(
          key: '',
          fresh: fresh(key: 'test', freshFor: 1.sec),
          config: MixConfig(wrapRun: (action) {
            throw Exception('WrapRun failed');
          }),
          () async {},
        );
      } catch (_) {
        // Expected
      }

      // Second call should run (freshness was rolled back)
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 1.sec),
        () async {
          secondRan = true;
        },
      );

      expect(secondRan, true);
    });
  });

  group('stress tests', () {
    test('many different keys can be tracked', () async {
      // Create 100 different fresh keys
      for (var i = 0; i < 100; i++) {
        await mix<void>(
          key: '',
          fresh: fresh(key: 'key_$i', freshFor: 5.sec, ignoreFresh: null),
          () async {},
        );
      }

      // All should be fresh, second calls should be aborted
      var ranCount = 0;
      for (var i = 0; i < 100; i++) {
        await mix<void>(
          key: '',
          fresh: fresh(key: 'key_$i', freshFor: 5.sec, ignoreFresh: null),
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
        key: '',
        fresh: fresh(key: 'rapid', freshFor: 1000.sec, ignoreFresh: null),
        () async {
          count++;
        },
      );

      // 50 rapid calls
      for (var i = 0; i < 50; i++) {
        await mix<void>(
          key: '',
          fresh: fresh(key: 'rapid', freshFor: 1000.sec, ignoreFresh: null),
          () async {
            count++;
          },
        );
      }

      expect(count, 1); // Only first should have run
    });
  });

  group('ignoreFresh parameter', () {
    test('ignoreFresh: true bypasses fresh check', () async {
      var count = 0;

      // First call sets freshness
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 5.sec, ignoreFresh: null),
        () async {
          count++;
        },
      );
      expect(count, 1);

      // Second call normally would be aborted, but ignoreFresh: true bypasses
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 5.sec, ignoreFresh: true),
        () async {
          count++;
        },
      );
      expect(count, 2); // Ran because ignoreFresh: true
    });

    test('ignoreFresh: true still sets new expiry after running', () async {
      var count = 0;

      // First call with ignoreFresh: true
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 5.sec, ignoreFresh: true),
        () async {
          count++;
        },
      );
      expect(count, 1);

      // Second call without ignoreFresh should be aborted (expiry was set)
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 5.sec, ignoreFresh: null),
        () async {
          count++;
        },
      );
      expect(count, 1); // Aborted because fresh
    });

    test('ignoreFresh: true makes key stale on failure', () async {
      var count = 0;

      // First call sets freshness
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 5.sec, ignoreFresh: null),
        () async {
          count++;
        },
      );
      expect(count, 1);

      // Second call with ignoreFresh: true fails
      try {
        await mix<void>(
          key: '',
          fresh: fresh(key: 'test', freshFor: 5.sec, ignoreFresh: true),
          () async {
            throw Exception('Failed');
          },
        );
      } catch (_) {}

      // Third call should run because ignoreFresh failure made it stale
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 5.sec, ignoreFresh: null),
        () async {
          count++;
        },
      );
      expect(count, 2); // Ran because key became stale
    });

    test('ignoreFresh: false behaves same as null (normal fresh check)',
        () async {
      var count = 0;

      // First call
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 5.sec, ignoreFresh: false),
        () async {
          count++;
        },
      );
      expect(count, 1);

      // Second call should be aborted
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 5.sec, ignoreFresh: false),
        () async {
          count++;
        },
      );
      expect(count, 1); // Aborted
    });

    test('ignoreFresh works with retry', () async {
      var attempts = 0;

      // First call sets freshness
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 5.sec, ignoreFresh: null),
        () async {},
      );

      // Force refresh with retry
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 5.sec, ignoreFresh: true),
        retry: retry(
          maxRetries: 2,
          initialDelay: Duration(milliseconds: 10),
          multiplier: 2.0,
          maxDelay: Duration(seconds: 1),
          onRetry: null,
        ),
        () async {
          attempts++;
          if (attempts < 2) throw Exception('Retry');
        },
      );

      expect(attempts, 2); // Ran with retry despite being fresh
    });

    test('ignoreFresh for pull-to-refresh pattern', () async {
      var loadCount = 0;

      // Simulate initial load
      await mix<void>(
        key: '',
        fresh: fresh(key: 'loadData', freshFor: 60.sec, ignoreFresh: null),
        () async {
          loadCount++;
        },
      );
      expect(loadCount, 1);

      // Normal load attempt (should be aborted - still fresh)
      await mix<void>(
        key: '',
        fresh: fresh(key: 'loadData', freshFor: 60.sec, ignoreFresh: null),
        () async {
          loadCount++;
        },
      );
      expect(loadCount, 1);

      // Pull-to-refresh (force refresh)
      await mix<void>(
        key: '',
        fresh: fresh(key: 'loadData', freshFor: 60.sec, ignoreFresh: true),
        () async {
          loadCount++;
        },
      );
      expect(loadCount, 2);
    });
  });

  group('removeFreshKey function', () {
    test('removeFreshKey makes specific key stale', () async {
      var count = 0;

      // Set up fresh key
      await mix<void>(
        key: '',
        fresh: fresh(key: 'myKey', freshFor: 5.sec, ignoreFresh: null),
        () async {
          count++;
        },
      );
      expect(count, 1);

      // Verify it's fresh (would be aborted)
      await mix<void>(
        key: '',
        fresh: fresh(key: 'myKey', freshFor: 5.sec, ignoreFresh: null),
        () async {
          count++;
        },
      );
      expect(count, 1);

      // Remove the key
      removeFreshKey('myKey');

      // Now it should run
      await mix<void>(
        key: '',
        fresh: fresh(key: 'myKey', freshFor: 5.sec, ignoreFresh: null),
        () async {
          count++;
        },
      );
      expect(count, 2);
    });

    test('removeFreshKey does not affect other keys', () async {
      var countA = 0;
      var countB = 0;

      // Set up two fresh keys
      await mix<void>(
        key: '',
        fresh: fresh(key: 'keyA', freshFor: 5.sec, ignoreFresh: null),
        () async {
          countA++;
        },
      );
      await mix<void>(
        key: '',
        fresh: fresh(key: 'keyB', freshFor: 5.sec, ignoreFresh: null),
        () async {
          countB++;
        },
      );

      // Remove only keyA
      removeFreshKey('keyA');

      // keyA should run
      await mix<void>(
        key: '',
        fresh: fresh(key: 'keyA', freshFor: 5.sec, ignoreFresh: null),
        () async {
          countA++;
        },
      );
      expect(countA, 2);

      // keyB should still be fresh (aborted)
      await mix<void>(
        key: '',
        fresh: fresh(key: 'keyB', freshFor: 5.sec, ignoreFresh: null),
        () async {
          countB++;
        },
      );
      expect(countB, 1);
    });

    test('removeFreshKey on non-existent key is safe', () async {
      // Should not throw
      removeFreshKey('nonExistent');
    });

    test('removeFreshKey can be called from within an action', () async {
      var countLoad = 0;
      var countSave = 0;

      // Load data (sets fresh)
      await mix<void>(
        key: '',
        fresh: fresh(key: 'loadUser', freshFor: 5.sec, ignoreFresh: null),
        () async {
          countLoad++;
        },
      );
      expect(countLoad, 1);

      // Verify load is fresh
      await mix<void>(
        key: '',
        fresh: fresh(key: 'loadUser', freshFor: 5.sec, ignoreFresh: null),
        () async {
          countLoad++;
        },
      );
      expect(countLoad, 1);

      // Save data (invalidates load fresh)
      await mix<void>(
        key: '',
        () async {
          countSave++;
          // After saving, invalidate the load freshness
          removeFreshKey('loadUser');
        },
      );
      expect(countSave, 1);

      // Now load should run again
      await mix<void>(
        key: '',
        fresh: fresh(key: 'loadUser', freshFor: 5.sec, ignoreFresh: null),
        () async {
          countLoad++;
        },
      );
      expect(countLoad, 2);
    });
  });

  group('removeAllFreshKeys function', () {
    test('removeAllFreshKeys clears all fresh keys', () async {
      var countA = 0;
      var countB = 0;
      var countC = 0;

      // Set up multiple fresh keys
      await mix<void>(
        key: '',
        fresh: fresh(key: 'keyA', freshFor: 5.sec, ignoreFresh: null),
        () async {
          countA++;
        },
      );
      await mix<void>(
        key: '',
        fresh: fresh(key: 'keyB', freshFor: 5.sec, ignoreFresh: null),
        () async {
          countB++;
        },
      );
      await mix<void>(
        key: '',
        fresh: fresh(key: 'keyC', freshFor: 5.sec, ignoreFresh: null),
        () async {
          countC++;
        },
      );

      // Clear all
      removeAllFreshKeys();

      // All should run now
      await mix<void>(
        key: '',
        fresh: fresh(key: 'keyA', freshFor: 5.sec, ignoreFresh: null),
        () async {
          countA++;
        },
      );
      await mix<void>(
        key: '',
        fresh: fresh(key: 'keyB', freshFor: 5.sec, ignoreFresh: null),
        () async {
          countB++;
        },
      );
      await mix<void>(
        key: '',
        fresh: fresh(key: 'keyC', freshFor: 5.sec, ignoreFresh: null),
        () async {
          countC++;
        },
      );

      expect(countA, 2);
      expect(countB, 2);
      expect(countC, 2);
    });

    test('removeAllFreshKeys on empty map is safe', () async {
      Superpowers.clear(); // Clear state
      // Should not throw
      removeAllFreshKeys();
    });

    test('removeAllFreshKeys for logout pattern', () async {
      var userDataCount = 0;
      var settingsCount = 0;
      var preferencesCount = 0;

      // User is logged in, load various data
      await mix<void>(
        key: '',
        fresh: fresh(key: 'userData', freshFor: 60.sec, ignoreFresh: null),
        () async {
          userDataCount++;
        },
      );
      await mix<void>(
        key: '',
        fresh: fresh(key: 'settings', freshFor: 60.sec, ignoreFresh: null),
        () async {
          settingsCount++;
        },
      );
      await mix<void>(
        key: '',
        fresh: fresh(key: 'preferences', freshFor: 60.sec, ignoreFresh: null),
        () async {
          preferencesCount++;
        },
      );

      // Simulate logout - clear all fresh data
      await mix<void>(
        key: '',
        () async {
          // Logout logic...
          removeAllFreshKeys();
        },
      );

      // After login again, all data should be reloaded
      await mix<void>(
        key: '',
        fresh: fresh(key: 'userData', freshFor: 60.sec, ignoreFresh: null),
        () async {
          userDataCount++;
        },
      );
      await mix<void>(
        key: '',
        fresh: fresh(key: 'settings', freshFor: 60.sec, ignoreFresh: null),
        () async {
          settingsCount++;
        },
      );
      await mix<void>(
        key: '',
        fresh: fresh(key: 'preferences', freshFor: 60.sec, ignoreFresh: null),
        () async {
          preferencesCount++;
        },
      );

      expect(userDataCount, 2);
      expect(settingsCount, 2);
      expect(preferencesCount, 2);
    });
  });

  group('onFresh callback', () {
    test('onFresh is called when a call is skipped due to fresh data', () async {
      Object? freshKey;
      Duration? freshRemaining;
      var freshCount = 0;

      // First call runs
      await mix<void>(
        key: 'test',
        fresh: fresh(
          key: 'testKey',
          freshFor: 1.sec,
          onFresh: (key, remaining) {
            freshKey = key;
            freshRemaining = remaining;
            freshCount++;
          },
        ),
        () async {},
      );

      expect(freshCount, 0); // Not skipped

      // Second call - should be skipped (still fresh)
      await mix<void>(
        key: 'test',
        fresh: fresh(
          key: 'testKey',
          freshFor: 1.sec,
          onFresh: (key, remaining) {
            freshKey = key;
            freshRemaining = remaining;
            freshCount++;
          },
        ),
        () async {},
      );

      expect(freshCount, 1);
      expect(freshKey, 'testKey');
      expect(freshRemaining, isNotNull);
      expect(freshRemaining!.inMilliseconds, greaterThan(0));
      expect(freshRemaining!.inMilliseconds, lessThanOrEqualTo(1000));
    });

    test('onFresh is not called when the call runs', () async {
      var freshCount = 0;

      await mix<void>(
        key: 'test',
        fresh: fresh(
          key: 'testKey',
          freshFor: 1.sec,
          onFresh: (key, remaining) {
            freshCount++;
          },
        ),
        () async {},
      );

      expect(freshCount, 0);
    });

    test('onFresh receives accurate remaining time', () async {
      Duration? firstRemaining;
      Duration? secondRemaining;

      // First call sets fresh
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 500.millis),
        () async {},
      );

      // Immediate second call
      await mix<void>(
        key: 'test',
        fresh: fresh(
          key: 'test',
          freshFor: 500.millis,
          onFresh: (key, remaining) {
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
        fresh: fresh(
          key: 'test',
          freshFor: 500.millis,
          onFresh: (key, remaining) {
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

    test('onFresh receives the effective key', () async {
      final freshKeys = <Object>[];

      // First call sets fresh
      await mix<void>(
        key: 'test',
        fresh: fresh(key: ('loadUser', 123), freshFor: 1.sec),
        () async {},
      );

      // Second call skipped
      await mix<void>(
        key: 'test',
        fresh: fresh(
          key: ('loadUser', 123),
          freshFor: 1.sec,
          onFresh: (key, remaining) => freshKeys.add(key),
        ),
        () async {},
      );

      // Third call skipped
      await mix<void>(
        key: 'test',
        fresh: fresh(
          key: ('loadUser', 123),
          freshFor: 1.sec,
          onFresh: (key, remaining) => freshKeys.add(key),
        ),
        () async {},
      );

      expect(freshKeys.length, 2);
      expect(freshKeys[0], ('loadUser', 123));
      expect(freshKeys[1], ('loadUser', 123));
    });

    test('onFresh works with sync mix', () async {
      var freshCount = 0;

      // First call sets fresh
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 1.sec),
        () {},
      );

      // Second call should be skipped
      await mix<void>(
        key: 'test',
        fresh: fresh(
          key: 'test',
          freshFor: 1.sec,
          onFresh: (key, remaining) => freshCount++,
        ),
        () {},
      );

      expect(freshCount, 1);
    });

    test('onFresh works with mix.ctx', () async {
      var freshCount = 0;

      // First call sets fresh
      await mix.ctx<void>(
        (ctx) async {},
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 1.sec),
      );

      // Second call should be skipped
      await mix.ctx<void>(
        (ctx) async {},
        key: 'test',
        fresh: fresh(
          key: 'test',
          freshFor: 1.sec,
          onFresh: (key, remaining) => freshCount++,
        ),
      );

      expect(freshCount, 1);
    });

    test('onFresh is not called when ignoreFresh is true', () async {
      var freshCount = 0;

      // First call sets fresh
      await mix<void>(
        key: 'test',
        fresh: fresh(key: 'test', freshFor: 1.sec),
        () async {},
      );

      // Second call with ignoreFresh - should run, not trigger callback
      await mix<void>(
        key: 'test',
        fresh: fresh(
          key: 'test',
          freshFor: 1.sec,
          ignoreFresh: true,
          onFresh: (key, remaining) => freshCount++,
        ),
        () async {},
      );

      expect(freshCount, 0);
    });
  });
}
