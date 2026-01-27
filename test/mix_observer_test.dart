// Developed by Marcelo Glasberg (2026) https://glasberg.dev and https://github.com/marcglasberg
// For more info, see: https://pub.dartlang.org/packages/bloc_superpowers and http://blocsuperpowers.org
import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    Superpowers.clear();
  });

  group('Superpowers.observer', () {
    group('basic functionality', () {
      test('is null by default', () {
        expect(Superpowers.observer, isNull);
      });

      test('can be set and retrieved', () {
        void observer(bool isStart, Object key, Object? metrics, Object? error,
            StackTrace? stackTrace, Duration? duration) {}
        Superpowers.observer = observer;
        expect(Superpowers.observer, equals(observer));
      });

      test('is cleared by Superpowers.clear()', () {
        Superpowers.observer =
            (isStart, key, metrics, error, stackTrace, duration) {};
        expect(Superpowers.observer, isNotNull);

        Superpowers.clear();
        expect(Superpowers.observer, isNull);
      });
    });

    group('called at start and end', () {
      test('is called at start of mix with isStart=true', () async {
        var startCalled = false;
        Object? receivedKey;

        Superpowers.observer =
            (isStart, key, metrics, error, stackTrace, duration) {
          if (isStart) {
            startCalled = true;
            receivedKey = key;
          }
        };

        await mix(
          key: 'testKey',
          () async {
            // Action
          },
        );

        expect(startCalled, isTrue);
        expect(receivedKey, equals('testKey'));
      });

      test('is called at end of mix with isStart=false', () async {
        var endCalled = false;
        Object? receivedKey;
        Duration? receivedDuration;

        Superpowers.observer =
            (isStart, key, metrics, error, stackTrace, duration) {
          if (!isStart) {
            endCalled = true;
            receivedKey = key;
            receivedDuration = duration;
          }
        };

        await mix(
          key: 'testKey',
          () async {
            await Future.delayed(const Duration(milliseconds: 10));
          },
        );

        expect(endCalled, isTrue);
        expect(receivedKey, equals('testKey'));
        expect(receivedDuration, isNotNull);
        expect(receivedDuration!.inMilliseconds, greaterThanOrEqualTo(10));
      });

      test('is called with both start and end in order', () async {
        final calls = <String>[];

        Superpowers.observer =
            (isStart, key, metrics, error, stackTrace, duration) {
          calls.add(isStart ? 'start' : 'end');
        };

        await mix(
          key: 'testKey',
          () async {},
        );

        expect(calls, equals(['start', 'end']));
      });
    });

    group('metrics parameter', () {
      test('receives metrics value from callback', () async {
        Object? startMetrics;
        Object? endMetrics;

        Superpowers.observer =
            (isStart, key, metrics, error, stackTrace, duration) {
          if (isStart) {
            startMetrics = metrics;
          } else {
            endMetrics = metrics;
          }
        };

        await mix(
          key: 'testKey',
          metrics: () => {'counter': 42},
          () async {},
        );

        expect(startMetrics, equals({'counter': 42}));
        expect(endMetrics, equals({'counter': 42}));
      });

      test('receives null when no metrics callback provided', () async {
        Object? startMetrics = 'not-null';
        Object? endMetrics = 'not-null';

        Superpowers.observer =
            (isStart, key, metrics, error, stackTrace, duration) {
          if (isStart) {
            startMetrics = metrics;
          } else {
            endMetrics = metrics;
          }
        };

        await mix(
          key: 'testKey',
          () async {},
        );

        expect(startMetrics, isNull);
        expect(endMetrics, isNull);
      });

      test('metrics callback error is captured and returned', () async {
        Object? receivedMetrics;

        Superpowers.observer =
            (isStart, key, metrics, error, stackTrace, duration) {
          if (isStart) {
            receivedMetrics = metrics;
          }
        };

        await mix(
          key: 'testKey',
          metrics: () => throw StateError('metrics error'),
          () async {},
        );

        expect(receivedMetrics, isA<StateError>());
        expect((receivedMetrics as StateError).message, equals('metrics error'));
      });

      test('metrics from MixConfig is used', () async {
        Object? receivedMetrics;

        Superpowers.observer =
            (isStart, key, metrics, error, stackTrace, duration) {
          if (isStart) {
            receivedMetrics = metrics;
          }
        };

        final config = MixConfig(
          metrics: () => 'config-metrics',
        );

        await mix(
          key: 'testKey',
          config: config,
          () async {},
        );

        expect(receivedMetrics, equals('config-metrics'));
      });

      test('explicit metrics overrides MixConfig.metrics', () async {
        Object? receivedMetrics;

        Superpowers.observer =
            (isStart, key, metrics, error, stackTrace, duration) {
          if (isStart) {
            receivedMetrics = metrics;
          }
        };

        final config = MixConfig(
          metrics: () => 'config-metrics',
        );

        await mix(
          key: 'testKey',
          config: config,
          metrics: () => 'explicit-metrics',
          () async {},
        );

        expect(receivedMetrics, equals('explicit-metrics'));
      });
    });

    group('error handling', () {
      test('receives error on failure', () async {
        Object? receivedError;
        StackTrace? receivedStack;

        Superpowers.observer =
            (isStart, key, metrics, error, stackTrace, duration) {
          if (!isStart) {
            receivedError = error;
            receivedStack = stackTrace;
          }
        };

        await mix(
          key: 'testKey',
          catchError: (error, stack) {
            // Suppress error
          },
          () async {
            throw StateError('test error');
          },
        );

        expect(receivedError, isA<StateError>());
        expect(receivedStack, isNotNull);
      });

      test('receives null error on success', () async {
        Object? receivedError = 'not-null';
        StackTrace? receivedStack = StackTrace.current;

        Superpowers.observer =
            (isStart, key, metrics, error, stackTrace, duration) {
          if (!isStart) {
            receivedError = error;
            receivedStack = stackTrace;
          }
        };

        await mix(
          key: 'testKey',
          () async {
            // Success
          },
        );

        expect(receivedError, isNull);
        expect(receivedStack, isNull);
      });

      test('observer errors do not propagate', () async {
        var actionCompleted = false;

        Superpowers.observer =
            (isStart, key, metrics, error, stackTrace, duration) {
          throw StateError('observer error');
        };

        await mix(
          key: 'testKey',
          () async {
            actionCompleted = true;
          },
        );

        expect(actionCompleted, isTrue);
      });
    });

    group('with sync mix', () {
      test('is called for sync mix', () {
        final calls = <String>[];

        Superpowers.observer =
            (isStart, key, metrics, error, stackTrace, duration) {
          calls.add(isStart ? 'start' : 'end');
        };

        mix(
          key: 'testKey',
          () {
            // Sync action
            return 42;
          },
        );

        expect(calls, equals(['start', 'end']));
      });

      test('receives duration for sync mix', () {
        Duration? receivedDuration;

        Superpowers.observer =
            (isStart, key, metrics, error, stackTrace, duration) {
          if (!isStart) {
            receivedDuration = duration;
          }
        };

        mix(
          key: 'testKey',
          () {
            // Fast sync action
            return 42;
          },
        );

        expect(receivedDuration, isNotNull);
        expect(receivedDuration!.inMicroseconds, greaterThanOrEqualTo(0));
      });
    });

    group('with retry', () {
      test('is called only once at start and once at end (after retries)', () async {
        var startCount = 0;
        var endCount = 0;

        Superpowers.observer =
            (isStart, key, metrics, error, stackTrace, duration) {
          if (isStart) {
            startCount++;
          } else {
            endCount++;
          }
        };

        var attemptCount = 0;
        await mix(
          key: 'testKey',
          retry: retry(maxRetries: 2, initialDelay: 1.millis),
          catchError: (error, stack) {
            // Suppress final error
          },
          () async {
            attemptCount++;
            throw Exception('always fails');
          },
        );

        expect(attemptCount, equals(3)); // 1 initial + 2 retries
        expect(startCount, equals(1)); // Observer called once at start
        expect(endCount, equals(1)); // Observer called once at end
      });
    });

    group('with mix.ctx', () {
      test('works with mix.ctx', () async {
        final calls = <String>[];
        Object? receivedKey;

        Superpowers.observer =
            (isStart, key, metrics, error, stackTrace, duration) {
          calls.add(isStart ? 'start' : 'end');
          receivedKey = key;
        };

        await mix.ctx(
          key: 'ctxTestKey',
          (ctx) async {
            // Action
          },
        );

        expect(calls, equals(['start', 'end']));
        expect(receivedKey, equals('ctxTestKey'));
      });

      test('receives metrics with mix.ctx', () async {
        Object? receivedMetrics;

        Superpowers.observer =
            (isStart, key, metrics, error, stackTrace, duration) {
          if (isStart) {
            receivedMetrics = metrics;
          }
        };

        await mix.ctx(
          key: 'testKey',
          metrics: () => 'ctx-metrics',
          (ctx) async {},
        );

        expect(receivedMetrics, equals('ctx-metrics'));
      });
    });

    group('multiple mix calls', () {
      test('tracks each call separately', () async {
        final events = <Map<String, dynamic>>[];

        Superpowers.observer =
            (isStart, key, metrics, error, stackTrace, duration) {
          events.add({
            'isStart': isStart,
            'key': key,
            'metrics': metrics,
          });
        };

        await mix(
          key: 'first',
          metrics: () => 1,
          () async {},
        );

        await mix(
          key: 'second',
          metrics: () => 2,
          () async {},
        );

        expect(events.length, equals(4));
        expect(events[0], equals({'isStart': true, 'key': 'first', 'metrics': 1}));
        expect(events[1], equals({'isStart': false, 'key': 'first', 'metrics': 1}));
        expect(events[2], equals({'isStart': true, 'key': 'second', 'metrics': 2}));
        expect(events[3], equals({'isStart': false, 'key': 'second', 'metrics': 2}));
      });
    });

    group('use case: performance metrics', () {
      test('can track execution times', () async {
        final metrics = <String, Duration>{};

        Superpowers.observer =
            (isStart, key, metricsValue, error, stackTrace, duration) {
          if (!isStart && duration != null) {
            metrics[key.toString()] = duration;
          }
        };

        await mix(
          key: 'operation1',
          () async {
            await Future.delayed(const Duration(milliseconds: 15));
          },
        );

        await mix(
          key: 'operation2',
          () async {
            await Future.delayed(const Duration(milliseconds: 25));
          },
        );

        expect(metrics['operation1']!.inMilliseconds, greaterThanOrEqualTo(15));
        expect(metrics['operation2']!.inMilliseconds, greaterThanOrEqualTo(25));
      });
    });

    group('use case: analytics logging', () {
      test('can log analytics with state snapshots', () async {
        final logs = <Map<String, dynamic>>[];

        Superpowers.observer =
            (isStart, key, metricsValue, error, stackTrace, duration) {
          logs.add({
            'event': isStart ? 'start' : 'end',
            'action': key,
            'state': metricsValue,
            'error': error?.toString(),
            'duration_ms': duration?.inMilliseconds,
          });
        };

        var counter = 0;

        await mix(
          key: 'incrementCounter',
          metrics: () => {'counter': counter},
          () async {
            counter++;
          },
        );

        expect(logs.length, equals(2));
        expect(logs[0]['event'], equals('start'));
        expect(logs[0]['state'], equals({'counter': 0}));
        expect(logs[1]['event'], equals('end'));
        expect(logs[1]['state'], equals({'counter': 1}));
        expect(logs[1]['error'], isNull);
        expect(logs[1]['duration_ms'], isNotNull);
      });
    });
  });
}
