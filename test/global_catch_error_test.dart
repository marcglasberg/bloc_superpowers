// Developed by Marcelo Glasberg (2026) https://glasberg.dev and https://github.com/marcglasberg
// For more info, see: https://pub.dartlang.org/packages/bloc_superpowers and http://blocsuperpowers.org
import 'dart:async';

import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    Superpowers.clear();
  });

  group('Superpowers.globalCatchError', () {
    group('basic functionality', () {
      test('is null by default', () {
        expect(Superpowers.globalCatchError, isNull);
      });

      test('can be set and retrieved', () {
        void handler(Object error, StackTrace stack, Object key) {}
        Superpowers.globalCatchError = handler;
        expect(Superpowers.globalCatchError, equals(handler));
      });

      test('is cleared by Superpowers.clear()', () {
        Superpowers.globalCatchError = (error, stack, key) {};
        expect(Superpowers.globalCatchError, isNotNull);

        Superpowers.clear();
        expect(Superpowers.globalCatchError, isNull);
      });
    });

    group('called after local catchError', () {
      test('is called when no local catchError is provided', () async {
        var globalCalled = false;
        Object? receivedError;
        Object? receivedKey;

        Superpowers.globalCatchError = (error, stack, key) {
          globalCalled = true;
          receivedError = error;
          receivedKey = key;
          // Suppress by not throwing
        };

        await mix(
          key: 'testKey',
          () async {
            throw Exception('test error');
          },
        );

        expect(globalCalled, isTrue);
        expect(receivedError, isA<Exception>());
        expect(receivedKey, equals('testKey'));
      });

      test('is called after local catchError transforms error', () async {
        var globalCalled = false;
        Object? receivedError;

        Superpowers.globalCatchError = (error, stack, key) {
          globalCalled = true;
          receivedError = error;
          // Suppress
        };

        await mix(
          key: 'testKey',
          catchError: (error, stack) {
            // Transform to UserException
            throw UserException('Transformed error');
          },
          () async {
            throw Exception('original error');
          },
        );

        expect(globalCalled, isTrue);
        expect(receivedError, isA<UserException>());
        expect((receivedError as UserException).message, equals('Transformed error'));
      });

      test('is NOT called when local catchError suppresses error', () async {
        var globalCalled = false;

        Superpowers.globalCatchError = (error, stack, key) {
          globalCalled = true;
          throw error;
        };

        await mix(
          key: 'testKey',
          catchError: (error, stack) {
            // Suppress error by returning normally
          },
          () async {
            throw Exception('test error');
          },
        );

        expect(globalCalled, isFalse);
      });

      test('is NOT called when MixConfig.catchError suppresses error', () async {
        var globalCalled = false;

        Superpowers.globalCatchError = (error, stack, key) {
          globalCalled = true;
          throw error;
        };

        final config = MixConfig(
          catchError: (error, stack) {
            // Suppress error
          },
        );

        await mix(
          key: 'testKey',
          config: config,
          () async {
            throw Exception('test error');
          },
        );

        expect(globalCalled, isFalse);
      });
    });

    group('error handling behavior', () {
      test('can suppress error by returning normally', () async {
        var globalCalled = false;

        Superpowers.globalCatchError = (error, stack, key) {
          globalCalled = true;
          // Suppress by not throwing
        };

        final result = await mix(
          key: 'testKey',
          () async {
            throw Exception('test error');
          },
        );

        expect(globalCalled, isTrue);
        expect(result, isNull); // Suppressed, returns null
      });

      test('can transform error to UserException', () async {
        Superpowers.globalCatchError = (error, stack, key) {
          throw UserException('Global transformed: ${error.toString()}');
        };

        await mix(
          key: 'testKey',
          () async {
            throw Exception('original');
          },
        );

        // UserException with ifOpenDialog=true should be in queue
        final queuedError = Superpowers.getAndRemoveFirstError();
        expect(queuedError, isNotNull);
        expect(queuedError!.message, contains('Global transformed'));
      });

      test('receives the correct key for logging', () async {
        Object? receivedKey;

        Superpowers.globalCatchError = (error, stack, key) {
          receivedKey = key;
          // Suppress
        };

        // Test with string key
        await mix(
          key: 'myStringKey',
          () async {
            throw Exception('error');
          },
        );
        expect(receivedKey, equals('myStringKey'));

        // Test with record key
        await mix(
          key: ('MyType', 123),
          () async {
            throw Exception('error');
          },
        );
        expect(receivedKey, equals(('MyType', 123)));

        // Test with enum key
        await mix(
          key: _TestEnum.value1,
          () async {
            throw Exception('error');
          },
        );
        expect(receivedKey, equals(_TestEnum.value1));
      });

      test('error thrown by global catchError is propagated', () async {
        Superpowers.globalCatchError = (error, stack, key) {
          throw StateError('Global error');
        };

        // The global threw StateError, which should be rethrown
        // (since it's not a UserException with ifOpenDialog=true)
        Object? thrownError;
        try {
          await mix(
            key: 'testKey',
            () async {
              throw Exception('original');
            },
          );
        } catch (e) {
          thrownError = e;
        }

        expect(thrownError, isA<StateError>());
        expect((thrownError as StateError).message, equals('Global error'));
      });

      test('UserException with ifOpenDialog=false is rethrown', () async {
        Superpowers.globalCatchError = (error, stack, key) {
          throw UserException('No dialog').withDialog(false);
        };

        Object? thrownError;
        try {
          await mix(
            key: 'testKey',
            () async {
              throw Exception('original');
            },
          );
        } catch (e) {
          thrownError = e;
        }

        expect(thrownError, isA<UserException>());
        expect((thrownError as UserException).ifOpenDialog, isFalse);
      });
    });

    group('use case: centralized logging', () {
      test('logs all errors that propagate', () async {
        final loggedErrors = <Object>[];
        final loggedKeys = <Object>[];

        Superpowers.globalCatchError = (error, stack, key) {
          loggedErrors.add(error);
          loggedKeys.add(key);
          // Suppress to prevent rethrow in test
        };

        // Error 1
        await mix(
          key: 'action1',
          () async {
            throw Exception('error 1');
          },
        );

        // Error 2
        await mix(
          key: 'action2',
          () async {
            throw Exception('error 2');
          },
        );

        // Suppressed error - should NOT be logged (local catchError suppresses it)
        await mix(
          key: 'action3',
          catchError: (error, stack) {
            // Suppress before reaching global
          },
          () async {
            throw Exception('suppressed');
          },
        );

        expect(loggedErrors.length, equals(2));
        expect(loggedKeys, equals(['action1', 'action2']));
      });

      test('can log and re-throw', () async {
        final loggedErrors = <Object>[];

        Superpowers.globalCatchError = (error, stack, key) {
          loggedErrors.add(error);
          // Convert to UserException so it's queued for dialog (not rethrown)
          throw UserException('Logged: ${error.toString()}');
        };

        await mix(
          key: 'test',
          () async {
            throw Exception('original');
          },
        );

        expect(loggedErrors.length, equals(1));
        expect(loggedErrors[0], isA<Exception>());

        // The converted UserException should be in queue
        final error = Superpowers.getAndRemoveFirstError();
        expect(error?.message, contains('Logged'));
      });
    });

    group('use case: exception conversion', () {
      test('converts known exceptions to UserException', () async {
        Superpowers.globalCatchError = (error, stack, key) {
          if (error is UserException) throw error; // Already converted

          if (error is FormatException) {
            throw UserException('Invalid format. Please check your input.');
          }

          if (error is TimeoutException) {
            throw UserException('Request timed out. Please try again.');
          }

          // Unknown error - generic message
          throw UserException('Something went wrong. Please try again.');
        };

        // Test FormatException conversion
        await mix(
          key: 'test1',
          () async {
            throw const FormatException('bad format');
          },
        );

        var error = Superpowers.getAndRemoveFirstError();
        expect(error?.message, equals('Invalid format. Please check your input.'));

        // Test TimeoutException conversion
        await mix(
          key: 'test2',
          () async {
            throw TimeoutException('timeout');
          },
        );

        error = Superpowers.getAndRemoveFirstError();
        expect(error?.message, equals('Request timed out. Please try again.'));

        // Test unknown error conversion
        await mix(
          key: 'test3',
          () async {
            throw ArgumentError('some arg error');
          },
        );

        error = Superpowers.getAndRemoveFirstError();
        expect(error?.message, equals('Something went wrong. Please try again.'));
      });

      test('does not double-convert UserException', () async {
        Superpowers.globalCatchError = (error, stack, key) {
          if (error is UserException) throw error;
          throw UserException('Converted');
        };

        await mix(
          key: 'test',
          () async {
            throw UserException('Original user message');
          },
        );

        final error = Superpowers.getAndRemoveFirstError();
        expect(error?.message, equals('Original user message'));
      });
    });

    group('interaction with retry', () {
      test('is only called after all retries exhausted', () async {
        var globalCallCount = 0;

        Superpowers.globalCatchError = (error, stack, key) {
          globalCallCount++;
          // Suppress to prevent test failure
        };

        var attemptCount = 0;
        await mix(
          key: 'testKey',
          retry: retry(maxRetries: 2, initialDelay: 1.millis),
          () async {
            attemptCount++;
            throw Exception('always fails');
          },
        );

        // Action should be called 3 times (initial + 2 retries)
        expect(attemptCount, equals(3));
        // But globalCatchError should only be called once, after all retries
        expect(globalCallCount, equals(1));
      });
    });

    group('interaction with async operations', () {
      test('works with async errors', () async {
        var globalCalled = false;

        Superpowers.globalCatchError = (error, stack, key) {
          globalCalled = true;
          // Suppress
        };

        await mix(
          key: 'testKey',
          () async {
            await Future.delayed(const Duration(milliseconds: 1));
            throw Exception('async error');
          },
        );

        expect(globalCalled, isTrue);
      });

      test('works with sync errors in sync mix', () {
        var globalCalled = false;

        Superpowers.globalCatchError = (error, stack, key) {
          globalCalled = true;
          // Suppress
        };

        mix(
          key: 'testKey',
          () {
            throw Exception('sync error');
          },
        );

        expect(globalCalled, isTrue);
      });
    });

    group('interaction with before/after callbacks', () {
      test('after() is called before globalCatchError', () async {
        final callOrder = <String>[];

        Superpowers.globalCatchError = (error, stack, key) {
          callOrder.add('global');
          // Suppress
        };

        await mix(
          key: 'testKey',
          config: MixConfig(
            after: () {
              callOrder.add('after');
            },
          ),
          () async {
            throw Exception('error');
          },
        );

        expect(callOrder, equals(['after', 'global']));
      });

      test('globalCatchError is called when before() throws', () async {
        var globalCalled = false;
        Object? receivedError;

        Superpowers.globalCatchError = (error, stack, key) {
          globalCalled = true;
          receivedError = error;
          // Suppress
        };

        await mix(
          key: 'testKey',
          config: MixConfig(
            before: () {
              throw Exception('before error');
            },
          ),
          () async {
            // Never reached
          },
        );

        expect(globalCalled, isTrue);
        expect((receivedError as Exception).toString(), contains('before error'));
      });
    });

    group('with mix.ctx', () {
      test('works with mix.ctx variant', () async {
        Object? receivedKey;

        Superpowers.globalCatchError = (error, stack, key) {
          receivedKey = key;
          // Suppress
        };

        await mix.ctx(
          key: 'ctxTestKey',
          (ctx) async {
            throw Exception('error');
          },
        );

        expect(receivedKey, equals('ctxTestKey'));
      });
    });

    group('edge cases', () {
      test('globalCatchError throwing null-like values', () async {
        // Test that the handler can throw various types
        var callCount = 0;

        Superpowers.globalCatchError = (error, stack, key) {
          callCount++;
          // Just suppress
        };

        await mix(key: 'test', () => throw 'string error');
        await mix(key: 'test', () => throw 42);
        await mix(key: 'test', () => throw ['list', 'error']);

        expect(callCount, equals(3));
      });

      test('globalCatchError receives original stack trace', () async {
        StackTrace? receivedStack;

        Superpowers.globalCatchError = (error, stack, key) {
          receivedStack = stack;
          // Suppress
        };

        await mix(
          key: 'testKey',
          () async {
            throw Exception('with stack');
          },
        );

        expect(receivedStack, isNotNull);
        expect(receivedStack.toString(), contains('global_catch_error_test.dart'));
      });

      test('multiple sequential calls each trigger globalCatchError', () async {
        var callCount = 0;

        Superpowers.globalCatchError = (error, stack, key) {
          callCount++;
          // Suppress
        };

        for (var i = 0; i < 5; i++) {
          await mix(
            key: 'test$i',
            () async {
              throw Exception('error $i');
            },
          );
        }

        expect(callCount, equals(5));
      });
    });
  });
}

enum _TestEnum { value1, value2 }
