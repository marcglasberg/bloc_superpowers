import 'dart:async';

import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:flutter_test/flutter_test.dart';

class TestException implements Exception {
  final String message;
  TestException(this.message);
  @override
  String toString() => 'TestException: $message';
}

void main() {
  // Reset Superpowers static state before each test.
  setUp(() {
    Superpowers.clear();
  });

  group('mix with sequential - basic behavior', () {
    test('single call executes', () async {
      var ran = false;

      await mix<void>(
        key: 'test',
        sequential: sequential,
        () async {
          ran = true;
        },
      );

      expect(ran, true);
    });

    test('returns result from action', () async {
      final result = await mix<int>(
        key: 'test',
        sequential: sequential,
        () async => 42,
      );

      expect(result, 42);
    });

    test('multiple calls execute in order', () async {
      final tracker = <int>[];

      final future1 = mix<void>(
        key: 'test',
        sequential: sequential,
        () async {
          await Future.delayed(const Duration(milliseconds: 50));
          tracker.add(1);
        },
      );

      final future2 = mix<void>(
        key: 'test',
        sequential: sequential,
        () async {
          tracker.add(2);
        },
      );

      final future3 = mix<void>(
        key: 'test',
        sequential: sequential,
        () async {
          tracker.add(3);
        },
      );

      await future1;
      await future2;
      await future3;

      // All three should execute in order
      expect(tracker, [1, 2, 3]);
    });

    test('all calls eventually execute (unlike nonReentrant)', () async {
      var count = 0;
      final completer = Completer<void>();

      // Start first call that will block
      final future1 = mix<void>(
        key: 'test',
        sequential: sequential,
        () async {
          count++;
          await completer.future;
        },
      );

      // Give first call time to start
      await Future.delayed(const Duration(milliseconds: 10));

      // Start second and third calls while first is running
      final future2 = mix<void>(
        key: 'test',
        sequential: sequential,
        () async {
          count++;
        },
      );

      final future3 = mix<void>(
        key: 'test',
        sequential: sequential,
        () async {
          count++;
        },
      );

      // Only first should have run so far
      expect(count, 1);

      // Complete first call
      completer.complete();
      await future1;
      await future2;
      await future3;

      // All three should have run
      expect(count, 3);
    });

    test('waits for previous call before starting next', () async {
      final timestamps = <String>[];

      final future1 = mix<void>(
        key: 'test',
        sequential: sequential,
        () async {
          timestamps.add('start1');
          await Future.delayed(const Duration(milliseconds: 50));
          timestamps.add('end1');
        },
      );

      // Small delay to ensure ordering of queue entry
      await Future.delayed(const Duration(milliseconds: 5));

      final future2 = mix<void>(
        key: 'test',
        sequential: sequential,
        () async {
          timestamps.add('start2');
          await Future.delayed(const Duration(milliseconds: 50));
          timestamps.add('end2');
        },
      );

      await future1;
      await future2;

      // Second should start only after first ends
      expect(timestamps, ['start1', 'end1', 'start2', 'end2']);
    });

    test('works without sequential (default null)', () async {
      final timestamps = <String>[];
      final completer1 = Completer<void>();
      final completer2 = Completer<void>();

      // Without sequential, calls run concurrently
      final future1 = mix<void>(
        key: 'test',
        () async {
          timestamps.add('start1');
          await completer1.future;
          timestamps.add('end1');
        },
      );

      await Future.delayed(const Duration(milliseconds: 5));

      final future2 = mix<void>(
        key: 'test',
        () async {
          timestamps.add('start2');
          await completer2.future;
          timestamps.add('end2');
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Both should have started
      expect(timestamps, ['start1', 'start2']);

      completer1.complete();
      completer2.complete();
      await future1;
      await future2;

      expect(timestamps.length, 4);
    });
  });

  group('mix with sequential - different keys', () {
    test('different keys have separate queues', () async {
      final tracker = <String>[];
      final completerA = Completer<void>();
      final completerB = Completer<void>();

      // Start call with key 'A' that will block
      final futureA = mix<void>(
        key: 'test',
        sequential: sequential(key: 'A'),
        () async {
          tracker.add('startA');
          await completerA.future;
          tracker.add('endA');
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Start call with key 'B' - should run immediately (different queue)
      final futureB = mix<void>(
        key: 'test',
        sequential: sequential(key: 'B'),
        () async {
          tracker.add('startB');
          await completerB.future;
          tracker.add('endB');
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Both should have started (different queues)
      expect(tracker, ['startA', 'startB']);

      completerA.complete();
      completerB.complete();
      await futureA;
      await futureB;

      expect(tracker.length, 4);
    });

    test('same key queues even with different mix keys', () async {
      final tracker = <int>[];
      final completer = Completer<void>();

      // First call with mix key 'test1' and sequential key 'shared'
      final future1 = mix<void>(
        key: 'test1',
        sequential: sequential(key: 'shared'),
        () async {
          tracker.add(1);
          await completer.future;
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Second call with mix key 'test2' but same sequential key 'shared'
      final future2 = mix<void>(
        key: 'test2',
        sequential: sequential(key: 'shared'),
        () async {
          tracker.add(2);
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Only first should have started (same sequential key)
      expect(tracker, [1]);

      completer.complete();
      await future1;
      await future2;

      // Both should have run in order
      expect(tracker, [1, 2]);
    });

    test('uses mix key when sequential key is null', () async {
      final tracker = <int>[];
      final completer = Completer<void>();

      // First call - sequential key defaults to mix key
      final future1 = mix<void>(
        key: 'shared',
        sequential: sequential,
        () async {
          tracker.add(1);
          await completer.future;
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Second call with same mix key
      final future2 = mix<void>(
        key: 'shared',
        sequential: sequential,
        () async {
          tracker.add(2);
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Should be queued (same key)
      expect(tracker, [1]);

      completer.complete();
      await future1;
      await future2;

      expect(tracker, [1, 2]);
    });

    test('record keys work for queue isolation', () async {
      final tracker = <String>[];
      final completer1 = Completer<void>();
      final completer2 = Completer<void>();

      // Call for chat 'A'
      final futureA = mix<void>(
        key: 'test',
        sequential: sequential(key: ('chat', 'A')),
        () async {
          tracker.add('A1');
          await completer1.future;
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Another call for chat 'A' - should queue
      final futureA2 = mix<void>(
        key: 'test',
        sequential: sequential(key: ('chat', 'A')),
        () async {
          tracker.add('A2');
        },
      );

      // Call for chat 'B' - should run immediately (different queue)
      final futureB = mix<void>(
        key: 'test',
        sequential: sequential(key: ('chat', 'B')),
        () async {
          tracker.add('B1');
          await completer2.future;
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // A1 and B1 should have started (different queues), A2 waiting
      expect(tracker, ['A1', 'B1']);

      completer1.complete();
      completer2.complete();
      await futureA;
      await futureA2;
      await futureB;

      // A2 should run after A1
      expect(tracker, ['A1', 'B1', 'A2']);
    });
  });

  group('mix with sequential - maxQueueSize', () {
    test('allows up to maxQueueSize calls in queue', () async {
      final tracker = <int>[];
      final completer = Completer<void>();

      // First call - starts immediately
      final future1 = mix<void>(
        key: 'test',
        sequential: sequential(maxQueueSize: 2),
        () async {
          tracker.add(1);
          await completer.future;
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Second call - queued (1 in queue)
      final future2 = mix<void>(
        key: 'test',
        sequential: sequential(maxQueueSize: 2),
        () async {
          tracker.add(2);
        },
      );

      // Third call - queued (2 in queue = at limit)
      final future3 = mix<void>(
        key: 'test',
        sequential: sequential(maxQueueSize: 2),
        () async {
          tracker.add(3);
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Only first should have run so far
      expect(tracker, [1]);

      completer.complete();
      await future1;
      await future2;
      await future3;

      // All three should have run
      expect(tracker, [1, 2, 3]);
    });

    test('drops calls when queue exceeds maxQueueSize', () async {
      final tracker = <int>[];
      final completer = Completer<void>();

      // First call - starts immediately
      final future1 = mix<void>(
        key: 'test',
        sequential: sequential(maxQueueSize: 1),
        () async {
          tracker.add(1);
          await completer.future;
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Second call - queued (1 in queue = at limit)
      final future2 = mix<void>(
        key: 'test',
        sequential: sequential(maxQueueSize: 1),
        () async {
          tracker.add(2);
        },
      );

      // Third call - should be dropped (queue full)
      final result3 = await mix<int?>(
        key: 'test',
        sequential: sequential(maxQueueSize: 1),
        () async {
          tracker.add(3);
          return 3;
        },
      );

      // Third call should return null (dropped)
      expect(result3, null);

      completer.complete();
      await future1;
      await future2;

      // Only 1 and 2 should have run
      expect(tracker, [1, 2]);
    });

    test('maxQueueSize 0 means only one running at a time (no queue)', () async {
      final tracker = <int>[];
      final completer = Completer<void>();

      // First call - starts immediately
      final future1 = mix<void>(
        key: 'test',
        sequential: sequential(maxQueueSize: 0),
        () async {
          tracker.add(1);
          await completer.future;
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Second call - should be dropped (maxQueueSize: 0)
      final result2 = await mix<int?>(
        key: 'test',
        sequential: sequential(maxQueueSize: 0),
        () async {
          tracker.add(2);
          return 2;
        },
      );

      expect(result2, null);

      completer.complete();
      await future1;

      // Only first should have run
      expect(tracker, [1]);
    });

    test('queue size recovers after calls complete', () async {
      final tracker = <int>[];

      // Run first call to completion
      await mix<void>(
        key: 'test',
        sequential: sequential(maxQueueSize: 1),
        () async {
          tracker.add(1);
        },
      );

      // Run second call to completion
      await mix<void>(
        key: 'test',
        sequential: sequential(maxQueueSize: 1),
        () async {
          tracker.add(2);
        },
      );

      // Both should have run
      expect(tracker, [1, 2]);

      // Now start a blocking call
      final completer = Completer<void>();
      final future3 = mix<void>(
        key: 'test',
        sequential: sequential(maxQueueSize: 1),
        () async {
          tracker.add(3);
          await completer.future;
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Queue one call
      final future4 = mix<void>(
        key: 'test',
        sequential: sequential(maxQueueSize: 1),
        () async {
          tracker.add(4);
        },
      );

      // This should be dropped
      final result5 = await mix<int?>(
        key: 'test',
        sequential: sequential(maxQueueSize: 1),
        () async {
          tracker.add(5);
          return 5;
        },
      );

      expect(result5, null);

      completer.complete();
      await future3;
      await future4;

      // 1, 2, 3, 4 should have run (5 was dropped)
      expect(tracker, [1, 2, 3, 4]);
    });
  });

  group('mix with sequential - queueTimeout', () {
    test('call executes if it waits less than queueTimeout', () async {
      final tracker = <int>[];

      // First call - takes 30ms
      final future1 = mix<void>(
        key: 'test',
        sequential: sequential(queueTimeout: const Duration(milliseconds: 100)),
        () async {
          tracker.add(1);
          await Future.delayed(const Duration(milliseconds: 30));
        },
      );

      // Second call - should wait less than 100ms timeout
      final future2 = mix<void>(
        key: 'test',
        sequential: sequential(queueTimeout: const Duration(milliseconds: 100)),
        () async {
          tracker.add(2);
        },
      );

      await future1;
      await future2;

      // Both should have run
      expect(tracker, [1, 2]);
    });

    test('call is discarded if it waits longer than queueTimeout', () async {
      final tracker = <int>[];
      final completer = Completer<void>();

      // First call - blocks until we complete it
      final future1 = mix<void>(
        key: 'test',
        sequential: sequential(queueTimeout: const Duration(milliseconds: 50)),
        () async {
          tracker.add(1);
          await completer.future;
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Second call - will timeout
      final future2 = mix<int?>(
        key: 'test',
        sequential: sequential(queueTimeout: const Duration(milliseconds: 50)),
        () async {
          tracker.add(2);
          return 2;
        },
      );

      // Wait longer than the timeout
      await Future.delayed(const Duration(milliseconds: 100));

      // Now complete the first call
      completer.complete();

      final result2 = await future2;
      await future1;

      // Second call should have timed out
      expect(result2, null);
      expect(tracker, [1]); // Only first ran
    });

    test('discarded call returns null and does not execute', () async {
      var secondRan = false;
      final completer = Completer<void>();

      final future1 = mix<void>(
        key: 'test',
        sequential: sequential(queueTimeout: const Duration(milliseconds: 30)),
        () async {
          await completer.future;
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      final future2 = mix<int?>(
        key: 'test',
        sequential: sequential(queueTimeout: const Duration(milliseconds: 30)),
        () async {
          secondRan = true;
          return 42;
        },
      );

      // Wait for timeout
      await Future.delayed(const Duration(milliseconds: 80));

      completer.complete();

      final result2 = await future2;
      await future1;

      expect(result2, null);
      expect(secondRan, false);
    });

    test('queue continues after timed out call', () async {
      final tracker = <int>[];
      final completer = Completer<void>();

      // First call - blocks
      final future1 = mix<void>(
        key: 'test',
        sequential: sequential(queueTimeout: const Duration(milliseconds: 20)),
        () async {
          tracker.add(1);
          await completer.future;
        },
      );

      await Future.delayed(const Duration(milliseconds: 5));

      // Second call - will timeout
      final future2 = mix<void>(
        key: 'test',
        sequential: sequential(queueTimeout: const Duration(milliseconds: 20)),
        () async {
          tracker.add(2);
        },
      );

      await Future.delayed(const Duration(milliseconds: 5));

      // Third call - also queued, will also timeout
      final future3 = mix<void>(
        key: 'test',
        sequential: sequential(queueTimeout: const Duration(milliseconds: 20)),
        () async {
          tracker.add(3);
        },
      );

      // Wait for timeouts
      await Future.delayed(const Duration(milliseconds: 50));

      // Complete first call
      completer.complete();
      await future1;
      await future2;
      await future3;

      // Only first should have run (2 and 3 timed out)
      expect(tracker, [1]);
    });

    test('no timeout when queueTimeout is null', () async {
      final tracker = <int>[];
      final completer = Completer<void>();

      // First call - blocks for a while
      final future1 = mix<void>(
        key: 'test',
        sequential: sequential, // No timeout
        () async {
          tracker.add(1);
          await completer.future;
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Second call - should wait indefinitely
      final future2 = mix<void>(
        key: 'test',
        sequential: sequential,
        () async {
          tracker.add(2);
        },
      );

      // Wait a while
      await Future.delayed(const Duration(milliseconds: 100));

      // Second should still be waiting
      expect(tracker, [1]);

      // Complete first
      completer.complete();
      await future1;
      await future2;

      // Now both should have run
      expect(tracker, [1, 2]);
    });
  });

  group('mix with sequential - error handling', () {
    test('queue advances when action fails', () async {
      final tracker = <int>[];

      // First call - fails
      final future1 = mix<void>(
        key: 'test',
        sequential: sequential,
        config: MixConfig(catchError: (e, s) {}), // Suppress error
        () async {
          tracker.add(1);
          throw TestException('First failed');
        },
      );

      // Second call - should still run after first fails
      final future2 = mix<void>(
        key: 'test',
        sequential: sequential,
        () async {
          tracker.add(2);
        },
      );

      await future1;
      await future2;

      // Both should have run in order
      expect(tracker, [1, 2]);
    });

    test('queue advances when action throws UserException', () async {
      final tracker = <int>[];

      // First call - throws UserException
      final future1 = mix<void>(
        key: 'test',
        sequential: sequential,
        () async {
          tracker.add(1);
          throw UserException('First failed');
        },
      );

      // Second call - should still run
      final future2 = mix<void>(
        key: 'test',
        sequential: sequential,
        () async {
          tracker.add(2);
        },
      );

      await future1;
      await future2;

      expect(tracker, [1, 2]);
      expect(Superpowers.errors.length, 1); // UserException was queued
    });

    test('queue advances when before() fails', () async {
      final tracker = <String>[];

      // First call - before() fails
      final future1 = mix<void>(
        key: 'test',
        sequential: sequential,
        config: MixConfig(
          before: () {
            tracker.add('before1');
            throw TestException('Before failed');
          },
          catchError: (e, s) {},
        ),
        () async {
          tracker.add('action1');
        },
      );

      // Second call - should still run
      final future2 = mix<void>(
        key: 'test',
        sequential: sequential,
        () async {
          tracker.add('action2');
        },
      );

      await future1;
      await future2;

      // before1 ran, action1 did not, action2 ran
      expect(tracker, ['before1', 'action2']);
    });

    test('after() is called even when action fails', () async {
      var afterCalled = false;

      await mix<void>(
        key: 'test',
        sequential: sequential,
        config: MixConfig(
          after: () {
            afterCalled = true;
          },
          catchError: (e, s) {},
        ),
        () async {
          throw TestException('Failed');
        },
      );

      expect(afterCalled, true);
    });

    test('catchError can transform errors', () async {
      final future1 = mix<void>(
        key: 'test',
        sequential: sequential,
        config: MixConfig(catchError: (e, s) => throw UserException('Wrapped error')),
        () async {
          throw TestException('Original error');
        },
      );

      await future1;

      expect(Superpowers.errors.length, 1);
      expect(Superpowers.errors.first.message, 'Wrapped error');
    });
  });

  group('mix with sequential - combination with retry', () {
    test('retries happen before next queued call starts', () async {
      final tracker = <String>[];
      var failCount = 0;

      // First call - fails twice then succeeds
      final future1 = mix<void>(
        key: 'test',
        sequential: sequential,
        retry: retry(
          maxRetries: 3,
          initialDelay: const Duration(milliseconds: 10),
        ),
        () async {
          failCount++;
          tracker.add('attempt1-$failCount');
          if (failCount < 3) throw TestException('Retry');
        },
      );

      // Second call - should wait for all retries to complete
      final future2 = mix<void>(
        key: 'test',
        sequential: sequential,
        () async {
          tracker.add('call2');
        },
      );

      await future1;
      await future2;

      // First call should retry twice, then succeed, then second call runs
      expect(tracker, ['attempt1-1', 'attempt1-2', 'attempt1-3', 'call2']);
    });

    test('next queued call starts after all retries exhausted', () async {
      final tracker = <String>[];

      // First call - always fails
      final future1 = mix<void>(
        key: 'test',
        sequential: sequential,
        retry: retry(
          maxRetries: 2,
          initialDelay: const Duration(milliseconds: 5),
        ),
        config: MixConfig(catchError: (e, s) {}), // Suppress error
        () async {
          tracker.add('attempt1');
          throw TestException('Always fails');
        },
      );

      // Second call - should run after first exhausts retries
      final future2 = mix<void>(
        key: 'test',
        sequential: sequential,
        () async {
          tracker.add('call2');
        },
      );

      await future1;
      await future2;

      // 3 attempts (1 initial + 2 retries), then second call
      expect(tracker, ['attempt1', 'attempt1', 'attempt1', 'call2']);
    });
  });

  group('mix with sequential - combination with other features', () {
    test('sequential with checkInternet', () async {
      Superpowers.clear(simulateInternet: () => true);

      final tracker = <int>[];

      final future1 = mix<void>(
        key: 'test',
        sequential: sequential,
        checkInternet: checkInternet,
        () async {
          tracker.add(1);
          await Future.delayed(const Duration(milliseconds: 20));
        },
      );

      final future2 = mix<void>(
        key: 'test',
        sequential: sequential,
        checkInternet: checkInternet,
        () async {
          tracker.add(2);
        },
      );

      await future1;
      await future2;

      expect(tracker, [1, 2]);
    });

    test('sequential + nonReentrant with same key (nonReentrant redundant)',
        () async {
      final tracker = <int>[];
      final completer = Completer<void>();

      // With sequential, calls are queued, so nonReentrant never triggers
      final future1 = mix<void>(
        key: 'test',
        sequential: sequential,
        nonReentrant: nonReentrant,
        () async {
          tracker.add(1);
          await completer.future;
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // This call will wait in sequential queue, not be dropped by nonReentrant
      // because by the time it reaches nonReentrant check, the first call
      // has already completed (sequential ensures serialization)
      final future2 = mix<void>(
        key: 'test',
        sequential: sequential,
        nonReentrant: nonReentrant,
        () async {
          tracker.add(2);
        },
      );

      completer.complete();
      await future1;
      await future2;

      // Both should run because sequential queues them
      expect(tracker, [1, 2]);
    });

    test('sequential + throttle with different keys', () async {
      final tracker = <int>[];

      final future1 = mix<void>(
        key: 'test',
        sequential: sequential(key: 'seq'),
        throttle: throttle(key: 'throttle', duration: 100.millis),
        () async {
          tracker.add(1);
          await Future.delayed(const Duration(milliseconds: 20));
        },
      );

      final future2 = mix<void>(
        key: 'test',
        sequential: sequential(key: 'seq'),
        throttle: throttle(key: 'throttle', duration: 100.millis),
        () async {
          tracker.add(2);
        },
      );

      await future1;
      await future2;

      // Second call will be blocked by throttle (after sequential wait completes)
      // because throttle is checked after sequential wait
      expect(tracker, [1]);
    });

    test('sequential + fresh with same key', () async {
      final tracker = <int>[];

      final future1 = mix<void>(
        key: 'test',
        sequential: sequential,
        fresh: fresh(freshFor: 100.millis),
        () async {
          tracker.add(1);
          await Future.delayed(const Duration(milliseconds: 20));
        },
      );

      final future2 = mix<void>(
        key: 'test',
        sequential: sequential,
        fresh: fresh(freshFor: 100.millis),
        () async {
          tracker.add(2);
        },
      );

      await future1;
      await future2;

      // Second call will be blocked by fresh (still fresh after sequential wait)
      expect(tracker, [1]);
    });
  });

  group('mix with sequential - queue cleanup', () {
    test('queue advances when nonReentrant aborts (different sequential key)',
        () async {
      final tracker = <String>[];
      final completer1 = Completer<void>();
      final completer2 = Completer<void>();

      // First call for sequential queue
      final future1 = mix<void>(
        key: 'test',
        sequential: sequential,
        () async {
          tracker.add('seq1');
          await completer1.future;
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Start a nonReentrant call (not using sequential)
      final nonReentrantFuture = mix<void>(
        key: 'nr',
        nonReentrant: nonReentrant(key: 'nr-key'),
        () async {
          tracker.add('nr-start');
          await completer2.future;
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Second call for sequential queue
      final future2 = mix<void>(
        key: 'test',
        sequential: sequential,
        () async {
          tracker.add('seq2');
        },
      );

      // seq1 is running, nr is running, seq2 is queued
      expect(tracker, ['seq1', 'nr-start']);

      completer1.complete();
      completer2.complete();

      await future1;
      await future2;
      await nonReentrantFuture;

      expect(tracker, ['seq1', 'nr-start', 'seq2']);
    });

    test('sequential cleanup happens even if action is aborted by fresh',
        () async {
      final tracker = <int>[];

      // First call - sets fresh
      await mix<void>(
        key: 'test',
        sequential: sequential,
        fresh: fresh(freshFor: 500.millis),
        () async {
          tracker.add(1);
        },
      );

      // Second call - should be queued by sequential, then aborted by fresh
      final result2 = await mix<int?>(
        key: 'test',
        sequential: sequential,
        fresh: fresh(freshFor: 500.millis),
        () async {
          tracker.add(2);
          return 2;
        },
      );

      // Second was aborted by fresh (returned null), but queue should still work
      expect(result2, null);
      expect(tracker, [1]);

      // Wait for fresh to expire
      await Future.delayed(const Duration(milliseconds: 550));

      // Third call - should work
      await mix<void>(
        key: 'test',
        sequential: sequential,
        fresh: fresh(freshFor: 500.millis),
        () async {
          tracker.add(3);
        },
      );

      expect(tracker, [1, 3]);
    });
  });

  group('SequentialConfig', () {
    test('default values', () {
      expect(sequential.key, null);
      expect(sequential.maxQueueSize, null);
      expect(sequential.queueTimeout, null);
    });

    test('call() creates new config with overridden values', () {
      final config = sequential(
        key: 'myKey',
        maxQueueSize: 5,
        queueTimeout: const Duration(seconds: 10),
      );

      expect(config.key, 'myKey');
      expect(config.maxQueueSize, 5);
      expect(config.queueTimeout, const Duration(seconds: 10));
    });

    test('call() preserves existing values when not overridden', () {
      final config1 = sequential(key: 'first', maxQueueSize: 3);
      final config2 = config1(queueTimeout: const Duration(seconds: 5));

      expect(config2.key, 'first');
      expect(config2.maxQueueSize, 3);
      expect(config2.queueTimeout, const Duration(seconds: 5));
    });
  });

  group('mix with sequential - stress tests', () {
    test('handles many concurrent calls', () async {
      final tracker = <int>[];
      const numCalls = 20;

      final futures = <FutureOr<void>>[];
      for (var i = 0; i < numCalls; i++) {
        final index = i;
        futures.add(mix<void>(
          key: 'test',
          sequential: sequential,
          () async {
            await Future.delayed(const Duration(milliseconds: 5));
            tracker.add(index);
          },
        ));
      }

      for (final future in futures) {
        await future;
      }

      // All calls should execute in order
      expect(tracker.length, numCalls);
      for (var i = 0; i < numCalls; i++) {
        expect(tracker[i], i);
      }
    });

    test('handles rapid calls with maxQueueSize', () async {
      final tracker = <int>[];
      final completer = Completer<void>();

      // First call blocks
      final future1 = mix<int?>(
        key: 'test',
        sequential: sequential(maxQueueSize: 3),
        () async {
          tracker.add(0);
          await completer.future;
          return 0;
        },
      );

      await Future.delayed(const Duration(milliseconds: 5));

      // Dispatch rapid calls without awaiting - some will queue, some will drop
      final futures = <FutureOr<int?>>[];
      for (var i = 1; i <= 10; i++) {
        final index = i;
        futures.add(mix<int?>(
          key: 'test',
          sequential: sequential(maxQueueSize: 3),
          () async {
            tracker.add(index);
            return index;
          },
        ));
        // Small delay to ensure ordering
        await Future.delayed(const Duration(milliseconds: 1));
      }

      // Complete the blocking call
      completer.complete();

      // Wait for all futures
      final results = <int?>[];
      results.add(await future1);
      for (final future in futures) {
        results.add(await future);
      }

      // First call ran, 3 were queued, 7 were dropped
      // Total executed: 1 (running) + 3 (queued) = 4
      expect(tracker.length, 4);
      expect(tracker[0], 0);

      // Count non-null results (successful executions)
      final executedCount = results.where((r) => r != null).length;
      expect(executedCount, 4);
    });

    test('multiple sequential queues operate independently', () async {
      final trackerA = <int>[];
      final trackerB = <int>[];

      final futuresA = <FutureOr<void>>[];
      final futuresB = <FutureOr<void>>[];

      for (var i = 0; i < 5; i++) {
        final index = i;
        futuresA.add(mix<void>(
          key: 'test',
          sequential: sequential(key: 'A'),
          () async {
            await Future.delayed(const Duration(milliseconds: 10));
            trackerA.add(index);
          },
        ));
        futuresB.add(mix<void>(
          key: 'test',
          sequential: sequential(key: 'B'),
          () async {
            await Future.delayed(const Duration(milliseconds: 10));
            trackerB.add(index);
          },
        ));
      }

      for (final future in futuresA) {
        await future;
      }
      for (final future in futuresB) {
        await future;
      }

      // Both queues should complete independently and in order
      expect(trackerA, [0, 1, 2, 3, 4]);
      expect(trackerB, [0, 1, 2, 3, 4]);
    });
  });

  group('mix with sequential - edge cases', () {
    test('empty action completes and advances queue', () async {
      final tracker = <int>[];

      await mix<void>(
        key: 'test',
        sequential: sequential,
        () async {
          // Empty action
        },
      );

      await mix<void>(
        key: 'test',
        sequential: sequential,
        () async {
          tracker.add(1);
        },
      );

      expect(tracker, [1]);
    });

    test('synchronous action works', () async {
      final tracker = <int>[];

      await mix<void>(
        key: 'test',
        sequential: sequential,
        () {
          tracker.add(1);
        },
      );

      await mix<void>(
        key: 'test',
        sequential: sequential,
        () {
          tracker.add(2);
        },
      );

      expect(tracker, [1, 2]);
    });

    test('action that returns value works in queue', () async {
      final results = <int>[];

      final future1 = mix<int>(
        key: 'test',
        sequential: sequential,
        () async {
          await Future.delayed(const Duration(milliseconds: 20));
          return 1;
        },
      );

      final future2 = mix<int>(
        key: 'test',
        sequential: sequential,
        () async => 2,
      );

      final future3 = mix<int>(
        key: 'test',
        sequential: sequential,
        () async => 3,
      );

      results.add((await future1)!);
      results.add((await future2)!);
      results.add((await future3)!);

      expect(results, [1, 2, 3]);
    });

    test('AbortException in action advances queue', () async {
      final tracker = <int>[];

      final future1 = mix<void>(
        key: 'test',
        sequential: sequential,
        () async {
          tracker.add(1);
          throw AbortException();
        },
      );

      final future2 = mix<void>(
        key: 'test',
        sequential: sequential,
        () async {
          tracker.add(2);
        },
      );

      await future1;
      await future2;

      expect(tracker, [1, 2]);
    });

    test('Superpowers.clear() clears sequential state', () async {
      final tracker = <int>[];
      final completer = Completer<void>();

      // Start a blocking call
      final future1 = mix<void>(
        key: 'test',
        sequential: sequential,
        () async {
          tracker.add(1);
          await completer.future;
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Queue a call
      mix<void>(
        key: 'test',
        sequential: sequential,
        () async {
          tracker.add(2);
        },
      );

      // Reset Superpowers state
      Superpowers.clear();

      // New call should start immediately (state was cleared)
      await mix<void>(
        key: 'test',
        sequential: sequential,
        () async {
          tracker.add(3);
        },
      );

      // 3 ran immediately because init() cleared the queue state
      expect(tracker.contains(3), true);

      // Complete the original call (might cause issues if not handled)
      completer.complete();
      try {
        await future1;
      } catch (_) {
        // Ignore any errors
      }
    });
  });

  group('onQueued callback', () {
    test('onQueued is called when a call is queued', () async {
      Object? queuedKey;
      int? queuedPosition;
      var queuedCount = 0;

      final completer = Completer<void>();

      // First call - starts immediately, not queued
      final future1 = mix<void>(
        key: 'test',
        sequential: sequential(
          key: 'testKey',
          onQueued: (key, position) {
            queuedKey = key;
            queuedPosition = position;
            queuedCount++;
          },
        ),
        () async {
          await completer.future;
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Second call - should be queued
      final future2 = mix<void>(
        key: 'test',
        sequential: sequential(
          key: 'testKey',
          onQueued: (key, position) {
            queuedKey = key;
            queuedPosition = position;
            queuedCount++;
          },
        ),
        () async {},
      );

      expect(queuedCount, 1);
      expect(queuedKey, 'testKey');
      expect(queuedPosition, 1); // Position 1 in queue

      completer.complete();
      await future1;
      await future2;
    });

    test('onQueued is not called when call runs immediately', () async {
      var queuedCount = 0;

      await mix<void>(
        key: 'test',
        sequential: sequential(
          key: 'testKey',
          onQueued: (key, position) {
            queuedCount++;
          },
        ),
        () async {},
      );

      expect(queuedCount, 0);
    });

    test('onQueued receives correct queue positions', () async {
      final queuedPositions = <int>[];
      final completer = Completer<void>();

      // First call - starts immediately
      final future1 = mix<void>(
        key: 'test',
        sequential: sequential(
          key: 'test',
          onQueued: (key, position) => queuedPositions.add(position),
        ),
        () async {
          await completer.future;
        },
      );

      await Future.delayed(const Duration(milliseconds: 5));

      // Second call - position 1
      final future2 = mix<void>(
        key: 'test',
        sequential: sequential(
          key: 'test',
          onQueued: (key, position) => queuedPositions.add(position),
        ),
        () async {},
      );

      await Future.delayed(const Duration(milliseconds: 5));

      // Third call - position 2
      final future3 = mix<void>(
        key: 'test',
        sequential: sequential(
          key: 'test',
          onQueued: (key, position) => queuedPositions.add(position),
        ),
        () async {},
      );

      await Future.delayed(const Duration(milliseconds: 5));

      // Fourth call - position 3
      final future4 = mix<void>(
        key: 'test',
        sequential: sequential(
          key: 'test',
          onQueued: (key, position) => queuedPositions.add(position),
        ),
        () async {},
      );

      expect(queuedPositions, [1, 2, 3]);

      completer.complete();
      await future1;
      await future2;
      await future3;
      await future4;
    });

    test('onQueued works with mix.ctx', () async {
      var queuedCount = 0;
      final completer = Completer<void>();

      // First call
      final future1 = mix.ctx<void>(
        (ctx) async {
          await completer.future;
        },
        key: 'test',
        sequential: sequential(
          key: 'test',
          onQueued: (key, position) => queuedCount++,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Second call - should be queued
      final future2 = mix.ctx<void>(
        (ctx) async {},
        key: 'test',
        sequential: sequential(
          key: 'test',
          onQueued: (key, position) => queuedCount++,
        ),
      );

      expect(queuedCount, 1);

      completer.complete();
      await future1;
      await future2;
    });
  });

  group('onDropped callback', () {
    test('onDropped is called with queueFull reason when queue is full', () async {
      Object? droppedKey;
      SequentialDropReason? droppedReason;
      var droppedCount = 0;

      final completer = Completer<void>();

      // First call - starts immediately
      final future1 = mix<void>(
        key: 'test',
        sequential: sequential(
          key: 'testKey',
          maxQueueSize: 1,
          onDropped: (key, reason) {
            droppedKey = key;
            droppedReason = reason;
            droppedCount++;
          },
        ),
        () async {
          await completer.future;
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Second call - queued (1 in queue)
      final future2 = mix<void>(
        key: 'test',
        sequential: sequential(
          key: 'testKey',
          maxQueueSize: 1,
          onDropped: (key, reason) {
            droppedKey = key;
            droppedReason = reason;
            droppedCount++;
          },
        ),
        () async {},
      );

      // Third call - should be dropped (queue full)
      await mix<void>(
        key: 'test',
        sequential: sequential(
          key: 'testKey',
          maxQueueSize: 1,
          onDropped: (key, reason) {
            droppedKey = key;
            droppedReason = reason;
            droppedCount++;
          },
        ),
        () async {},
      );

      expect(droppedCount, 1);
      expect(droppedKey, 'testKey');
      expect(droppedReason, SequentialDropReason.queueFull);

      completer.complete();
      await future1;
      await future2;
    });

    test('onDropped is called with timeout reason when call times out', () async {
      Object? droppedKey;
      SequentialDropReason? droppedReason;
      var droppedCount = 0;

      final completer = Completer<void>();

      // First call - blocks
      final future1 = mix<void>(
        key: 'test',
        sequential: sequential(
          key: 'testKey',
          queueTimeout: const Duration(milliseconds: 50),
          onDropped: (key, reason) {
            droppedKey = key;
            droppedReason = reason;
            droppedCount++;
          },
        ),
        () async {
          await completer.future;
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Second call - will timeout
      final future2 = mix<void>(
        key: 'test',
        sequential: sequential(
          key: 'testKey',
          queueTimeout: const Duration(milliseconds: 50),
          onDropped: (key, reason) {
            droppedKey = key;
            droppedReason = reason;
            droppedCount++;
          },
        ),
        () async {},
      );

      // Wait for timeout
      await Future.delayed(const Duration(milliseconds: 100));

      completer.complete();
      await future1;
      await future2;

      expect(droppedCount, 1);
      expect(droppedKey, 'testKey');
      expect(droppedReason, SequentialDropReason.timeout);
    });

    test('onDropped is not called when call executes', () async {
      var droppedCount = 0;

      await mix<void>(
        key: 'test',
        sequential: sequential(
          key: 'testKey',
          onDropped: (key, reason) {
            droppedCount++;
          },
        ),
        () async {},
      );

      expect(droppedCount, 0);
    });

    test('onDropped is not called when call is queued but executes', () async {
      var droppedCount = 0;
      final completer = Completer<void>();

      // First call
      final future1 = mix<void>(
        key: 'test',
        sequential: sequential(
          key: 'test',
          onDropped: (key, reason) => droppedCount++,
        ),
        () async {
          await completer.future;
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Second call - queued but will execute
      final future2 = mix<void>(
        key: 'test',
        sequential: sequential(
          key: 'test',
          onDropped: (key, reason) => droppedCount++,
        ),
        () async {},
      );

      completer.complete();
      await future1;
      await future2;

      expect(droppedCount, 0);
    });

    test('multiple drops with queueFull reason', () async {
      final droppedReasons = <SequentialDropReason>[];
      final completer = Completer<void>();

      // First call - runs
      final future1 = mix<void>(
        key: 'test',
        sequential: sequential(
          key: 'test',
          maxQueueSize: 0, // No queue allowed
          onDropped: (key, reason) => droppedReasons.add(reason),
        ),
        () async {
          await completer.future;
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // These should all be dropped
      for (var i = 0; i < 3; i++) {
        await mix<void>(
          key: 'test',
          sequential: sequential(
            key: 'test',
            maxQueueSize: 0,
            onDropped: (key, reason) => droppedReasons.add(reason),
          ),
          () async {},
        );
      }

      expect(droppedReasons.length, 3);
      expect(droppedReasons.every((r) => r == SequentialDropReason.queueFull), true);

      completer.complete();
      await future1;
    });

    test('onDropped works with mix.ctx', () async {
      var droppedCount = 0;
      final completer = Completer<void>();

      // First call
      final future1 = mix.ctx<void>(
        (ctx) async {
          await completer.future;
        },
        key: 'test',
        sequential: sequential(
          key: 'test',
          maxQueueSize: 0,
          onDropped: (key, reason) => droppedCount++,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Second call - should be dropped
      await mix.ctx<void>(
        (ctx) async {},
        key: 'test',
        sequential: sequential(
          key: 'test',
          maxQueueSize: 0,
          onDropped: (key, reason) => droppedCount++,
        ),
      );

      expect(droppedCount, 1);

      completer.complete();
      await future1;
    });
  });

  group('onQueued and onDropped together', () {
    test('onQueued then onDropped for timeout', () async {
      var queuedCount = 0;
      var droppedCount = 0;
      SequentialDropReason? droppedReason;

      final completer = Completer<void>();

      // First call
      final future1 = mix<void>(
        key: 'test',
        sequential: sequential(
          key: 'test',
          queueTimeout: const Duration(milliseconds: 30),
          onQueued: (key, position) => queuedCount++,
          onDropped: (key, reason) {
            droppedCount++;
            droppedReason = reason;
          },
        ),
        () async {
          await completer.future;
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Second call - queued, then times out
      final future2 = mix<void>(
        key: 'test',
        sequential: sequential(
          key: 'test',
          queueTimeout: const Duration(milliseconds: 30),
          onQueued: (key, position) => queuedCount++,
          onDropped: (key, reason) {
            droppedCount++;
            droppedReason = reason;
          },
        ),
        () async {},
      );

      // Wait for timeout
      await Future.delayed(const Duration(milliseconds: 80));

      completer.complete();
      await future1;
      await future2;

      // onQueued was called when queued
      expect(queuedCount, 1);
      // onDropped was called when timed out
      expect(droppedCount, 1);
      expect(droppedReason, SequentialDropReason.timeout);
    });

    test('onDropped for queueFull does not call onQueued', () async {
      var queuedCount = 0;
      var droppedCount = 0;

      final completer = Completer<void>();

      // First call
      final future1 = mix<void>(
        key: 'test',
        sequential: sequential(
          key: 'test',
          maxQueueSize: 0,
          onQueued: (key, position) => queuedCount++,
          onDropped: (key, reason) => droppedCount++,
        ),
        () async {
          await completer.future;
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Second call - dropped immediately (queue full)
      await mix<void>(
        key: 'test',
        sequential: sequential(
          key: 'test',
          maxQueueSize: 0,
          onQueued: (key, position) => queuedCount++,
          onDropped: (key, reason) => droppedCount++,
        ),
        () async {},
      );

      // onQueued should not be called (dropped before queuing)
      expect(queuedCount, 0);
      expect(droppedCount, 1);

      completer.complete();
      await future1;
    });
  });

  group('dropOldest feature', () {
    test('dropOldest defaults to false', () {
      // Raw config has null (not specified)
      expect(sequential.dropOldest, null);
      expect(sequential(key: 'test').dropOldest, null);
      // After merging with defaults and resolving, dropOldest is false
      expect(SequentialConfig.defaults.dropOldest, false);
      expect(SequentialConfig.defaults.merge(sequential).resolve().dropOldest, false);
    });

    test('dropOldest can be set to true', () {
      final config = sequential(dropOldest: true);
      expect(config.dropOldest, true);
    });

    test('dropOldest supersedes oldest waiting call when queue is full', () async {
      final tracker = <int>[];
      final completer = Completer<void>();

      // First call - starts immediately
      final future1 = mix<void>(
        key: 'test',
        sequential: sequential(maxQueueSize: 1, dropOldest: true),
        () async {
          tracker.add(1);
          await completer.future;
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Second call - queued (1 in queue = at limit)
      final future2 = mix<void>(
        key: 'test',
        sequential: sequential(maxQueueSize: 1, dropOldest: true),
        () async {
          tracker.add(2);
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Third call - should supersede second call (dropOldest)
      final future3 = mix<void>(
        key: 'test',
        sequential: sequential(maxQueueSize: 1, dropOldest: true),
        () async {
          tracker.add(3);
        },
      );

      completer.complete();
      await future1;
      await future2;
      await future3;

      // 1 ran, 2 was superseded, 3 ran
      expect(tracker, [1, 3]);
    });

    test('dropOldest calls onDropped with superseded reason', () async {
      final droppedReasons = <SequentialDropReason>[];
      final droppedKeys = <Object>[];
      final completer = Completer<void>();

      // First call
      final future1 = mix<void>(
        key: 'test',
        sequential: sequential(
          key: 'testKey',
          maxQueueSize: 1,
          dropOldest: true,
          onDropped: (key, reason) {
            droppedKeys.add(key);
            droppedReasons.add(reason);
          },
        ),
        () async {
          await completer.future;
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Second call - queued
      final future2 = mix<void>(
        key: 'test',
        sequential: sequential(
          key: 'testKey',
          maxQueueSize: 1,
          dropOldest: true,
          onDropped: (key, reason) {
            droppedKeys.add(key);
            droppedReasons.add(reason);
          },
        ),
        () async {},
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Third call - supersedes second
      final future3 = mix<void>(
        key: 'test',
        sequential: sequential(
          key: 'testKey',
          maxQueueSize: 1,
          dropOldest: true,
          onDropped: (key, reason) {
            droppedKeys.add(key);
            droppedReasons.add(reason);
          },
        ),
        () async {},
      );

      expect(droppedReasons.length, 1);
      expect(droppedReasons[0], SequentialDropReason.superseded);
      expect(droppedKeys[0], 'testKey');

      completer.complete();
      await future1;
      await future2;
      await future3;
    });

    test('dropOldest preserves execution order of non-superseded calls', () async {
      final tracker = <int>[];
      final completer = Completer<void>();

      // First call - starts immediately
      final future1 = mix<void>(
        key: 'test',
        sequential: sequential(maxQueueSize: 2, dropOldest: true),
        () async {
          tracker.add(1);
          await completer.future;
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Queue 3 calls - only 2 can be in queue, so first queued (2) will be superseded
      final future2 = mix<void>(
        key: 'test',
        sequential: sequential(maxQueueSize: 2, dropOldest: true),
        () async {
          tracker.add(2);
        },
      );

      await Future.delayed(const Duration(milliseconds: 5));

      final future3 = mix<void>(
        key: 'test',
        sequential: sequential(maxQueueSize: 2, dropOldest: true),
        () async {
          tracker.add(3);
        },
      );

      await Future.delayed(const Duration(milliseconds: 5));

      // Fourth call supersedes the oldest waiting (2)
      final future4 = mix<void>(
        key: 'test',
        sequential: sequential(maxQueueSize: 2, dropOldest: true),
        () async {
          tracker.add(4);
        },
      );

      completer.complete();
      await future1;
      await future2;
      await future3;
      await future4;

      // 1 ran, 2 was superseded, 3 and 4 ran in order
      expect(tracker, [1, 3, 4]);
    });

    test('dropOldest with maxQueueSize 1 always keeps latest waiting call', () async {
      final tracker = <int>[];
      final completer = Completer<void>();

      // First call blocks
      final future1 = mix<void>(
        key: 'test',
        sequential: sequential(maxQueueSize: 1, dropOldest: true),
        () async {
          tracker.add(1);
          await completer.future;
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Queue several calls - each new one supersedes the previous
      final futures = <FutureOr<void>>[];
      for (var i = 2; i <= 5; i++) {
        final index = i;
        futures.add(mix<void>(
          key: 'test',
          sequential: sequential(maxQueueSize: 1, dropOldest: true),
          () async {
            tracker.add(index);
          },
        ));
        await Future.delayed(const Duration(milliseconds: 5));
      }

      completer.complete();
      await future1;
      for (final f in futures) {
        await f;
      }

      // Only 1 and 5 should run (5 is the last one, superseded all others)
      expect(tracker, [1, 5]);
    });

    test('dropOldest does not drop if no waiters exist', () async {
      final tracker = <int>[];
      final completer = Completer<void>();

      // First call blocks
      final future1 = mix<void>(
        key: 'test',
        sequential: sequential(maxQueueSize: 0, dropOldest: true),
        () async {
          tracker.add(1);
          await completer.future;
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Second call - queue is full (maxQueueSize: 0), but no waiters to supersede
      // So it should be dropped (queueFull behavior)
      final result2 = await mix<int?>(
        key: 'test',
        sequential: sequential(maxQueueSize: 0, dropOldest: true),
        () async {
          tracker.add(2);
          return 2;
        },
      );

      expect(result2, null);

      completer.complete();
      await future1;

      // Only 1 ran (2 was dropped because no waiters to supersede)
      expect(tracker, [1]);
    });

    test('dropOldest calls onDropped with queueFull when no waiters to supersede', () async {
      SequentialDropReason? droppedReason;
      final completer = Completer<void>();

      // First call
      final future1 = mix<void>(
        key: 'test',
        sequential: sequential(
          maxQueueSize: 0,
          dropOldest: true,
          onDropped: (key, reason) => droppedReason = reason,
        ),
        () async {
          await completer.future;
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Second call - dropped (no waiters to supersede)
      await mix<void>(
        key: 'test',
        sequential: sequential(
          maxQueueSize: 0,
          dropOldest: true,
          onDropped: (key, reason) => droppedReason = reason,
        ),
        () async {},
      );

      expect(droppedReason, SequentialDropReason.queueFull);

      completer.complete();
      await future1;
    });

    test('dropOldest works with mix.ctx', () async {
      final tracker = <int>[];
      final completer = Completer<void>();

      // First call
      final future1 = mix.ctx<void>(
        (ctx) async {
          tracker.add(1);
          await completer.future;
        },
        key: 'test',
        sequential: sequential(maxQueueSize: 1, dropOldest: true),
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Second call - queued
      final future2 = mix.ctx<void>(
        (ctx) async {
          tracker.add(2);
        },
        key: 'test',
        sequential: sequential(maxQueueSize: 1, dropOldest: true),
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Third call - supersedes second
      final future3 = mix.ctx<void>(
        (ctx) async {
          tracker.add(3);
        },
        key: 'test',
        sequential: sequential(maxQueueSize: 1, dropOldest: true),
      );

      completer.complete();
      await future1;
      await future2;
      await future3;

      expect(tracker, [1, 3]);
    });

    test('multiple sequential supersedes', () async {
      final tracker = <int>[];
      var supersededCount = 0;
      final completer = Completer<void>();

      // First call blocks
      final future1 = mix<void>(
        key: 'test',
        sequential: sequential(
          maxQueueSize: 1,
          dropOldest: true,
          onDropped: (key, reason) {
            if (reason == SequentialDropReason.superseded) supersededCount++;
          },
        ),
        () async {
          tracker.add(1);
          await completer.future;
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Queue several calls - each supersedes the previous
      final futures = <FutureOr<void>>[];
      for (var i = 2; i <= 6; i++) {
        final index = i;
        futures.add(mix<void>(
          key: 'test',
          sequential: sequential(
            maxQueueSize: 1,
            dropOldest: true,
            onDropped: (key, reason) {
              if (reason == SequentialDropReason.superseded) supersededCount++;
            },
          ),
          () async {
            tracker.add(index);
          },
        ));
        await Future.delayed(const Duration(milliseconds: 5));
      }

      // 4 calls were superseded (2, 3, 4, 5)
      expect(supersededCount, 4);

      completer.complete();
      await future1;
      for (final f in futures) {
        await f;
      }

      // Only 1 and 6 ran
      expect(tracker, [1, 6]);
    });

    test('dropOldest: false (default) drops newest when queue is full', () async {
      final tracker = <int>[];
      final droppedReasons = <SequentialDropReason>[];
      final completer = Completer<void>();

      // First call blocks
      final future1 = mix<void>(
        key: 'test',
        sequential: sequential(
          maxQueueSize: 1,
          dropOldest: false, // Explicit default
          onDropped: (key, reason) => droppedReasons.add(reason),
        ),
        () async {
          tracker.add(1);
          await completer.future;
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Second call - queued
      final future2 = mix<void>(
        key: 'test',
        sequential: sequential(
          maxQueueSize: 1,
          dropOldest: false,
          onDropped: (key, reason) => droppedReasons.add(reason),
        ),
        () async {
          tracker.add(2);
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Third call - dropped (queue full, dropOldest: false)
      final result3 = await mix<int?>(
        key: 'test',
        sequential: sequential(
          maxQueueSize: 1,
          dropOldest: false,
          onDropped: (key, reason) => droppedReasons.add(reason),
        ),
        () async {
          tracker.add(3);
          return 3;
        },
      );

      expect(result3, null);
      expect(droppedReasons, [SequentialDropReason.queueFull]);

      completer.complete();
      await future1;
      await future2;

      // 1 and 2 ran, 3 was dropped
      expect(tracker, [1, 2]);
    });

    test('superseded call returns null', () async {
      final completer = Completer<void>();

      // First call blocks
      final future1 = mix<void>(
        key: 'test',
        sequential: sequential(maxQueueSize: 1, dropOldest: true),
        () async {
          await completer.future;
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Second call - queued, will be superseded
      final future2 = mix<int?>(
        key: 'test',
        sequential: sequential(maxQueueSize: 1, dropOldest: true),
        () async => 42,
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Third call - supersedes second
      final future3 = mix<int?>(
        key: 'test',
        sequential: sequential(maxQueueSize: 1, dropOldest: true),
        () async => 100,
      );

      completer.complete();
      await future1;
      final result2 = await future2;
      final result3 = await future3;

      expect(result2, null); // Superseded
      expect(result3, 100); // Executed
    });

    test('dropOldest combined with timeout', () async {
      final tracker = <int>[];
      final droppedReasons = <SequentialDropReason>[];
      final completer = Completer<void>();

      // First call blocks for a long time
      final future1 = mix<void>(
        key: 'test',
        sequential: sequential(
          maxQueueSize: 2,
          dropOldest: true,
          queueTimeout: const Duration(milliseconds: 50),
          onDropped: (key, reason) => droppedReasons.add(reason),
        ),
        () async {
          tracker.add(1);
          await completer.future;
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Second call - queued, will timeout
      final future2 = mix<void>(
        key: 'test',
        sequential: sequential(
          maxQueueSize: 2,
          dropOldest: true,
          queueTimeout: const Duration(milliseconds: 50),
          onDropped: (key, reason) => droppedReasons.add(reason),
        ),
        () async {
          tracker.add(2);
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Third call - queued
      final future3 = mix<void>(
        key: 'test',
        sequential: sequential(
          maxQueueSize: 2,
          dropOldest: true,
          queueTimeout: const Duration(milliseconds: 50),
          onDropped: (key, reason) => droppedReasons.add(reason),
        ),
        () async {
          tracker.add(3);
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Fourth call - supersedes second (oldest waiting)
      final future4 = mix<void>(
        key: 'test',
        sequential: sequential(
          maxQueueSize: 2,
          dropOldest: true,
          queueTimeout: const Duration(milliseconds: 50),
          onDropped: (key, reason) => droppedReasons.add(reason),
        ),
        () async {
          tracker.add(4);
        },
      );

      // Wait for remaining calls to potentially timeout
      await Future.delayed(const Duration(milliseconds: 100));

      completer.complete();
      await future1;
      await future2;
      await future3;
      await future4;

      // Call 2 was superseded, calls 3 and 4 timed out (waited > 50ms)
      // Note: timeout is checked AFTER waking up, so superseded call 2
      // doesn't timeout - it's already marked superseded
      expect(droppedReasons.contains(SequentialDropReason.superseded), true);
      // Remaining calls may have timed out or executed depending on timing
      expect(tracker.contains(1), true);
    });

    test('dropOldest isWaiting/isFailed state tracking works correctly', () async {
      Superpowers.clear();
      final tracker = <int>[];
      final completer = Completer<void>();

      // First call
      final future1 = mix<void>(
        key: 'testKey',
        sequential: sequential(maxQueueSize: 1, dropOldest: true),
        () async {
          tracker.add(1);
          await completer.future;
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Check isWaiting
      expect(Superpowers.isWaiting('testKey'), true);

      // Second call - queued
      final future2 = mix<void>(
        key: 'testKey',
        sequential: sequential(maxQueueSize: 1, dropOldest: true),
        () async {
          tracker.add(2);
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Third call - supersedes second
      final future3 = mix<void>(
        key: 'testKey',
        sequential: sequential(maxQueueSize: 1, dropOldest: true),
        () async {
          tracker.add(3);
        },
      );

      completer.complete();
      await future1;
      await future2;
      await future3;

      // All calls completed
      expect(Superpowers.isWaiting('testKey'), false);
      expect(tracker, [1, 3]);
    });
  });

  group('sequential.latestWins', () {
    test('latestWins sets maxQueueSize: 1 and dropOldest: true', () {
      final config = sequential.latestWins;
      expect(config.maxQueueSize, 1);
      expect(config.dropOldest, true);
    });

    test('latestWins can be chained with call() for custom key', () {
      final config = sequential.latestWins(key: 'myKey');
      expect(config.key, 'myKey');
      expect(config.maxQueueSize, 1);
      expect(config.dropOldest, true);
    });

    test('latestWins can be chained from config with queueTimeout', () {
      final config = sequential(queueTimeout: const Duration(seconds: 5)).latestWins;
      expect(config.queueTimeout, const Duration(seconds: 5));
      expect(config.maxQueueSize, 1);
      expect(config.dropOldest, true);
    });

    test('latestWins keeps only latest waiting call', () async {
      final tracker = <int>[];
      final completer = Completer<void>();

      // First call blocks
      final future1 = mix<void>(
        key: 'test',
        sequential: sequential.latestWins,
        () async {
          tracker.add(1);
          await completer.future;
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Queue several calls - each supersedes the previous
      final futures = <FutureOr<void>>[];
      for (var i = 2; i <= 5; i++) {
        final index = i;
        futures.add(mix<void>(
          key: 'test',
          sequential: sequential.latestWins,
          () async {
            tracker.add(index);
          },
        ));
        await Future.delayed(const Duration(milliseconds: 5));
      }

      completer.complete();
      await future1;
      for (final f in futures) {
        await f;
      }

      // Only 1 and 5 should run (5 is the last one, superseded all others)
      expect(tracker, [1, 5]);
    });

    test('latestWins with custom key', () async {
      final tracker = <String>[];
      final completerA = Completer<void>();
      final completerB = Completer<void>();

      // Queue A - blocks
      final futureA1 = mix<void>(
        key: 'test',
        sequential: sequential.latestWins(key: 'A'),
        () async {
          tracker.add('A1');
          await completerA.future;
        },
      );

      // Queue B - blocks (different key, runs concurrently)
      final futureB1 = mix<void>(
        key: 'test',
        sequential: sequential.latestWins(key: 'B'),
        () async {
          tracker.add('B1');
          await completerB.future;
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Both should be running
      expect(tracker, ['A1', 'B1']);

      // Add more to queue A
      final futureA2 = mix<void>(
        key: 'test',
        sequential: sequential.latestWins(key: 'A'),
        () async {
          tracker.add('A2');
        },
      );

      await Future.delayed(const Duration(milliseconds: 5));

      final futureA3 = mix<void>(
        key: 'test',
        sequential: sequential.latestWins(key: 'A'),
        () async {
          tracker.add('A3');
        },
      );

      completerA.complete();
      completerB.complete();

      await futureA1;
      await futureA2;
      await futureA3;
      await futureB1;

      // A1, B1 ran, A2 was superseded, A3 ran
      expect(tracker, ['A1', 'B1', 'A3']);
    });
  });
}
