// Developed by Marcelo Glasberg (2026) https://glasberg.dev and https://github.com/marcglasberg
// For more info, see: https://pub.dartlang.org/packages/bloc_superpowers and http://blocsuperpowers.org

import 'dart:async';

import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    Superpowers.clear(simulateInternet: () => true);
  });

  // ============================================================
  // MixConfig with RetryConfig
  // ============================================================

  group('MixConfig with RetryConfig', () {
    test('config.retry enables retry', () async {
      var callCount = 0;

      try {
        await mix(
          key: 'test',
          config: MixConfig(retry: RetryConfig(initialDelay: 1.millis)),
          () {
            callCount++;
            throw Exception('Test error');
          },
        );
      } catch (_) {}

      // Default maxRetries is 3, so 1 initial + 3 retries = 4 calls
      expect(callCount, 4);
    });

    test('config.retry values are used', () async {
      var callCount = 0;

      try {
        await mix(
          key: 'test',
          config: MixConfig(retry: RetryConfig(maxRetries: 5, initialDelay: 1.millis)),
          () {
            callCount++;
            throw Exception('Test error');
          },
        );
      } catch (_) {}

      expect(callCount, 6); // 1 initial + 5 retries
    });

    test('explicit retry overrides config.retry', () async {
      var callCount = 0;

      try {
        await mix(
          key: 'test',
          config: MixConfig(retry: RetryConfig(maxRetries: 10, initialDelay: 1.millis)),
          retry: RetryConfig(maxRetries: 2),
          () {
            callCount++;
            throw Exception('Test error');
          },
        );
      } catch (_) {}

      expect(callCount, 3); // 1 initial + 2 retries (explicit wins)
    });

    test('explicit retry inherits unspecified values from config.retry', () async {
      final delays = <Duration>[];

      try {
        await mix(
          key: 'test',
          config: MixConfig(
            retry: RetryConfig(
              maxRetries: 10,
              initialDelay: 50.millis,
              multiplier: 3.0,
            ),
          ),
          retry: RetryConfig(
            maxRetries: 2,
            onRetry: (attempt, delay, e, s) => delays.add(delay),
          ),
          () {
            throw Exception('Test error');
          },
        );
      } catch (_) {}

      expect(delays.length, 2);
      expect(delays[0], 50.millis); // From config
      expect(delays[1], 150.millis); // 50ms * 3.0 from config
    });

    test('defaults are applied when neither config nor explicit specify value', () async {
      final delays = <Duration>[];

      try {
        await mix(
          key: 'test',
          config: MixConfig(retry: RetryConfig(maxRetries: 2)),
          retry: RetryConfig(onRetry: (attempt, delay, e, s) => delays.add(delay)),
          () {
            throw Exception('Test error');
          },
        );
      } catch (_) {}

      expect(delays.length, 2);
      expect(delays[0], RetryConfig.defaults.initialDelay);
    });

    test('mix.ctx context reflects merged config', () async {
      MixContext? ctx;

      await mix.ctx(
        key: 'test',
        config: MixConfig(retry: RetryConfig(maxRetries: 7, multiplier: 4.0)),
        retry: RetryConfig(maxRetries: 3),
        (context) {
          ctx = context;
        },
      );

      expect(ctx!.retry, isNotNull);
      expect(ctx!.retry!.config.maxRetries, 3); // From explicit
      expect(ctx!.retry!.config.multiplier, 4.0); // From config
      expect(ctx!.retry!.config.initialDelay, RetryConfig.defaults.initialDelay); // From defaults
    });

    test('RetryConfig.merge works correctly', () {
      final base = RetryConfig(maxRetries: 3, initialDelay: 100.millis);
      final overlay = RetryConfig(maxRetries: 5, multiplier: 3.0);

      final merged = base.merge(overlay);

      expect(merged.maxRetries, 5);
      expect(merged.initialDelay, 100.millis);
      expect(merged.multiplier, 3.0);
    });

    test('RetryConfig.defaults setter validates required fields', () {
      expect(
        () => RetryConfig.defaults = RetryConfig(maxRetries: null),
        throwsArgumentError,
      );
    });
  });

  // ============================================================
  // MixConfig with CheckInternetConfig
  // ============================================================

  group('MixConfig with CheckInternetConfig', () {
    test('config.checkInternet enables internet check', () async {
      Superpowers.clear(simulateInternet: () => false);

      var actionRan = false;
      final result = await mix(
        key: 'test',
        config: const MixConfig(checkInternet: CheckInternetConfig()),
        () {
          actionRan = true;
          return 'success';
        },
      );

      expect(actionRan, false);
      expect(result, null);
    });

    test('config.checkInternet values are used', () async {
      Superpowers.clear(simulateInternet: () => false);

      var onNoInternetCalled = false;
      final result = await mix(
        key: 'test',
        config: MixConfig(
          checkInternet: CheckInternetConfig(
            abortSilently: true,
            onNoInternet: () => onNoInternetCalled = true,
          ),
        ),
        () => 'success',
      );

      expect(result, null);
      expect(onNoInternetCalled, true);
    });

    test('explicit checkInternet overrides config.checkInternet', () async {
      Superpowers.clear(simulateInternet: () => false);

      // Config says abortSilently: false (throw), explicit says true (silent)
      final result = await mix(
        key: 'test',
        config: const MixConfig(checkInternet: CheckInternetConfig(abortSilently: false)),
        checkInternet: checkInternet(abortSilently: true),
        () => 'success',
      );

      // Should use explicit: abortSilently=true, so returns null without throwing
      expect(result, null);
      expect(Superpowers.errors, isEmpty); // No error queued
    });

    test('explicit checkInternet inherits unspecified values from config', () async {
      Superpowers.clear(simulateInternet: () => false);

      var onNoInternetCalled = false;

      // Config specifies onNoInternet, explicit only specifies abortSilently
      await mix(
        key: 'test',
        config: MixConfig(
          checkInternet: CheckInternetConfig(
            abortSilently: false,
            onNoInternet: () => onNoInternetCalled = true,
          ),
        ),
        checkInternet: checkInternet(abortSilently: true), // Override to silent
        () => 'success',
      );

      // onNoInternet should still be called (inherited from config)
      expect(onNoInternetCalled, true);
    });

    test('defaults are applied when neither config nor explicit specify value', () async {
      Superpowers.clear(simulateInternet: () => false);

      // Config enables checkInternet but doesn't specify abortSilently
      // Default is abortSilently: false, so it should throw/queue error
      await mix(
        key: 'test',
        config: const MixConfig(checkInternet: CheckInternetConfig()),
        () => 'success',
      );

      // Default abortSilently is false, ifOpenDialog is true, so error should be queued
      expect(Superpowers.errors.length, 1);
      expect(Superpowers.errors.first, isA<ConnectionException>());
    });

    test('mix.ctx context reflects merged config', () async {
      MixContext? ctx;

      await mix.ctx(
        key: 'test',
        config: const MixConfig(
          checkInternet: CheckInternetConfig(
            abortSilently: true,
            maxRetryDelay: Duration(seconds: 10),
          ),
        ),
        checkInternet: checkInternet(ifOpenDialog: false),
        (context) {
          ctx = context;
        },
      );

      expect(ctx!.checkInternet, isNotNull);
      expect(ctx!.checkInternet!.config.abortSilently, true); // From config
      expect(ctx!.checkInternet!.config.ifOpenDialog, false); // From explicit
      expect(ctx!.checkInternet!.config.maxRetryDelay, const Duration(seconds: 10)); // From config
    });

    test('CheckInternetConfig.merge works correctly', () {
      final base = CheckInternetConfig(abortSilently: true, maxRetryDelay: 5.sec);
      final overlay = CheckInternetConfig(ifOpenDialog: false);

      final merged = base.merge(overlay);

      expect(merged.abortSilently, true); // From base
      expect(merged.ifOpenDialog, false); // From overlay
      expect(merged.maxRetryDelay, 5.sec); // From base
    });

    test('CheckInternetConfig.defaults setter validates required fields', () {
      expect(
        () => CheckInternetConfig.defaults = CheckInternetConfig(abortSilently: null),
        throwsArgumentError,
      );
    });
  });

  // ============================================================
  // MixConfig with NonReentrantConfig
  // ============================================================

  group('MixConfig with NonReentrantConfig', () {
    test('config.nonReentrant enables non-reentrant protection', () async {
      final completer = Completer<void>();
      var call1Started = false;
      var call2Started = false;

      final future1 = mix(
        key: 'test',
        config: const MixConfig(nonReentrant: NonReentrantConfig()),
        () async {
          call1Started = true;
          await completer.future;
        },
      );

      await Future.delayed(10.millis);

      final future2 = mix(
        key: 'test',
        config: const MixConfig(nonReentrant: NonReentrantConfig()),
        () async {
          call2Started = true;
        },
      );

      expect(call1Started, true);
      expect(call2Started, false); // Blocked by non-reentrant

      completer.complete();
      await future1;
      await future2;
    });

    test('config.nonReentrant values are used (custom key)', () async {
      final completer = Completer<void>();
      var call2Blocked = false;

      final future1 = mix(
        key: 'test1',
        config: const MixConfig(nonReentrant: NonReentrantConfig(key: 'shared')),
        () async {
          await completer.future;
        },
      );

      await Future.delayed(10.millis);

      final result = await mix(
        key: 'test2',
        config: MixConfig(
          nonReentrant: NonReentrantConfig(
            key: 'shared',
            onBlocked: (_) => call2Blocked = true,
          ),
        ),
        () async => 'success',
      );

      expect(call2Blocked, true);
      expect(result, null);

      completer.complete();
      await future1;
    });

    test('explicit nonReentrant overrides config.nonReentrant key', () async {
      final completer = Completer<void>();

      final future1 = mix(
        key: 'test1',
        config: const MixConfig(nonReentrant: NonReentrantConfig(key: 'key1')),
        () async {
          await completer.future;
        },
      );

      await Future.delayed(10.millis);

      // Explicit key is different, so should NOT be blocked
      var call2Started = false;
      final future2 = mix(
        key: 'test2',
        config: const MixConfig(nonReentrant: NonReentrantConfig(key: 'key1')),
        nonReentrant: nonReentrant(key: 'key2'), // Different key
        () async {
          call2Started = true;
        },
      );

      await Future.delayed(10.millis);
      expect(call2Started, true);

      completer.complete();
      await future1;
      await future2;
    });

    test('explicit nonReentrant inherits unspecified values from config', () async {
      final completer = Completer<void>();
      var onBlockedCalled = false;

      final future1 = mix(
        key: 'test',
        config: MixConfig(
          nonReentrant: NonReentrantConfig(
            onBlocked: (_) => onBlockedCalled = true,
          ),
        ),
        () async {
          await completer.future;
        },
      );

      await Future.delayed(10.millis);

      await mix(
        key: 'test',
        config: MixConfig(
          nonReentrant: NonReentrantConfig(
            onBlocked: (_) => onBlockedCalled = true,
          ),
        ),
        nonReentrant: nonReentrant(), // No override, just enable
        () async => 'success',
      );

      expect(onBlockedCalled, true); // Inherited from config

      completer.complete();
      await future1;
    });

    test('mix.ctx context reflects merged config', () async {
      MixContext? ctx;

      await mix.ctx(
        key: 'test',
        config: const MixConfig(nonReentrant: NonReentrantConfig(key: 'configKey')),
        nonReentrant: nonReentrant(), // Just enable, no key override
        (context) {
          ctx = context;
        },
      );

      expect(ctx!.nonReentrant, isNotNull);
      expect(ctx!.nonReentrant!.config.key, 'configKey');
    });

    test('NonReentrantConfig.merge works correctly', () {
      final base = NonReentrantConfig(key: 'baseKey');
      final overlay = NonReentrantConfig(onBlocked: (_) {});

      final merged = base.merge(overlay);

      expect(merged.key, 'baseKey');
      expect(merged.onBlocked, isNotNull);
    });
  });

  // ============================================================
  // MixConfig with ThrottleConfig
  // ============================================================

  group('MixConfig with ThrottleConfig', () {
    test('config.throttle enables throttling', () async {
      var callCount = 0;

      await mix(
        key: 'test',
        config: MixConfig(throttle: ThrottleConfig(duration: 100.millis)),
        () {
          callCount++;
        },
      );

      await mix(
        key: 'test',
        config: MixConfig(throttle: ThrottleConfig(duration: 100.millis)),
        () {
          callCount++;
        },
      );

      expect(callCount, 1); // Second call throttled
    });

    test('config.throttle values are used', () async {
      var callCount = 0;

      await mix(
        key: 'test',
        config: MixConfig(throttle: ThrottleConfig(duration: 50.millis)),
        () {
          callCount++;
        },
      );

      await Future.delayed(60.millis);

      await mix(
        key: 'test',
        config: MixConfig(throttle: ThrottleConfig(duration: 50.millis)),
        () {
          callCount++;
        },
      );

      expect(callCount, 2); // Second call runs after throttle expires
    });

    test('explicit throttle overrides config.throttle duration', () async {
      var callCount = 0;

      await mix(
        key: 'test',
        config: MixConfig(throttle: ThrottleConfig(duration: 500.millis)),
        throttle: throttle(duration: 10.millis), // Much shorter
        () {
          callCount++;
        },
      );

      await Future.delayed(20.millis);

      await mix(
        key: 'test',
        config: MixConfig(throttle: ThrottleConfig(duration: 500.millis)),
        throttle: throttle(duration: 10.millis),
        () {
          callCount++;
        },
      );

      expect(callCount, 2); // Both run due to short explicit duration
    });

    test('explicit throttle inherits unspecified values from config', () async {
      var onThrottledCalled = false;

      await mix(
        key: 'test',
        config: MixConfig(
          throttle: ThrottleConfig(
            duration: 100.millis,
            onThrottled: (_, __) => onThrottledCalled = true,
          ),
        ),
        () {},
      );

      await mix(
        key: 'test',
        config: MixConfig(
          throttle: ThrottleConfig(
            duration: 100.millis,
            onThrottled: (_, __) => onThrottledCalled = true,
          ),
        ),
        throttle: throttle(), // Just enable, inherits onThrottled
        () {},
      );

      expect(onThrottledCalled, true);
    });

    test('defaults are applied when neither config nor explicit specify value', () async {
      MixContext? ctx;

      await mix.ctx(
        key: 'test',
        config: const MixConfig(throttle: ThrottleConfig()),
        (context) {
          ctx = context;
        },
      );

      expect(ctx!.throttle!.config.duration, ThrottleConfig.defaults.duration);
      expect(ctx!.throttle!.config.removeLockOnError, ThrottleConfig.defaults.removeLockOnError);
      expect(ctx!.throttle!.config.ignoreThrottle, ThrottleConfig.defaults.ignoreThrottle);
    });

    test('mix.ctx context reflects merged config', () async {
      MixContext? ctx;

      await mix.ctx(
        key: 'test',
        config: MixConfig(
          throttle: ThrottleConfig(duration: 200.millis, removeLockOnError: true),
        ),
        throttle: throttle(ignoreThrottle: true),
        (context) {
          ctx = context;
        },
      );

      expect(ctx!.throttle, isNotNull);
      expect(ctx!.throttle!.config.duration, 200.millis); // From config
      expect(ctx!.throttle!.config.removeLockOnError, true); // From config
      expect(ctx!.throttle!.config.ignoreThrottle, true); // From explicit
    });

    test('ThrottleConfig.merge works correctly', () {
      final base = ThrottleConfig(duration: 100.millis, removeLockOnError: true);
      final overlay = ThrottleConfig(ignoreThrottle: true);

      final merged = base.merge(overlay);

      expect(merged.duration, 100.millis);
      expect(merged.removeLockOnError, true);
      expect(merged.ignoreThrottle, true);
    });

    test('ThrottleConfig.defaults setter validates required fields', () {
      expect(
        () => ThrottleConfig.defaults = ThrottleConfig(duration: null),
        throwsArgumentError,
      );
    });
  });

  // ============================================================
  // MixConfig with DebounceConfig
  // ============================================================

  group('MixConfig with DebounceConfig', () {
    test('config.debounce enables debouncing', () async {
      var callCount = 0;

      // First call - will be superseded
      final future1 = mix<void>(
        key: 'test',
        config: MixConfig(debounce: DebounceConfig(duration: 50.millis)),
        () async {
          callCount++;
        },
      );

      await Future.delayed(10.millis);

      // Second call - supersedes first
      final future2 = mix<void>(
        key: 'test',
        config: MixConfig(debounce: DebounceConfig(duration: 50.millis)),
        () async {
          callCount++;
        },
      );

      await future1;
      await future2;

      expect(callCount, 1); // Only second call ran
    });

    test('config.debounce values are used', () async {
      var callCount = 0;
      final stopwatch = Stopwatch()..start();

      await mix<void>(
        key: 'test',
        config: MixConfig(debounce: DebounceConfig(duration: 100.millis)),
        () async {
          callCount++;
        },
      );

      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(95));
      expect(callCount, 1);
    });

    test('explicit debounce overrides config.debounce duration', () async {
      final stopwatch = Stopwatch()..start();

      await mix<void>(
        key: 'test',
        config: MixConfig(debounce: DebounceConfig(duration: 500.millis)),
        debounce: debounce(duration: 20.millis), // Much shorter
        () async {},
      );

      expect(stopwatch.elapsedMilliseconds, lessThan(100)); // Uses explicit short duration
    });

    test('explicit debounce inherits unspecified values from config', () async {
      var onSupersededCalled = false;

      // First call
      final future1 = mix<void>(
        key: 'test',
        config: MixConfig(
          debounce: DebounceConfig(
            duration: 50.millis,
            onSuperseded: (_) => onSupersededCalled = true,
          ),
        ),
        () async {},
      );

      await Future.delayed(10.millis);

      // Second call supersedes first
      final future2 = mix<void>(
        key: 'test',
        config: MixConfig(
          debounce: DebounceConfig(
            duration: 50.millis,
            onSuperseded: (_) => onSupersededCalled = true,
          ),
        ),
        debounce: debounce(), // Just enable, inherits onSuperseded
        () async {},
      );

      await future1;
      await future2;

      expect(onSupersededCalled, true);
    });

    test('defaults are applied when neither config nor explicit specify value', () async {
      MixContext? ctx;

      await mix.ctx(
        key: 'test',
        config: const MixConfig(debounce: DebounceConfig()),
        (context) {
          ctx = context;
        },
      );

      expect(ctx!.debounce!.config.duration, DebounceConfig.defaults.duration);
    });

    test('mix.ctx context reflects merged config', () async {
      MixContext? ctx;

      await mix.ctx(
        key: 'test',
        config: MixConfig(debounce: DebounceConfig(duration: 200.millis)),
        debounce: debounce(key: 'customKey'),
        (context) {
          ctx = context;
        },
      );

      expect(ctx!.debounce, isNotNull);
      expect(ctx!.debounce!.config.duration, 200.millis); // From config
      expect(ctx!.debounce!.config.key, 'customKey'); // From explicit
    });

    test('DebounceConfig.merge works correctly', () {
      final base = DebounceConfig(duration: 100.millis);
      final overlay = DebounceConfig(key: 'myKey');

      final merged = base.merge(overlay);

      expect(merged.duration, 100.millis);
      expect(merged.key, 'myKey');
    });

    test('DebounceConfig.defaults setter validates required fields', () {
      expect(
        () => DebounceConfig.defaults = DebounceConfig(duration: null),
        throwsArgumentError,
      );
    });
  });

  // ============================================================
  // MixConfig with FreshConfig
  // ============================================================

  group('MixConfig with FreshConfig', () {
    test('config.fresh enables freshness checking', () async {
      var callCount = 0;

      await mix(
        key: 'test',
        config: MixConfig(fresh: FreshConfig(freshFor: 100.millis)),
        () {
          callCount++;
        },
      );

      await mix(
        key: 'test',
        config: MixConfig(fresh: FreshConfig(freshFor: 100.millis)),
        () {
          callCount++;
        },
      );

      expect(callCount, 1); // Second call skipped (still fresh)
    });

    test('config.fresh values are used', () async {
      var callCount = 0;

      await mix(
        key: 'test',
        config: MixConfig(fresh: FreshConfig(freshFor: 30.millis)),
        () {
          callCount++;
        },
      );

      await Future.delayed(40.millis);

      await mix(
        key: 'test',
        config: MixConfig(fresh: FreshConfig(freshFor: 30.millis)),
        () {
          callCount++;
        },
      );

      expect(callCount, 2); // Second runs after freshness expires
    });

    test('explicit fresh overrides config.fresh freshFor', () async {
      var callCount = 0;

      await mix(
        key: 'test',
        config: MixConfig(fresh: FreshConfig(freshFor: 500.millis)),
        fresh: fresh(freshFor: 10.millis), // Much shorter
        () {
          callCount++;
        },
      );

      await Future.delayed(20.millis);

      await mix(
        key: 'test',
        config: MixConfig(fresh: FreshConfig(freshFor: 500.millis)),
        fresh: fresh(freshFor: 10.millis),
        () {
          callCount++;
        },
      );

      expect(callCount, 2); // Both run due to short explicit freshFor
    });

    test('explicit fresh inherits unspecified values from config', () async {
      var onFreshCalled = false;

      await mix(
        key: 'test',
        config: MixConfig(
          fresh: FreshConfig(
            freshFor: 100.millis,
            onFresh: (_, __) => onFreshCalled = true,
          ),
        ),
        () {},
      );

      await mix(
        key: 'test',
        config: MixConfig(
          fresh: FreshConfig(
            freshFor: 100.millis,
            onFresh: (_, __) => onFreshCalled = true,
          ),
        ),
        fresh: fresh(), // Just enable, inherits onFresh
        () {},
      );

      expect(onFreshCalled, true);
    });

    test('defaults are applied when neither config nor explicit specify value', () async {
      MixContext? ctx;

      await mix.ctx(
        key: 'test',
        config: const MixConfig(fresh: FreshConfig()),
        (context) {
          ctx = context;
        },
      );

      expect(ctx!.fresh!.config.freshFor, FreshConfig.defaults.freshFor);
      expect(ctx!.fresh!.config.ignoreFresh, FreshConfig.defaults.ignoreFresh);
    });

    test('mix.ctx context reflects merged config', () async {
      MixContext? ctx;

      await mix.ctx(
        key: 'test',
        config: MixConfig(fresh: FreshConfig(freshFor: 200.millis)),
        fresh: fresh(ignoreFresh: true),
        (context) {
          ctx = context;
        },
      );

      expect(ctx!.fresh, isNotNull);
      expect(ctx!.fresh!.config.freshFor, 200.millis); // From config
      expect(ctx!.fresh!.config.ignoreFresh, true); // From explicit
    });

    test('FreshConfig.merge works correctly', () {
      final base = FreshConfig(freshFor: 100.millis, ignoreFresh: true);
      final overlay = FreshConfig(key: 'myKey');

      final merged = base.merge(overlay);

      expect(merged.freshFor, 100.millis);
      expect(merged.ignoreFresh, true);
      expect(merged.key, 'myKey');
    });

    test('FreshConfig.defaults setter validates required fields', () {
      expect(
        () => FreshConfig.defaults = FreshConfig(freshFor: null),
        throwsArgumentError,
      );
    });
  });

  // ============================================================
  // MixConfig with SequentialConfig
  // ============================================================

  group('MixConfig with SequentialConfig', () {
    test('config.sequential enables sequential execution', () async {
      final tracker = <int>[];
      final completer = Completer<void>();

      // First call
      final future1 = mix(
        key: 'test',
        config: const MixConfig(sequential: SequentialConfig()),
        () async {
          tracker.add(1);
          await completer.future;
          tracker.add(2);
        },
      );

      await Future.delayed(10.millis);

      // Second call - should wait for first
      final future2 = mix(
        key: 'test',
        config: const MixConfig(sequential: SequentialConfig()),
        () async {
          tracker.add(3);
        },
      );

      await Future.delayed(10.millis);
      expect(tracker, [1]); // Only first started

      completer.complete();
      await future1;
      await future2;

      expect(tracker, [1, 2, 3]); // Sequential execution
    });

    test('config.sequential values are used (maxQueueSize)', () async {
      final completer = Completer<void>();
      var droppedCount = 0;

      // First call - runs immediately
      final future1 = mix<void>(
        key: 'test',
        config: MixConfig(
          sequential: SequentialConfig(
            maxQueueSize: 1,
            onDropped: (_, __) => droppedCount++,
          ),
        ),
        () async {
          await completer.future;
        },
      );

      await Future.delayed(10.millis);

      // Second call - queued (1 in queue)
      final future2 = mix<void>(
        key: 'test',
        config: MixConfig(
          sequential: SequentialConfig(
            maxQueueSize: 1,
            onDropped: (_, __) => droppedCount++,
          ),
        ),
        () async {},
      );

      await Future.delayed(10.millis);

      // Third call - dropped (queue full)
      final future3 = mix<void>(
        key: 'test',
        config: MixConfig(
          sequential: SequentialConfig(
            maxQueueSize: 1,
            onDropped: (_, __) => droppedCount++,
          ),
        ),
        () async {},
      );

      expect(droppedCount, 1);

      completer.complete();
      await future1;
      await future2;
      await future3;
    });

    test('explicit sequential overrides config.sequential', () async {
      final completer = Completer<void>();
      var droppedCount = 0;
      var queuedCount = 0;

      final future1 = mix<void>(
        key: 'test',
        config: const MixConfig(sequential: SequentialConfig(maxQueueSize: 1)),
        sequential: sequential(maxQueueSize: 10), // Override to larger queue
        () async {
          await completer.future;
        },
      );

      await Future.delayed(10.millis);

      // These should all queue (large queue size)
      for (var i = 0; i < 5; i++) {
        mix<void>(
          key: 'test',
          config: const MixConfig(sequential: SequentialConfig(maxQueueSize: 1)),
          sequential: SequentialConfig(
            maxQueueSize: 10,
            onDropped: (_, __) => droppedCount++,
            onQueued: (_, __) => queuedCount++,
          ),
          () async {},
        );
      }

      await Future.delayed(10.millis);
      expect(droppedCount, 0); // None dropped due to explicit large queue
      expect(queuedCount, 5); // All 5 were queued

      completer.complete();
      await future1;
      await Future.delayed(50.millis); // Let queued calls complete
    });

    test('explicit sequential inherits unspecified values from config', () async {
      final completer = Completer<void>();
      var onQueuedCalled = false;

      final future1 = mix<void>(
        key: 'test',
        config: MixConfig(
          sequential: SequentialConfig(
            onQueued: (_, __) => onQueuedCalled = true,
          ),
        ),
        () async {
          await completer.future;
        },
      );

      await Future.delayed(10.millis);

      final future2 = mix<void>(
        key: 'test',
        config: MixConfig(
          sequential: SequentialConfig(
            onQueued: (_, __) => onQueuedCalled = true,
          ),
        ),
        sequential: sequential(), // Just enable, inherits onQueued
        () async {},
      );

      await Future.delayed(10.millis);
      expect(onQueuedCalled, true);

      completer.complete();
      await future1;
      await future2;
    });

    test('defaults are applied when neither config nor explicit specify value', () async {
      MixContext? ctx;
      final completer = Completer<void>();

      final future1 = mix.ctx(
        key: 'test',
        config: const MixConfig(sequential: SequentialConfig()),
        (context) async {
          ctx = context;
          await completer.future;
        },
      );

      await Future.delayed(10.millis);
      completer.complete();
      await future1;

      expect(ctx!.sequential!.config.dropOldest, SequentialConfig.defaults.dropOldest);
    });

    test('mix.ctx context reflects merged config', () async {
      MixContext? ctx;
      final completer = Completer<void>();

      final future1 = mix.ctx(
        key: 'test',
        config: const MixConfig(sequential: SequentialConfig(maxQueueSize: 5)),
        sequential: sequential(dropOldest: true),
        (context) async {
          ctx = context;
          await completer.future;
        },
      );

      await Future.delayed(10.millis);
      completer.complete();
      await future1;

      expect(ctx!.sequential, isNotNull);
      expect(ctx!.sequential!.config.maxQueueSize, 5); // From config
      expect(ctx!.sequential!.config.dropOldest, true); // From explicit
    });

    test('SequentialConfig.merge works correctly', () {
      final base = SequentialConfig(maxQueueSize: 5, dropOldest: true);
      final overlay = SequentialConfig(queueTimeout: 10.sec);

      final merged = base.merge(overlay);

      expect(merged.maxQueueSize, 5);
      expect(merged.dropOldest, true);
      expect(merged.queueTimeout, 10.sec);
    });

    test('SequentialConfig.defaults setter validates required fields', () {
      expect(
        () => SequentialConfig.defaults = SequentialConfig(dropOldest: null),
        throwsArgumentError,
      );
    });
  });

  // ============================================================
  // MixConfig with multiple configs
  // ============================================================

  group('MixConfig with multiple configs', () {
    test('multiple configs can be combined', () async {
      MixContext? ctx;

      await mix.ctx(
        key: 'test',
        config: MixConfig(
          retry: RetryConfig(maxRetries: 5),
          throttle: ThrottleConfig(duration: 100.millis),
          fresh: FreshConfig(freshFor: 200.millis),
        ),
        (context) {
          ctx = context;
        },
      );

      expect(ctx!.retry, isNotNull);
      expect(ctx!.retry!.config.maxRetries, 5);
      expect(ctx!.throttle, isNotNull);
      expect(ctx!.throttle!.config.duration, 100.millis);
      expect(ctx!.fresh, isNotNull);
      expect(ctx!.fresh!.config.freshFor, 200.millis);
    });

    test('explicit params override corresponding config values', () async {
      MixContext? ctx;

      await mix.ctx(
        key: 'test',
        config: MixConfig(
          retry: RetryConfig(maxRetries: 10),
          throttle: ThrottleConfig(duration: 500.millis),
        ),
        retry: RetryConfig(maxRetries: 2),
        throttle: throttle(duration: 50.millis),
        (context) {
          ctx = context;
        },
      );

      expect(ctx!.retry!.config.maxRetries, 2); // From explicit
      expect(ctx!.throttle!.config.duration, 50.millis); // From explicit
    });

    test('MixConfig.merge combines all config types', () {
      final base = MixConfig(
        retry: RetryConfig(maxRetries: 3),
        throttle: ThrottleConfig(duration: 100.millis),
      );

      final overlay = MixConfig(
        retry: RetryConfig(multiplier: 5.0),
        debounce: DebounceConfig(duration: 200.millis),
      );

      final merged = base.merge(overlay);

      expect(merged.retry!.maxRetries, 3); // From base
      expect(merged.retry!.multiplier, 5.0); // From overlay
      expect(merged.throttle!.duration, 100.millis); // From base only
      expect(merged.debounce!.duration, 200.millis); // From overlay only
    });

    test('comprehensive config scenario', () async {
      Superpowers.clear(simulateInternet: () => true);

      const appConfig = MixConfig(
        retry: RetryConfig(maxRetries: 3, initialDelay: Duration(milliseconds: 10)),
        checkInternet: CheckInternetConfig(abortSilently: true),
        throttle: ThrottleConfig(duration: Duration(milliseconds: 100)),
      );

      var callCount = 0;
      MixContext? ctx;

      // First call - runs
      await mix.ctx(
        key: 'test',
        config: appConfig,
        (context) {
          ctx = context;
          callCount++;
        },
      );

      expect(callCount, 1);
      expect(ctx!.retry!.config.maxRetries, 3);
      expect(ctx!.checkInternet!.config.abortSilently, true);
      expect(ctx!.throttle!.config.duration, 100.millis);

      // Second call - throttled
      await mix.ctx(
        key: 'test',
        config: appConfig,
        (context) {
          callCount++;
        },
      );

      expect(callCount, 1); // Still 1, second was throttled
    });
  });

  // ============================================================
  // MixConfig with callback fields (before, after, wrapRun, catchError)
  // ============================================================

  group('MixConfig with before callback', () {
    test('config.before is called', () async {
      var beforeCalled = false;

      await mix(
        key: 'test',
        config: MixConfig(before: () => beforeCalled = true),
        () {},
      );

      expect(beforeCalled, true);
    });

    test('config.before works with retry', () async {
      var beforeCallCount = 0;
      var actionCallCount = 0;

      try {
        await mix(
          key: 'test',
          config: MixConfig(
            before: () => beforeCallCount++,
            retry: RetryConfig(maxRetries: 2, initialDelay: 1.millis),
          ),
          () {
            actionCallCount++;
            throw Exception('fail');
          },
        );
      } catch (_) {}

      expect(beforeCallCount, 1); // Called only once, not per retry
      expect(actionCallCount, 3); // 1 + 2 retries
    });

    test('config.before works with mix.ctx', () async {
      var beforeCalled = false;

      await mix.ctx(
        key: 'test',
        config: MixConfig(before: () => beforeCalled = true),
        (ctx) {},
      );

      expect(beforeCalled, true);
    });
  });

  group('MixConfig with after callback', () {
    test('config.after is called on success', () async {
      var afterCalled = false;

      await mix(
        key: 'test',
        config: MixConfig(after: () => afterCalled = true),
        () {},
      );

      expect(afterCalled, true);
    });

    test('config.after is called on failure', () async {
      var afterCalled = false;

      await mix(
        key: 'test',
        config: MixConfig(
          after: () => afterCalled = true,
          catchError: (e, s) {}, // Suppress error (return normally)
        ),
        () => throw Exception('fail'),
      );

      expect(afterCalled, true);
    });

    test('config.after works with retry', () async {
      var afterCallCount = 0;

      try {
        await mix(
          key: 'test',
          config: MixConfig(
            after: () => afterCallCount++,
            retry: RetryConfig(maxRetries: 2, initialDelay: 1.millis),
          ),
          () => throw Exception('fail'),
        );
      } catch (_) {}

      expect(afterCallCount, 1); // Called only once, after all retries
    });
  });

  group('MixConfig with wrapRun callback', () {
    test('config.wrapRun is called', () async {
      var wrapRunCalled = false;

      await mix(
        key: 'test',
        config: MixConfig(
          wrapRun: (action) {
            wrapRunCalled = true;
            return action();
          },
        ),
        () => 'result',
      );

      expect(wrapRunCalled, true);
    });

    test('config.wrapRun receives and returns action result', () async {
      final result = await mix(
        key: 'test',
        config: MixConfig(
          wrapRun: (action) {
            final result = action();
            return result;
          },
        ),
        () => 42,
      );

      expect(result, 42);
    });

    test('config.wrapRun is called on each retry', () async {
      var wrapRunCallCount = 0;

      try {
        await mix(
          key: 'test',
          config: MixConfig(
            wrapRun: (action) {
              wrapRunCallCount++;
              return action();
            },
            retry: RetryConfig(maxRetries: 2, initialDelay: 1.millis),
          ),
          () => throw Exception('fail'),
        );
      } catch (_) {}

      expect(wrapRunCallCount, 3); // Called on each attempt
    });

    test('config.wrapRun can modify action result', () async {
      final result = await mix(
        key: 'test',
        config: MixConfig(
          wrapRun: (action) async {
            final result = await action();
            return (result as int) * 2;
          },
        ),
        () => 21,
      );

      expect(result, 42);
    });
  });

  group('MixConfig with catchError callback', () {
    test('config.catchError is called on error', () async {
      var catchErrorCalled = false;

      await mix(
        key: 'test',
        config: MixConfig(
          catchError: (e, s) {
            catchErrorCalled = true;
            // Return normally to suppress error
          },
        ),
        () => throw Exception('test'),
      );

      expect(catchErrorCalled, true);
    });

    test('config.catchError can transform error', () async {
      await mix(
        key: 'test',
        config: MixConfig(
          catchError: (e, s) => throw UserException('Wrapped: $e'),
        ),
        () => throw Exception('original'),
      );

      expect(Superpowers.errors.length, 1);
      expect(Superpowers.errors.first, isA<UserException>());
      expect((Superpowers.errors.first as UserException).message, contains('Wrapped'));
    });

    test('config.catchError can suppress error', () async {
      final result = await mix(
        key: 'test',
        config: MixConfig(
          catchError: (e, s) {
            // Return normally to suppress error
          },
        ),
        () => throw Exception('test'),
      );

      expect(result, null);
      expect(Superpowers.errors, isEmpty);
    });

    test('explicit catchError overrides config.catchError', () async {
      var configCatchErrorCalled = false;
      var explicitCatchErrorCalled = false;

      await mix(
        key: 'test',
        config: MixConfig(
          catchError: (e, s) {
            configCatchErrorCalled = true;
            // Return normally to suppress
          },
        ),
        catchError: (e, s) {
          explicitCatchErrorCalled = true;
          // Return normally to suppress
        },
        () => throw Exception('test'),
      );

      expect(configCatchErrorCalled, false);
      expect(explicitCatchErrorCalled, true);
    });

    test('config.catchError is called after all retries', () async {
      var catchErrorCallCount = 0;

      await mix(
        key: 'test',
        config: MixConfig(
          catchError: (e, s) {
            catchErrorCallCount++;
            // Return normally to suppress
          },
          retry: RetryConfig(maxRetries: 2, initialDelay: 1.millis),
        ),
        () => throw Exception('fail'),
      );

      expect(catchErrorCallCount, 1); // Called only once, after all retries
    });
  });

  group('MixConfig with multiple callbacks', () {
    test('all callbacks work together', () async {
      final callOrder = <String>[];

      await mix(
        key: 'test',
        config: MixConfig(
          before: () => callOrder.add('before'),
          after: () => callOrder.add('after'),
          wrapRun: (action) {
            callOrder.add('wrapRun-start');
            final result = action();
            callOrder.add('wrapRun-end');
            return result;
          },
        ),
        () {
          callOrder.add('action');
        },
      );

      expect(callOrder, ['before', 'wrapRun-start', 'action', 'wrapRun-end', 'after']);
    });

    test('callbacks work with error handling', () async {
      final callOrder = <String>[];

      await mix(
        key: 'test',
        config: MixConfig(
          before: () => callOrder.add('before'),
          after: () => callOrder.add('after'),
          wrapRun: (action) {
            callOrder.add('wrapRun');
            return action();
          },
          catchError: (e, s) {
            callOrder.add('catchError');
            // Return normally to suppress
          },
        ),
        () {
          callOrder.add('action');
          throw Exception('fail');
        },
      );

      expect(callOrder, ['before', 'wrapRun', 'action', 'catchError', 'after']);
    });

    test('MixConfig.merge combines callback fields', () {
      var base1Called = false;
      var overlay1Called = false;

      final base = MixConfig(
        before: () => base1Called = true,
        after: () {},
      );

      final overlay = MixConfig(
        before: () => overlay1Called = true,
        catchError: (e, s) {},
      );

      final merged = base.merge(overlay);

      // Callbacks are not merged, they're replaced
      expect(merged.before, isNotNull);
      expect(merged.after, isNotNull); // From base
      expect(merged.catchError, isNotNull); // From overlay
      expect(merged.wrapRun, isNull);
    });

    test('comprehensive config with callbacks and features', () async {
      var beforeCalled = false;
      var afterCalled = false;
      var wrapRunCallCount = 0;
      var actionCallCount = 0;

      await mix(
        key: 'test',
        config: MixConfig(
          before: () => beforeCalled = true,
          after: () => afterCalled = true,
          wrapRun: (action) {
            wrapRunCallCount++;
            return action();
          },
          catchError: (e, s) {}, // Suppress (return normally)
          retry: RetryConfig(maxRetries: 2, initialDelay: 1.millis),
          throttle: ThrottleConfig(duration: 100.millis),
        ),
        () {
          actionCallCount++;
          if (actionCallCount < 3) throw Exception('fail');
        },
      );

      expect(beforeCalled, true);
      expect(afterCalled, true);
      expect(wrapRunCallCount, 3); // Called on each retry attempt
      expect(actionCallCount, 3);
    });
  });

  // ============================================================
  // Resolution order tests
  // ============================================================

  group('Resolution order (defaults -> config -> explicit)', () {
    test('resolution order: defaults win when nothing else specified', () async {
      MixContext? ctx;

      await mix.ctx(
        key: 'test',
        config: const MixConfig(retry: RetryConfig()),
        (context) {
          ctx = context;
        },
      );

      expect(ctx!.retry!.config.maxRetries, RetryConfig.defaults.maxRetries);
      expect(ctx!.retry!.config.initialDelay, RetryConfig.defaults.initialDelay);
      expect(ctx!.retry!.config.multiplier, RetryConfig.defaults.multiplier);
      expect(ctx!.retry!.config.maxDelay, RetryConfig.defaults.maxDelay);
    });

    test('resolution order: config wins over defaults', () async {
      MixContext? ctx;

      await mix.ctx(
        key: 'test',
        config: MixConfig(
          retry: RetryConfig(
            maxRetries: 10,
            initialDelay: 999.millis,
          ),
        ),
        (context) {
          ctx = context;
        },
      );

      expect(ctx!.retry!.config.maxRetries, 10); // From config
      expect(ctx!.retry!.config.initialDelay, 999.millis); // From config
      expect(ctx!.retry!.config.multiplier, RetryConfig.defaults.multiplier); // From defaults
    });

    test('resolution order: explicit wins over config and defaults', () async {
      MixContext? ctx;

      await mix.ctx(
        key: 'test',
        config: MixConfig(
          retry: RetryConfig(
            maxRetries: 10,
            initialDelay: 999.millis,
            multiplier: 5.0,
          ),
        ),
        retry: RetryConfig(
          maxRetries: 1,
          // initialDelay not specified - should come from config
          // multiplier not specified - should come from config
        ),
        (context) {
          ctx = context;
        },
      );

      expect(ctx!.retry!.config.maxRetries, 1); // From explicit
      expect(ctx!.retry!.config.initialDelay, 999.millis); // From config
      expect(ctx!.retry!.config.multiplier, 5.0); // From config
    });
  });
}
