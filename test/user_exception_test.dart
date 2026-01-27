import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Reset Superpowers static state before each test
  setUp(() {
    Superpowers.clear();
  });

  group('UserException behavior based on ifOpenDialog', () {
    // Scenario 1: ifOpenDialog=true → queued for dialog
    test('ifOpenDialog=true: queued for dialog', () async {
      // Should not throw - error is queued
      await mix<void>(
        () => throw UserException('Queued error'),
        key: 'test',
      );

      // Error should be queued
      expect(Superpowers.errors.length, 1);
      expect(Superpowers.errors.first.message, 'Queued error');
    });

    // Scenario 2: ifOpenDialog=false → rethrown
    test('ifOpenDialog=false: rethrown', () async {
      // Should throw because ifOpenDialog=false means dev wants to handle it
      expect(
        () => mix<void>(
          () => throw UserException('Not queued', ifOpenDialog: false),
          key: 'test',
        ),
        throwsA(isA<UserException>()),
      );

      // Error should NOT be queued
      expect(Superpowers.errors.length, 0);
    });

    // Scenario 3: Non-UserException → rethrown
    test('Non-UserException: rethrown', () async {
      expect(
        () => mix<void>(
          () => throw Exception('Regular error'),
          key: 'test',
        ),
        throwsA(isA<Exception>()),
      );

      // Error should NOT be queued
      expect(Superpowers.errors.length, 0);
    });
  });

  group('Superpowers static error queue', () {
    test('getAndRemoveFirstError consumes errors from queue', () async {
      await mix<void>(() => throw UserException('Error 1'), key: 'test1');
      await mix<void>(() => throw UserException('Error 2'), key: 'test2');
      await mix<void>(() => throw UserException('Error 3'), key: 'test3');

      expect(Superpowers.errors.length, 3);

      final first = Superpowers.getAndRemoveFirstError();
      expect(first?.message, 'Error 1');
      expect(Superpowers.errors.length, 2);

      final second = Superpowers.getAndRemoveFirstError();
      expect(second?.message, 'Error 2');
      expect(Superpowers.errors.length, 1);

      final third = Superpowers.getAndRemoveFirstError();
      expect(third?.message, 'Error 3');
      expect(Superpowers.errors.length, 0);

      final fourth = Superpowers.getAndRemoveFirstError();
      expect(fourth, null);
    });

    test('Queue respects maxErrorsQueued limit', () async {
      Superpowers.clear(maxErrorsQueued: 3);

      await mix<void>(() => throw UserException('Error 1'), key: 'test1');
      await mix<void>(() => throw UserException('Error 2'), key: 'test2');
      await mix<void>(() => throw UserException('Error 3'), key: 'test3');
      await mix<void>(() => throw UserException('Error 4'), key: 'test4');

      // Queue should have 3 errors (oldest removed)
      expect(Superpowers.errors.length, 3);

      // First error should be 'Error 2' (Error 1 was removed)
      final first = Superpowers.getAndRemoveFirstError();
      expect(first?.message, 'Error 2');
    });

    test('onUserException stream emits when errors are added', () async {
      final errors = <UserException>[];
      final subscription = Superpowers.onUserException.listen((error) {
        errors.add(error);
      });

      await mix<void>(() => throw UserException('Error 1'), key: 'test1');
      await mix<void>(() => throw UserException('Error 2'), key: 'test2');

      // Give stream time to emit
      await Future.delayed(Duration.zero);

      expect(errors.length, 2);
      expect(errors[0].message, 'Error 1');
      expect(errors[1].message, 'Error 2');

      await subscription.cancel();
    });

    test('errors getter returns a copy of the queue', () async {
      await mix<void>(() => throw UserException('Error 1'), key: 'test');

      final errorsCopy = Superpowers.errors;
      errorsCopy.clear(); // Modify the copy

      // Original queue should be unchanged
      expect(Superpowers.errors.length, 1);
    });

    test('clearErrors removes all errors from queue', () async {
      await mix<void>(() => throw UserException('Error 1'), key: 'test1');
      await mix<void>(() => throw UserException('Error 2'), key: 'test2');

      expect(Superpowers.errors.length, 2);

      Superpowers.clearErrors();

      expect(Superpowers.errors.length, 0);
    });

    test('Superpowers.clear() clears errors and resets maxErrorsQueued', () async {
      await mix<void>(() => throw UserException('Error 1'), key: 'test1');
      await mix<void>(() => throw UserException('Error 2'), key: 'test2');
      expect(Superpowers.errors.length, 2);

      // Init should clear errors
      Superpowers.clear(maxErrorsQueued: 5);
      expect(Superpowers.errors.length, 0);

      // And set new maxErrorsQueued
      for (int i = 0; i < 7; i++) {
        await mix<void>(() => throw UserException('Error $i'), key: 'test$i');
      }
      expect(Superpowers.errors.length, 5); // Limited to 5
    });
  });

  group('catchError transforms errors', () {
    test('catchError can transform regular exception to UserException', () async {
      await mix<void>(
        () => throw Exception('Original error'),
        key: 'test',
        catchError: (error, stack) => throw UserException('Wrapped error'),
      );

      expect(Superpowers.errors.length, 1);
      expect(Superpowers.errors.first.message, 'Wrapped error');
    });

    test('catchError returning normally suppresses the error', () async {
      await mix<void>(
        () => throw Exception('Should be suppressed'),
        key: 'test',
        catchError: (error, stack) {
          // Return normally to suppress
        },
      );

      // Error was suppressed
      expect(Superpowers.errors.length, 0);
    });
  });

  group('mix key tracks waiting/failed state', () {
    test('isWaiting is true during execution', () async {
      bool wasWaiting = false;

      await mix(
        () async {
          wasWaiting = Superpowers.isWaiting('trackTest');
          await Future.delayed(Duration(milliseconds: 10));
        },
        key: 'trackTest',
      );

      expect(wasWaiting, true);
      expect(Superpowers.isWaiting('trackTest'), false);
    });

    test('isFailed is true after UserException', () async {
      await mix<void>(
        () => throw UserException('Test error'),
        key: 'failTest',
      );

      expect(Superpowers.isFailed('failTest'), true);
      expect(Superpowers.getException('failTest')?.message, 'Test error');
    });

    test('clearException clears failed state', () async {
      await mix<void>(
        () => throw UserException('Test error'),
        key: 'clearTest',
      );

      expect(Superpowers.isFailed('clearTest'), true);

      Superpowers.clearException('clearTest');

      expect(Superpowers.isFailed('clearTest'), false);
    });
  });

  group('before and after callbacks', () {
    test('before is called before action', () async {
      final callOrder = <String>[];

      await mix(
        () {
          callOrder.add('action');
        },
        key: 'test',
        config: MixConfig(
          before: () => callOrder.add('before'),
          after: () => callOrder.add('after'),
        ),
      );

      expect(callOrder, ['before', 'action', 'after']);
    });

    test('after is called even when action throws', () async {
      bool afterCalled = false;

      await mix<void>(
        () => throw UserException('Test error'),
        key: 'test',
        config: MixConfig(after: () => afterCalled = true),
      );

      expect(afterCalled, true);
    });

    test('after is called even when before throws', () async {
      bool afterCalled = false;

      await mix<void>(
        () {},
        key: 'test',
        config: MixConfig(
          before: () => throw UserException('Before error'),
          after: () => afterCalled = true,
        ),
      );

      expect(afterCalled, true);
      expect(Superpowers.errors.first.message, 'Before error');
    });
  });
}
