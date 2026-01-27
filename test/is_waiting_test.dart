import 'dart:async';

import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    Superpowers.clear();
  });

  group('Superpowers.isWaitingInline', () {
    test('returns false when no mix with key is running', () {
      expect(Superpowers.isWaiting('testKey'), isFalse);
    });

    test('returns true while mix with key is running', () async {
      final completer = Completer<void>();
      var wasWaitingDuringExecution = false;

      final future = mix(
        key: 'testKey',
        () async {
          wasWaitingDuringExecution = Superpowers.isWaiting('testKey');
          await completer.future;
        },
      );

      // Give time for mix to start
      await Future.delayed(Duration.zero);

      // Should be waiting
      expect(Superpowers.isWaiting('testKey'), isTrue);

      // Complete the action
      completer.complete();
      await future;

      // Should no longer be waiting
      expect(Superpowers.isWaiting('testKey'), isFalse);
      expect(wasWaitingDuringExecution, isTrue);
    });

    test('returns false for different key', () async {
      final completer = Completer<void>();

      final future = mix(
        key: 'keyA',
        () async {
          await completer.future;
        },
      );

      await Future.delayed(Duration.zero);

      expect(Superpowers.isWaiting('keyA'), isTrue);
      expect(Superpowers.isWaiting('keyB'), isFalse);

      completer.complete();
      await future;
    });

    test('works with list of keys', () async {
      final completerA = Completer<void>();
      final completerB = Completer<void>();

      final futureA = mix(
        key: 'keyA',
        () async => await completerA.future,
      );

      await Future.delayed(Duration.zero);

      // Only keyA is running
      expect(Superpowers.isWaiting(['keyA', 'keyB']), isTrue);
      expect(Superpowers.isWaiting(['keyB', 'keyC']), isFalse);

      final futureB = mix(
        key: 'keyB',
        () async => await completerB.future,
      );

      await Future.delayed(Duration.zero);

      // Both keyA and keyB are running
      expect(Superpowers.isWaiting(['keyA', 'keyB']), isTrue);
      expect(Superpowers.isWaiting(['keyB', 'keyC']), isTrue);

      completerA.complete();
      await futureA;

      // Only keyB is running now
      expect(Superpowers.isWaiting(['keyA', 'keyB']), isTrue);
      expect(Superpowers.isWaiting(['keyA', 'keyC']), isFalse);

      completerB.complete();
      await futureB;
    });

    test('tracks multiple concurrent mix calls with same key', () async {
      final completer1 = Completer<void>();
      final completer2 = Completer<void>();

      final future1 = mix(
        key: 'testKey',
        () async => await completer1.future,
      );

      final future2 = mix(
        key: 'testKey',
        () async => await completer2.future,
      );

      await Future.delayed(Duration.zero);

      // Should be waiting (both are running)
      expect(Superpowers.isWaiting('testKey'), isTrue);

      completer1.complete();
      await future1;

      // Still waiting because second mix is running
      // Note: This depends on implementation - if key is a Set, it's tracked once
      // Let's check what actually happens
      expect(Superpowers.isWaiting('testKey'), isTrue);

      completer2.complete();
      await future2;

      expect(Superpowers.isWaiting('testKey'), isFalse);
    });
  });

  group('Superpowers.isFailedInline', () {
    test('returns false when no mix with key has failed', () {
      expect(Superpowers.isFailed('testKey'), isFalse);
    });

    test('returns true after mix with key fails with UserException', () async {
      await mix<void>(
        key: 'testKey',
        catchError: (e, s) => throw UserException('Test error'),
        () async {
          throw Exception('Test');
        },
      );

      expect(Superpowers.isFailed('testKey'), isTrue);
    });

    test('returns false if error is not UserException', () async {
      try {
        await mix(
          key: 'testKey',
          () async {
            throw Exception('Test');
          },
        );
      } catch (_) {
        // Expected to throw
      }

      expect(Superpowers.isFailed('testKey'), isFalse);
    });

    test('clears failed state when key starts again', () async {
      // First, fail
      await mix<void>(
        key: 'testKey',
        catchError: (e, s) => throw UserException('Test error'),
        () async {
          throw Exception('Test');
        },
      );

      expect(Superpowers.isFailed('testKey'), isTrue);

      // Now check that watching the key registers it for notifications
      Superpowers.isFailed('testKey');

      // Start a new mix with the same key
      final completer = Completer<void>();
      final future = mix(
        key: 'testKey',
        () async => await completer.future,
      );

      await Future.delayed(Duration.zero);

      // Failed state should be cleared when new action starts
      expect(Superpowers.isFailed('testKey'), isFalse);
      expect(Superpowers.isWaiting('testKey'), isTrue);

      completer.complete();
      await future;
    });
  });

  group('Superpowers.exceptionForInline', () {
    test('returns null when no mix with key has failed', () {
      expect(Superpowers.getException('testKey'), isNull);
    });

    test('returns UserException after mix with key fails', () async {
      await mix<void>(
        key: 'testKey',
        catchError: (e, s) => throw UserException('Test error message'),
        () async {
          throw Exception('Test');
        },
      );

      final exception = Superpowers.getException('testKey');
      expect(exception, isNotNull);
      expect(exception!.message, equals('Test error message'));
    });

    test('works with list of keys', () async {
      await mix<void>(
        key: 'keyA',
        catchError: (e, s) => throw UserException('Error A'),
        () async {
          throw Exception('Test A');
        },
      );

      // Returns first matching exception
      final exception = Superpowers.getException(['keyB', 'keyA']);
      expect(exception, isNotNull);
      expect(exception!.message, equals('Error A'));
    });
  });

  group('Superpowers.clearException', () {
    test('clears the failed state for a key', () async {
      await mix<void>(
        key: 'testKey',
        catchError: (e, s) => throw UserException('Test error'),
        () async {
          throw Exception('Test');
        },
      );

      expect(Superpowers.isFailed('testKey'), isTrue);

      Superpowers.clearException('testKey');

      expect(Superpowers.isFailed('testKey'), isFalse);
      expect(Superpowers.getException('testKey'), isNull);
    });

    test('clears multiple keys from list', () async {
      await mix<void>(
        key: 'keyA',
        catchError: (e, s) => throw UserException('Error A'),
        () async {
          throw Exception('Test');
        },
      );

      await mix<void>(
        key: 'keyB',
        catchError: (e, s) => throw UserException('Error B'),
        () async {
          throw Exception('Test');
        },
      );

      expect(Superpowers.isFailed('keyA'), isTrue);
      expect(Superpowers.isFailed('keyB'), isTrue);

      Superpowers.clearException(['keyA', 'keyB']);

      expect(Superpowers.isFailed('keyA'), isFalse);
      expect(Superpowers.isFailed('keyB'), isFalse);
    });
  });

  group('Superpowers.onStateChange with inline tracking', () {
    test('emits when mix with watched key starts', () async {
      // First, register interest in the key
      Superpowers.isWaiting('testKey');

      var stateChangeCount = 0;
      final subscription = Superpowers.onStateChange.listen((_) {
        stateChangeCount++;
      });

      final completer = Completer<void>();
      final future = mix(
        key: 'testKey',
        () async => await completer.future,
      );

      await Future.delayed(Duration.zero);

      // Should have emitted at least once when mix started
      expect(stateChangeCount, greaterThan(0));

      final countBeforeComplete = stateChangeCount;
      completer.complete();
      await future;

      await Future.delayed(Duration.zero);

      // Should have emitted again when mix completed
      expect(stateChangeCount, greaterThan(countBeforeComplete));

      await subscription.cancel();
    });

    test('does not emit for unwatched keys', () async {
      var stateChangeCount = 0;
      final subscription = Superpowers.onStateChange.listen((_) {
        stateChangeCount++;
      });

      final completer = Completer<void>();
      final future = mix(
        key: 'unwatchedKey',
        () async => await completer.future,
      );

      await Future.delayed(Duration.zero);

      // Should not have emitted because key was not watched
      expect(stateChangeCount, equals(0));

      completer.complete();
      await future;

      await subscription.cancel();
    });
  });

  group('Superpowers.init resets inline state', () {
    test('clears in-progress inline keys', () async {
      final completer = Completer<void>();

      // ignore: unawaited_futures
      mix(
        key: 'testKey',
        () async => await completer.future,
      );

      await Future.delayed(Duration.zero);
      expect(Superpowers.isWaiting('testKey'), isTrue);

      Superpowers.clear();

      expect(Superpowers.isWaiting('testKey'), isFalse);

      completer.complete();
    });

    test('clears failed inline keys', () async {
      await mix<void>(
        key: 'testKey',
        catchError: (e, s) => throw UserException('Test error'),
        () async {
          throw Exception('Test');
        },
      );

      expect(Superpowers.isFailed('testKey'), isTrue);

      Superpowers.clear();

      expect(Superpowers.isFailed('testKey'), isFalse);
    });
  });

  group('mix without key', () {
    test('does not affect inline tracking', () async {
      final completer = Completer<void>();

      final future = mix(
        key: '',
        // No key parameter
        () async => await completer.future,
      );

      await Future.delayed(Duration.zero);

      // Should not be tracked
      expect(Superpowers.isWaiting('anyKey'), isFalse);

      completer.complete();
      await future;
    });
  });

  group('widget rebuild on isWaiting change', () {
    // These tests demonstrate that context.isWaiting REQUIRES Superpowers
    // to trigger rebuilds. Without Superpowers, the methods throw an error.

    testWidgets(
        'without Superpowers, context.isWaiting throws FlutterError',
        (WidgetTester tester) async {
      // Build a widget WITHOUT Superpowers - should throw FlutterError
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final isWaiting = context.isWaiting('testAction');
              return Text('isWaiting: $isWaiting');
            },
          ),
        ),
      );

      // Expect a FlutterError with a helpful message
      expect(tester.takeException(), isA<FlutterError>().having(
        (e) => e.message,
        'message',
        contains('Superpowers widget not found'),
      ));
    });

    testWidgets(
        'without Superpowers, context.isFailed throws FlutterError',
        (WidgetTester tester) async {
      // Build a widget WITHOUT Superpowers - should throw FlutterError
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final isFailed = context.isFailed('testAction');
              return Text('isFailed: $isFailed');
            },
          ),
        ),
      );

      // Expect a FlutterError with a helpful message
      expect(tester.takeException(), isA<FlutterError>().having(
        (e) => e.message,
        'message',
        contains('Superpowers widget not found'),
      ));
    });

    testWidgets(
        'without Superpowers, context.getException throws FlutterError',
        (WidgetTester tester) async {
      // Build a widget WITHOUT Superpowers - should throw FlutterError
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final exception = context.getException('testAction');
              return Text('exception: $exception');
            },
          ),
        ),
      );

      // Expect a FlutterError with a helpful message
      expect(tester.takeException(), isA<FlutterError>().having(
        (e) => e.message,
        'message',
        contains('Superpowers widget not found'),
      ));
    });

    testWidgets('WITH Superpowers: widget rebuilds when isWaiting changes to true',
        (WidgetTester tester) async {
      final buildLog = <bool>[];
      Completer<void>? actionCompleter;

      // Build a widget WITH Superpowers
      await tester.pumpWidget(
        MaterialApp(
          home: Superpowers(
            child: Builder(
              builder: (context) {
                final isWaiting = context.isWaiting('testAction');
                buildLog.add(isWaiting);
                return Text('isWaiting: $isWaiting');
              },
            ),
          ),
        ),
      );

      // Initial build
      expect(buildLog, equals([false]));
      expect(find.text('isWaiting: false'), findsOneWidget);

      // Start an async mix action
      actionCompleter = Completer<void>();
      // ignore: unawaited_futures
      mix(
        key: 'testAction',
        () async {
          await actionCompleter!.future;
        },
      );

      // Pump to process the onStateChange stream event
      await tester.pump();

      // WITH Superpowers, widget should rebuild when isWaiting changes
      expect(buildLog, equals([false, true]),
          reason: 'Widget should rebuild when isWaiting changes to true');
      expect(find.text('isWaiting: true'), findsOneWidget);

      // Clean up
      actionCompleter.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('WITH Superpowers: widget rebuilds when isWaiting changes to false',
        (WidgetTester tester) async {
      final buildLog = <bool>[];
      late Completer<void> actionCompleter;
      late FutureOr<void> mixFuture;

      await tester.pumpWidget(
        MaterialApp(
          home: Superpowers(
            child: Builder(
              builder: (context) {
                final isWaiting = context.isWaiting('testAction');
                buildLog.add(isWaiting);
                return Text('isWaiting: $isWaiting');
              },
            ),
          ),
        ),
      );

      // Initial build
      expect(buildLog, equals([false]));

      // Start an async mix action
      actionCompleter = Completer<void>();
      mixFuture = mix(
        key: 'testAction',
        () async {
          await actionCompleter.future;
        },
      );

      // Wait for start notification to be processed
      await tester.pump();
      expect(buildLog, equals([false, true]));

      // Complete the action and wait for mix to finish
      actionCompleter.complete();
      await mixFuture;

      // Verify internally isWaiting is now false
      expect(Superpowers.isWaiting('testAction'), isFalse,
          reason: 'Superpowers.isWaiting should return false after mix completes');

      // Wait for completion notification to be processed
      await tester.pump();
      await tester.pump(); // Extra pump just in case

      // Widget should have rebuilt with isWaiting=false
      // This test may fail if Superpowers.onComplete doesn't properly notify
      expect(buildLog, equals([false, true, false]),
          reason: 'Widget should rebuild when isWaiting changes to false');
      expect(find.text('isWaiting: false'), findsOneWidget);
    });

    testWidgets('WITH Superpowers: full cycle false->true->false works',
        (WidgetTester tester) async {
      // This test verifies the complete isWaiting cycle with Superpowers.
      // It's more lenient about exact rebuild counts.
      late Completer<void> actionCompleter;
      late FutureOr<void> mixFuture;

      await tester.pumpWidget(
        MaterialApp(
          home: Superpowers(
            child: Builder(
              builder: (context) {
                final isWaiting = context.isWaiting('testAction');
                return Column(
                  children: [
                    Text('isWaiting: $isWaiting'),
                    if (isWaiting) const Text('LOADING'),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Initial state: not waiting
      expect(find.text('isWaiting: false'), findsOneWidget);
      expect(find.text('LOADING'), findsNothing);

      // Start action
      actionCompleter = Completer<void>();
      mixFuture = mix(
        key: 'testAction',
        () async {
          await actionCompleter.future;
        },
      );

      await tester.pump();

      // During action: should be waiting
      expect(find.text('isWaiting: true'), findsOneWidget,
          reason: 'Widget should show isWaiting=true while action runs');
      expect(find.text('LOADING'), findsOneWidget);

      // Complete action
      actionCompleter.complete();
      await mixFuture;
      await tester.pumpAndSettle();

      // After action: should not be waiting
      expect(find.text('isWaiting: false'), findsOneWidget,
          reason: 'Widget should show isWaiting=false after action completes');
      expect(find.text('LOADING'), findsNothing);
    });
  });
}
