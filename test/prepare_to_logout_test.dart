// Developed by Marcelo Glasberg (2026) https://glasberg.dev and https://github.com/marcglasberg
// For more info, see: https://pub.dartlang.org/packages/bloc_superpowers and http://blocsuperpowers.org
import 'dart:async';

import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    Superpowers.clear();
  });

  group('Superpowers.prepareToLogout', () {
    group('clears user-specific state', () {
      test('clears props', () async {
        Superpowers.setProp('userToken', 'abc123');
        Superpowers.setProp('userData', {'name': 'John'});

        expect(Superpowers.prop<String>('userToken'), equals('abc123'));

        await Superpowers.prepareToLogout(delay: Duration.zero);

        expect(() => Superpowers.prop<String>('userToken'), throwsA(anything));
      });

      test('clears error queue', () async {
        Superpowers.addUserException(UserException('Test error 1'));
        Superpowers.addUserException(UserException('Test error 2'));

        expect(Superpowers.errors.length, equals(2));

        await Superpowers.prepareToLogout(delay: Duration.zero);

        expect(Superpowers.errors.length, equals(0));
      });

      test('clears waiting state', () async {
        // Simulate a mix call in progress
        Superpowers.onStart('testKey');
        expect(Superpowers.isWaiting('testKey'), isTrue);

        await Superpowers.prepareToLogout(delay: Duration.zero);

        expect(Superpowers.isWaiting('testKey'), isFalse);
      });

      test('clears failed state', () async {
        // Simulate a failed mix call
        Superpowers.onStart('testKey');
        Superpowers.onComplete('testKey', UserException('Test failure'));

        expect(Superpowers.isFailed('testKey'), isTrue);
        expect(Superpowers.getException('testKey'), isNotNull);

        await Superpowers.prepareToLogout(delay: Duration.zero);

        expect(Superpowers.isFailed('testKey'), isFalse);
        expect(Superpowers.getException('testKey'), isNull);
      });
    });

    group('preserves app-level configuration', () {
      test('preserves globalCatchError', () async {
        void handler(Object error, StackTrace stack, Object key) {}
        Superpowers.globalCatchError = handler;

        await Superpowers.prepareToLogout(delay: Duration.zero);

        expect(Superpowers.globalCatchError, equals(handler));
      });

      test('preserves observer', () async {
        void obs(bool isStart, Object key, Object? metrics, Object? error,
            StackTrace? stackTrace, Duration? duration) {}
        Superpowers.observer = obs;

        await Superpowers.prepareToLogout(delay: Duration.zero);

        expect(Superpowers.observer, equals(obs));
      });
    });

    group('disposes resources automatically', () {
      test('cancels Timer props', () async {
        var timerFired = false;
        final timer = Timer(const Duration(milliseconds: 50), () {
          timerFired = true;
        });
        Superpowers.setProp('timer', timer);

        await Superpowers.prepareToLogout(delay: Duration.zero);

        // Wait to see if timer fires (it shouldn't because it was canceled)
        await Future.delayed(const Duration(milliseconds: 100));
        expect(timerFired, isFalse);
      });

      test('cancels StreamSubscription props', () async {
        final controller = StreamController<int>.broadcast();
        var receivedValue = 0;

        final subscription = controller.stream.listen((value) {
          receivedValue = value;
        });
        Superpowers.setProp('subscription', subscription);

        await Superpowers.prepareToLogout(delay: Duration.zero);

        // Try to emit a value (should not be received)
        controller.add(42);
        await Future.delayed(const Duration(milliseconds: 10));
        expect(receivedValue, equals(0));

        await controller.close();
      });

      test('closes Sink props', () async {
        final controller = StreamController<int>();
        Superpowers.setProp('sink', controller.sink);

        await Superpowers.prepareToLogout(delay: Duration.zero);

        // The sink should be closed
        expect(controller.isClosed, isTrue);
      });
    });

    group('delay parameter', () {
      test('with delay=Duration.zero, completes immediately', () async {
        final stopwatch = Stopwatch()..start();

        await Superpowers.prepareToLogout(delay: Duration.zero);

        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });

      test('with delay, waits approximately that duration', () async {
        final stopwatch = Stopwatch()..start();

        await Superpowers.prepareToLogout(
            delay: const Duration(milliseconds: 200));

        stopwatch.stop();
        // Should take at least 200ms (the delay)
        expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(180));
      });

      test('with delay, clears state twice to catch in-flight operations',
          () async {
        // Start a "long running" operation
        Superpowers.onStart('longRunning');

        // Start prepareToLogout with a delay
        final logoutFuture =
            Superpowers.prepareToLogout(delay: const Duration(milliseconds: 200));

        // After first cleanup, simulate operation completing and adding new state
        await Future.delayed(const Duration(milliseconds: 50));

        // This simulates an in-flight operation completing after first cleanup
        // In real code, mix() calls could still be completing
        Superpowers.setProp('lateArrival', 'data');
        Superpowers.onStart('anotherKey');

        // Wait for logout to complete
        await logoutFuture;

        // The second cleanup should have cleared the late arrivals
        expect(() => Superpowers.prop<String>('lateArrival'), throwsA(anything));
        expect(Superpowers.isWaiting('anotherKey'), isFalse);
      });
    });

    group('notifies UI', () {
      test('emits state change after cleanup with delay', () async {
        var notificationCount = 0;
        final subscription = Superpowers.onStateChange.listen((_) {
          notificationCount++;
        });

        await Superpowers.prepareToLogout(
            delay: const Duration(milliseconds: 100));

        // Give the stream time to deliver the event
        await Future.delayed(const Duration(milliseconds: 20));

        // Should have notified at least once
        expect(notificationCount, greaterThanOrEqualTo(1));

        await subscription.cancel();
      });
    });

    group('comparison with clear()', () {
      test('clear() resets globalCatchError, prepareToLogout() does not',
          () async {
        void handler(Object error, StackTrace stack, Object key) {}
        Superpowers.globalCatchError = handler;

        // prepareToLogout keeps it
        await Superpowers.prepareToLogout(delay: Duration.zero);
        expect(Superpowers.globalCatchError, equals(handler));

        // clear() resets it
        Superpowers.clear();
        expect(Superpowers.globalCatchError, isNull);
      });

      test('clear() resets observer, prepareToLogout() does not', () async {
        void obs(bool isStart, Object key, Object? metrics, Object? error,
            StackTrace? stackTrace, Duration? duration) {}
        Superpowers.observer = obs;

        // prepareToLogout keeps it
        await Superpowers.prepareToLogout(delay: Duration.zero);
        expect(Superpowers.observer, equals(obs));

        // clear() resets it
        Superpowers.clear();
        expect(Superpowers.observer, isNull);
      });

      test('both clear props equally', () async {
        // Test prepareToLogout
        Superpowers.setProp('key1', 'value1');
        await Superpowers.prepareToLogout(delay: Duration.zero);
        expect(() => Superpowers.prop<String>('key1'), throwsA(anything));

        // Test clear
        Superpowers.setProp('key2', 'value2');
        Superpowers.clear();
        expect(() => Superpowers.prop<String>('key2'), throwsA(anything));
      });

      test('both clear errors equally', () async {
        // Test prepareToLogout
        Superpowers.addUserException(UserException('Error 1'));
        await Superpowers.prepareToLogout(delay: Duration.zero);
        expect(Superpowers.errors.length, equals(0));

        // Test clear
        Superpowers.addUserException(UserException('Error 2'));
        Superpowers.clear();
        expect(Superpowers.errors.length, equals(0));
      });
    });

    group('real-world scenarios', () {
      test('logout flow with active timers and subscriptions', () async {
        // Simulate app state after login
        var refreshCount = 0;
        final refreshTimer = Timer.periodic(
          const Duration(milliseconds: 50),
          (_) => refreshCount++,
        );
        Superpowers.setProp('refreshTimer', refreshTimer);

        final messageController = StreamController<String>.broadcast();
        final messages = <String>[];
        final subscription = messageController.stream.listen(messages.add);
        Superpowers.setProp('messageSubscription', subscription);

        Superpowers.setProp('authToken', 'user123token');
        Superpowers.setProp('userProfile', {'id': 123, 'name': 'John'});

        // Let timer fire a few times
        await Future.delayed(const Duration(milliseconds: 120));
        expect(refreshCount, greaterThan(0));

        // User logs out
        await Superpowers.prepareToLogout(delay: Duration.zero);

        // Verify all cleanup happened
        final countBeforeWait = refreshCount;
        await Future.delayed(const Duration(milliseconds: 100));
        expect(refreshCount, equals(countBeforeWait)); // Timer stopped

        messageController.add('new message');
        await Future.delayed(const Duration(milliseconds: 10));
        expect(messages, isEmpty); // Subscription canceled

        await messageController.close();
      });

      test('multiple logouts in sequence', () async {
        for (var i = 0; i < 3; i++) {
          Superpowers.setProp('session', 'session$i');
          Superpowers.addUserException(UserException('Error $i'));
          Superpowers.onStart('action$i');

          await Superpowers.prepareToLogout(delay: Duration.zero);

          expect(Superpowers.errors.length, equals(0));
          expect(Superpowers.isWaiting('action$i'), isFalse);
        }
      });
    });
  });
}
