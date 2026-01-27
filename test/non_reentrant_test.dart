import 'dart:async';

import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Reset Superpowers static state before each test.
  setUp(() {
    Superpowers.clear();
  });

  group('mix with nonReentrant', () {
    test('allows first call to run', () async {
      var ran = false;

      await mix<void>(
        key: '',
        nonReentrant: nonReentrant(key: 'test'),
        () async {
          ran = true;
        },
      );

      expect(ran, true);
    });

    test('aborts concurrent call with same key', () async {
      final completer = Completer<void>();
      var firstRan = false;
      var secondRan = false;

      // Start first call (it will wait on completer)
      final future1 = mix<void>(
        key: '',
        nonReentrant: nonReentrant(key: 'test'),
        () async {
          firstRan = true;
          await completer.future;
        },
      );

      // Give first call time to start
      await Future.delayed(Duration(milliseconds: 10));

      // Start second call while first is running
      final result2 = await mix<int?>(
        key: '',
        nonReentrant: nonReentrant(key: 'test'),
        () async {
          secondRan = true;
          return 42;
        },
      );

      // Second call should be aborted (returns null)
      expect(result2, null);
      expect(secondRan, false);

      // Complete first call
      completer.complete();
      await future1;

      expect(firstRan, true);
    });

    test('allows call after previous one completes', () async {
      var count = 0;

      await mix<void>(
        key: '',
        nonReentrant: nonReentrant(key: 'test'),
        () async {
          count++;
        },
      );
      expect(count, 1);

      await mix<void>(
        key: '',
        nonReentrant: nonReentrant(key: 'test'),
        () async {
          count++;
        },
      );
      expect(count, 2);
    });

    test('releases lock even when action fails', () async {
      var secondRan = false;

      // First call fails
      try {
        await mix<void>(
          key: '',
          nonReentrant: nonReentrant(key: 'test'),
          () async {
            throw Exception('First failed');
          },
        );
      } catch (_) {
        // Expected
      }

      // Second call should be allowed to run
      await mix<void>(
        key: '',
        nonReentrant: nonReentrant(key: 'test'),
        () async {
          secondRan = true;
        },
      );

      expect(secondRan, true);
    });

    test('different keys allow concurrent execution', () async {
      final completer1 = Completer<void>();
      final completer2 = Completer<void>();
      var firstRan = false;
      var secondRan = false;

      // Start first call with key 'A'
      final future1 = mix<void>(
        key: '',
        nonReentrant: nonReentrant(key: 'A'),
        () async {
          firstRan = true;
          await completer1.future;
        },
      );

      // Give first call time to start
      await Future.delayed(Duration(milliseconds: 10));

      // Start second call with key 'B' - should NOT be aborted
      final future2 = mix<void>(
        key: '',
        nonReentrant: nonReentrant(key: 'B'),
        () async {
          secondRan = true;
          await completer2.future;
        },
      );

      // Give second call time to start
      await Future.delayed(Duration(milliseconds: 10));

      // Both should be running
      expect(firstRan, true);
      expect(secondRan, true);

      // Complete both
      completer1.complete();
      completer2.complete();
      await future1;
      await future2;
    });

    test('works without nonReentrant (default null)', () async {
      final completer = Completer<void>();
      var firstRan = false;
      var secondRan = false;

      // Start first call (no nonReentrant)
      final future1 = mix<void>(
        key: '',
        () async {
          firstRan = true;
          await completer.future;
        },
      );

      // Give first call time to start
      await Future.delayed(Duration(milliseconds: 10));

      // Start second call - should run since nonReentrant is false
      final future2 = mix<void>(
        key: '',
        () async {
          secondRan = true;
        },
      );

      await future2;
      expect(secondRan, true);

      completer.complete();
      await future1;
      expect(firstRan, true);
    });
  });

  group('nonReentrant with parameterized keys', () {
    test('different params allow concurrent execution', () async {
      final completer1 = Completer<void>();
      final completer2 = Completer<void>();
      var count = 0;

      // Start first call with itemId 'A'
      final future1 = mix<void>(
        key: '',
        nonReentrant: nonReentrant(key: 'saveItem_A'),
        () async {
          count++;
          await completer1.future;
        },
      );

      // Give first call time to start
      await Future.delayed(Duration(milliseconds: 10));

      // Start second call with itemId 'B' - should run
      final future2 = mix<void>(
        key: '',
        nonReentrant: nonReentrant(key: 'saveItem_B'),
        () async {
          count++;
          await completer2.future;
        },
      );

      // Give second call time to start
      await Future.delayed(Duration(milliseconds: 10));

      expect(count, 2); // Both should have started

      // Complete both
      completer1.complete();
      completer2.complete();
      await future1;
      await future2;
    });

    test('same params block each other', () async {
      final completer = Completer<void>();
      var count = 0;

      // Start first call with itemId 'A'
      final future1 = mix<void>(
        key: '',
        nonReentrant: nonReentrant(key: 'saveItem_A'),
        () async {
          count++;
          await completer.future;
        },
      );

      // Give first call time to start
      await Future.delayed(Duration(milliseconds: 10));

      // Start second call with same itemId 'A' - should be aborted
      await mix<void>(
        key: '',
        nonReentrant: nonReentrant(key: 'saveItem_A'),
        () async {
          count++;
        },
      );

      expect(count, 1); // Only first should have run

      // Complete first
      completer.complete();
      await future1;
    });

    test('string keys work correctly', () async {
      final completer = Completer<void>();
      var count = 0;

      // Start first call with string key
      final future1 = mix<void>(
        key: '',
        nonReentrant: nonReentrant(key: 'user_123_save'),
        () async {
          count++;
          await completer.future;
        },
      );

      // Give first call time to start
      await Future.delayed(Duration(milliseconds: 10));

      // Same string key - should be aborted
      await mix<void>(
        key: '',
        nonReentrant: nonReentrant(key: 'user_123_save'),
        () async {
          count++;
        },
      );

      expect(count, 1);

      // Different string key - should run
      await mix<void>(
        key: '',
        nonReentrant: nonReentrant(key: 'user_456_save'),
        () async {
          count++;
        },
      );

      expect(count, 2);

      completer.complete();
      await future1;
    });
  });

  group('Superpowers.clear() clears nonReentrant state', () {
    test('Superpowers.clear() clears running keys', () async {
      final completer = Completer<void>();
      var secondRan = false;

      // Start first call but don't complete it
      mix<void>(
        key: '',
        nonReentrant: nonReentrant(key: 'test'),
        () async {
          await completer.future;
        },
      );

      // Give first call time to start
      await Future.delayed(Duration(milliseconds: 10));

      // Reset Superpowers state - should clear the running key
      Superpowers.clear();

      // New call should be allowed to run
      await mix<void>(
        key: '',
        nonReentrant: nonReentrant(key: 'test'),
        () async {
          secondRan = true;
        },
      );

      expect(secondRan, true);

      // Complete original call (won't affect anything)
      completer.complete();
    });
  });

  group('nonReentrant with lifecycle methods', () {
    test('before() not called when aborted', () async {
      final completer = Completer<void>();
      var beforeCallCount = 0;

      // Start first call
      final future1 = mix<void>(
        key: '',
        nonReentrant: nonReentrant(key: 'test'),
        config: MixConfig(before: () => beforeCallCount++),
        () async {
          await completer.future;
        },
      );

      // Give first call time to start
      await Future.delayed(Duration(milliseconds: 10));
      expect(beforeCallCount, 1);

      // Start second call - should be aborted, before() should NOT be called
      await mix<void>(
        key: '',
        nonReentrant: nonReentrant(key: 'test'),
        config: MixConfig(before: () => beforeCallCount++),
        () async {},
      );

      expect(beforeCallCount, 1); // Still 1 - second before() was not called

      completer.complete();
      await future1;
    });

    test('after() not called when aborted', () async {
      final completer = Completer<void>();
      var afterCallCount = 0;

      // Start first call
      final future1 = mix<void>(
        key: '',
        nonReentrant: nonReentrant(key: 'test'),
        config: MixConfig(after: () => afterCallCount++),
        () async {
          await completer.future;
        },
      );

      // Give first call time to start
      await Future.delayed(Duration(milliseconds: 10));

      // Start second call - should be aborted, after() should NOT be called
      await mix<void>(
        key: '',
        nonReentrant: nonReentrant(key: 'test'),
        config: MixConfig(after: () => afterCallCount++),
        () async {},
      );

      expect(afterCallCount, 0); // Second after() was not called

      // Complete first call
      completer.complete();
      await future1;

      expect(afterCallCount, 1); // Now first after() was called
    });

    test('catchError() not called when aborted', () async {
      final completer = Completer<void>();
      var catchErrorCallCount = 0;

      // Start first call
      final future1 = mix<void>(
        key: '',
        nonReentrant: nonReentrant(key: 'test'),
        config: MixConfig(catchError: (e, s) {
          catchErrorCallCount++;
          throw e;
        }),
        () async {
          await completer.future;
        },
      );

      // Give first call time to start
      await Future.delayed(Duration(milliseconds: 10));

      // Start second call - should be aborted, catchError() should NOT be called
      await mix<void>(
        key: '',
        nonReentrant: nonReentrant(key: 'test'),
        config: MixConfig(catchError: (e, s) {
          catchErrorCallCount++;
          throw e;
        }),
        () async {
          throw Exception('Should not run');
        },
      );

      expect(catchErrorCallCount, 0);

      completer.complete();
      await future1;
    });
  });

  group('nonReentrant combined with retry', () {
    test('retry works with nonReentrant', () async {
      var attemptCount = 0;

      await mix<void>(
        key: '',
        nonReentrant: nonReentrant(key: 'test'),
        retry: retry(
          maxRetries: 2,
          initialDelay: Duration(milliseconds: 10),
          multiplier: 2.0,
          maxDelay: Duration(seconds: 1),
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

    test('concurrent call aborted even during retries', () async {
      final completer = Completer<void>();
      var firstAttempts = 0;
      var secondRan = false;

      // Start first call that will retry
      final future1 = mix<void>(
        key: '',
        nonReentrant: nonReentrant(key: 'test'),
        retry: retry(
          maxRetries: 5,
          initialDelay: Duration(milliseconds: 50),
          multiplier: 2.0,
          maxDelay: Duration(seconds: 1),
        ),
        config: MixConfig(catchError: (e, s) {}), // Suppress error
        () async {
          firstAttempts++;
          await completer.future;
          throw Exception('Keep retrying');
        },
      );

      // Give first call time to start
      await Future.delayed(Duration(milliseconds: 10));

      // Start second call - should be aborted
      await mix<void>(
        key: '',
        nonReentrant: nonReentrant(key: 'test'),
        () async {
          secondRan = true;
        },
      );

      expect(secondRan, false);

      // Complete first call (will eventually fail and exit)
      completer.complete();

      // Wait for first call to complete (all retries)
      await future1;

      // Now second call should be allowed
      await mix<void>(
        key: '',
        nonReentrant: nonReentrant(key: 'test'),
        () async {
          secondRan = true;
        },
      );

      expect(secondRan, true);
    });

    test('lock released after retry failure', () async {
      var secondRan = false;

      // First call fails after retries
      await mix<int?>(
        key: '',
        nonReentrant: nonReentrant(key: 'test'),
        retry: retry(
          maxRetries: 1,
          initialDelay: Duration(milliseconds: 10),
          multiplier: 2.0,
          maxDelay: Duration(seconds: 1),
        ),
        config: MixConfig(catchError: (e, s) {}), // Suppress error
        () async {
          throw Exception('Always fails');
        },
      );

      // Second call should be allowed to run
      await mix<void>(
        key: '',
        nonReentrant: nonReentrant(key: 'test'),
        () async {
          secondRan = true;
        },
      );

      expect(secondRan, true);
    });
  });

  group('multiple concurrent calls', () {
    test('only first of three concurrent calls runs', () async {
      final completer = Completer<void>();
      var count = 0;

      // Start first call
      final future1 = mix<void>(
        key: '',
        nonReentrant: nonReentrant(key: 'test'),
        () async {
          count++;
          await completer.future;
        },
      );

      // Give first call time to start
      await Future.delayed(Duration(milliseconds: 10));

      // Try to start second and third while first is running
      await mix<void>(
        key: '',
        nonReentrant: nonReentrant(key: 'test'),
        () async {
          count++;
        },
      );

      await mix<void>(
        key: '',
        nonReentrant: nonReentrant(key: 'test'),
        () async {
          count++;
        },
      );

      expect(count, 1); // Only first incremented

      // Complete first
      completer.complete();
      await future1;
    });

    test('third call can run after first completes', () async {
      final completer = Completer<void>();
      var count = 0;

      // Start first call
      final future1 = mix<void>(
        key: '',
        nonReentrant: nonReentrant(key: 'test'),
        () async {
          count++;
          await completer.future;
        },
      );

      // Give first call time to start
      await Future.delayed(Duration(milliseconds: 10));

      // Second aborted
      await mix<void>(
        key: '',
        nonReentrant: nonReentrant(key: 'test'),
        () async {
          count++;
        },
      );

      expect(count, 1);

      // Complete first
      completer.complete();
      await future1;

      // Third should be allowed since lock is released
      await mix<void>(
        key: '',
        nonReentrant: nonReentrant(key: 'test'),
        () async {
          count++;
        },
      );

      expect(count, 2); // first + third
    });

    test('multiple different keys can be active simultaneously', () async {
      final completer1 = Completer<void>();
      final completer2 = Completer<void>();
      final completer3 = Completer<void>();
      var countA = 0;
      var countB = 0;
      var countC = 0;

      // Start all three with different keys
      final future1 = mix<void>(
        key: '',
        nonReentrant: nonReentrant(key: 'A'),
        () async {
          countA++;
          await completer1.future;
        },
      );

      final future2 = mix<void>(
        key: '',
        nonReentrant: nonReentrant(key: 'B'),
        () async {
          countB++;
          await completer2.future;
        },
      );

      final future3 = mix<void>(
        key: '',
        nonReentrant: nonReentrant(key: 'C'),
        () async {
          countC++;
          await completer3.future;
        },
      );

      // Give all calls time to start
      await Future.delayed(Duration(milliseconds: 10));

      // All should be running
      expect(countA, 1);
      expect(countB, 1);
      expect(countC, 1);

      // Try to start duplicates - all should be aborted
      await mix<void>(
        key: '',
        nonReentrant: nonReentrant(key: 'A'),
        () async {
          countA++;
        },
      );

      await mix<void>(
        key: '',
        nonReentrant: nonReentrant(key: 'B'),
        () async {
          countB++;
        },
      );

      // Duplicates should have been aborted
      expect(countA, 1);
      expect(countB, 1);

      // Complete all
      completer1.complete();
      completer2.complete();
      completer3.complete();
      await future1;
      await future2;
      await future3;
    });
  });

  group('sync actions', () {
    test('sync nonReentrant call completes immediately', () {
      var ran = false;

      mix<void>(
        key: '',
        nonReentrant: nonReentrant(key: 'test'),
        () {
          ran = true;
        },
      );

      // Note: Even sync actions return Future from mix, but execution is immediate
      expect(ran, true);
    });

    test('sync action releases lock immediately', () async {
      var count = 0;

      await mix<void>(
        key: '',
        nonReentrant: nonReentrant(key: 'test'),
        () {
          count++;
        },
      );

      await mix<void>(
        key: '',
        nonReentrant: nonReentrant(key: 'test'),
        () {
          count++;
        },
      );

      // Both should complete (no concurrent blocking for sync)
      expect(count, 2);
    });
  });

  group('return value handling', () {
    test('returns action result on success', () async {
      final result = await mix<int>(
        key: '',
        nonReentrant: nonReentrant(key: 'test'),
        () async => 42,
      );

      expect(result, 42);
    });

    test('returns null when aborted', () async {
      final completer = Completer<void>();

      // Start first call
      final future1 = mix<int>(
        key: '',
        nonReentrant: nonReentrant(key: 'test'),
        () async {
          await completer.future;
          return 42;
        },
      );

      // Give first call time to start
      await Future.delayed(Duration(milliseconds: 10));

      // Start second call - should be aborted and return null
      final result = await mix<int?>(
        key: '',
        nonReentrant: nonReentrant(key: 'test'),
        () async => 100,
      );

      expect(result, null);

      completer.complete();
      final firstResult = await future1;
      expect(firstResult, 42);
    });
  });

  group('onBlocked callback', () {
    test('onBlocked is called when a call is blocked', () async {
      final completer = Completer<void>();
      Object? blockedKey;
      var blockedCount = 0;

      // Start first call
      final future1 = mix<void>(
        key: '',
        nonReentrant: nonReentrant(
          key: 'testKey',
          onBlocked: (key) {
            blockedKey = key;
            blockedCount++;
          },
        ),
        () async {
          await completer.future;
        },
      );

      // Give first call time to start
      await Future.delayed(Duration(milliseconds: 10));

      // Start second call - should be blocked and onBlocked should be called
      await mix<void>(
        key: '',
        nonReentrant: nonReentrant(
          key: 'testKey',
          onBlocked: (key) {
            blockedKey = key;
            blockedCount++;
          },
        ),
        () async {},
      );

      expect(blockedCount, 1);
      expect(blockedKey, 'testKey');

      completer.complete();
      await future1;
    });

    test('onBlocked is not called when the call runs', () async {
      var blockedCount = 0;

      await mix<void>(
        key: '',
        nonReentrant: nonReentrant(
          key: 'testKey',
          onBlocked: (key) {
            blockedCount++;
          },
        ),
        () async {},
      );

      expect(blockedCount, 0);
    });

    test('onBlocked receives the effective key', () async {
      final completer = Completer<void>();
      final blockedKeys = <Object>[];

      // Start first call
      final future1 = mix<void>(
        key: '',
        nonReentrant: nonReentrant(
          key: ('action', 123),
          onBlocked: (key) => blockedKeys.add(key),
        ),
        () async {
          await completer.future;
        },
      );

      await Future.delayed(Duration(milliseconds: 10));

      // Second call blocked
      await mix<void>(
        key: '',
        nonReentrant: nonReentrant(
          key: ('action', 123),
          onBlocked: (key) => blockedKeys.add(key),
        ),
        () async {},
      );

      // Third call blocked
      await mix<void>(
        key: '',
        nonReentrant: nonReentrant(
          key: ('action', 123),
          onBlocked: (key) => blockedKeys.add(key),
        ),
        () async {},
      );

      expect(blockedKeys.length, 2);
      expect(blockedKeys[0], ('action', 123));
      expect(blockedKeys[1], ('action', 123));

      completer.complete();
      await future1;
    });

    test('onBlocked works with sync mix', () {
      final completer = Completer<void>();
      var blockedCount = 0;

      // Start async call that will hold the lock
      mix<void>(
        key: '',
        nonReentrant: nonReentrant(key: 'test'),
        () async {
          await completer.future;
        },
      );

      // Sync call should be blocked
      mix<void>(
        key: '',
        nonReentrant: nonReentrant(
          key: 'test',
          onBlocked: (key) => blockedCount++,
        ),
        () {},
      );

      expect(blockedCount, 1);

      completer.complete();
    });

    test('onBlocked works with mix.ctx', () async {
      final completer = Completer<void>();
      var blockedCount = 0;

      // Start first call
      final future1 = mix.ctx<void>(
        (ctx) async {
          await completer.future;
        },
        key: '',
        nonReentrant: nonReentrant(
          key: 'test',
          onBlocked: (key) => blockedCount++,
        ),
      );

      await Future.delayed(Duration(milliseconds: 10));

      // Second call should be blocked
      await mix.ctx<void>(
        (ctx) async {},
        key: '',
        nonReentrant: nonReentrant(
          key: 'test',
          onBlocked: (key) => blockedCount++,
        ),
      );

      expect(blockedCount, 1);

      completer.complete();
      await future1;
    });
  });
}
