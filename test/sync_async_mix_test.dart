import 'dart:async';

import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Reset Superpowers static state before each test.
  setUp(() {
    Superpowers.clear();
  });

  group('mix sync execution', () {
    test('sync action without async features returns value synchronously', () {
      var executed = false;

      // This should execute synchronously and return the value immediately
      final result = mix<int>(
        key: 'test',
        () {
          executed = true;
          return 42;
        },
      );

      // The action should have already executed
      expect(executed, true);

      // Result should be the value directly, not a Future
      expect(result, isNot(isA<Future>()));
      expect(result, 42);
    });

    test('sync action with nonReentrant returns synchronously', () {
      var executed = false;

      final result = mix(
        key: 'test',
        nonReentrant: nonReentrant,
        () {
          executed = true;
          return 42;
        },
      );

      expect(executed, true);
      expect(result, isNot(isA<Future>()));
      expect(result, 42);
    });

    test('sync action with throttle returns synchronously', () {
      var executed = false;

      final result = mix(
        key: 'test',
        throttle: throttle(duration: 100.millis),
        () {
          executed = true;
          return 42;
        },
      );

      expect(executed, true);
      expect(result, isNot(isA<Future>()));
      expect(result, 42);
    });

    test('sync action with fresh returns synchronously', () {
      var executed = false;

      final result = mix<int>(
        key: 'test',
        fresh: fresh(freshFor: 100.millis),
        () {
          executed = true;
          return 42;
        },
      );

      expect(executed, true);
      expect(result, isNot(isA<Future>()));
      expect(result, 42);
    });

    test('sync action with nonReentrant + throttle + fresh returns synchronously',
        () {
      var executed = false;

      final result = mix<int>(
        key: 'test',
        nonReentrant: nonReentrant,
        throttle: throttle(duration: 100.millis),
        fresh: fresh(freshFor: 100.millis),
        () {
          executed = true;
          return 42;
        },
      );

      expect(executed, true);
      expect(result, isNot(isA<Future>()));
      expect(result, 42);
    });

    test('sync action with before callback returns synchronously', () {
      var beforeCalled = false;
      var executed = false;

      final result = mix<int>(
        key: 'test',
        config: MixConfig(before: () {
          beforeCalled = true;
        }),
        () {
          executed = true;
          return 42;
        },
      );

      expect(beforeCalled, true);
      expect(executed, true);
      expect(result, isNot(isA<Future>()));
      expect(result, 42);
    });

    test('sync action with after callback returns synchronously', () {
      var afterCalled = false;
      var executed = false;

      final result = mix<int>(
        key: 'test',
        config: MixConfig(after: () {
          afterCalled = true;
        }),
        () {
          executed = true;
          return 42;
        },
      );

      expect(executed, true);
      expect(afterCalled, true);
      expect(result, isNot(isA<Future>()));
      expect(result, 42);
    });

    test('sync action with wrapRun returns synchronously', () {
      var wrapRunCalled = false;

      final result = mix<int>(
        key: 'test',
        config: MixConfig(wrapRun: (action) {
          wrapRunCalled = true;
          return action();
        }),
        () => 42,
      );

      expect(wrapRunCalled, true);
      expect(result, isNot(isA<Future>()));
      expect(result, 42);
    });

    test('sync action that throws executes synchronously', () {
      var executed = false;

      expect(
        () => mix<int>(
          key: 'test',
          () {
            executed = true;
            throw Exception('Sync error');
          },
        ),
        throwsException,
      );

      expect(executed, true);
    });

    test('sync action with catchError suppressing error returns null synchronously',
        () {
      var executed = false;

      final result = mix<int>(
        key: 'test',
        config: MixConfig(catchError: (e, s) {}),
        () {
          executed = true;
          throw Exception('Sync error');
        },
      );

      expect(executed, true);
      expect(result, isNot(isA<Future>()));
      expect(result, null);
    });

    test('aborted by nonReentrant returns null synchronously', () async {
      final completer = Completer<void>();

      // Start a blocking async action
      final future1 = mix<void>(
        key: 'test',
        nonReentrant: nonReentrant,
        () async {
          await completer.future;
        },
      );

      // Give it time to start
      await Future.delayed(const Duration(milliseconds: 10));

      // This sync action should be aborted and return null synchronously
      final result = mix<int>(
        key: 'test',
        nonReentrant: nonReentrant,
        () => 42,
      );

      expect(result, isNot(isA<Future>()));
      expect(result, null);

      // Cleanup
      completer.complete();
      await future1;
    });

    test('aborted by throttle returns null synchronously', () {
      // First call sets throttle lock
      mix<void>(
        key: 'test',
        throttle: throttle(duration: 1.sec),
        () {},
      );

      // Second call should be aborted synchronously
      final result = mix<int>(
        key: 'test',
        throttle: throttle(duration: 1.sec),
        () => 42,
      );

      expect(result, isNot(isA<Future>()));
      expect(result, null);
    });

    test('aborted by fresh returns null synchronously', () {
      // First call sets fresh
      mix<void>(
        key: 'test',
        fresh: fresh(freshFor: 1.sec),
        () {},
      );

      // Second call should be aborted synchronously
      final result = mix<int>(
        key: 'test',
        fresh: fresh(freshFor: 1.sec),
        () => 42,
      );

      expect(result, isNot(isA<Future>()));
      expect(result, null);
    });
  });

  group('mix async execution', () {
    test('async action without async features returns Future', () async {
      var executed = false;

      final result = mix<int>(
        key: 'test',
        () async {
          executed = true;
          return 42;
        },
      );

      // The action starts but result is a Future
      expect(result, isA<Future>());

      // Wait for completion
      final value = await result;
      expect(executed, true);
      expect(value, 42);
    });

    test('sync action with debounce returns Future', () async {
      var executed = false;

      final result = mix<int>(
        key: 'test',
        debounce: debounce(duration: 10.millis),
        () {
          executed = true;
          return 42;
        },
      );

      // Should return a Future because debounce is async
      expect(result, isA<Future>());

      // Action shouldn't have executed yet (debounce delay)
      expect(executed, false);

      // Wait for completion
      final value = await result;
      expect(executed, true);
      expect(value, 42);
    });

    test('sync action with checkInternet returns Future', () async {
      Superpowers.clear(simulateInternet: () => true);
      var executed = false;

      final result = mix<int>(
        key: 'test',
        checkInternet: checkInternet,
        () {
          executed = true;
          return 42;
        },
      );

      // Should return a Future because checkInternet is async
      expect(result, isA<Future>());

      // Wait for completion
      final value = await result;
      expect(executed, true);
      expect(value, 42);
    });

    test('sync action with sequential returns Future', () async {
      var executed = false;

      final result = mix<int>(
        key: 'test',
        sequential: sequential,
        () {
          executed = true;
          return 42;
        },
      );

      // Should return a Future because sequential is async
      expect(result, isA<Future>());

      // Wait for completion
      final value = await result;
      expect(executed, true);
      expect(value, 42);
    });

    test('sync action with retry returns Future', () async {
      var executed = false;

      final result = mix<int>(
        key: 'test',
        retry: retry,
        () {
          executed = true;
          return 42;
        },
      );

      // Should return a Future because retry is async
      expect(result, isA<Future>());

      // Wait for completion
      final value = await result;
      expect(executed, true);
      expect(value, 42);
    });

    test('async action with all sync features returns Future', () async {
      var executed = false;

      final result = mix<int>(
        key: 'test',
        nonReentrant: nonReentrant,
        throttle: throttle(duration: 100.millis),
        fresh: fresh(freshFor: 100.millis),
        () async {
          executed = true;
          return 42;
        },
      );

      // Should return a Future because action is async
      expect(result, isA<Future>());

      // Wait for completion
      final value = await result;
      expect(executed, true);
      expect(value, 42);
    });

    test('sync action with async before callback returns Future', () async {
      var beforeCompleted = false;
      var executed = false;

      final result = mix<int>(
        key: 'test',
        config: MixConfig(before: () async {
          await Future.delayed(const Duration(milliseconds: 10));
          beforeCompleted = true;
        }),
        () {
          executed = true;
          return 42;
        },
      );

      // Should return a Future because before is async
      expect(result, isA<Future>());

      // Wait for completion
      final value = await result;
      expect(beforeCompleted, true);
      expect(executed, true);
      expect(value, 42);
    });

    test('sync action with async wrapRun returns Future', () async {
      var executed = false;

      final result = mix<int>(
        key: 'test',
        config: MixConfig(wrapRun: (action) async {
          await Future.delayed(const Duration(milliseconds: 10));
          return action();
        }),
        () {
          executed = true;
          return 42;
        },
      );

      // Should return a Future because wrapRun is async
      expect(result, isA<Future>());

      // Wait for completion
      final value = await result;
      expect(executed, true);
      expect(value, 42);
    });
  });

  group('mix FutureOr behavior', () {
    test('FutureOr<T> can be awaited whether sync or async', () async {
      // Sync path
      final syncResult = mix<int>(
        key: 'test1',
        () => 1,
      );
      final syncValue = await syncResult;
      expect(syncValue, 1);

      // Async path
      final asyncResult = mix<int>(
        key: 'test2',
        () async => 2,
      );
      final asyncValue = await asyncResult;
      expect(asyncValue, 2);
    });

    test('sync result can be used directly without await', () {
      final result = mix<int>(
        key: 'test',
        () => 42,
      );

      // Can check if it's not a Future and use directly
      if (result is! Future) {
        expect(result, 42);
      } else {
        fail('Expected sync result');
      }
    });

    test('async result must be awaited', () async {
      final result = mix<int>(
        key: 'test',
        debounce: debounce(duration: 10.millis),
        () => 42,
      );

      // Must await because it's a Future
      expect(result, isA<Future>());
      final value = await result;
      expect(value, 42);
    });
  });

  group('mix return type edge cases', () {
    test('void sync action works', () {
      var executed = false;

      final result = mix<void>(
        key: 'test',
        () {
          executed = true;
        },
      );

      expect(executed, true);
      expect(result, isNot(isA<Future>()));
    });

    test('void async action works', () async {
      var executed = false;

      final result = mix<void>(
        key: 'test',
        () async {
          executed = true;
        },
      );

      expect(result, isA<Future>());
      await result;
      expect(executed, true);
    });

    test('nullable type sync action works', () {
      final result = mix<int?>(
        key: 'test',
        () => null,
      );

      expect(result, isNot(isA<Future>()));
      expect(result, null);
    });

    test('complex type sync action works', () {
      final result = mix<Map<String, List<int>>>(
        key: 'test',
        () => {
              'a': [1, 2, 3]
            },
      );

      expect(result, isNot(isA<Future>()));
      expect(result, {
        'a': [1, 2, 3]
      });
    });

    test('aborted action returns null regardless of return type', () {
      // First call sets fresh
      mix<void>(
        key: 'test',
        fresh: fresh(freshFor: 1.sec),
        () {},
      );

      // Aborted call returns null even though type is int (not int?)
      // The return type is actually T? so this is fine
      final result = mix<int>(
        key: 'test',
        fresh: fresh(freshFor: 1.sec),
        () => 42,
      );

      expect(result, null);
    });
  });

  group('state tracking with sync/async', () {
    test('isWaiting works with sync action', () {
      // Before sync action
      expect(Superpowers.isWaiting('testKey'), false);

      // Sync action completes immediately, so isWaiting is brief
      final result = mix<int>(
        key: 'testKey',
        () => 42,
      );

      // After sync action (already complete)
      expect(result, 42);
      expect(Superpowers.isWaiting('testKey'), false);
    });

    test('isWaiting works with async action', () async {
      final completer = Completer<void>();

      expect(Superpowers.isWaiting('testKey'), false);

      final future = mix<int>(
        key: 'testKey',
        () async {
          await completer.future;
          return 42;
        },
      );

      // Give it time to start
      await Future.delayed(const Duration(milliseconds: 10));

      // During async action
      expect(Superpowers.isWaiting('testKey'), true);

      // Complete the action
      completer.complete();
      await future;

      // After completion
      expect(Superpowers.isWaiting('testKey'), false);
    });

    test('isFailed works with sync action that fails', () {
      expect(Superpowers.isFailed('testKey'), false);

      mix<int>(
        key: 'testKey',
        config: MixConfig(catchError: (e, s) => throw UserException('Failed')),
        () {
          throw Exception('Test error');
        },
      );

      expect(Superpowers.isFailed('testKey'), true);
      expect(Superpowers.getException('testKey')?.message, 'Failed');
    });

    test('isFailed works with async action that fails', () async {
      expect(Superpowers.isFailed('testKey'), false);

      await mix<int>(
        key: 'testKey',
        config: MixConfig(catchError: (e, s) => throw UserException('Failed')),
        () async {
          throw Exception('Test error');
        },
      );

      expect(Superpowers.isFailed('testKey'), true);
      expect(Superpowers.getException('testKey')?.message, 'Failed');
    });
  });

  group('cleanup with sync/async', () {
    test('nonReentrant lock released after sync action', () {
      // First sync call
      mix<void>(
        key: 'test',
        nonReentrant: nonReentrant,
        () {},
      );

      // Second sync call should work (lock was released)
      var secondRan = false;
      mix<void>(
        key: 'test',
        nonReentrant: nonReentrant,
        () {
          secondRan = true;
        },
      );

      expect(secondRan, true);
    });

    test('nonReentrant lock released after sync action throws', () {
      // First sync call throws
      try {
        mix<void>(
          key: 'test',
          nonReentrant: nonReentrant,
          () {
            throw Exception('Error');
          },
        );
      } catch (_) {}

      // Second sync call should work (lock was released)
      var secondRan = false;
      mix<void>(
        key: 'test',
        nonReentrant: nonReentrant,
        () {
          secondRan = true;
        },
      );

      expect(secondRan, true);
    });

    test('fresh rollback works with sync action that throws', () {
      // First sync call throws
      try {
        mix<void>(
          key: 'test',
          fresh: fresh(freshFor: 1.sec),
          () {
            throw Exception('Error');
          },
        );
      } catch (_) {}

      // Second sync call should work (fresh was rolled back)
      var secondRan = false;
      mix<void>(
        key: 'test',
        fresh: fresh(freshFor: 1.sec),
        () {
          secondRan = true;
        },
      );

      expect(secondRan, true);
    });

    test('throttle lock removed on error with removeLockOnError', () {
      // First sync call throws
      try {
        mix<void>(
          key: 'test',
          throttle: throttle(duration: 1.sec, removeLockOnError: true),
          () {
            throw Exception('Error');
          },
        );
      } catch (_) {}

      // Second sync call should work (throttle lock was removed on error)
      var secondRan = false;
      mix<void>(
        key: 'test',
        throttle: throttle(duration: 1.sec, removeLockOnError: true),
        () {
          secondRan = true;
        },
      );

      expect(secondRan, true);
    });
  });
}
