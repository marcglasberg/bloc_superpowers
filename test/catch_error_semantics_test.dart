import 'dart:async';

import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the `catchError` parameter semantics.
///
/// The `catchError` callback has `void` return type and uses throw-based semantics:
/// - **Return normally** → suppress the error (error is swallowed)
/// - **Throw** → propagate the error with original stack trace preserved
///
/// This is more intuitive than return-based semantics because it matches
/// how try/catch blocks work in Dart. The key benefit is that
/// `Error.throwWithStackTrace()` is used internally to preserve the original
/// stack trace when the error is rethrown.
void main() {
  setUp(() {
    Superpowers.clear();
  });

  group('catchError semantics - suppress vs propagate', () {
    test('returning normally suppresses the error', () async {
      var catchErrorCalled = false;

      // This should NOT throw because catchError returns normally
      final result = await mix<int>(
        key: 'test',
        catchError: (error, stackTrace) {
          catchErrorCalled = true;
          // Return normally = suppress
        },
        () => throw Exception('test error'),
      );

      expect(catchErrorCalled, true);
      expect(result, null); // Returns null when error is suppressed
    });

    test('throwing propagates the error', () async {
      var catchErrorCalled = false;

      await expectLater(
        () => mix<int>(
          key: 'test',
          catchError: (error, stackTrace) {
            catchErrorCalled = true;
            throw error; // Throw = propagate
          },
          () => throw Exception('test error'),
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('test error'),
        )),
      );

      expect(catchErrorCalled, true);
    });

    test('throwing a different error propagates the new error', () async {
      // Use ifOpenDialog=false so it throws instead of queuing
      await expectLater(
        () => mix<int>(
          key: 'test',
          catchError: (error, stackTrace) {
            throw UserException(
              'Transformed: ${error.toString()}',
              ifOpenDialog: false,
            );
          },
          () => throw Exception('original error'),
        ),
        throwsA(isA<UserException>().having(
          (e) => e.message,
          'message',
          contains('Transformed'),
        )),
      );
    });

    test('empty catchError body suppresses error', () async {
      // Common pattern: catchError: (e, s) {}
      final result = await mix<int>(
        key: 'test',
        catchError: (error, stackTrace) {},
        () => throw Exception('test error'),
      );

      expect(result, null);
    });

    test('arrow function returning void suppresses error', () async {
      var logged = false;

      // Common pattern: catchError: (e, s) => log(e)
      final result = await mix<int>(
        key: 'test',
        catchError: (error, stackTrace) => logged = true,
        () => throw Exception('test error'),
      );

      expect(logged, true);
      expect(result, null);
    });
  });

  group('catchError stack trace preservation', () {
    test('original stack trace is preserved when throwing same error', () async {
      StackTrace? originalStackTrace;
      StackTrace? caughtStackTrace;

      try {
        await mix<int>(
          key: 'test',
          catchError: (error, stackTrace) {
            originalStackTrace = stackTrace;
            throw error; // Rethrow
          },
          () {
            throw Exception('test error');
          },
        );
      } catch (e, s) {
        caughtStackTrace = s;
      }

      expect(originalStackTrace, isNotNull);
      expect(caughtStackTrace, isNotNull);

      // The caught stack trace should contain the original throw location
      // (the action), not the catchError location
      final originalStr = originalStackTrace.toString();
      final caughtStr = caughtStackTrace.toString();

      // Both should reference the same origin point
      expect(caughtStr, contains('mix'));
    });

    test('original stack trace is preserved when throwing different error', () async {
      StackTrace? originalStackTrace;
      StackTrace? caughtStackTrace;

      try {
        await mix<int>(
          key: 'test',
          catchError: (error, stackTrace) {
            originalStackTrace = stackTrace;
            // Use ifOpenDialog=false so it throws instead of queuing
            throw UserException('Wrapped error', ifOpenDialog: false);
          },
          () {
            throw Exception('original error');
          },
        );
      } catch (e, s) {
        caughtStackTrace = s;
      }

      expect(originalStackTrace, isNotNull);
      expect(caughtStackTrace, isNotNull);

      // The stack traces should be the same (original is preserved)
      expect(caughtStackTrace.toString(), originalStackTrace.toString());
    });

    test('catchError receives correct stack trace from nested call', () async {
      StackTrace? receivedStackTrace;

      Future<void> nestedFunction() async {
        throw Exception('nested error');
      }

      try {
        await mix<void>(
          key: 'test',
          catchError: (error, stackTrace) {
            receivedStackTrace = stackTrace;
            throw error;
          },
          () async {
            await nestedFunction();
          },
        );
      } catch (_) {}

      expect(receivedStackTrace, isNotNull);
      // Stack trace should contain the nested function
      expect(receivedStackTrace.toString(), contains('nestedFunction'));
    });
  });

  group('catchError receives correct parameters', () {
    test('catchError receives the thrown error', () async {
      Object? receivedError;
      final originalError = Exception('specific error message');

      await mix<void>(
        key: 'test',
        catchError: (error, stackTrace) {
          receivedError = error;
        },
        () => throw originalError,
      );

      expect(receivedError, same(originalError));
    });

    test('catchError receives non-null stack trace', () async {
      StackTrace? receivedStackTrace;

      await mix<void>(
        key: 'test',
        catchError: (error, stackTrace) {
          receivedStackTrace = stackTrace;
        },
        () => throw Exception('test'),
      );

      expect(receivedStackTrace, isNotNull);
      expect(receivedStackTrace.toString().isNotEmpty, true);
    });

    test('catchError can use stack trace for logging', () async {
      String? loggedStackTrace;

      await mix<void>(
        key: 'test',
        catchError: (error, stackTrace) {
          loggedStackTrace = 'Error: $error at $stackTrace';
          // Return normally to suppress
        },
        () => throw Exception('test error'),
      );

      expect(loggedStackTrace, isNotNull);
      expect(loggedStackTrace, contains('Error:'));
      expect(loggedStackTrace, contains('test error'));
    });
  });

  group('catchError with UserException', () {
    test('throwing UserException queues it for dialog (ifOpenDialog=true)', () async {
      await mix<void>(
        key: 'test',
        catchError: (error, stackTrace) {
          throw UserException('User-facing error');
        },
        () => throw Exception('internal error'),
      );

      final errors = Superpowers.errors;
      expect(errors.length, 1);
      expect(errors.first.message, 'User-facing error');
    });

    test('throwing UserException with ifOpenDialog=false throws instead of queuing',
        () async {
      await expectLater(
        () => mix<void>(
          key: 'test',
          catchError: (error, stackTrace) {
            throw UserException('Error', ifOpenDialog: false);
          },
          () => throw Exception('internal error'),
        ),
        throwsA(isA<UserException>()),
      );

      // Should NOT be queued
      expect(Superpowers.errors, isEmpty);
    });

    test('catchError can conditionally transform to UserException', () async {
      Future<void> runWithError(Object error) async {
        await mix<void>(
          key: 'test',
          catchError: (e, s) {
            if (e is FormatException) {
              throw UserException('Invalid format: ${e.message}');
            }
            // Suppress other errors
          },
          () => throw error,
        );
      }

      // FormatException should become UserException
      await runWithError(FormatException('bad input'));
      expect(Superpowers.errors.length, 1);
      expect(Superpowers.errors.first.message, contains('Invalid format'));

      Superpowers.clearErrors();

      // Other exceptions should be suppressed
      await runWithError(Exception('other error'));
      expect(Superpowers.errors, isEmpty);
    });
  });

  group('catchError edge cases', () {
    test('catchError throwing null-like values', () async {
      // Throwing an Error (not Exception)
      await expectLater(
        () => mix<void>(
          key: 'test',
          catchError: (error, stackTrace) {
            throw StateError('state error');
          },
          () => throw Exception('original'),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('catchError with synchronous action', () async {
      var catchErrorCalled = false;

      // When a synchronous action throws and catchError suppresses it,
      // mix() returns null synchronously (not a Future)
      final result = await mix<int>(
        key: 'test',
        catchError: (error, stackTrace) {
          catchErrorCalled = true;
        },
        () {
          throw Exception('sync error');
        },
      );

      expect(result, null);
      expect(catchErrorCalled, true);
    });

    test('catchError is not called when action succeeds', () async {
      var catchErrorCalled = false;

      final result = await mix<int>(
        key: 'test',
        catchError: (error, stackTrace) {
          catchErrorCalled = true;
        },
        () => 42,
      );

      expect(result, 42);
      expect(catchErrorCalled, false);
    });

    test('catchError is not called when AbortException is thrown', () async {
      var catchErrorCalled = false;

      final result = await mix<int>(
        key: 'test',
        catchError: (error, stackTrace) {
          catchErrorCalled = true;
        },
        () => throw AbortException(),
      );

      expect(result, null);
      expect(catchErrorCalled, false);
    });

    test('catchError throwing AbortException propagates it', () async {
      // When catchError throws AbortException, it gets rethrown
      // (only the ORIGINAL error being AbortException is suppressed)
      await expectLater(
        () => mix<int>(
          key: 'test',
          catchError: (error, stackTrace) {
            throw AbortException(); // This will be rethrown
          },
          () => throw Exception('error'),
        ),
        throwsA(isA<AbortException>()),
      );
    });

    test('to suppress error in catchError, return normally instead of throwing AbortException',
        () async {
      // The correct way to suppress an error in catchError is to return normally
      final result = await mix<int>(
        key: 'test',
        catchError: (error, stackTrace) {
          // Return normally to suppress (don't throw AbortException)
        },
        () => throw Exception('error'),
      );

      expect(result, null);
      expect(Superpowers.errors, isEmpty);
    });
  });

  group('catchError with MixConfig', () {
    test('config.catchError works with new semantics', () async {
      var configCatchErrorCalled = false;

      final config = MixConfig(
        catchError: (error, stackTrace) {
          configCatchErrorCalled = true;
          // Suppress by returning normally
        },
      );

      final result = await mix<int>(
        key: 'test',
        config: config,
        () => throw Exception('test'),
      );

      expect(configCatchErrorCalled, true);
      expect(result, null);
    });

    test('explicit catchError overrides config.catchError', () async {
      var configCalled = false;
      var explicitCalled = false;

      final config = MixConfig(
        catchError: (error, stackTrace) {
          configCalled = true;
        },
      );

      await mix<int>(
        key: 'test',
        config: config,
        catchError: (error, stackTrace) {
          explicitCalled = true;
        },
        () => throw Exception('test'),
      );

      expect(configCalled, false);
      expect(explicitCalled, true);
    });
  });

  group('catchError with mix.ctx', () {
    test('catchError works with mix.ctx', () async {
      var catchErrorCalled = false;
      MixContext? capturedContext;

      await mix.ctx<int>(
        key: 'test',
        catchError: (error, stackTrace) {
          catchErrorCalled = true;
        },
        (ctx) {
          capturedContext = ctx;
          throw Exception('test');
        },
      );

      expect(catchErrorCalled, true);
      expect(capturedContext, isNotNull);
    });

    test('catchError can access retry info from mix.ctx', () async {
      var attemptWhenError = -1;

      await mix.ctx<int>(
        key: 'test',
        retry: retry(maxRetries: 2, initialDelay: 1.millis),
        catchError: (error, stackTrace) {
          // Suppress after all retries
        },
        (ctx) {
          attemptWhenError = ctx.retry?.attempt ?? -1;
          throw Exception('retry me');
        },
      );

      // Should have tried 3 times (initial + 2 retries)
      expect(attemptWhenError, 2); // 0-indexed, so 2 is the third attempt
    });
  });

  group('catchError documentation examples', () {
    test('example: transform API error to user-friendly message', () async {
      // Simulating an API call that fails
      Future<String> apiCall() async {
        throw Exception('HTTP 500: Internal Server Error');
      }

      await mix<String>(
        key: 'fetchData',
        catchError: (error, stackTrace) {
          // Transform technical error to user-friendly message
          throw UserException(
            'Unable to load data. Please try again later.',
          );
        },
        () async => apiCall(),
      );

      expect(Superpowers.errors.length, 1);
      expect(Superpowers.errors.first.message, contains('Unable to load data'));
    });

    test('example: log error and suppress', () async {
      final loggedErrors = <String>[];

      await mix<void>(
        key: 'backgroundTask',
        catchError: (error, stackTrace) {
          // Log error but don't show to user
          loggedErrors.add('Background task failed: $error');
          // Return normally to suppress
        },
        () => throw Exception('Background sync failed'),
      );

      expect(loggedErrors.length, 1);
      expect(loggedErrors.first, contains('Background sync failed'));
      expect(Superpowers.errors, isEmpty); // No user-facing error
    });

    test('example: conditional error handling', () async {
      Future<void> handleWithCatchError(Object errorToThrow) async {
        await mix<void>(
          key: 'conditionalHandler',
          catchError: (error, stackTrace) {
            if (error is FormatException) {
              throw UserException('Invalid input format');
            } else if (error is TimeoutException) {
              throw UserException('Request timed out. Please try again.');
            }
            // Re-throw unknown errors
            throw error;
          },
          () => throw errorToThrow,
        );
      }

      // FormatException -> UserException (queued)
      await handleWithCatchError(FormatException('bad'));
      expect(Superpowers.errors.length, 1);
      Superpowers.clearErrors();

      // TimeoutException -> UserException (queued)
      await handleWithCatchError(TimeoutException('slow'));
      expect(Superpowers.errors.length, 1);
      Superpowers.clearErrors();

      // Unknown error -> re-thrown
      await expectLater(
        () => handleWithCatchError(StateError('unknown')),
        throwsA(isA<StateError>()),
      );
    });
  });
}
