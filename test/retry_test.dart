import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Reset Superpowers static state before each test.
  setUp(() {
    Superpowers.clear();
  });

  group('mix with retry', () {
    test('action succeeds on first try without retry', () async {
      var result = 0;
      var attempts = 0;
      var log = '';

      await mix(
        key: '',
        retry: retry(
          maxRetries: 3,
          initialDelay: const Duration(milliseconds: 1),
          multiplier: 2.0,
          maxDelay: const Duration(seconds: 5),
          onRetry: (attempt, delay, error, stack) {
            attempts = attempt;
          },
        ),
        () {
          log += attempts.toString();
          result = 1;
        },
      );

      expect(result, 1);
      expect(attempts, 0);
      expect(log, '0');
    });

    test('action retries and eventually succeeds', () async {
      var result = 0;
      var attempts = 0;
      var log = '';

      await mix(
        key: '',
        retry: retry(
          maxRetries: 10,
          initialDelay: const Duration(milliseconds: 1),
          multiplier: 2.0,
          maxDelay: const Duration(seconds: 5),
          onRetry: (attempt, delay, error, stack) {
            attempts = attempt;
          },
        ),
        () {
          log += attempts.toString();
          if (attempts <= 4) throw TestException('Failed: $attempts');
          result = 1;
        },
      );

      expect(result, 1);
      expect(attempts, 5); // Failed 5 times, then succeeded
      expect(log, '012345'); // 0=first try, 1-5=retries
    });

    test('action retries and eventually fails after maxRetries', () async {
      var result = 0;
      var attempts = 0;
      var log = '';

      await expectLater(
        mix(
          key: '',
          retry: retry(
            maxRetries: 3,
            initialDelay: const Duration(milliseconds: 1),
            multiplier: 2.0,
            maxDelay: const Duration(seconds: 5),
            onRetry: (attempt, delay, error, stack) {
              attempts = attempt;
            },
          ),
          () {
            log += attempts.toString();
            if (attempts <= 10) throw TestException('Failed: $attempts');
            result = 1;
          },
        ),
        throwsA(isA<TestException>()),
      );

      expect(result, 0); // State unchanged
      expect(attempts, 3); // 3 retries (onRetry called 3 times)
      expect(log, '0123'); // 0=first try, 1-3=retries
    });

    test('action uses exponential backoff', () async {
      final delaysUsed = <Duration>[];
      var failCount = 0;

      await mix(
        key: '',
        retry: retry(
          maxRetries: 3,
          initialDelay: const Duration(milliseconds: 10),
          multiplier: 2.0,
          maxDelay: const Duration(seconds: 5),
          onRetry: (attempt, delay, error, stack) {
            delaysUsed.add(delay);
          },
        ),
        () {
          failCount++;
          if (failCount <= 3) throw TestException('Fail $failCount');
        },
      );

      // Verify delays are increasing exponentially
      expect(delaysUsed.length, 3); // 3 retries
      expect(delaysUsed[0], const Duration(milliseconds: 10));
      expect(delaysUsed[1], const Duration(milliseconds: 20));
      expect(delaysUsed[2], const Duration(milliseconds: 40));
    });

    test('delay is capped at maxDelay', () async {
      final delaysUsed = <Duration>[];
      var failCount = 0;

      await mix(
        key: '',
        retry: retry(
          maxRetries: 10,
          initialDelay: const Duration(milliseconds: 50),
          multiplier: 2.0,
          maxDelay: const Duration(milliseconds: 100),
          onRetry: (attempt, delay, error, stack) {
            delaysUsed.add(delay);
          },
        ),
        () {
          failCount++;
          if (failCount <= 5) throw TestException('Fail $failCount');
        },
      );

      // All delays after the first should be capped at maxDelay
      expect(delaysUsed.length, 5);
      expect(delaysUsed[0], const Duration(milliseconds: 50));
      expect(delaysUsed[1], const Duration(milliseconds: 100));
      expect(delaysUsed[2], const Duration(milliseconds: 100)); // Capped
      expect(delaysUsed[3], const Duration(milliseconds: 100)); // Capped
      expect(delaysUsed[4], const Duration(milliseconds: 100)); // Capped
    });

    test('multiplier less than or equal to 1 defaults to 2', () async {
      final delaysUsed = <Duration>[];
      var failCount = 0;

      await mix(
        key: '',
        retry: retry(
          maxRetries: 3,
          initialDelay: const Duration(milliseconds: 10),
          multiplier: 0.5,
          // Invalid, should default to 2
          maxDelay: const Duration(seconds: 5),
          onRetry: (attempt, delay, error, stack) {
            delaysUsed.add(delay);
          },
        ),
        () {
          failCount++;
          if (failCount <= 3) throw TestException('Fail $failCount');
        },
      );

      // With multiplier defaulting to 2
      expect(delaysUsed[0], const Duration(milliseconds: 10));
      expect(delaysUsed[1], const Duration(milliseconds: 20));
      expect(delaysUsed[2], const Duration(milliseconds: 40));
    });

    test('custom initialDelay is respected', () async {
      final delaysUsed = <Duration>[];
      var failCount = 0;

      await mix(
        key: '',
        retry: retry(
          maxRetries: 2,
          initialDelay: const Duration(milliseconds: 100),
          multiplier: 2.0,
          maxDelay: const Duration(seconds: 5),
          onRetry: (attempt, delay, error, stack) {
            delaysUsed.add(delay);
          },
        ),
        () {
          failCount++;
          if (failCount <= 2) throw TestException('Fail $failCount');
        },
      );

      expect(delaysUsed[0], const Duration(milliseconds: 100));
      expect(delaysUsed[1], const Duration(milliseconds: 200));
    });

    test('custom multiplier is respected', () async {
      final delaysUsed = <Duration>[];
      var failCount = 0;

      await mix(
        key: '',
        retry: retry(
          maxRetries: 3,
          initialDelay: const Duration(milliseconds: 10),
          multiplier: 3.0,
          maxDelay: const Duration(seconds: 5),
          onRetry: (attempt, delay, error, stack) {
            delaysUsed.add(delay);
          },
        ),
        () {
          failCount++;
          if (failCount <= 3) throw TestException('Fail $failCount');
        },
      );

      expect(delaysUsed[0], const Duration(milliseconds: 10));
      expect(delaysUsed[1], const Duration(milliseconds: 30)); // 10 * 3
      expect(delaysUsed[2], const Duration(milliseconds: 90)); // 30 * 3
    });

    test('sync action works with retry', () async {
      var result = 0;

      final future = mix(
        key: '',
        retry: retry(
          maxRetries: 3,
          initialDelay: const Duration(milliseconds: 1),
          multiplier: 2.0,
          maxDelay: const Duration(seconds: 5),
        ),
        () {
          result = 1;
        },
      );

      // With mix, even sync actions become async
      expect(future, isA<Future>());
      await future;
      expect(result, 1);
    });

    test('action state is preserved between retries', () async {
      var accumulatedValue = 0;
      var failCount = 0;

      await mix(
        key: '',
        retry: retry(
          maxRetries: 3,
          initialDelay: const Duration(milliseconds: 1),
          multiplier: 2.0,
          maxDelay: const Duration(seconds: 5),
        ),
        () {
          failCount++;
          accumulatedValue += failCount;
          if (failCount < 3) throw TestException('Fail $failCount');
        },
      );

      // The action should have accumulated state across retries
      expect(accumulatedValue, 6); // 1 + 2 + 3
    });

    test('maxRetries of 0 means no retries', () async {
      var attempts = 0;
      var log = '';

      await expectLater(
        mix(
          key: '',
          retry: retry(
            maxRetries: 0,
            initialDelay: const Duration(milliseconds: 1),
            multiplier: 2.0,
            maxDelay: const Duration(seconds: 5),
            onRetry: (attempt, delay, error, stack) {
              attempts = attempt;
            },
          ),
          () {
            log += attempts.toString();
            throw TestException('Always fails');
          },
        ),
        throwsA(isA<TestException>()),
      );

      expect(attempts, 0); // No retries occurred (onRetry not called)
      expect(log, '0');
    });
  });

  group('mix with unlimited retries', () {
    test('action retries until it succeeds', () async {
      var result = 0;
      var attempts = 0;
      var log = '';

      await mix(
        key: '',
        retry: retry(
          maxRetries: -1,
          // Unlimited
          initialDelay: const Duration(milliseconds: 1),
          multiplier: 2.0,
          maxDelay: const Duration(seconds: 5),
          onRetry: (attempt, delay, error, stack) {
            attempts = attempt;
          },
        ),
        () {
          log += attempts.toString();
          if (attempts <= 6) throw TestException('Failed: $attempts');
          result = 1;
        },
      );

      expect(result, 1);
      expect(attempts, 7); // Fails 7 times, then succeeds
      expect(log, '01234567');
    });

    test('unlimited retries overrides maxRetries', () async {
      var result = 0;
      var attempts = 0;

      await mix(
        key: '',
        retry: retry(
          maxRetries: -1,
          // Unlimited
          initialDelay: const Duration(milliseconds: 1),
          multiplier: 2.0,
          maxDelay: const Duration(seconds: 5),
          onRetry: (attempt, delay, error, stack) {
            attempts = attempt;
          },
        ),
        () {
          if (attempts <= 9) throw TestException('Failed: $attempts');
          result = 1;
        },
      );

      // Should succeed even though it fails more times than default maxRetries
      expect(result, 1);
      expect(attempts, 10);
    });

    test('exponential backoff still works with unlimited retries', () async {
      final delaysUsed = <Duration>[];
      var failCount = 0;

      await mix(
        key: '',
        retry: retry(
          maxRetries: -1,
          // Unlimited
          initialDelay: const Duration(milliseconds: 10),
          multiplier: 2.0,
          maxDelay: const Duration(seconds: 5),
          onRetry: (attempt, delay, error, stack) {
            delaysUsed.add(delay);
          },
        ),
        () {
          failCount++;
          if (failCount <= 5) throw TestException('Fail $failCount');
        },
      );

      // Verify delays follow exponential backoff pattern
      expect(delaysUsed.length, 5);
      expect(delaysUsed[0], const Duration(milliseconds: 10));
      expect(delaysUsed[1], const Duration(milliseconds: 20));
      expect(delaysUsed[2], const Duration(milliseconds: 40));
      expect(delaysUsed[3], const Duration(milliseconds: 80));
      expect(delaysUsed[4], const Duration(milliseconds: 160));
    });

    test('custom maxDelay is respected with unlimited retries', () async {
      final delaysUsed = <Duration>[];
      var failCount = 0;

      await mix(
        key: '',
        retry: retry(
          maxRetries: -1,
          // Unlimited
          initialDelay: const Duration(milliseconds: 10),
          multiplier: 2.0,
          maxDelay: const Duration(milliseconds: 50),
          onRetry: (attempt, delay, error, stack) {
            delaysUsed.add(delay);
          },
        ),
        () {
          failCount++;
          if (failCount <= 6) throw TestException('Fail $failCount');
        },
      );

      // Delays should be capped at maxDelay
      expect(delaysUsed.length, 6);
      expect(delaysUsed[0], const Duration(milliseconds: 10));
      expect(delaysUsed[1], const Duration(milliseconds: 20));
      expect(delaysUsed[2], const Duration(milliseconds: 40));
      expect(delaysUsed[3], const Duration(milliseconds: 50)); // Capped
      expect(delaysUsed[4], const Duration(milliseconds: 50)); // Capped
      expect(delaysUsed[5], const Duration(milliseconds: 50)); // Capped
    });

    test('attempts counter increments correctly with unlimited retries',
        () async {
      final attemptValues = <int>[];
      var attempts = 0;

      await mix(
        key: '',
        retry: retry(
          maxRetries: -1,
          // Unlimited
          initialDelay: const Duration(milliseconds: 1),
          multiplier: 2.0,
          maxDelay: const Duration(seconds: 5),
          onRetry: (attempt, delay, error, stack) {
            attempts = attempt;
          },
        ),
        () {
          attemptValues.add(attempts);
          if (attempts <= 4) throw TestException('Fail $attempts');
        },
      );

      // Verify attempts were tracked correctly during retries
      expect(attemptValues, [0, 1, 2, 3, 4, 5]);
      expect(attempts, 5);
    });

    test('state is preserved across unlimited retries', () async {
      var accumulatedValue = 0;
      var failCount = 0;
      var result = 0;

      await mix(
        key: '',
        retry: retry(
          maxRetries: -1,
          // Unlimited
          initialDelay: const Duration(milliseconds: 1),
          multiplier: 2.0,
          maxDelay: const Duration(seconds: 5),
          onRetry: null,
        ),
        () {
          failCount++;
          accumulatedValue += failCount;
          if (failCount < 6) throw TestException('Fail $failCount');
          result = 1;
        },
      );

      // Action should have accumulated state across all retries
      expect(accumulatedValue, 21); // 1+2+3+4+5+6
      expect(result, 1);
    });

    test('lifecycle methods work with unlimited retries', () async {
      var beforeCalls = 0;
      var runCalls = 0;
      var afterCalls = 0;
      var failCount = 0;

      await mix(
        key: '',
        retry: retry(
          maxRetries: -1,
          // Unlimited
          initialDelay: const Duration(milliseconds: 1),
          multiplier: 2.0,
          maxDelay: const Duration(seconds: 5),
          onRetry: null,
        ),
        config: MixConfig(
          before: () {
            beforeCalls++;
          },
          after: () {
            afterCalls++;
          },
        ),
        () {
          runCalls++;
          failCount++;
          if (failCount < 5) throw TestException('Fail $failCount');
        },
      );

      // before() once, run() 5 times (4 failures + 1 success), after() once
      expect(beforeCalls, 1);
      expect(runCalls, 5);
      expect(afterCalls, 1);
    });

    test('can recover from different error types with unlimited retries',
        () async {
      final errorTypes = <String>[];
      var failCount = 0;
      var result = 0;

      await mix(
        key: '',
        retry: retry(
          maxRetries: -1,
          // Unlimited
          initialDelay: const Duration(milliseconds: 1),
          multiplier: 2.0,
          maxDelay: const Duration(seconds: 5),
          onRetry: null,
        ),
        () {
          failCount++;
          if (failCount == 1) {
            errorTypes.add('TestException');
            throw TestException('First error');
          }
          if (failCount == 2) {
            errorTypes.add('StateError');
            throw StateError('Second error');
          }
          if (failCount == 3) {
            errorTypes.add('ArgumentError');
            throw ArgumentError('Third error');
          }
          if (failCount == 4) {
            errorTypes.add('FormatException');
            throw const FormatException('Fourth error');
          }
          result = 1;
        },
      );

      expect(result, 1);
      expect(errorTypes.length, 4);
      expect(errorTypes[0], 'TestException');
      expect(errorTypes[1], 'StateError');
      expect(errorTypes[2], 'ArgumentError');
      expect(errorTypes[3], 'FormatException');
    });
  });

  group('mix with lifecycle methods', () {
    test('before() is called only once, not on retries', () async {
      var beforeCalls = 0;
      var runCalls = 0;
      var afterCalls = 0;
      var failCount = 0;

      await mix(
        key: '',
        retry: retry(
          maxRetries: 3,
          initialDelay: const Duration(milliseconds: 1),
          multiplier: 2.0,
          maxDelay: const Duration(seconds: 5),
        ),
        config: MixConfig(
          before: () {
            beforeCalls++;
          },
          after: () {
            afterCalls++;
          },
        ),
        () {
          runCalls++;
          failCount++;
          if (failCount < 4) throw TestException('Fail $failCount');
        },
      );

      // before() called once, run() called 4 times (1 initial + 3 retries), after() once
      expect(beforeCalls, 1);
      expect(runCalls, 4);
      expect(afterCalls, 1);
    });

    test('after() is called even if all retries fail', () async {
      var beforeCalls = 0;
      var afterCalls = 0;

      await expectLater(
        mix(
          key: '',
          retry: retry(
            maxRetries: 2,
            initialDelay: const Duration(milliseconds: 1),
            multiplier: 2.0,
            maxDelay: const Duration(seconds: 5),
            onRetry: null,
          ),
          config: MixConfig(
            before: () {
              beforeCalls++;
            },
            after: () {
              afterCalls++;
            },
          ),
          () {
            throw TestException('Always fails');
          },
        ),
        throwsA(isA<TestException>()),
      );

      expect(beforeCalls, 1);
      expect(afterCalls, 1);
    });

    test('catchError is called for the final failure', () async {
      var catchErrorCalled = false;
      Object? originalError;
      Object? wrappedError;

      await expectLater(
        mix(
          key: '',
          retry: retry(
            maxRetries: 2,
            initialDelay: const Duration(milliseconds: 1),
            multiplier: 2.0,
            maxDelay: const Duration(seconds: 5),
            onRetry: null,
          ),
          config: MixConfig(catchError: (error, stack) {
            catchErrorCalled = true;
            originalError = error;
            wrappedError = WrappedTestException(error);
            throw wrappedError!;
          }),
          () {
            throw TestException('Always fails');
          },
        ),
        throwsA(isA<WrappedTestException>()),
      );

      // catchError should have been called
      expect(catchErrorCalled, true);
      expect(originalError, isA<TestException>());
      expect(wrappedError, isA<WrappedTestException>());
    });

    test('catchError throwing UserException adds to error queue', () async {
      await mix<int?>(
        key: '',
        retry: retry(
          maxRetries: 1,
          initialDelay: const Duration(milliseconds: 1),
          multiplier: 2.0,
          maxDelay: const Duration(seconds: 5),
          onRetry: null,
        ),
        catchError: (error, stack) {
          throw UserException('User-facing error');
        },
        () {
          throw TestException('Internal error');
        },
      );

      // UserException should be in the queue, not thrown
      expect(Superpowers.errors.length, 1);
      expect(Superpowers.errors.first.message, 'User-facing error');
    });

    test('catchError returning normally suppresses the error', () async {
      var afterCalled = false;

      // Should not throw
      await mix<int?>(
        key: '',
        retry: retry(
          maxRetries: 1,
          initialDelay: const Duration(milliseconds: 1),
          multiplier: 2.0,
          maxDelay: const Duration(seconds: 5),
          onRetry: null,
        ),
        config: MixConfig(
          after: () {
            afterCalled = true;
          },
          catchError: (error, stack) {
            // Return normally to suppress the error
          },
        ),
        () {
          throw TestException('Suppressed error');
        },
      );

      // after() should still be called
      expect(afterCalled, true);
      // No error in queue
      expect(Superpowers.errors.length, 0);
    });
  });

  group('mix with wrapRun', () {
    test('wrapRun wraps each attempt', () async {
      var wrapRunCalls = 0;
      var failCount = 0;

      await mix(
        key: '',
        retry: retry(
          maxRetries: 2,
          initialDelay: const Duration(milliseconds: 1),
          multiplier: 2.0,
          maxDelay: const Duration(seconds: 5),
          onRetry: null,
        ),
        config: MixConfig(wrapRun: (action) {
          wrapRunCalls++;
          return action();
        }),
        () {
          failCount++;
          if (failCount < 3) throw TestException('Fail $failCount');
        },
      );

      // wrapRun is called for each attempt (initial + 2 retries)
      expect(wrapRunCalls, 3);
    });

    test('wrapRun can modify action behavior', () async {
      var result = 0;

      await mix(
        key: '',
        retry: retry(
          maxRetries: 3,
          initialDelay: const Duration(milliseconds: 1),
          multiplier: 2.0,
          maxDelay: const Duration(seconds: 5),
        ),
        config: MixConfig(wrapRun: (action) async {
          await action();
          result += 10; // Add extra after each attempt
        }),
        () {
          result += 1;
        },
      );

      // Action ran once (success), wrapRun added 10
      expect(result, 11); // 1 + 10
    });

    test('wrapRun is called even on retries', () async {
      final wrapRunAttempts = <int>[];
      var failCount = 0;

      await mix(
        key: '',
        retry: retry(
          maxRetries: 3,
          initialDelay: const Duration(milliseconds: 1),
          multiplier: 2.0,
          maxDelay: const Duration(seconds: 5),
        ),
        config: MixConfig(wrapRun: (action) {
          wrapRunAttempts.add(failCount);
          return action();
        }),
        () {
          failCount++;
          if (failCount < 3) throw TestException('Fail $failCount');
        },
      );

      expect(wrapRunAttempts, [0, 1, 2]); // Called 3 times
    });
  });

  group('nextDelay calculation', () {
    test('nextDelay returns correct exponential sequence', () async {
      final delaysUsed = <Duration>[];
      var failCount = 0;

      await mix(
        key: '',
        retry: retry(
          maxRetries: 10,
          initialDelay: const Duration(milliseconds: 100),
          multiplier: 2.0,
          maxDelay: const Duration(seconds: 5),
          onRetry: (attempt, delay, error, stack) {
            delaysUsed.add(delay);
          },
        ),
        () {
          failCount++;
          if (failCount <= 4) throw TestException('Fail $failCount');
        },
      );

      // Verify the delays were calculated correctly (4 failures = 4 delays)
      expect(delaysUsed.length, 4);
      expect(delaysUsed[0], const Duration(milliseconds: 100));
      expect(delaysUsed[1], const Duration(milliseconds: 200));
      expect(delaysUsed[2], const Duration(milliseconds: 400));
      expect(delaysUsed[3], const Duration(milliseconds: 800));
    });

    test('nextDelay is capped at maxDelay', () async {
      final delaysUsed = <Duration>[];
      var failCount = 0;

      await mix(
        key: '',
        retry: retry(
          maxRetries: 10,
          initialDelay: const Duration(milliseconds: 100),
          multiplier: 2.0,
          maxDelay: const Duration(milliseconds: 250),
          onRetry: (attempt, delay, error, stack) {
            delaysUsed.add(delay);
          },
        ),
        () {
          failCount++;
          if (failCount <= 4) throw TestException('Fail $failCount');
        },
      );

      expect(delaysUsed.length, 4);
      expect(delaysUsed[0], const Duration(milliseconds: 100));
      expect(delaysUsed[1], const Duration(milliseconds: 200));
      expect(delaysUsed[2], const Duration(milliseconds: 250)); // Capped
      expect(delaysUsed[3], const Duration(milliseconds: 250)); // Still capped
    });
  });

  group('Default values', () {
    test('RetryConfig.defaults has correct values', () {
      expect(RetryConfig.defaults.initialDelay, const Duration(milliseconds: 350));
      expect(RetryConfig.defaults.multiplier, 2.0);
      expect(RetryConfig.defaults.maxRetries, 3);
      expect(RetryConfig.defaults.maxDelay, const Duration(milliseconds: 5000));
      expect(RetryConfig.defaults.onRetry, null);
    });

    test('RetryConfig.defaults setter validates all required fields', () {
      // Should throw if any required field is missing
      expect(
        () => RetryConfig.defaults = RetryConfig(
          maxRetries: 3,
          initialDelay: const Duration(milliseconds: 350),
          multiplier: 2.0,
          // maxDelay missing
        ),
        throwsArgumentError,
      );

      expect(
        () => RetryConfig.defaults = RetryConfig(
          // maxRetries missing
          initialDelay: const Duration(milliseconds: 350),
          multiplier: 2.0,
          maxDelay: const Duration(seconds: 5),
        ),
        throwsArgumentError,
      );

      // Should succeed with all fields
      RetryConfig.defaults = RetryConfig(
        maxRetries: 5,
        initialDelay: const Duration(milliseconds: 500),
        multiplier: 3.0,
        maxDelay: const Duration(seconds: 10),
      );

      expect(RetryConfig.defaults.maxRetries, 5);
      expect(RetryConfig.defaults.initialDelay, const Duration(milliseconds: 500));
      expect(RetryConfig.defaults.multiplier, 3.0);
      expect(RetryConfig.defaults.maxDelay, const Duration(seconds: 10));

      // Reset to original defaults for other tests
      RetryConfig.defaults = RetryConfig(
        maxRetries: 3,
        initialDelay: const Duration(milliseconds: 350),
        multiplier: 2.0,
        maxDelay: const Duration(seconds: 5),
      );
    });

    test('retry constant has null values (merged with defaults when used)', () {
      expect(retry.initialDelay, null);
      expect(retry.multiplier, null);
      expect(retry.maxRetries, null);
      expect(retry.maxDelay, null);
      expect(retry.onRetry, null);
    });
  });

  group('Edge cases', () {
    test('multiplier equal to 1 defaults to 2', () async {
      final delaysUsed = <Duration>[];
      var failCount = 0;

      await mix(
        key: '',
        retry: retry(
          maxRetries: 3,
          initialDelay: const Duration(milliseconds: 10),
          multiplier: 1.0,
          // Should default to 2
          maxDelay: const Duration(seconds: 5),
          onRetry: (attempt, delay, error, stack) {
            delaysUsed.add(delay);
          },
        ),
        () {
          failCount++;
          if (failCount <= 3) throw TestException('Fail $failCount');
        },
      );

      // With multiplier = 1 defaulting to 2
      expect(delaysUsed[0], const Duration(milliseconds: 10));
      expect(delaysUsed[1], const Duration(milliseconds: 20)); // 10 * 2
      expect(delaysUsed[2], const Duration(milliseconds: 40)); // 20 * 2
    });

    test('negative multiplier defaults to 2', () async {
      final delaysUsed = <Duration>[];
      var failCount = 0;

      await mix(
        key: '',
        retry: retry(
          maxRetries: 3,
          initialDelay: const Duration(milliseconds: 10),
          multiplier: -2.0,
          // Negative, should default to 2
          maxDelay: const Duration(seconds: 5),
          onRetry: (attempt, delay, error, stack) {
            delaysUsed.add(delay);
          },
        ),
        () {
          failCount++;
          if (failCount <= 3) throw TestException('Fail $failCount');
        },
      );

      // With negative multiplier defaulting to 2
      expect(delaysUsed[0], const Duration(milliseconds: 10));
      expect(delaysUsed[1], const Duration(milliseconds: 20));
      expect(delaysUsed[2], const Duration(milliseconds: 40));
    });

    test('maxRetries of -1 directly retries indefinitely', () async {
      var result = 0;
      var attempts = 0;

      await mix(
        key: '',
        retry: retry(
          maxRetries: -1,
          // Unlimited retries directly
          initialDelay: const Duration(milliseconds: 1),
          multiplier: 2.0,
          maxDelay: const Duration(seconds: 5),
          onRetry: (attempt, delay, error, stack) {
            attempts = attempt;
          },
        ),
        () {
          if (attempts <= 7) throw TestException('Failed: $attempts');
          result = 1;
        },
      );

      // Should retry beyond normal maxRetries
      expect(result, 1);
      expect(attempts, 8); // Failed 8 times, then succeeded
    });

    test('rethrows the exact last error after maxRetries exhausted', () async {
      var attemptCount = 0;

      try {
        await mix(
          key: '',
          retry: retry(
            maxRetries: 3,
            initialDelay: const Duration(milliseconds: 1),
            multiplier: 2.0,
            maxDelay: const Duration(seconds: 5),
            onRetry: null,
          ),
          () {
            attemptCount++;
            throw TestException('Error on attempt $attemptCount');
          },
        );
        fail('Should have thrown');
      } catch (e) {
        expect(e, isA<TestException>());
        expect((e as TestException).message, 'Error on attempt 4');
      }
    });

    test('async action that succeeds', () async {
      var result = 0;
      var asyncCompleted = false;

      await mix(
        key: '',
        retry: retry(
          maxRetries: 3,
          initialDelay: const Duration(milliseconds: 1),
          multiplier: 2.0,
          maxDelay: const Duration(seconds: 5),
        ),
        () async {
          await Future.delayed(const Duration(milliseconds: 1));
          asyncCompleted = true;
          result = 1;
        },
      );

      expect(result, 1);
      expect(asyncCompleted, true);
    });

    test('async action that fails and retries', () async {
      var result = 0;
      var failCount = 0;

      await mix(
        key: '',
        retry: retry(
          maxRetries: 5,
          initialDelay: const Duration(milliseconds: 1),
          multiplier: 2.0,
          maxDelay: const Duration(seconds: 5),
          onRetry: null,
        ),
        () async {
          await Future.delayed(const Duration(milliseconds: 1));
          failCount++;
          if (failCount <= 3) throw TestException('Async fail $failCount');
          result = 1;
        },
      );

      expect(result, 1);
      expect(failCount, 4); // Failed 3 times async, then succeeded
    });

    test('async action that exhausts retries', () async {
      var result = 0;
      var attempts = 0;

      await expectLater(
        mix(
          key: '',
          retry: retry(
            maxRetries: 3,
            initialDelay: const Duration(milliseconds: 1),
            multiplier: 2.0,
            maxDelay: const Duration(seconds: 5),
            onRetry: (attempt, delay, error, stack) {
              attempts = attempt;
            },
          ),
          () async {
            await Future.delayed(const Duration(milliseconds: 1));
            throw TestException('Always fails async');
          },
        ),
        throwsA(isA<TestException>()),
      );

      expect(result, 0);
      expect(attempts, 3); // 3 retries
    });

    test('mix without retry config does not retry', () async {
      var attempts = 0;

      // mix now executes synchronously when no async features are used,
      // so we need to use expect/throwsA instead of expectLater
      expect(
        () => mix(
          key: '',
          () {
            attempts++;
            throw TestException('Fails once');
          },
        ),
        throwsA(isA<TestException>()),
      );

      expect(attempts, 1); // Only one attempt, no retries
    });

    test('mix without retry config succeeds on first try', () async {
      var result = 0;

      await mix(
        key: '',
        () {
          result = 1;
        },
      );

      expect(result, 1);
    });

    test('mix returns value from action', () async {
      final result = await mix(
        key: '',
        () => 42,
      );

      expect(result, 42);
    });

    test('mix returns value from async action', () async {
      final result = await mix(
        key: '',
        () async {
          await Future.delayed(const Duration(milliseconds: 1));
          return 'async result';
        },
      );

      expect(result, 'async result');
    });

    test('mix returns value after retries succeed', () async {
      var attempts = 0;

      final result = await mix(
        key: '',
        retry: retry(
          maxRetries: 3,
          initialDelay: const Duration(milliseconds: 1),
          multiplier: 2.0,
          maxDelay: const Duration(seconds: 5),
        ),
        () {
          attempts++;
          if (attempts < 3) throw TestException('Fail $attempts');
          return 'success after $attempts attempts';
        },
      );

      expect(result, 'success after 3 attempts');
    });
  });

  group('before() error handling', () {
    test('error in before() calls after() and catchError', () async {
      var afterCalled = false;
      var catchErrorCalled = false;

      // mix now executes synchronously when no async features are used
      expect(
        () => mix(
          key: '',
          config: MixConfig(
            before: () {
              throw TestException('before() failed');
            },
            after: () {
              afterCalled = true;
            },
            catchError: (error, stack) {
              catchErrorCalled = true;
              throw error;
            },
          ),
          () {
            // Should never be called
            fail('Action should not run');
          },
        ),
        throwsA(isA<TestException>()),
      );

      expect(afterCalled, true);
      expect(catchErrorCalled, true);
    });

    test('error in before() can be suppressed by catchError', () async {
      var afterCalled = false;

      // Should not throw
      await mix<int?>(
        key: '',
        config: MixConfig(
          before: () {
            throw TestException('before() failed');
          },
          after: () {
            afterCalled = true;
          },
          catchError: (error, stack) {
            // Return normally to suppress error
          },
        ),
        () {
          fail('Action should not run');
        },
      );

      expect(afterCalled, true);
    });

    test('error in before() with UserException goes to queue', () async {
      await mix<int?>(
        key: '',
        config: MixConfig(
          before: () {
            throw TestException('before() failed');
          },
          catchError: (error, stack) {
            throw UserException('User-facing before error');
          },
        ),
        () {
          fail('Action should not run');
        },
      );

      expect(Superpowers.errors.length, 1);
      expect(Superpowers.errors.first.message, 'User-facing before error');
    });
  });
}

// Test Exception
class TestException implements Exception {
  final String message;

  TestException([this.message = 'Test exception']);

  @override
  String toString() => 'TestException: $message';
}

class WrappedTestException implements Exception {
  final Object original;

  WrappedTestException(this.original);
}
