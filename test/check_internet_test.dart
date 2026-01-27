import 'dart:async';

import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:bloc_superpowers/src/connection_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    Superpowers.clear();
  });

  group('mix with checkInternet - basic behavior', () {
    test('action runs when internet is available', () async {
      Superpowers.clear(simulateInternet: () => true);

      var ran = false;
      await mix(
        key: '',
        checkInternet: checkInternet(
          abortSilently: false,
          ifOpenDialog: true,
          maxRetryDelay: null,
        ),
        () async {
          ran = true;
          return 42;
        },
      );

      expect(ran, true);
    });

    test('action returns result when internet is available', () async {
      Superpowers.clear(simulateInternet: () => true);

      final result = await mix(
        key: '',
        checkInternet: checkInternet(
          abortSilently: false,
          ifOpenDialog: true,
          maxRetryDelay: null,
        ),
        () async => 42,
      );

      expect(result, 42);
    });

    test('ifOpenDialog defaults to true when not specified', () async {
      Superpowers.clear(simulateInternet: () => false);

      // ifOpenDialog: null should default to true (queued for dialog)
      await mix(
        key: '',
        checkInternet: checkInternet(
          abortSilently: false,
          ifOpenDialog: null,
          maxRetryDelay: null,
        ),
        () async => 42,
      );

      expect(Superpowers.errors.length, 1);
      final error = Superpowers.errors.first as ConnectionException;
      expect(error.ifOpenDialog, true);
    });
  });


  // ============================================================
  // AbortWhenNoInternet behavior: abortSilently=true
  // ============================================================
  group('checkInternet - AbortWhenNoInternet behavior (abortSilently=true)',
      () {
    test('returns null when no internet', () async {
      Superpowers.clear(simulateInternet: () => false);

      final result = await mix<int?>(
        key: '',
        checkInternet: checkInternet(
            abortSilently: true, ifOpenDialog: null, maxRetryDelay: null),
        () async => 42,
      );

      expect(result, null);
    });

    test('action does not run when no internet', () async {
      Superpowers.clear(simulateInternet: () => false);

      var ran = false;
      await mix<int?>(
        key: '',
        checkInternet: checkInternet(
            abortSilently: true, ifOpenDialog: null, maxRetryDelay: null),
        () async {
          ran = true;
          return 42;
        },
      );

      expect(ran, false);
    });

    test('no exception thrown or queued', () async {
      Superpowers.clear(simulateInternet: () => false);

      // Should not throw
      await mix<int?>(
        key: '',
        checkInternet: checkInternet(
            abortSilently: true, ifOpenDialog: null, maxRetryDelay: null),
        () async => 42,
      );

      // No exception queued
      expect(Superpowers.errors.length, 0);
    });

    test('action runs normally when internet is available', () async {
      Superpowers.clear(simulateInternet: () => true);

      var ran = false;
      final result = await mix(
        key: '',
        checkInternet: checkInternet(
            abortSilently: true, ifOpenDialog: null, maxRetryDelay: null),
        () async {
          ran = true;
          return 42;
        },
      );

      expect(ran, true);
      expect(result, 42);
    });
  });

  // ============================================================
  // CheckInternet behavior: abortSilently=false, ifOpenDialog=true
  // ============================================================
  group('checkInternet - CheckInternet behavior (ifOpenDialog=true)', () {
    test('ConnectionException queued when no internet', () async {
      Superpowers.clear(simulateInternet: () => false);

      final result = await mix<int?>(
        key: '',
        checkInternet: checkInternet(
            abortSilently: false, ifOpenDialog: true, maxRetryDelay: null),
        () async => 42,
      );

      expect(result, null);
      expect(Superpowers.errors.length, 1);
      expect(Superpowers.errors.first, isA<ConnectionException>());
    });

    test('action does not run when no internet', () async {
      Superpowers.clear(simulateInternet: () => false);

      var ran = false;
      await mix<int?>(
        key: '',
        checkInternet: checkInternet(
            abortSilently: false, ifOpenDialog: true, maxRetryDelay: null),
        () async {
          ran = true;
          return 42;
        },
      );

      expect(ran, false);
    });

    test('ConnectionException has ifOpenDialog=true', () async {
      Superpowers.clear(simulateInternet: () => false);

      await mix<int?>(
        key: '',
        checkInternet: checkInternet(
            abortSilently: false, ifOpenDialog: true, maxRetryDelay: null),
        () async => 42,
      );

      final error = Superpowers.errors.first as ConnectionException;
      expect(error.ifOpenDialog, true);
      expect(error.message, 'There is no Internet');
    });

    test('no exception thrown (queued instead)', () async {
      Superpowers.clear(simulateInternet: () => false);

      // Should not throw - exception is queued
      await mix<int?>(
        key: '',
        checkInternet: checkInternet(
            abortSilently: false, ifOpenDialog: true, maxRetryDelay: null),
        () async => 42,
      );

      expect(Superpowers.errors.length, 1);
    });
  });

  // ============================================================
  // CheckInternet + NoDialog behavior: abortSilently=false, ifOpenDialog=false
  // ============================================================
  group('checkInternet - NoDialog behavior (ifOpenDialog=false)', () {
    test('ConnectionException thrown when no internet', () async {
      Superpowers.clear(simulateInternet: () => false);

      await expectLater(
        mix(
          key: '',
          checkInternet: checkInternet(
            abortSilently: false,
            ifOpenDialog: false,
            maxRetryDelay: null,
          ),
          () async => 42,
        ),
        throwsA(isA<ConnectionException>()),
      );
    });

    test('action does not run when no internet', () async {
      Superpowers.clear(simulateInternet: () => false);

      var ran = false;
      try {
        await mix(
          key: '',
          checkInternet: checkInternet(
              abortSilently: false,
              ifOpenDialog: false,
              maxRetryDelay: null),
          () async {
            ran = true;
            return 42;
          },
        );
      } catch (_) {}

      expect(ran, false);
    });

    test('ConnectionException has ifOpenDialog=false', () async {
      Superpowers.clear(simulateInternet: () => false);

      ConnectionException? caught;
      try {
        await mix(
          key: '',
          checkInternet: checkInternet(
              abortSilently: false,
              ifOpenDialog: false,
              maxRetryDelay: null),
          () async => 42,
        );
      } catch (e) {
        caught = e as ConnectionException;
      }

      expect(caught, isNotNull);
      expect(caught!.ifOpenDialog, false);
      expect(caught.message, 'There is no Internet');
    });

    test('exception NOT queued (thrown instead)', () async {
      Superpowers.clear(simulateInternet: () => false);

      try {
        await mix(
          key: '',
          checkInternet: checkInternet(
              abortSilently: false,
              ifOpenDialog: false,
              maxRetryDelay: null),
          () async => 42,
        );
      } catch (_) {}

      // Exception was thrown, not queued
      expect(Superpowers.errors.length, 0);
    });

    test('action runs normally when internet is available', () async {
      Superpowers.clear(simulateInternet: () => true);

      var ran = false;
      final result = await mix(
        key: '',
        checkInternet: checkInternet(
            abortSilently: false,
            ifOpenDialog: false,
            maxRetryDelay: null),
        () async {
          ran = true;
          return 42;
        },
      );

      expect(ran, true);
      expect(result, 42);
      expect(Superpowers.errors.length, 0);
    });

    test('catchError can transform the thrown exception', () async {
      Superpowers.clear(simulateInternet: () => false);

      await expectLater(
        mix(
          key: '',
          checkInternet: checkInternet(
              abortSilently: false,
              ifOpenDialog: false,
              maxRetryDelay: null),
          catchError: (error, stack) {
            if (error is ConnectionException) {
              throw Exception('Transformed: ${error.message}');
            }
            throw error;
          },
          () async => 42,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('catchError can suppress the exception', () async {
      Superpowers.clear(simulateInternet: () => false);

      final result = await mix<int?>(
        key: '',
        checkInternet: checkInternet(
            abortSilently: false,
            ifOpenDialog: false,
            maxRetryDelay: null),
        catchError: (error, stack) {}, // Suppress
        () async => 42,
      );

      expect(result, null);
      expect(Superpowers.errors.length, 0);
    });
  });

  group('checkInternet with error queue', () {
    test('catchError can transform ConnectionException', () async {
      Superpowers.clear(simulateInternet: () => false);

      await mix<int?>(
        key: '',
        checkInternet: checkInternet(
            abortSilently: false, ifOpenDialog: true, maxRetryDelay: null),
        catchError: (error, stack) {
          if (error is ConnectionException) {
            throw const UserException('Custom no internet message');
          }
          throw error;
        },
        () async => 42,
      );

      expect(Superpowers.errors.length, 1);
      expect(Superpowers.errors.first, isA<UserException>());
      expect(Superpowers.errors.first.message, 'Custom no internet message');
    });

    test('catchError can suppress ConnectionException', () async {
      Superpowers.clear(simulateInternet: () => false);

      final result = await mix<int?>(
        key: '',
        checkInternet: checkInternet(
            abortSilently: false, ifOpenDialog: true, maxRetryDelay: null),
        catchError: (error, stack) {}, // Suppress
        () async => 42,
      );

      expect(result, null);
      expect(Superpowers.errors.length, 0);
    });
  });

  group('checkInternet with lifecycle methods', () {
    test('before() not called when no internet and abortSilently=true',
        () async {
      Superpowers.clear(simulateInternet: () => false);

      var beforeCalled = false;
      await mix<int?>(
        key: '',
        config: MixConfig(before: () => beforeCalled = true),
        checkInternet: checkInternet(
            abortSilently: true, ifOpenDialog: null, maxRetryDelay: null),
        () async => 42,
      );

      expect(beforeCalled, false);
    });

    test('before() not called when no internet and ifOpenDialog=true',
        () async {
      Superpowers.clear(simulateInternet: () => false);

      var beforeCalled = false;
      await mix<int?>(
        key: '',
        config: MixConfig(before: () => beforeCalled = true),
        checkInternet: checkInternet(
            abortSilently: false, ifOpenDialog: true, maxRetryDelay: null),
        () async => 42,
      );

      expect(beforeCalled, false);
    });

    test('before() not called when no internet and ifOpenDialog=false',
        () async {
      Superpowers.clear(simulateInternet: () => false);

      var beforeCalled = false;
      try {
        await mix(
          key: '',
          config: MixConfig(before: () => beforeCalled = true),
          checkInternet: checkInternet(
            abortSilently: false,
            ifOpenDialog: false,
            maxRetryDelay: null,
          ),
          () async => 42,
        );
      } catch (_) {}

      expect(beforeCalled, false);
    });

    test('after() not called when no internet and abortSilently=true',
        () async {
      Superpowers.clear(simulateInternet: () => false);

      var afterCalled = false;
      await mix<int?>(
        key: '',
        config: MixConfig(after: () => afterCalled = true),
        checkInternet: checkInternet(
            abortSilently: true, ifOpenDialog: null, maxRetryDelay: null),
        () async => 42,
      );

      expect(afterCalled, false);
    });

    test('before() and after() called when internet is available', () async {
      Superpowers.clear(simulateInternet: () => true);

      var beforeCalled = false;
      var afterCalled = false;
      await mix(
        key: '',
        config: MixConfig(
          before: () => beforeCalled = true,
          after: () => afterCalled = true,
        ),
        checkInternet: checkInternet(
          abortSilently: false,
          ifOpenDialog: true,
          maxRetryDelay: null,
        ),
        () async => 42,
      );

      expect(beforeCalled, true);
      expect(afterCalled, true);
    });
  });

  group('checkInternet with debounce', () {
    test('debounce happens before checkInternet', () async {
      Superpowers.clear(simulateInternet: () => false);

      var checkCount = 0;
      // Create a way to count internet checks
      final results = <int?>[];

      // Dispatch multiple calls rapidly
      final futures = [
        mix<int?>(
          key: '',
          debounce: debounce(key: 'test', duration: 50.millis),
          checkInternet: checkInternet(
              abortSilently: true,
              ifOpenDialog: null,
              maxRetryDelay: null),
          () async {
            checkCount++;
            return 1;
          },
        ),
        mix<int?>(
          key: '',
          debounce: debounce(key: 'test', duration: 50.millis),
          checkInternet: checkInternet(
              abortSilently: true,
              ifOpenDialog: null,
              maxRetryDelay: null),
          () async {
            checkCount++;
            return 2;
          },
        ),
      ];

      for (final future in futures) {
        results.add(await future);
      }
      await Future.delayed(const Duration(milliseconds: 100));

      // First call is superseded by second, so only one check happens
      // But the second call should still abort due to no internet
      expect(checkCount, 0); // No action runs because no internet
    });

    test('superseded debounce does not check internet', () async {
      Superpowers.clear(simulateInternet: () => true);

      var actionCount = 0;
      final futures = [
        mix<int?>(
          key: '',
          debounce: debounce(key: 'test', duration: 50.millis),
          checkInternet: checkInternet(
              abortSilently: false,
              ifOpenDialog: true,
              maxRetryDelay: null),
          () async {
            actionCount++;
            return 1;
          },
        ),
        mix<int?>(
          key: '',
          debounce: debounce(key: 'test', duration: 50.millis),
          checkInternet: checkInternet(
              abortSilently: false,
              ifOpenDialog: true,
              maxRetryDelay: null),
          () async {
            actionCount++;
            return 2;
          },
        ),
      ];

      for (final future in futures) {
        await future;
      }

      // Only the last debounced call runs
      expect(actionCount, 1);
    });
  });

  group('checkInternet with nonReentrant', () {
    test('checkInternet check happens before nonReentrant lock', () async {
      Superpowers.clear(simulateInternet: () => false);

      // First call should fail on internet check, not acquire lock
      await mix<int?>(
        key: '',
        checkInternet: checkInternet(
            abortSilently: true, ifOpenDialog: null, maxRetryDelay: null),
        nonReentrant: nonReentrant(key: 'test'),
        () async => 42,
      );

      // Second call should also fail on internet check (lock was never acquired)
      Superpowers.clear(simulateInternet: () => true);
      var ran = false;
      await mix(
        key: '',
        checkInternet: checkInternet(
            abortSilently: false, ifOpenDialog: true, maxRetryDelay: null),
        nonReentrant: nonReentrant(key: 'test'),
        () async {
          ran = true;
          return 42;
        },
      );

      expect(ran, true);
    });

    test('nonReentrant lock not acquired when no internet', () async {
      Superpowers.clear(simulateInternet: () => false);

      final completer = Completer<void>();

      // Start first call (will fail on internet check)
      final future1 = mix<int?>(
        key: '',
        checkInternet: checkInternet(
            abortSilently: true, ifOpenDialog: null, maxRetryDelay: null),
        nonReentrant: nonReentrant(key: 'test'),
        () async {
          await completer.future;
          return 1;
        },
      );

      await future1;

      // Second call should be able to run (lock was never acquired)
      Superpowers.clear(simulateInternet: () => true);
      var ran = false;
      await mix(
        key: '',
        checkInternet: checkInternet(
            abortSilently: false, ifOpenDialog: true, maxRetryDelay: null),
        nonReentrant: nonReentrant(key: 'test'),
        () async {
          ran = true;
          return 2;
        },
      );

      expect(ran, true);
    });
  });

  group('checkInternet with throttle', () {
    test('checkInternet check happens before throttle lock', () async {
      Superpowers.clear(simulateInternet: () => false);

      // First call should fail on internet check, not set throttle lock
      await mix<int?>(
        key: '',
        checkInternet: checkInternet(
            abortSilently: true, ifOpenDialog: null, maxRetryDelay: null),
        throttle: throttle(
            key: 'test',
            duration: 1000.sec,
            removeLockOnError: null,
            ignoreThrottle: null),
        () async => 42,
      );

      // Second call should also be able to run (throttle was never set)
      Superpowers.clear(simulateInternet: () => true);
      var ran = false;
      await mix(
        key: '',
        checkInternet: checkInternet(
            abortSilently: false, ifOpenDialog: true, maxRetryDelay: null),
        throttle: throttle(
            key: 'test',
            duration: 1000.sec,
            removeLockOnError: null,
            ignoreThrottle: null),
        () async {
          ran = true;
          return 42;
        },
      );

      expect(ran, true);
    });
  });

  group('checkInternet with fresh', () {
    test('checkInternet check happens before fresh check', () async {
      Superpowers.clear(simulateInternet: () => false);

      // First call should fail on internet check, not set fresh
      await mix<int?>(
        key: '',
        checkInternet: checkInternet(
            abortSilently: true, ifOpenDialog: null, maxRetryDelay: null),
        fresh: fresh(key: 'test', freshFor: 5000.millis, ignoreFresh: null),
        () async => 42,
      );

      // Second call should also be able to run (fresh was never set)
      Superpowers.clear(simulateInternet: () => true);
      var ran = false;
      await mix(
        key: '',
        checkInternet: checkInternet(
            abortSilently: false, ifOpenDialog: true, maxRetryDelay: null),
        fresh: fresh(key: 'test', freshFor: 5000.millis, ignoreFresh: null),
        () async {
          ran = true;
          return 42;
        },
      );

      expect(ran, true);
    });
  });

  group('checkInternet with maxRetryDelay', () {
    test('uses default maxRetryDelay of 1 second when not specified',
        () async {
      Superpowers.clear(simulateInternet: () => false);

      final delays = <Duration>[];
      await mix<int?>(
        key: '',
        checkInternet: checkInternet(
            abortSilently: false, ifOpenDialog: true, maxRetryDelay: null),
        retry: retry(
          maxRetries: 3,
          initialDelay: const Duration(milliseconds: 100),
          multiplier: 10.0,
          // Large multiplier to hit max quickly
          maxDelay: const Duration(seconds: 10),
          // Large maxDelay that shouldn't be used
          onRetry: (attempt, delay, error, stack) {
            delays.add(delay);
          },
        ),
        () async => 42,
      );

      // All delays should be capped at default 1 second (not 10 seconds)
      expect(delays.length, 3);
      expect(delays[0], const Duration(milliseconds: 100)); // First delay
      expect(delays[1],
          const Duration(seconds: 1)); // 100*10=1000ms -> capped at 1s
      expect(delays[2], const Duration(seconds: 1)); // Still capped at 1s
    });

    test('uses custom maxRetryDelay when specified', () async {
      Superpowers.clear(simulateInternet: () => false);

      final delays = <Duration>[];
      await mix<int?>(
        key: '',
        checkInternet: checkInternet(
          abortSilently: false,
          ifOpenDialog: true,
          maxRetryDelay: const Duration(milliseconds: 200),
        ),
        retry: retry(
          maxRetries: 3,
          initialDelay: const Duration(milliseconds: 100),
          multiplier: 10.0,
          // Large multiplier to hit max quickly
          maxDelay: const Duration(seconds: 10),
          // Large maxDelay that shouldn't be used
          onRetry: (attempt, delay, error, stack) {
            delays.add(delay);
          },
        ),
        () async => 42,
      );

      // All delays should be capped at 200ms (not 10 seconds)
      expect(delays.length, 3);
      expect(delays[0], const Duration(milliseconds: 100)); // First delay
      expect(
          delays[1],
          const Duration(
              milliseconds: 200)); // 100*10=1000ms -> capped at 200ms
      expect(delays[2],
          const Duration(milliseconds: 200)); // Still capped at 200ms
    });

    test(
        'uses maxDelay for non-internet errors, maxRetryDelay for internet errors',
        () async {
      // Start with internet, then lose it
      var hasInternet = true;
      var callCount = 0;
      Superpowers.clear(simulateInternet: () {
        callCount++;
        // First call has internet, but action fails
        // Second and third calls have no internet
        return callCount == 1;
      });

      final delays = <Duration>[];
      final errors = <Object>[];
      try {
        await mix(
          key: '',
          checkInternet: checkInternet(
            abortSilently: false,
            ifOpenDialog: false,
            maxRetryDelay: const Duration(milliseconds: 50),
          ),
          retry: retry(
            maxRetries: 3,
            initialDelay: const Duration(milliseconds: 20),
            multiplier: 100.0,
            // Very large multiplier
            maxDelay: const Duration(seconds: 5),
            // For non-internet errors
            onRetry: (attempt, delay, error, stack) {
              delays.add(delay);
              errors.add(error);
            },
          ),
          () async {
            throw Exception('Action failed');
          },
        );
      } catch (_) {}

      expect(delays.length, 3);
      expect(errors.length, 3);

      // First retry: action threw Exception (internet was available)
      // Uses maxDelay (5s) as cap, but initial delay is 20ms
      expect(delays[0], const Duration(milliseconds: 20));
      expect(errors[0], isA<Exception>());

      // Second retry: no internet error
      // Uses maxRetryDelay (50ms) as cap
      // 20ms * 100 = 2000ms, capped to 50ms
      expect(delays[1], const Duration(milliseconds: 50));
      expect(errors[1], isA<ConnectionException>());

      // Third retry: no internet error
      // Still capped at 50ms
      expect(delays[2], const Duration(milliseconds: 50));
      expect(errors[2], isA<ConnectionException>());
    });

    test('maxRetryDelay has no effect when checkInternet is not used',
        () async {
      Superpowers.clear(simulateInternet: () => true);

      final delays = <Duration>[];
      try {
        await mix(
          key: '',
          // Note: no checkInternet, so maxRetryDelay in a hypothetical config
          // wouldn't apply - this test verifies normal retry behavior
          retry: retry(
            maxRetries: 2,
            initialDelay: const Duration(milliseconds: 100),
            multiplier: 10.0,
            maxDelay: const Duration(milliseconds: 500),
            // Should be used
            onRetry: (attempt, delay, error, stack) {
              delays.add(delay);
            },
          ),
          () async {
            throw Exception('Fail');
          },
        );
      } catch (_) {}

      expect(delays.length, 2);
      expect(delays[0], const Duration(milliseconds: 100)); // First delay
      expect(
          delays[1],
          const Duration(
              milliseconds: 500)); // 100*10=1000ms -> capped at 500ms
    });

    test('maxRetryDelay allows quick internet detection', () async {
      var checkCount = 0;
      Superpowers.clear(simulateInternet: () {
        checkCount++;
        // Internet comes back on 5th check
        return checkCount >= 5;
      });

      final stopwatch = Stopwatch()..start();
      await mix<int?>(
        key: '',
        checkInternet: checkInternet(
          abortSilently: false,
          ifOpenDialog: true,
          maxRetryDelay: const Duration(milliseconds: 10), // Very short
        ),
        retry: retry(
          maxRetries: -1,
          // Unlimited
          initialDelay: const Duration(milliseconds: 5),
          multiplier: 2.0,
          maxDelay: const Duration(seconds: 30),
          // Would be slow if used
          onRetry: null,
        ),
        () async => 42,
      );
      stopwatch.stop();

      // Should complete quickly due to short maxRetryDelay
      expect(checkCount, 5);
      expect(stopwatch.elapsedMilliseconds, lessThan(500)); // Well under 30s
    });

    test('abortSilently ignores maxRetryDelay (no retry happens)',
        () async {
      Superpowers.clear(simulateInternet: () => false);

      var retryCount = 0;
      final result = await mix<int?>(
        key: '',
        checkInternet: checkInternet(
          abortSilently: true,
          ifOpenDialog: null,
          maxRetryDelay: const Duration(milliseconds: 50),
        ),
        retry: retry(
          maxRetries: 5,
          initialDelay: const Duration(milliseconds: 10),
          multiplier: 2.0,
          maxDelay: const Duration(seconds: 1),
          onRetry: (attempt, delay, error, stack) {
            retryCount++;
          },
        ),
        () async => 42,
      );

      // abortSilently=true means upfront check, no retry loop
      expect(result, null);
      expect(retryCount, 0);
    });
  });

  group('checkInternet with retry', () {
    test('action retries when internet is available and action fails',
        () async {
      Superpowers.clear(simulateInternet: () => true);

      var attempts = 0;
      try {
        await mix(
          key: '',
          checkInternet: checkInternet(
              abortSilently: false,
              ifOpenDialog: true,
              maxRetryDelay: null),
          retry: retry(
            maxRetries: 2,
            initialDelay: const Duration(milliseconds: 10),
            multiplier: 1.5,
            maxDelay: const Duration(milliseconds: 100),
            onRetry: null,
          ),
          () async {
            attempts++;
            throw Exception('Fail');
          },
        );
      } catch (_) {}

      expect(attempts, 3); // 1 initial + 2 retries
    });

    test('no retry when abortSilently=true (upfront check)', () async {
      Superpowers.clear(simulateInternet: () => false);

      var attempts = 0;
      await mix<int?>(
        key: '',
        checkInternet: checkInternet(
            abortSilently: true, ifOpenDialog: null, maxRetryDelay: null),
        retry: retry(
          maxRetries: 2,
          initialDelay: const Duration(milliseconds: 10),
          multiplier: 1.5,
          maxDelay: const Duration(milliseconds: 100),
          onRetry: null,
        ),
        () async {
          attempts++;
          return 42;
        },
      );

      expect(attempts, 0); // Never called - abortSilently uses upfront check
    });

    test('internet check retries when no internet and abortSilently=false',
        () async {
      // Start with no internet
      var hasInternet = false;
      Superpowers.clear(simulateInternet: () => hasInternet);

      var attempts = 0;
      var internetCheckCount = 0;

      // Simulate internet coming back after 2 retries
      final result = await mix<int?>(
        key: '',
        checkInternet: checkInternet(
            abortSilently: false, ifOpenDialog: true, maxRetryDelay: null),
        retry: retry(
          maxRetries: 5,
          initialDelay: const Duration(milliseconds: 10),
          multiplier: 1.0,
          maxDelay: const Duration(milliseconds: 10),
          onRetry: (attempt, delay, error, stack) {
            internetCheckCount++;
            // Internet comes back after 2 retry attempts
            if (internetCheckCount >= 2) {
              hasInternet = true;
            }
          },
        ),
        () async {
          attempts++;
          return 42;
        },
      );

      // Internet check retried until available, then action ran successfully
      expect(result, 42);
      expect(attempts, 1);
      expect(internetCheckCount, 2); // 2 retries before internet came back
    });

    test(
        'ConnectionException thrown when all retries exhausted with no internet',
        () async {
      Superpowers.clear(simulateInternet: () => false);

      await expectLater(
        mix(
          key: '',
          checkInternet: checkInternet(
              abortSilently: false,
              ifOpenDialog: false,
              maxRetryDelay: null),
          retry: retry(
            maxRetries: 2,
            initialDelay: const Duration(milliseconds: 10),
            multiplier: 1.0,
            maxDelay: const Duration(milliseconds: 10),
            onRetry: null,
          ),
          () async => 42,
        ),
        throwsA(isA<ConnectionException>()),
      );
    });

    test(
        'ConnectionException queued when all retries exhausted and ifOpenDialog=true',
        () async {
      Superpowers.clear(simulateInternet: () => false);

      final result = await mix<int?>(
        key: '',
        checkInternet: checkInternet(
            abortSilently: false, ifOpenDialog: true, maxRetryDelay: null),
        retry: retry(
          maxRetries: 2,
          initialDelay: const Duration(milliseconds: 10),
          multiplier: 1.0,
          maxDelay: const Duration(milliseconds: 10),
          onRetry: null,
        ),
        () async => 42,
      );

      expect(result, null);
      expect(Superpowers.errors.length, 1);
      expect(Superpowers.errors.first, isA<ConnectionException>());
    });

    test(
        'onRetry callback receives ConnectionException for no internet retries',
        () async {
      Superpowers.clear(simulateInternet: () => false);

      final errors = <Object>[];
      await mix<int?>(
        key: '',
        checkInternet: checkInternet(
            abortSilently: false, ifOpenDialog: true, maxRetryDelay: null),
        retry: retry(
          maxRetries: 2,
          initialDelay: const Duration(milliseconds: 10),
          multiplier: 1.0,
          maxDelay: const Duration(milliseconds: 10),
          onRetry: (attempt, delay, error, stack) {
            errors.add(error);
          },
        ),
        () async => 42,
      );

      expect(errors.length, 2);
      expect(errors.every((e) => e is ConnectionException), true);
    });

    test('internet check inside retry loop - internet returns mid-retry',
        () async {
      var callCount = 0;
      Superpowers.clear(simulateInternet: () {
        callCount++;
        // Internet available on 3rd check (after 2 no-internet retries)
        return callCount >= 3;
      });

      var actionRan = false;
      final result = await mix<int?>(
        key: '',
        checkInternet: checkInternet(
            abortSilently: false, ifOpenDialog: true, maxRetryDelay: null),
        retry: retry(
          maxRetries: 5,
          initialDelay: const Duration(milliseconds: 10),
          multiplier: 1.0,
          maxDelay: const Duration(milliseconds: 10),
          onRetry: null,
        ),
        () async {
          actionRan = true;
          return 42;
        },
      );

      expect(result, 42);
      expect(actionRan, true);
      expect(callCount, 3); // 2 failed checks + 1 successful check
    });

    test('unlimited retries with checkInternet waits for internet indefinitely',
        () async {
      var checkCount = 0;
      Superpowers.clear(simulateInternet: () {
        checkCount++;
        // Internet available on 10th check
        return checkCount >= 10;
      });

      final result = await mix<String?>(
        key: '',
        checkInternet: checkInternet(
            abortSilently: false, ifOpenDialog: true, maxRetryDelay: null),
        retry: retry(
          maxRetries: -1,
          // Unlimited
          initialDelay: const Duration(milliseconds: 5),
          multiplier: 1.0,
          maxDelay: const Duration(milliseconds: 5),
          onRetry: null,
        ),
        () async => 'success',
      );

      expect(result, 'success');
      expect(checkCount, 10);
    });

    test('action failure after internet check passes triggers normal retry',
        () async {
      Superpowers.clear(simulateInternet: () => true);

      var actionAttempts = 0;
      try {
        await mix(
          key: '',
          checkInternet: checkInternet(
              abortSilently: false,
              ifOpenDialog: true,
              maxRetryDelay: null),
          retry: retry(
            maxRetries: 2,
            initialDelay: const Duration(milliseconds: 10),
            multiplier: 1.0,
            maxDelay: const Duration(milliseconds: 10),
            onRetry: null,
          ),
          () async {
            actionAttempts++;
            throw Exception('Action failed');
          },
        );
      } catch (_) {}

      expect(actionAttempts, 3); // 1 initial + 2 retries
    });
  });

  group('Superpowers.simulateInternet', () {
    test('simulateInternet defaults to null', () {
      Superpowers.clear();
      expect(Superpowers.simulateInternet, null);
    });

    test('simulateInternet can be set to true via init', () {
      Superpowers.clear(simulateInternet: () => true);
      expect(Superpowers.simulateInternet, true);
    });

    test('simulateInternet can be set to false via init', () {
      Superpowers.clear(simulateInternet: () => false);
      expect(Superpowers.simulateInternet, false);
    });

    test('Superpowers.clear() resets simulateInternet', () {
      Superpowers.clear(simulateInternet: () => false);
      expect(Superpowers.simulateInternet, false);

      Superpowers.clear();
      expect(Superpowers.simulateInternet, null);
    });

    test('simulation changes between calls are respected', () async {
      Superpowers.clear(simulateInternet: () => true);

      var firstResult = await mix(
        key: '',
        checkInternet: checkInternet(
            abortSilently: false, ifOpenDialog: true, maxRetryDelay: null),
        () async => 1,
      );
      expect(firstResult, 1);

      Superpowers.clear(simulateInternet: () => false);

      var secondResult = await mix<int?>(
        key: '',
        checkInternet: checkInternet(
            abortSilently: true, ifOpenDialog: null, maxRetryDelay: null),
        () async => 2,
      );
      expect(secondResult, null);
    });
  });

  group('all protections together', () {
    test(
        'debounce, checkInternet, nonReentrant, throttle, and fresh work together',
        () async {
      Superpowers.clear(simulateInternet: () => true);

      var executions = 0;

      final result = await mix(
        key: '',
        debounce: debounce(key: 'test', duration: 10.millis),
        checkInternet: checkInternet(
            abortSilently: false, ifOpenDialog: true, maxRetryDelay: null),
        nonReentrant: nonReentrant(key: 'test'),
        throttle: throttle(
            key: 'test',
            duration: 100.millis,
            removeLockOnError: null,
            ignoreThrottle: null),
        fresh: fresh(key: 'test', freshFor: 100.millis, ignoreFresh: null),
        () async {
          executions++;
          return 42;
        },
      );

      expect(result, 42);
      expect(executions, 1);
    });

    test(
        'order: debounce -> checkInternet -> nonReentrant -> throttle -> fresh',
        () async {
      Superpowers.clear(simulateInternet: () => false);

      // All protections are set but checkInternet should fail first
      // (after debounce check passes)
      final result = await mix<int?>(
        key: '',
        debounce: debounce(key: 'test', duration: 10.millis),
        checkInternet: checkInternet(
            abortSilently: true, ifOpenDialog: null, maxRetryDelay: null),
        nonReentrant: nonReentrant(key: 'test'),
        throttle: throttle(
            key: 'test',
            duration: 100.millis,
            removeLockOnError: null,
            ignoreThrottle: null),
        fresh: fresh(key: 'test', freshFor: 100.millis, ignoreFresh: null),
        () async => 42,
      );

      expect(result, null);

      // Now with internet, second call should work (no locks were acquired)
      Superpowers.clear(simulateInternet: () => true);
      final result2 = await mix(
        key: '',
        debounce: debounce(key: 'test', duration: 10.millis),
        checkInternet: checkInternet(
            abortSilently: false, ifOpenDialog: true, maxRetryDelay: null),
        nonReentrant: nonReentrant(key: 'test'),
        throttle: throttle(
            key: 'test',
            duration: 5000.millis,
            removeLockOnError: null,
            ignoreThrottle: null),
        fresh: fresh(key: 'test', freshFor: 5000.millis, ignoreFresh: null),
        () async => 100,
      );

      expect(result2, 100);
    });
  });

  group('sync actions', () {
    test('sync action works with checkInternet', () async {
      Superpowers.clear(simulateInternet: () => true);

      final result = await mix(
        key: '',
        checkInternet: checkInternet(
            abortSilently: false, ifOpenDialog: true, maxRetryDelay: null),
        () => 42, // Sync action
      );

      expect(result, 42);
    });

    test('sync action aborted when no internet', () async {
      Superpowers.clear(simulateInternet: () => false);

      final result = await mix<int?>(
        key: '',
        checkInternet: checkInternet(
            abortSilently: true, ifOpenDialog: null, maxRetryDelay: null),
        () => 42,
      );

      expect(result, null);
    });

    test('sync action throws when no internet and ifOpenDialog=false',
        () async {
      Superpowers.clear(simulateInternet: () => false);

      await expectLater(
        mix(
          key: '',
          checkInternet: checkInternet(
            abortSilently: false,
            ifOpenDialog: false,
            maxRetryDelay: null,
          ),
          () => 42,
        ),
        throwsA(isA<ConnectionException>()),
      );
    });
  });

  group('wrapRun interaction', () {
    test('wrapRun called when internet check passes', () async {
      Superpowers.clear(simulateInternet: () => true);

      var wrapRunCalled = false;
      await mix(
        key: '',
        config: MixConfig(
          wrapRun: (action) {
            wrapRunCalled = true;
            return action();
          },
        ),
        checkInternet: checkInternet(
            abortSilently: false, ifOpenDialog: true, maxRetryDelay: null),
        () async => 42,
      );

      expect(wrapRunCalled, true);
    });

    test('wrapRun not called when internet check fails (abortSilently)',
        () async {
      Superpowers.clear(simulateInternet: () => false);

      var wrapRunCalled = false;
      await mix<int?>(
        key: '',
        config: MixConfig(
          wrapRun: (action) {
            wrapRunCalled = true;
            return action();
          },
        ),
        checkInternet: checkInternet(
            abortSilently: true, ifOpenDialog: null, maxRetryDelay: null),
        () async => 42,
      );

      expect(wrapRunCalled, false);
    });

    test('wrapRun not called when internet check fails (ifOpenDialog=true)',
        () async {
      Superpowers.clear(simulateInternet: () => false);

      var wrapRunCalled = false;
      await mix<int?>(
        key: '',
        config: MixConfig(
          wrapRun: (action) {
            wrapRunCalled = true;
            return action();
          },
        ),
        checkInternet: checkInternet(
            abortSilently: false, ifOpenDialog: true, maxRetryDelay: null),
        () async => 42,
      );

      expect(wrapRunCalled, false);
    });

    test('wrapRun not called when internet check fails (ifOpenDialog=false)',
        () async {
      Superpowers.clear(simulateInternet: () => false);

      var wrapRunCalled = false;
      try {
        await mix(
          key: '',
          config: MixConfig(
            wrapRun: (action) {
              wrapRunCalled = true;
              return action();
            },
          ),
          checkInternet: checkInternet(
              abortSilently: false,
              ifOpenDialog: false,
              maxRetryDelay: null),
          () async => 42,
        );
      } catch (_) {}

      expect(wrapRunCalled, false);
    });
  });

  group('edge cases', () {
    test('mix without checkInternet still works', () async {
      // Default: no internet check
      var ran = false;
      await mix(
        key: '',
        () async {
          ran = true;
          return 42;
        },
      );

      expect(ran, true);
    });

    test('multiple calls with internet check', () async {
      Superpowers.clear(simulateInternet: () => true);

      final results = <int?>[];
      for (var i = 0; i < 5; i++) {
        final result = await mix(
          key: '',
          checkInternet: checkInternet(
              abortSilently: false,
              ifOpenDialog: true,
              maxRetryDelay: null),
          () async => i,
        );
        results.add(result);
      }

      expect(results, [0, 1, 2, 3, 4]);
    });

    test('error in action after internet check passes', () async {
      Superpowers.clear(simulateInternet: () => true);

      await expectLater(
        mix(
          key: '',
          checkInternet: checkInternet(
              abortSilently: false,
              ifOpenDialog: true,
              maxRetryDelay: null),
          () async => throw Exception('Action failed'),
        ),
        throwsException,
      );
    });

    test('null return type works with abortSilently', () async {
      Superpowers.clear(simulateInternet: () => false);

      final result = await mix<String?>(
        key: '',
        checkInternet: checkInternet(
            abortSilently: true, ifOpenDialog: null, maxRetryDelay: null),
        () async => 'hello',
      );

      expect(result, null);
    });

    test('ifOpenDialog is ignored when abortSilently=true', () async {
      Superpowers.clear(simulateInternet: () => false);

      // Even with ifOpenDialog: true, abortSilently takes precedence
      final result1 = await mix<int?>(
        key: '',
        checkInternet: checkInternet(
            abortSilently: true, ifOpenDialog: true, maxRetryDelay: null),
        () async => 42,
      );
      expect(result1, null);
      expect(Superpowers.errors.length, 0);

      // Even with ifOpenDialog: false, abortSilently takes precedence
      final result2 = await mix<int?>(
        key: '',
        checkInternet: checkInternet(
            abortSilently: true, ifOpenDialog: false, maxRetryDelay: null),
        () async => 42,
      );
      expect(result2, null);
      expect(Superpowers.errors.length, 0);
    });
  });

  group('onNoInternet callback', () {
    test('onNoInternet is called when there is no internet (abortSilently=true)',
        () async {
      Superpowers.clear(simulateInternet: () => false);

      var callCount = 0;
      await mix<int?>(
        key: '',
        checkInternet: checkInternet(
          abortSilently: true,
          onNoInternet: () => callCount++,
        ),
        () async => 42,
      );

      expect(callCount, 1);
    });

    test(
        'onNoInternet is called when there is no internet (abortSilently=false)',
        () async {
      Superpowers.clear(simulateInternet: () => false);

      var callCount = 0;
      await mix<int?>(
        key: '',
        checkInternet: checkInternet(
          abortSilently: false,
          ifOpenDialog: true,
          onNoInternet: () => callCount++,
        ),
        () async => 42,
      );

      expect(callCount, 1);
      expect(Superpowers.errors.length, 1); // ConnectionException queued
    });

    test(
        'onNoInternet is called when there is no internet (ifOpenDialog=false)',
        () async {
      Superpowers.clear(simulateInternet: () => false);

      var callCount = 0;
      try {
        await mix(
          key: '',
          checkInternet: checkInternet(
            abortSilently: false,
            ifOpenDialog: false,
            onNoInternet: () => callCount++,
          ),
          () async => 42,
        );
      } catch (_) {}

      expect(callCount, 1);
    });

    test('onNoInternet is not called when internet is available', () async {
      Superpowers.clear(simulateInternet: () => true);

      var callCount = 0;
      await mix(
        key: '',
        checkInternet: checkInternet(
          abortSilently: false,
          ifOpenDialog: true,
          onNoInternet: () => callCount++,
        ),
        () async => 42,
      );

      expect(callCount, 0);
    });

    test('onNoInternet is called only once after retries exhausted', () async {
      Superpowers.clear(simulateInternet: () => false);

      var callCount = 0;
      await mix<int?>(
        key: '',
        checkInternet: checkInternet(
          abortSilently: false,
          ifOpenDialog: true,
          onNoInternet: () => callCount++,
        ),
        retry: retry(
          maxRetries: 3,
          initialDelay: const Duration(milliseconds: 10),
          multiplier: 1.0,
          maxDelay: const Duration(milliseconds: 10),
        ),
        () async => 42,
      );

      // onNoInternet is called once when all retries are exhausted
      expect(callCount, 1);
    });

    test('onNoInternet is called when internet comes back but then action runs',
        () async {
      var checkCount = 0;
      Superpowers.clear(simulateInternet: () {
        checkCount++;
        // Internet available on 3rd check
        return checkCount >= 3;
      });

      var noInternetCallCount = 0;
      var actionRan = false;
      await mix<int?>(
        key: '',
        checkInternet: checkInternet(
          abortSilently: false,
          ifOpenDialog: true,
          onNoInternet: () => noInternetCallCount++,
        ),
        retry: retry(
          maxRetries: 5,
          initialDelay: const Duration(milliseconds: 10),
          multiplier: 1.0,
          maxDelay: const Duration(milliseconds: 10),
        ),
        () async {
          actionRan = true;
          return 42;
        },
      );

      // onNoInternet is NOT called because internet eventually came back
      expect(noInternetCallCount, 0);
      expect(actionRan, true);
    });

    test('onNoInternet works with mix.ctx', () async {
      Superpowers.clear(simulateInternet: () => false);

      var callCount = 0;
      await mix.ctx<int?>(
        (ctx) async => 42,
        key: '',
        checkInternet: checkInternet(
          abortSilently: true,
          onNoInternet: () => callCount++,
        ),
      );

      expect(callCount, 1);
    });

    test('onNoInternet can be used for logging/analytics', () async {
      Superpowers.clear(simulateInternet: () => false);

      final events = <String>[];
      await mix<int?>(
        key: '',
        checkInternet: checkInternet(
          abortSilently: true,
          onNoInternet: () {
            events.add('no_internet_detected');
          },
        ),
        () async => 42,
      );

      expect(events, ['no_internet_detected']);
    });

    test('onNoInternet called before exception is thrown/queued', () async {
      Superpowers.clear(simulateInternet: () => false);

      final events = <String>[];
      await mix<int?>(
        key: '',
        checkInternet: checkInternet(
          abortSilently: false,
          ifOpenDialog: true,
          onNoInternet: () {
            events.add('callback');
          },
        ),
        () async {
          events.add('action');
          return 42;
        },
      );

      // Callback should be called, action should not
      expect(events, ['callback']);
      expect(Superpowers.errors.length, 1);
    });

    test(
        'onNoInternet with retry - called after exhausting retries due to no internet',
        () async {
      Superpowers.clear(simulateInternet: () => false);

      var onNoInternetCalls = 0;
      var retryAttempts = 0;

      await mix<int?>(
        key: '',
        checkInternet: checkInternet(
          abortSilently: false,
          ifOpenDialog: true,
          onNoInternet: () => onNoInternetCalls++,
        ),
        retry: retry(
          maxRetries: 2,
          initialDelay: const Duration(milliseconds: 10),
          multiplier: 1.0,
          maxDelay: const Duration(milliseconds: 10),
          onRetry: (_, __, ___, ____) => retryAttempts++,
        ),
        () async => 42,
      );

      // 2 retries happened
      expect(retryAttempts, 2);
      // onNoInternet called once when all retries exhausted
      expect(onNoInternetCalls, 1);
    });
  });
}
