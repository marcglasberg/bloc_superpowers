// Developed by Marcelo Glasberg (2026) https://glasberg.dev and https://github.com/marcglasberg
// For more info, see: https://pub.dartlang.org/packages/bloc_superpowers and http://blocsuperpowers.org

import 'dart:async';

import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:bloc_superpowers/src/mix_preset.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    Superpowers.clear(simulateInternet: () => true);
  });

  // ============================================================
  // Basic call() functionality
  // ============================================================

  group('Basic call() functionality', () {
    test('MixPreset can be called like a function', () async {
      const preset = MixPreset();
      var called = false;

      await preset(
        key: 'test',
        () {
          called = true;
        },
      );

      expect(called, true);
    });

    test('MixPreset returns the action result', () async {
      const preset = MixPreset();

      final result = await preset(
        key: 'test',
        () => 42,
      );

      expect(result, 42);
    });

    test('MixPreset works with async actions', () async {
      const preset = MixPreset();

      final result = await preset(
        key: 'test',
        () async {
          await Future.delayed(10.millis);
          return 'async result';
        },
      );

      expect(result, 'async result');
    });

    test('MixPreset returns null when action is aborted', () async {
      final preset = MixPreset(
        checkInternet: checkInternet(abortSilently: true),
      );

      Superpowers.clear(simulateInternet: () => false);

      final result = await preset(
        key: 'test',
        () => 'should not run',
      );

      expect(result, null);
    });
  });

  // ============================================================
  // Key parameter handling
  // ============================================================

  group('Key parameter handling', () {
    test('key is required if not preset', () async {
      const preset = MixPreset();

      expect(
        () => preset(() => 'test'),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('key is required'),
        )),
      );
    });

    test('preset key is used when no explicit key provided', () async {
      final preset = MixPreset(key: 'presetKey');
      Object? usedKey;

      // We'll use nonReentrant to verify the key
      final completer = Completer<void>();

      final future1 = preset(
        nonReentrant: NonReentrantConfig(
          onBlocked: (k) => usedKey = k,
        ),
        () async {
          await completer.future;
        },
      );

      await Future.delayed(10.millis);

      // Second call should be blocked with presetKey
      await preset(
        nonReentrant: NonReentrantConfig(
          onBlocked: (k) => usedKey = k,
        ),
        () async {},
      );

      expect(usedKey, 'presetKey');

      completer.complete();
      await future1;
    });

    test('explicit key overrides preset key', () async {
      final preset = MixPreset(key: 'presetKey');
      Object? usedKey;

      final completer = Completer<void>();

      final future1 = preset(
        key: 'explicitKey',
        nonReentrant: NonReentrantConfig(
          onBlocked: (k) => usedKey = k,
        ),
        () async {
          await completer.future;
        },
      );

      await Future.delayed(10.millis);

      // Second call with same explicit key should be blocked
      await preset(
        key: 'explicitKey',
        nonReentrant: NonReentrantConfig(
          onBlocked: (k) => usedKey = k,
        ),
        () async {},
      );

      expect(usedKey, 'explicitKey');

      completer.complete();
      await future1;
    });
  });

  // ============================================================
  // Preset values are used
  // ============================================================

  group('Preset values are used', () {
    test('preset retry config is used', () async {
      var callCount = 0;

      final preset = MixPreset(
        retry: RetryConfig(maxRetries: 2, initialDelay: 1.millis),
      );

      try {
        await preset(
          key: 'test',
          () {
            callCount++;
            throw Exception('Test error');
          },
        );
      } catch (_) {}

      // 1 initial + 2 retries = 3 calls
      expect(callCount, 3);
    });

    test('preset checkInternet config is used', () async {
      Superpowers.clear(simulateInternet: () => false);

      var onNoInternetCalled = false;
      final preset = MixPreset(
        checkInternet: CheckInternetConfig(
          abortSilently: true,
          onNoInternet: () => onNoInternetCalled = true,
        ),
      );

      final result = await preset(
        key: 'test',
        () => 'success',
      );

      expect(result, null);
      expect(onNoInternetCalled, true);
    });

    test('preset nonReentrant config is used', () async {
      final completer = Completer<void>();
      var call2Blocked = false;

      final preset = MixPreset(
        nonReentrant: NonReentrantConfig(
          onBlocked: (_) => call2Blocked = true,
        ),
      );

      final future1 = preset(
        key: 'test',
        () async {
          await completer.future;
        },
      );

      await Future.delayed(10.millis);

      await preset(
        key: 'test',
        () async {},
      );

      expect(call2Blocked, true);

      completer.complete();
      await future1;
    });

    test('preset throttle config is used', () async {
      var callCount = 0;

      final preset = MixPreset(
        throttle: ThrottleConfig(duration: 100.millis),
      );

      await preset(key: 'test', () => callCount++);
      await preset(key: 'test', () => callCount++);

      expect(callCount, 1); // Second call throttled
    });

    test('preset debounce config is used', () async {
      var callCount = 0;

      final preset = MixPreset(
        debounce: DebounceConfig(duration: 50.millis),
      );

      final future1 = preset(key: 'test', () => callCount++);
      await Future.delayed(10.millis);
      final future2 = preset(key: 'test', () => callCount++);

      await future1;
      await future2;

      expect(callCount, 1); // First call superseded
    });

    test('preset fresh config is used', () async {
      var callCount = 0;

      final preset = MixPreset(
        fresh: FreshConfig(freshFor: 100.millis),
      );

      await preset(key: 'test', () => callCount++);
      await preset(key: 'test', () => callCount++);

      expect(callCount, 1); // Second call skipped (still fresh)
    });

    test('preset sequential config is used', () async {
      final tracker = <int>[];
      final completer = Completer<void>();

      final preset = MixPreset(
        sequential: const SequentialConfig(),
      );

      final future1 = preset(
        key: 'test',
        () async {
          tracker.add(1);
          await completer.future;
          tracker.add(2);
        },
      );

      await Future.delayed(10.millis);

      final future2 = preset(
        key: 'test',
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

    test('preset before callback is used', () async {
      var beforeCalled = false;

      final preset = MixPreset(
        before: () => beforeCalled = true,
      );

      await preset(key: 'test', () {});

      expect(beforeCalled, true);
    });

    test('preset after callback is used', () async {
      var afterCalled = false;

      final preset = MixPreset(
        after: () => afterCalled = true,
      );

      await preset(key: 'test', () {});

      expect(afterCalled, true);
    });

    test('preset wrapRun callback is used', () async {
      var wrapRunCalled = false;

      final preset = MixPreset(
        wrapRun: (action) {
          wrapRunCalled = true;
          return action();
        },
      );

      await preset(key: 'test', () => 'result');

      expect(wrapRunCalled, true);
    });

    test('preset catchError callback is used', () async {
      var catchErrorCalled = false;

      final preset = MixPreset(
        catchError: (error, stack) {
          catchErrorCalled = true;
          // Return normally to suppress error
        },
      );

      await preset(key: 'test', () => throw Exception('test'));

      expect(catchErrorCalled, true);
    });
  });

  // ============================================================
  // Explicit values override preset
  // ============================================================

  group('Explicit values override preset', () {
    test('explicit retry overrides preset retry', () async {
      var callCount = 0;

      final preset = MixPreset(
        retry: RetryConfig(maxRetries: 10, initialDelay: 1.millis),
      );

      try {
        await preset(
          key: 'test',
          retry: RetryConfig(maxRetries: 1),
          () {
            callCount++;
            throw Exception('Test error');
          },
        );
      } catch (_) {}

      // 1 initial + 1 retry = 2 calls (explicit wins)
      expect(callCount, 2);
    });

    test('explicit checkInternet overrides preset checkInternet', () async {
      Superpowers.clear(simulateInternet: () => false);

      // Preset says throw, explicit says silent
      final preset = MixPreset(
        checkInternet: const CheckInternetConfig(abortSilently: false),
      );

      final result = await preset(
        key: 'test',
        checkInternet: checkInternet(abortSilently: true),
        () => 'success',
      );

      // Should use explicit: abortSilently=true
      expect(result, null);
      expect(Superpowers.errors, isEmpty);
    });

    test('explicit throttle overrides preset throttle', () async {
      var callCount = 0;

      final preset = MixPreset(
        throttle: ThrottleConfig(duration: 500.millis),
      );

      await preset(
        key: 'test',
        throttle: throttle(duration: 10.millis),
        () => callCount++,
      );

      await Future.delayed(20.millis);

      await preset(
        key: 'test',
        throttle: throttle(duration: 10.millis),
        () => callCount++,
      );

      expect(callCount, 2); // Both run due to short explicit duration
    });

    test('explicit before overrides preset before', () async {
      var presetBeforeCalled = false;
      var explicitBeforeCalled = false;

      final preset = MixPreset(
        before: () => presetBeforeCalled = true,
      );

      await preset(
        key: 'test',
        before: () => explicitBeforeCalled = true,
        () {},
      );

      expect(presetBeforeCalled, false);
      expect(explicitBeforeCalled, true);
    });

    test('explicit after overrides preset after', () async {
      var presetAfterCalled = false;
      var explicitAfterCalled = false;

      final preset = MixPreset(
        after: () => presetAfterCalled = true,
      );

      await preset(
        key: 'test',
        after: () => explicitAfterCalled = true,
        () {},
      );

      expect(presetAfterCalled, false);
      expect(explicitAfterCalled, true);
    });

    test('explicit wrapRun overrides preset wrapRun', () async {
      var presetWrapRunCalled = false;
      var explicitWrapRunCalled = false;

      final preset = MixPreset(
        wrapRun: (action) {
          presetWrapRunCalled = true;
          return action();
        },
      );

      await preset(
        key: 'test',
        wrapRun: (action) {
          explicitWrapRunCalled = true;
          return action();
        },
        () => 'result',
      );

      expect(presetWrapRunCalled, false);
      expect(explicitWrapRunCalled, true);
    });

    test('explicit catchError overrides preset catchError', () async {
      var presetWrapErrorCalled = false;
      var explicitWrapErrorCalled = false;

      final preset = MixPreset(
        catchError: (error, stack) {
          presetWrapErrorCalled = true;
          // Return normally to suppress
        },
      );

      await preset(
        key: 'test',
        catchError: (error, stack) {
          explicitWrapErrorCalled = true;
          // Return normally to suppress
        },
        () => throw Exception('test'),
      );

      expect(presetWrapErrorCalled, false);
      expect(explicitWrapErrorCalled, true);
    });
  });

  // ============================================================
  // ctx() method for mix.ctx
  // ============================================================

  group('ctx() method for mix.ctx', () {
    test('ctx() passes MixContext to action', () async {
      const preset = MixPreset();
      MixContext? ctx;

      await preset.ctx(
        key: 'test',
        (context) {
          ctx = context;
        },
      );

      expect(ctx, isNotNull);
    });

    test('ctx() provides retry context with attempt info', () async {
      final preset = MixPreset(
        retry: RetryConfig(maxRetries: 2, initialDelay: 1.millis),
      );

      final attempts = <int>[];

      try {
        await preset.ctx(
          key: 'test',
          (ctx) {
            attempts.add(ctx.retry!.attempt);
            throw Exception('test');
          },
        );
      } catch (_) {}

      expect(attempts, [0, 1, 2]); // Initial + 2 retries
    });

    test('ctx() provides sequential context with queue info', () async {
      final preset = MixPreset(
        sequential: const SequentialConfig(),
      );

      final completer = Completer<void>();
      int? firstIndex;
      int? secondIndex;
      bool? secondWasQueued;

      final future1 = preset.ctx(
        key: 'test',
        (ctx) async {
          firstIndex = ctx.sequential!.index;
          await completer.future;
        },
      );

      await Future.delayed(10.millis);

      final future2 = preset.ctx(
        key: 'test',
        (ctx) async {
          secondIndex = ctx.sequential!.index;
          secondWasQueued = ctx.sequential!.wasQueued;
        },
      );

      completer.complete();
      await future1;
      await future2;

      expect(firstIndex, 0); // Ran immediately
      expect(secondIndex, 1); // Was queued
      expect(secondWasQueued, true);
    });

    test('ctx() uses preset values', () async {
      final preset = MixPreset(
        retry: RetryConfig(maxRetries: 5),
        throttle: ThrottleConfig(duration: 100.millis),
      );

      MixContext? ctx;

      await preset.ctx(
        key: 'test',
        (context) {
          ctx = context;
        },
      );

      expect(ctx!.retry!.config.maxRetries, 5);
      expect(ctx!.throttle!.config.duration, 100.millis);
    });

    test('ctx() requires key if not preset', () async {
      const preset = MixPreset();

      expect(
        () => preset.ctx((ctx) => 'test'),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('key is required'),
        )),
      );
    });

    test('ctx() uses preset key when no explicit key', () async {
      final preset = MixPreset(key: 'presetKey');

      // Should not throw
      await preset.ctx((ctx) => 'test');
    });
  });

  // ============================================================
  // merge() method
  // ============================================================

  group('merge() method', () {
    test('merge combines two presets', () async {
      const preset1 = MixPreset(
        retry: RetryConfig(maxRetries: 5),
      );

      const preset2 = MixPreset(
        throttle: ThrottleConfig(duration: Duration(milliseconds: 100)),
      );

      final merged = preset1.merge(preset2);

      expect(merged.retry!.maxRetries, 5);
      expect(merged.throttle!.duration, 100.millis);
    });

    test('merge: other values override this values', () async {
      const preset1 = MixPreset(
        retry: RetryConfig(maxRetries: 5),
        throttle: ThrottleConfig(duration: Duration(milliseconds: 100)),
      );

      const preset2 = MixPreset(
        retry: RetryConfig(maxRetries: 10),
      );

      final merged = preset1.merge(preset2);

      expect(merged.retry!.maxRetries, 10); // From preset2
      expect(merged.throttle!.duration, 100.millis); // From preset1
    });

    test('merge with null returns this', () async {
      const preset = MixPreset(
        retry: RetryConfig(maxRetries: 5),
      );

      final merged = preset.merge(null);

      expect(identical(merged, preset), true);
    });

    test('merge combines all config types', () async {
      var beforeCalled = false;
      var afterCalled = false;

      final preset1 = MixPreset(
        key: 'key1',
        retry: RetryConfig(maxRetries: 5),
        checkInternet: const CheckInternetConfig(abortSilently: true),
        nonReentrant: const NonReentrantConfig(key: 'nr1'),
        before: () => beforeCalled = true,
      );

      final preset2 = MixPreset(
        throttle: ThrottleConfig(duration: 100.millis),
        debounce: DebounceConfig(duration: 200.millis),
        fresh: FreshConfig(freshFor: 300.millis),
        sequential: const SequentialConfig(maxQueueSize: 5),
        after: () => afterCalled = true,
      );

      final merged = preset1.merge(preset2);

      expect(merged.key, 'key1');
      expect(merged.retry!.maxRetries, 5);
      expect(merged.checkInternet!.abortSilently, true);
      expect(merged.nonReentrant!.key, 'nr1');
      expect(merged.throttle!.duration, 100.millis);
      expect(merged.debounce!.duration, 200.millis);
      expect(merged.fresh!.freshFor, 300.millis);
      expect(merged.sequential!.maxQueueSize, 5);

      // Verify callbacks work
      await merged(key: 'test', () {});
      expect(beforeCalled, true);
      expect(afterCalled, true);
    });

    test('merged preset works correctly', () async {
      var callCount = 0;

      const preset1 = MixPreset(
        retry: RetryConfig(maxRetries: 2, initialDelay: Duration(milliseconds: 1)),
      );

      const preset2 = MixPreset(
        throttle: ThrottleConfig(duration: Duration(milliseconds: 100)),
      );

      final merged = preset1.merge(preset2);

      // First call - runs with retry
      try {
        await merged(
          key: 'test',
          () {
            callCount++;
            if (callCount < 3) throw Exception('test');
            return 'success';
          },
        );
      } catch (_) {}

      expect(callCount, 3); // 1 + 2 retries

      // Second call - throttled
      callCount = 0;
      await merged(key: 'test', () => callCount++);

      expect(callCount, 0); // Throttled
    });
  });

  // ============================================================
  // copyWith() method
  // ============================================================

  group('copyWith() method', () {
    test('copyWith creates a modified copy', () async {
      const original = MixPreset(
        retry: RetryConfig(maxRetries: 5),
      );

      final modified = original.copyWith(
        throttle: ThrottleConfig(duration: 100.millis),
      );

      expect(modified.retry!.maxRetries, 5); // Preserved
      expect(modified.throttle!.duration, 100.millis); // Added
    });

    test('copyWith overrides existing values', () async {
      const original = MixPreset(
        retry: RetryConfig(maxRetries: 5),
        throttle: ThrottleConfig(duration: Duration(milliseconds: 100)),
      );

      final modified = original.copyWith(
        retry: RetryConfig(maxRetries: 10),
      );

      expect(modified.retry!.maxRetries, 10); // Overridden
      expect(modified.throttle!.duration, 100.millis); // Preserved
    });

    test('copyWith preserves all other values', () async {
      var beforeCalled = false;

      final original = MixPreset(
        key: 'originalKey',
        retry: RetryConfig(maxRetries: 5),
        checkInternet: const CheckInternetConfig(abortSilently: true),
        nonReentrant: const NonReentrantConfig(key: 'nr1'),
        throttle: ThrottleConfig(duration: 100.millis),
        debounce: DebounceConfig(duration: 200.millis),
        fresh: FreshConfig(freshFor: 300.millis),
        sequential: const SequentialConfig(maxQueueSize: 5),
        before: () => beforeCalled = true,
      );

      final modified = original.copyWith(
        retry: RetryConfig(maxRetries: 10),
      );

      expect(modified.key, 'originalKey');
      expect(modified.retry!.maxRetries, 10); // Changed
      expect(modified.checkInternet!.abortSilently, true);
      expect(modified.nonReentrant!.key, 'nr1');
      expect(modified.throttle!.duration, 100.millis);
      expect(modified.debounce!.duration, 200.millis);
      expect(modified.fresh!.freshFor, 300.millis);
      expect(modified.sequential!.maxQueueSize, 5);

      await modified(key: 'test', () {});
      expect(beforeCalled, true);
    });
  });

  // ============================================================
  // MixConfig integration
  // ============================================================

  group('Preset fields are passed to mix', () {
    test('preset fields are passed to mix', () async {
      MixContext? ctx;

      final preset = MixPreset(
        retry: RetryConfig(maxRetries: 7),
        throttle: ThrottleConfig(duration: 200.millis),
      );

      await preset.ctx(
        key: 'test',
        (context) {
          ctx = context;
        },
      );

      expect(ctx!.retry!.config.maxRetries, 7);
      expect(ctx!.throttle!.config.duration, 200.millis);
    });

    test('explicit retry overrides preset retry', () async {
      MixContext? ctx;

      final preset = MixPreset(
        retry: RetryConfig(maxRetries: 7),
      );

      await preset.ctx(
        key: 'test',
        retry: RetryConfig(maxRetries: 2),
        (context) {
          ctx = context;
        },
      );

      expect(ctx!.retry!.config.maxRetries, 2);
    });
  });

  // ============================================================
  // Real-world usage patterns
  // ============================================================

  group('Real-world usage patterns', () {
    test('API call preset pattern', () async {
      Superpowers.clear(simulateInternet: () => true);

      var callCount = 0;
      var beforeCount = 0;
      var afterCount = 0;

      final apiCall = MixPreset(
        retry: RetryConfig(maxRetries: 2, initialDelay: 1.millis),
        checkInternet: const CheckInternetConfig(),
        before: () => beforeCount++,
        after: () => afterCount++,
        catchError: (e, s) => throw UserException('API Error: $e'),
      );

      // Successful call
      final result = await apiCall(
        key: 'fetchUser',
        () {
          callCount++;
          return {'id': 1, 'name': 'Test'};
        },
      );

      expect(result, {'id': 1, 'name': 'Test'});
      expect(callCount, 1);
      expect(beforeCount, 1);
      expect(afterCount, 1);

      // Failing call with retry
      callCount = 0;
      beforeCount = 0;
      afterCount = 0;

      await apiCall(
        key: 'fetchData',
        () {
          callCount++;
          throw Exception('Network error');
        },
      );

      expect(callCount, 3); // 1 + 2 retries
      expect(beforeCount, 1); // Called once
      expect(afterCount, 1); // Called once
      expect(Superpowers.errors.length, 1);
      expect(Superpowers.errors.first, isA<UserException>());
    });

    test('background sync preset pattern', () async {
      Superpowers.clear(simulateInternet: () => false);

      var syncCalled = false;

      final backgroundSync = MixPreset(
        checkInternet: checkInternet(abortSilently: true),
        nonReentrant: const NonReentrantConfig(),
      );

      final result = await backgroundSync(
        key: 'sync',
        () {
          syncCalled = true;
          return 'synced';
        },
      );

      // Should abort silently without running
      expect(syncCalled, false);
      expect(result, null);
      expect(Superpowers.errors, isEmpty);
    });

    test('user action preset pattern with debounce', () async {
      var searchCount = 0;
      final results = <String>[];

      final userAction = MixPreset(
        debounce: DebounceConfig(duration: 30.millis),
      );

      // Rapid fire searches - only last should execute
      final futures = <Future<void>>[];
      for (var i = 0; i < 5; i++) {
        final index = i; // Capture for closure
        futures.add(Future(() async {
          await userAction(
            key: 'search',
            () {
              searchCount++;
              results.add('result$index');
            },
          );
        }));
        await Future.delayed(10.millis);
      }

      await Future.wait(futures);

      expect(searchCount, 1);
      expect(results.length, 1);
      expect(results.first, 'result4'); // Only last one
    });

    test('composing presets for specific use cases', () async {
      const baseApiPreset = MixPreset(
        retry: RetryConfig(maxRetries: 3, initialDelay: Duration(milliseconds: 1)),
        checkInternet: CheckInternetConfig(),
      );

      // Extend for critical operations
      final criticalPreset = baseApiPreset.copyWith(
        retry: retry.unlimited(initialDelay: 1.millis),
      );

      // Extend for optional operations
      final optionalPreset = baseApiPreset.copyWith(
        checkInternet: checkInternet(abortSilently: true),
      );

      // Verify criticalPreset has unlimited retries
      expect(criticalPreset.retry!.maxRetries, -1);
      expect(criticalPreset.checkInternet, isNotNull);

      // Verify optionalPreset aborts silently
      expect(optionalPreset.retry!.maxRetries, 3);
      expect(optionalPreset.checkInternet!.abortSilently, true);
    });

    test('preset with all common options', () async {
      var trackerCalled = false;

      final comprehensivePreset = MixPreset(
        key: 'defaultKey',
        retry: RetryConfig(maxRetries: 3, initialDelay: 1.millis),
        checkInternet: const CheckInternetConfig(abortSilently: true),
        throttle: ThrottleConfig(duration: 100.millis),
        before: () => trackerCalled = true,
        after: () {},
        catchError: (e, s) => throw UserException('Error: $e'),
      );

      // Should work without specifying key
      await comprehensivePreset(() => 'result');

      expect(trackerCalled, true);
    });
  });

  // ============================================================
  // Edge cases
  // ============================================================

  group('Edge cases', () {
    test('empty preset works', () async {
      const preset = MixPreset();

      final result = await preset(
        key: 'test',
        () => 42,
      );

      expect(result, 42);
    });

    test('preset with only key works', () async {
      final preset = MixPreset(key: 'onlyKey');

      final result = await preset(() => 'success');

      expect(result, 'success');
    });

    test('wrapRun type casting works correctly', () async {
      final preset = MixPreset(
        wrapRun: (action) {
          return action();
        },
      );

      // Test with different return types
      final intResult = await preset(key: 'int', () => 42);
      expect(intResult, 42);

      final stringResult = await preset(key: 'string', () => 'hello');
      expect(stringResult, 'hello');

      final listResult = await preset(key: 'list', () => [1, 2, 3]);
      expect(listResult, [1, 2, 3]);
    });

    test('multiple presets are independent', () async {
      var preset1CallCount = 0;
      var preset2CallCount = 0;

      final preset1 = MixPreset(
        throttle: ThrottleConfig(duration: 100.millis, key: 'preset1'),
      );

      final preset2 = MixPreset(
        throttle: ThrottleConfig(duration: 100.millis, key: 'preset2'),
      );

      await preset1(key: 'test', () => preset1CallCount++);
      await preset2(key: 'test', () => preset2CallCount++);

      // Both should run (different throttle keys)
      expect(preset1CallCount, 1);
      expect(preset2CallCount, 1);
    });

    test('preset const constructor works', () async {
      // Verify const works without errors
      const preset = MixPreset(
        retry: RetryConfig(maxRetries: 5),
        checkInternet: CheckInternetConfig(abortSilently: true),
        nonReentrant: NonReentrantConfig(key: 'test'),
        sequential: SequentialConfig(maxQueueSize: 10),
        throttle: ThrottleConfig(duration: Duration(seconds: 1)),
        debounce: DebounceConfig(duration: Duration(milliseconds: 300)),
        fresh: FreshConfig(freshFor: Duration(minutes: 5)),
      );

      expect(preset.retry!.maxRetries, 5);
      expect(preset.checkInternet!.abortSilently, true);
      expect(preset.nonReentrant!.key, 'test');
      expect(preset.sequential!.maxQueueSize, 10);
      expect(preset.throttle!.duration, 1.sec);
      expect(preset.debounce!.duration, 300.millis);
      expect(preset.fresh!.freshFor, const Duration(minutes: 5));
    });
  });

  // ============================================================
  // MixPresetWithParams<P, C> - Params and Config injection
  // ============================================================

  group('MixPresetWithParams<P, C> - Basic functionality', () {
    test('action receives injected params with default config', () async {
      // Using () (unit type) when no config is needed
      final preset = MixPresetWithParams<String, ()>(
        params: (ctx, config) => 'injected value',
        defaultConfig: (),
      );

      String? received;
      await preset(
        key: 'test',
        (ctx) {
          received = ctx;
        },
      );

      expect(received, 'injected value');
    });

    test('action receives record params', () async {
      final preset = MixPresetWithParams<({String name, int age}), ()>(
        params: (ctx, config) => (name: 'Alice', age: 30),
        defaultConfig: (),
      );

      String? name;
      int? age;
      await preset(
        key: 'test',
        (ctx) {
          name = ctx.name;
          age = ctx.age;
        },
      );

      expect(name, 'Alice');
      expect(age, 30);
    });

    test('action can return value', () async {
      final preset = MixPresetWithParams<int, ()>(
        params: (ctx, config) => 10,
        defaultConfig: (),
      );

      final result = await preset(
        key: 'test',
        (multiplier) => multiplier * 5,
      );

      expect(result, 50);
    });

    test('key is required if not preset', () async {
      final preset = MixPresetWithParams<String, ()>(
        params: (ctx, config) => 'value',
        defaultConfig: (),
      );

      expect(
        () => preset((ctx) => ctx),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('key is required'),
        )),
      );
    });

    test('config is required if no default config', () async {
      final preset = MixPresetWithParams<String, String>(
        params: (ctx, config) => config,
      );

      expect(
        () => preset(key: 'test', (ctx) => ctx),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('config is required'),
        )),
      );
    });

    test('preset key is used when no explicit key', () async {
      final preset = MixPresetWithParams<String, ()>(
        key: 'presetKey',
        params: (ctx, config) => 'value',
        defaultConfig: (),
      );

      final result = await preset((ctx) => ctx);
      expect(result, 'value');
    });

    test('default config is used when no explicit config', () async {
      final preset = MixPresetWithParams<String, String>(
        params: (ctx, config) => 'got: $config',
        defaultConfig: 'default',
      );

      final result = await preset(key: 'test', (ctx) => ctx);
      expect(result, 'got: default');
    });

    test('explicit config overrides default config', () async {
      final preset = MixPresetWithParams<String, String>(
        params: (ctx, config) => 'got: $config',
        defaultConfig: 'default',
      );

      final result = await preset(key: 'test', config: 'explicit', (ctx) => ctx);
      expect(result, 'got: explicit');
    });
  });

  group('MixPresetWithParams<P, C> - Config influences params', () {
    test('params uses config to determine values', () async {
      final preset = MixPresetWithParams<
          ({String url, bool verbose}), ({String env, bool debug})>(
        params: (ctx, config) => (
          url: config.env == 'prod'
              ? 'https://api.example.com'
              : 'https://staging.example.com',
          verbose: config.debug,
        ),
        defaultConfig: (env: 'dev', debug: false),
      );

      // Test with default (dev)
      var result = await preset(key: 'test', (ctx) => ctx);
      expect(result!.url, 'https://staging.example.com');
      expect(result.verbose, false);

      // Test with prod config
      result = await preset(
        key: 'test2',
        config: (env: 'prod', debug: true),
        (ctx) => ctx,
      );
      expect(result!.url, 'https://api.example.com');
      expect(result.verbose, true);
    });

    test('injected function uses config', () async {
      final logs = <String>[];

      final preset = MixPresetWithParams<({void Function(String) log}),
          ({bool verbose})>(
        params: (ctx, config) => (
          log: (msg) {
            if (config.verbose) {
              logs.add('[VERBOSE] $msg');
            } else {
              logs.add(msg);
            }
          },
        ),
        defaultConfig: (verbose: false),
      );

      // With default (not verbose)
      await preset(key: 'test1', (ctx) => ctx.log('Hello'));
      expect(logs.last, 'Hello');

      // With verbose
      await preset(
        key: 'test2',
        config: (verbose: true),
        (ctx) => ctx.log('World'),
      );
      expect(logs.last, '[VERBOSE] World');
    });
  });

  group('MixPresetWithParams<P, C> - Params have access to MixContext', () {
    test('params function receives MixContext', () async {
      MixContext? capturedCtx;

      final preset = MixPresetWithParams<String, ()>(
        params: (ctx, config) {
          capturedCtx = ctx;
          return 'value';
        },
        defaultConfig: (),
      );

      await preset(key: 'test', (ctx) {});

      expect(capturedCtx, isNotNull);
    });

    test('params can access retry attempt info', () async {
      final attempts = <int>[];

      final preset = MixPresetWithParams<({void Function() track}), ()>(
        params: (ctx, config) => (
          track: () => attempts.add(ctx.retry?.attempt ?? -1),
        ),
        defaultConfig: (),
        retry: RetryConfig(maxRetries: 2, initialDelay: 1.millis),
      );

      try {
        await preset(
          key: 'test',
          (ctx) {
            ctx.track();
            throw Exception('fail');
          },
        );
      } catch (_) {}

      expect(attempts, [0, 1, 2]); // Initial + 2 retries
    });

    test('injected log function has access to both ctx and config', () async {
      final logs = <String>[];

      final apiCall = MixPresetWithParams<({void Function(String) log}),
          ({String prefix})>(
        params: (ctx, config) => (
          log: (msg) {
            final attempt = ctx.retry?.attempt ?? 0;
            logs.add('[${config.prefix}:$attempt] $msg');
          },
        ),
        defaultConfig: (prefix: 'API'),
        retry: RetryConfig(maxRetries: 1, initialDelay: 1.millis),
      );

      try {
        await apiCall(
          key: 'fetch',
          config: (prefix: 'HTTP'),
          (ctx) {
            ctx.log('Fetching...');
            throw Exception('fail');
          },
        );
      } catch (_) {}

      expect(logs, [
        '[HTTP:0] Fetching...',
        '[HTTP:1] Fetching...',
      ]);
    });
  });

  group('MixPresetWithParams<P, C> - Config options work', () {
    test('retry config is applied', () async {
      var callCount = 0;

      final preset = MixPresetWithParams<String, ()>(
        params: (ctx, config) => 'value',
        defaultConfig: (),
        retry: RetryConfig(maxRetries: 2, initialDelay: 1.millis),
      );

      try {
        await preset(
          key: 'test',
          (ctx) {
            callCount++;
            throw Exception('fail');
          },
        );
      } catch (_) {}

      expect(callCount, 3); // 1 + 2 retries
    });

    test('throttle config is applied', () async {
      var callCount = 0;

      final preset = MixPresetWithParams<String, ()>(
        params: (ctx, config) => 'value',
        defaultConfig: (),
        throttle: ThrottleConfig(duration: 100.millis),
      );

      await preset(key: 'test', (ctx) => callCount++);
      await preset(key: 'test', (ctx) => callCount++);

      expect(callCount, 1); // Second call throttled
    });

    test('before/after callbacks work', () async {
      var beforeCalled = false;
      var afterCalled = false;

      final preset = MixPresetWithParams<String, ()>(
        params: (ctx, config) => 'value',
        defaultConfig: (),
        before: () => beforeCalled = true,
        after: () => afterCalled = true,
      );

      await preset(key: 'test', (ctx) {});

      expect(beforeCalled, true);
      expect(afterCalled, true);
    });
  });

  group('MixPresetWithParams<P, C> - catchError composition', () {
    test('preset catchError is used when no user catchError', () async {
      var presetWrapErrorCalled = false;

      final preset = MixPresetWithParams<String, ()>(
        params: (ctx, config) => 'value',
        defaultConfig: (),
        catchError: (e, s) {
          presetWrapErrorCalled = true;
          // Return normally to suppress
        },
      );

      await preset(key: 'test', (ctx) => throw Exception('test'));

      expect(presetWrapErrorCalled, true);
    });

    test('user catchError is used when no preset catchError', () async {
      var userWrapErrorCalled = false;

      final preset = MixPresetWithParams<String, ()>(
        params: (ctx, config) => 'value',
        defaultConfig: (),
      );

      await preset(
        key: 'test',
        catchError: (e, s) {
          userWrapErrorCalled = true;
          // Return normally to suppress
        },
        (ctx) => throw Exception('test'),
      );

      expect(userWrapErrorCalled, true);
    });

    test('catchErrors are composed: preset first, then user', () async {
      final callOrder = <String>[];
      Object? presetReceived;
      Object? userReceived;

      final preset = MixPresetWithParams<String, ()>(
        params: (ctx, config) => 'value',
        defaultConfig: (),
        catchError: (e, s) {
          callOrder.add('preset');
          presetReceived = e;
          throw UserException('Wrapped: $e');
        },
      );

      await preset(
        key: 'test',
        catchError: (e, s) {
          callOrder.add('user');
          userReceived = e;
          // Return normally to suppress
        },
        (ctx) => throw Exception('original'),
      );

      expect(callOrder, ['preset', 'user']);
      expect(presetReceived.toString(), 'Exception: original');
      expect(userReceived, isA<UserException>());
      expect((userReceived as UserException).message, contains('Wrapped'));
    });

    test('if preset catchError returns normally (suppresses), user catchError is not called',
        () async {
      var userWrapErrorCalled = false;

      final preset = MixPresetWithParams<String, ()>(
        params: (ctx, config) => 'value',
        defaultConfig: (),
        catchError: (e, s) {}, // Suppress
      );

      await preset(
        key: 'test',
        catchError: (e, s) {
          userWrapErrorCalled = true;
          throw e;
        },
        (ctx) => throw Exception('test'),
      );

      expect(userWrapErrorCalled, false);
    });
  });

  group('MixPresetWithParams<P, C> - merge() and copyWith()', () {
    test('merge combines presets', () async {
      final preset1 = MixPresetWithParams<String, String>(
        params: (ctx, config) => 'value1: $config',
        defaultConfig: 'default1',
        retry: RetryConfig(maxRetries: 5),
      );

      final preset2 = MixPresetWithParams<String, String>(
        params: (ctx, config) => 'value2: $config',
        defaultConfig: 'default2',
        throttle: ThrottleConfig(duration: 100.millis),
      );

      final merged = preset1.merge(preset2);

      expect(merged.retry!.maxRetries, 5); // From preset1
      expect(merged.throttle!.duration, 100.millis); // From preset2
      expect(merged.defaultConfig, 'default2'); // From preset2

      // params comes from preset2 (other wins)
      String? received;
      await merged(key: 'test', (ctx) => received = ctx);
      expect(received, 'value2: default2');
    });

    test('copyWith preserves params if not overridden', () async {
      final preset = MixPresetWithParams<String, String>(
        params: (ctx, config) => 'original: $config',
        defaultConfig: 'default',
        retry: RetryConfig(maxRetries: 5),
      );

      final modified = preset.copyWith(
        throttle: ThrottleConfig(duration: 100.millis),
      );

      String? received;
      await modified(key: 'test', (ctx) => received = ctx);
      expect(received, 'original: default');
      expect(modified.throttle!.duration, 100.millis);
    });

    test('copyWith can override params and defaultConfig', () async {
      final preset = MixPresetWithParams<String, String>(
        params: (ctx, config) => 'original',
        defaultConfig: 'default',
      );

      final modified = preset.copyWith(
        params: (ctx, config) => 'modified: $config',
        defaultConfig: 'newDefault',
      );

      String? received;
      await modified(key: 'test', (ctx) => received = ctx);
      expect(received, 'modified: newDefault');
    });
  });

  group('MixPresetWithParams<P, C> - Real-world patterns', () {
    test('API call with environment config', () async {
      final logs = <String>[];

      final apiCall = MixPresetWithParams<
          ({String baseUrl, void Function(String) log}),
          ({String env, bool verbose})>(
        params: (ctx, config) => (
          baseUrl: config.env == 'prod'
              ? 'https://api.example.com'
              : 'https://staging.example.com',
          log: (msg) {
            if (config.verbose) {
              final attempt = ctx.retry?.attempt ?? 0;
              logs.add('[$attempt] $msg');
            }
          },
        ),
        defaultConfig: (env: 'dev', verbose: false),
        retry: RetryConfig(maxRetries: 1, initialDelay: 1.millis),
      );

      // Test with prod, verbose
      var fetchCount = 0;
      try {
        await apiCall(
          key: 'fetchUsers',
          config: (env: 'prod', verbose: true),
          (ctx) {
            ctx.log('Fetching from ${ctx.baseUrl}');
            fetchCount++;
            throw Exception('Network error');
          },
        );
      } catch (_) {}

      expect(fetchCount, 2);
      expect(logs, [
        '[0] Fetching from https://api.example.com',
        '[1] Fetching from https://api.example.com',
      ]);
    });

    test('preset with config for custom error handling', () async {
      Object? capturedError;

      final preset = MixPresetWithParams<String, ({bool rethrowErrors})>(
        params: (ctx, config) => 'value',
        defaultConfig: (rethrowErrors: false),
        catchError: (e, s) => throw UserException('Error: $e'),
      );

      // With default config - error wrapped
      await preset(
        key: 'test1',
        catchError: (e, s) {
          capturedError = e;
          // Return normally to suppress
        },
        (ctx) => throw Exception('test'),
      );
      expect(capturedError, isA<UserException>());

      // We can't actually change behavior based on config in catchError
      // because catchError doesn't receive config, but we can use different
      // presets or user-level catchError
    });

    test('dependency injection with configurable services', () async {
      final callLog = <String>[];

      final serviceCall = MixPresetWithParams<
          ({
            String Function(String) transform,
            void Function(String) log,
          }),
          ({bool uppercase, String logPrefix})>(
        params: (ctx, config) => (
          transform: (s) => config.uppercase ? s.toUpperCase() : s,
          log: (msg) => callLog.add('[${config.logPrefix}] $msg'),
        ),
        defaultConfig: (uppercase: false, logPrefix: 'DEFAULT'),
      );

      // With default config
      await serviceCall(key: 'test1', (ctx) {
        ctx.log(ctx.transform('hello'));
      });
      expect(callLog.last, '[DEFAULT] hello');

      // With custom config
      await serviceCall(
        key: 'test2',
        config: (uppercase: true, logPrefix: 'CUSTOM'),
        (ctx) {
          ctx.log(ctx.transform('world'));
        },
      );
      expect(callLog.last, '[CUSTOM] WORLD');
    });
  });

  // ============================================================
  // MixPresetWithParams<P, C> - Additional config options
  // ============================================================

  group('MixPresetWithParams<P, C> - Additional config options', () {
    test('checkInternet config is applied', () async {
      Superpowers.clear(simulateInternet: () => false);

      var actionCalled = false;
      var onNoInternetCalled = false;

      final preset = MixPresetWithParams<String, ()>(
        params: (ctx, config) => 'value',
        defaultConfig: (),
        checkInternet: CheckInternetConfig(
          abortSilently: true,
          onNoInternet: () => onNoInternetCalled = true,
        ),
      );

      final result = await preset(
        key: 'test',
        (ctx) {
          actionCalled = true;
          return 'success';
        },
      );

      expect(actionCalled, false);
      expect(onNoInternetCalled, true);
      expect(result, null);
    });

    test('nonReentrant config is applied', () async {
      final completer = Completer<void>();
      var call2Blocked = false;

      final preset = MixPresetWithParams<String, ()>(
        params: (ctx, config) => 'value',
        defaultConfig: (),
        nonReentrant: NonReentrantConfig(
          onBlocked: (_) => call2Blocked = true,
        ),
      );

      final future1 = preset(
        key: 'test',
        (ctx) async {
          await completer.future;
        },
      );

      await Future.delayed(10.millis);

      await preset(key: 'test', (ctx) async {});

      expect(call2Blocked, true);

      completer.complete();
      await future1;
    });

    test('sequential config is applied', () async {
      final tracker = <int>[];
      final completer = Completer<void>();

      final preset = MixPresetWithParams<String, ()>(
        params: (ctx, config) => 'value',
        defaultConfig: (),
        sequential: const SequentialConfig(),
      );

      final future1 = preset(
        key: 'test',
        (ctx) async {
          tracker.add(1);
          await completer.future;
          tracker.add(2);
        },
      );

      await Future.delayed(10.millis);

      final future2 = preset(
        key: 'test',
        (ctx) async {
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

    test('debounce config is applied', () async {
      var callCount = 0;

      final preset = MixPresetWithParams<String, ()>(
        params: (ctx, config) => 'value',
        defaultConfig: (),
        debounce: DebounceConfig(duration: 50.millis),
      );

      final future1 = preset(key: 'test', (ctx) => callCount++);
      await Future.delayed(10.millis);
      final future2 = preset(key: 'test', (ctx) => callCount++);

      await future1;
      await future2;

      expect(callCount, 1); // First call superseded
    });

    test('fresh config is applied', () async {
      var callCount = 0;

      final preset = MixPresetWithParams<String, ()>(
        params: (ctx, config) => 'value',
        defaultConfig: (),
        fresh: FreshConfig(freshFor: 100.millis),
      );

      await preset(key: 'test', (ctx) => callCount++);
      await preset(key: 'test', (ctx) => callCount++);

      expect(callCount, 1); // Second call skipped (still fresh)
    });

    test('wrapRun callback is applied', () async {
      var wrapRunCalled = false;

      final preset = MixPresetWithParams<String, ()>(
        params: (ctx, config) => 'value',
        defaultConfig: (),
        wrapRun: (action) {
          wrapRunCalled = true;
          return action();
        },
      );

      await preset(key: 'test', (ctx) => 'result');

      expect(wrapRunCalled, true);
    });

    test('retry config is applied', () async {
      var callCount = 0;

      final preset = MixPresetWithParams<String, ()>(
        params: (ctx, config) => 'value',
        defaultConfig: (),
        retry: RetryConfig(maxRetries: 2, initialDelay: 1.millis),
      );

      try {
        await preset(
          key: 'test',
          (ctx) {
            callCount++;
            throw Exception('fail');
          },
        );
      } catch (_) {}

      expect(callCount, 3); // 1 + 2 retries
    });
  });

  // ============================================================
  // MixPresetWithParams<P, C> - Async and edge cases
  // ============================================================

  group('MixPresetWithParams<P, C> - Async and edge cases', () {
    test('works with async actions', () async {
      final preset = MixPresetWithParams<String, ()>(
        params: (ctx, config) => 'async-value',
        defaultConfig: (),
      );

      final result = await preset(
        key: 'test',
        (ctx) async {
          await Future.delayed(10.millis);
          return 'result: $ctx';
        },
      );

      expect(result, 'result: async-value');
    });

    test('returns null when aborted by checkInternet', () async {
      Superpowers.clear(simulateInternet: () => false);

      final preset = MixPresetWithParams<String, ()>(
        params: (ctx, config) => 'value',
        defaultConfig: (),
        checkInternet: checkInternet(abortSilently: true),
      );

      final result = await preset(
        key: 'test',
        (ctx) => 'should not run',
      );

      expect(result, null);
    });

    test('error propagates when catchError throws the error', () async {
      final preset = MixPresetWithParams<String, ()>(
        params: (ctx, config) => 'value',
        defaultConfig: (),
        catchError: (e, s) => throw e, // Don't suppress
      );

      expect(
        () => preset(key: 'test', (ctx) => throw Exception('test error')),
        throwsA(isA<Exception>()),
      );
    });

    test('params function is called on each retry', () async {
      var paramsCallCount = 0;

      final preset = MixPresetWithParams<int, ()>(
        params: (ctx, config) {
          paramsCallCount++;
          return paramsCallCount;
        },
        defaultConfig: (),
        retry: RetryConfig(maxRetries: 2, initialDelay: 1.millis),
      );

      final receivedCtx = <int>[];
      try {
        await preset(
          key: 'test',
          (ctx) {
            receivedCtx.add(ctx);
            throw Exception('fail');
          },
        );
      } catch (_) {}

      expect(paramsCallCount, 3); // Called on each attempt
      expect(receivedCtx, [1, 2, 3]); // Different value each time
    });

    test('params can access sequential queue context', () async {
      final completer = Completer<void>();
      int? firstIndex;
      int? secondIndex;
      bool? secondWasQueued;

      final preset = MixPresetWithParams<({int index, bool wasQueued}), ()>(
        params: (ctx, config) => (
          index: ctx.sequential?.index ?? -1,
          wasQueued: ctx.sequential?.wasQueued ?? false,
        ),
        defaultConfig: (),
        sequential: const SequentialConfig(),
      );

      final future1 = preset(
        key: 'test',
        (ctx) async {
          firstIndex = ctx.index;
          await completer.future;
        },
      );

      await Future.delayed(10.millis);

      final future2 = preset(
        key: 'test',
        (ctx) async {
          secondIndex = ctx.index;
          secondWasQueued = ctx.wasQueued;
        },
      );

      completer.complete();
      await future1;
      await future2;

      expect(firstIndex, 0);
      expect(secondIndex, 1);
      expect(secondWasQueued, true);
    });

    test('multiple presets are independent', () async {
      var preset1CallCount = 0;
      var preset2CallCount = 0;

      final preset1 = MixPresetWithParams<String, ()>(
        params: (ctx, config) => 'p1',
        defaultConfig: (),
        throttle: ThrottleConfig(duration: 100.millis, key: 'preset1'),
      );

      final preset2 = MixPresetWithParams<String, ()>(
        params: (ctx, config) => 'p2',
        defaultConfig: (),
        throttle: ThrottleConfig(duration: 100.millis, key: 'preset2'),
      );

      await preset1(key: 'test', (ctx) => preset1CallCount++);
      await preset2(key: 'test', (ctx) => preset2CallCount++);

      // Both should run (different throttle keys)
      expect(preset1CallCount, 1);
      expect(preset2CallCount, 1);
    });

    test('action can return null explicitly', () async {
      final preset = MixPresetWithParams<String, ()>(
        params: (ctx, config) => 'value',
        defaultConfig: (),
      );

      final result = await preset(
        key: 'test',
        (ctx) => null,
      );

      expect(result, null);
    });

    test('params throws propagates error', () async {
      final preset = MixPresetWithParams<String, ()>(
        params: (ctx, config) => throw Exception('params error'),
        defaultConfig: (),
      );

      expect(
        () => preset(key: 'test', (ctx) => ctx),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('params error'),
        )),
      );
    });
  });

  // ============================================================
  // MixPreset - Additional coverage for ctx() and merge()
  // ============================================================

  group('MixPreset - Additional ctx() coverage', () {
    test('ctx() with wrapRun callback', () async {
      var wrapRunCalled = false;
      MixContext? capturedCtx;

      final preset = MixPreset(
        wrapRun: (action) {
          wrapRunCalled = true;
          return action();
        },
      );

      await preset.ctx(
        key: 'test',
        (ctx) {
          capturedCtx = ctx;
          return 'result';
        },
      );

      expect(wrapRunCalled, true);
      expect(capturedCtx, isNotNull);
    });

    test('ctx() explicit wrapRun overrides preset wrapRun', () async {
      var presetWrapRunCalled = false;
      var explicitWrapRunCalled = false;

      final preset = MixPreset(
        wrapRun: (action) {
          presetWrapRunCalled = true;
          return action();
        },
      );

      await preset.ctx(
        key: 'test',
        wrapRun: (action) {
          explicitWrapRunCalled = true;
          return action();
        },
        (ctx) => 'result',
      );

      expect(presetWrapRunCalled, false);
      expect(explicitWrapRunCalled, true);
    });
  });

  group('MixPreset - Additional merge() coverage', () {
    test('merge combines wrapRun callbacks (other wins)', () async {
      var preset1WrapRunCalled = false;
      var preset2WrapRunCalled = false;

      final preset1 = MixPreset(
        wrapRun: (action) {
          preset1WrapRunCalled = true;
          return action();
        },
      );

      final preset2 = MixPreset(
        wrapRun: (action) {
          preset2WrapRunCalled = true;
          return action();
        },
      );

      final merged = preset1.merge(preset2);

      await merged(key: 'test', () => 'result');

      expect(preset1WrapRunCalled, false);
      expect(preset2WrapRunCalled, true); // Other wins
    });

    test('merge combines catchError callbacks (other wins)', () async {
      var preset1WrapErrorCalled = false;
      var preset2WrapErrorCalled = false;

      final preset1 = MixPreset(
        catchError: (e, s) {
          preset1WrapErrorCalled = true;
          // Return normally to suppress
        },
      );

      final preset2 = MixPreset(
        catchError: (e, s) {
          preset2WrapErrorCalled = true;
          // Return normally to suppress
        },
      );

      final merged = preset1.merge(preset2);

      await merged(key: 'test', () => throw Exception('test'));

      expect(preset1WrapErrorCalled, false);
      expect(preset2WrapErrorCalled, true); // Other wins
    });

    test('merge preserves wrapRun when other is null', () async {
      var preset1WrapRunCalled = false;

      final preset1 = MixPreset(
        wrapRun: (action) {
          preset1WrapRunCalled = true;
          return action();
        },
      );

      const preset2 = MixPreset(
        retry: RetryConfig(maxRetries: 5),
      );

      final merged = preset1.merge(preset2);

      await merged(key: 'test', () => 'result');

      expect(preset1WrapRunCalled, true); // Preserved
      expect(merged.retry!.maxRetries, 5); // From preset2
    });
  });

  // ============================================================
  // MixPresetWithParams<P, C> - merge() with catchError
  // ============================================================

  group('MixPresetWithParams<P, C> - merge() catchError behavior', () {
    test('merge replaces catchError (does not compose)', () async {
      // Note: merge() replaces catchError, it doesn't compose like call()
      var preset1WrapErrorCalled = false;
      var preset2WrapErrorCalled = false;

      final preset1 = MixPresetWithParams<String, String>(
        params: (ctx, config) => config,
        defaultConfig: 'default',
        catchError: (e, s) {
          preset1WrapErrorCalled = true;
          // Return normally to suppress
        },
      );

      final preset2 = MixPresetWithParams<String, String>(
        params: (ctx, config) => 'from preset2: $config',
        catchError: (e, s) {
          preset2WrapErrorCalled = true;
          // Return normally to suppress
        },
      );

      final merged = preset1.merge(preset2);

      await merged(key: 'test', (ctx) => throw Exception('test'));

      expect(preset1WrapErrorCalled, false); // Replaced, not composed
      expect(preset2WrapErrorCalled, true);
    });

    test('merge preserves catchError when other has none', () async {
      var preset1WrapErrorCalled = false;

      final preset1 = MixPresetWithParams<String, String>(
        params: (ctx, config) => config,
        defaultConfig: 'default',
        catchError: (e, s) {
          preset1WrapErrorCalled = true;
          // Return normally to suppress
        },
      );

      final preset2 = MixPresetWithParams<String, String>(
        params: (ctx, config) => 'from preset2: $config',
        retry: RetryConfig(maxRetries: 5),
      );

      final merged = preset1.merge(preset2);

      await merged(key: 'test', (ctx) => throw Exception('test'));

      expect(preset1WrapErrorCalled, true); // Preserved
      expect(merged.retry!.maxRetries, 5);
    });
  });

  // ============================================================
  // MixPresetWithParams<P, C> - copyWith() coverage
  // ============================================================

  group('MixPresetWithParams<P, C> - Additional copyWith() coverage', () {
    test('copyWith can override all config options', () async {
      var beforeCalled = false;
      var afterCalled = false;
      var wrapRunCalled = false;

      final preset = MixPresetWithParams<String, ()>(
        params: (ctx, config) => 'original',
        defaultConfig: (),
      );

      final modified = preset.copyWith(
        retry: RetryConfig(maxRetries: 3),
        checkInternet: const CheckInternetConfig(),
        nonReentrant: const NonReentrantConfig(),
        sequential: const SequentialConfig(),
        throttle: ThrottleConfig(duration: 100.millis),
        debounce: DebounceConfig(duration: 50.millis),
        fresh: FreshConfig(freshFor: 200.millis),
        before: () => beforeCalled = true,
        after: () => afterCalled = true,
        wrapRun: (action) {
          wrapRunCalled = true;
          return action();
        },
        catchError: (e, s) => throw UserException('wrapped'),
      );

      expect(modified.retry!.maxRetries, 3);
      expect(modified.checkInternet, isNotNull);
      expect(modified.nonReentrant, isNotNull);
      expect(modified.sequential, isNotNull);
      expect(modified.throttle!.duration, 100.millis);
      expect(modified.debounce!.duration, 50.millis);
      expect(modified.fresh!.freshFor, 200.millis);

      await modified(key: 'test', (ctx) => ctx);

      expect(beforeCalled, true);
      expect(afterCalled, true);
      expect(wrapRunCalled, true);
    });

    test('copyWith can override key', () async {
      final preset = MixPresetWithParams<String, ()>(
        params: (ctx, config) => 'value',
        defaultConfig: (),
        key: 'originalKey',
      );

      final modified = preset.copyWith(key: 'newKey');

      expect(modified.key, 'newKey');

      // Should work without specifying key at call time
      final result = await modified((ctx) => ctx);
      expect(result, 'value');
    });

    test('copyWith can override retry', () async {
      var callCount = 0;

      final preset = MixPresetWithParams<String, ()>(
        params: (ctx, config) => 'value',
        defaultConfig: (),
      );

      final modified = preset.copyWith(
        retry: RetryConfig(maxRetries: 1, initialDelay: 1.millis),
      );

      try {
        await modified(
          key: 'test',
          (ctx) {
            callCount++;
            throw Exception('fail');
          },
        );
      } catch (_) {}

      expect(callCount, 2); // 1 + 1 retry
    });
  });

  // ============================================================
  // MixPreset.withUserContext() static factory
  // ============================================================

  group('MixPreset.withUserContext() static factory', () {
    test('creates a working MixPresetWithParams', () async {
      final preset = MixPreset.withUserContext<String, ()>(
        params: (ctx, config) => 'injected value',
        defaultConfig: (),
      );

      String? receivedCtx;
      await preset(
        key: 'test',
        (ctx) {
          receivedCtx = ctx;
        },
      );

      expect(receivedCtx, 'injected value');
    });

    test('passes all configuration options correctly', () async {
      var beforeCalled = false;
      var afterCalled = false;
      var catchErrorCalled = false;

      final preset = MixPreset.withUserContext<String, ()>(
        params: (ctx, config) => 'value',
        defaultConfig: (),
        key: 'presetKey',
        before: () => beforeCalled = true,
        after: () => afterCalled = true,
        catchError: (e, s) => catchErrorCalled = true,
      );

      // Test with error to trigger catchError
      await preset((ctx) => throw Exception('test'));

      expect(beforeCalled, true);
      expect(afterCalled, true);
      expect(catchErrorCalled, true);
    });

    test('supports type inference', () async {
      // Using var - type should be inferred as MixPresetWithParams<String, ({int count})>
      final preset = MixPreset.withUserContext<String, ({int count})>(
        params: (ctx, config) => 'count: ${config.count}',
        defaultConfig: (count: 0),
      );

      final result = await preset(
        key: 'test',
        config: (count: 42),
        (ctx) => ctx,
      );

      expect(result, 'count: 42');
    });

    test('returned preset has all methods (call, merge, copyWith)', () async {
      final preset = MixPreset.withUserContext<int, ()>(
        params: (ctx, config) => 42,
        defaultConfig: (),
      );

      // Test call()
      final callResult = await preset(key: 'test', (ctx) => ctx * 2);
      expect(callResult, 84);

      // Note: MixPresetWithParams doesn't have a separate ctx() method
      // because MixContext is already accessible via the params function

      // Test merge()
      final merged = preset.merge(MixPreset.withUserContext<int, ()>(
        params: (ctx, config) => 100,
        defaultConfig: (),
      ));
      final mergedResult = await merged(key: 'test', (ctx) => ctx);
      expect(mergedResult, 100); // Other's params override

      // Test copyWith()
      final copied = preset.copyWith(key: 'newKey');
      // Should work without providing key since preset has it
      final copiedResult = await copied((ctx) => ctx);
      expect(copiedResult, 42);
    });

    test('params function receives MixContext for accessing retry info', () async {
      MixContext? capturedCtx;

      final preset = MixPreset.withUserContext<String, ()>(
        params: (ctx, config) {
          capturedCtx = ctx;
          return 'attempt: ${ctx.retry?.attempt ?? -1}';
        },
        defaultConfig: (),
        retry: RetryConfig(maxRetries: 0, initialDelay: 1.millis),
      );

      await preset(key: 'test', (ctx) => ctx);

      expect(capturedCtx, isNotNull);
    });

    test('works with retry configuration', () async {
      var attemptCount = 0;

      final preset = MixPreset.withUserContext<int, ()>(
        params: (ctx, config) => ctx.retry?.attempt ?? -1,
        defaultConfig: (),
        retry: RetryConfig(maxRetries: 2, initialDelay: 1.millis),
      );

      try {
        await preset(
          key: 'test',
          (attempt) {
            attemptCount++;
            throw Exception('fail');
          },
        );
      } catch (_) {}

      expect(attemptCount, 3); // Initial + 2 retries
    });

    test('works with checkInternet configuration', () async {
      Superpowers.clear(simulateInternet: () => false);

      final preset = MixPreset.withUserContext<String, ()>(
        params: (ctx, config) => 'value',
        defaultConfig: (),
        checkInternet: CheckInternetConfig(abortSilently: true),
      );

      var actionCalled = false;
      final result = await preset(
        key: 'test',
        (ctx) {
          actionCalled = true;
          return ctx;
        },
      );

      expect(actionCalled, false); // Should be aborted
      expect(result, null);

      // Restore internet simulation
      Superpowers.clear(simulateInternet: () => true);
    });

    test('is equivalent to direct MixPresetWithParams construction', () async {
      // Using MixPreset.withUserContext()
      final viaStatic = MixPreset.withUserContext<String, ({bool verbose})>(
        params: (ctx, config) => config.verbose ? 'VERBOSE' : 'quiet',
        defaultConfig: (verbose: false),
        key: 'test',
      );

      // Using MixPresetWithParams directly
      final viaDirect = MixPresetWithParams<String, ({bool verbose})>(
        params: (ctx, config) => config.verbose ? 'VERBOSE' : 'quiet',
        defaultConfig: (verbose: false),
        key: 'test',
      );

      // Both should behave identically
      final staticResult = await viaStatic(config: (verbose: true), (ctx) => ctx);
      final directResult = await viaDirect(config: (verbose: true), (ctx) => ctx);

      expect(staticResult, 'VERBOSE');
      expect(directResult, 'VERBOSE');
      expect(staticResult, directResult);
    });
  });
}
