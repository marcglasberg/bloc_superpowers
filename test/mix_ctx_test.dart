import 'dart:async';

import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    Superpowers.clear();
  });

  group('mix.ctx basic functionality', () {
    test('action receives MixContext parameter', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext, isNotNull);
    });

    test('returns value from action', () async {
      final result = await mix.ctx<int>(
        key: 'test',
        (ctx) => 42,
      );

      expect(result, 42);
    });

    test('async action works', () async {
      final result = await mix.ctx<int>(
        key: 'test',
        (ctx) async {
          await Future.delayed(const Duration(milliseconds: 10));
          return 42;
        },
      );

      expect(result, 42);
    });

    test('all contexts are null when no features configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.retry, isNull);
      expect(receivedContext!.nonReentrant, isNull);
      expect(receivedContext!.throttle, isNull);
      expect(receivedContext!.debounce, isNull);
      expect(receivedContext!.fresh, isNull);
      expect(receivedContext!.checkInternet, isNull);
      expect(receivedContext!.sequential, isNull);
    });
  });

  // ============================================================
  // RETRY CONTEXT TESTS
  // ============================================================

  group('mix.ctx retry context', () {
    test('retry context is null when retry not configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.retry, isNull);
    });

    test('retry context is null when only nonReentrant is configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        nonReentrant: nonReentrant,
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.retry, isNull);
      expect(receivedContext!.nonReentrant, isNotNull);
    });

    test('retry context is null when only throttle is configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        throttle: throttle(duration: 100.millis),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.retry, isNull);
      expect(receivedContext!.throttle, isNotNull);
    });

    test('retry context is null when only debounce is configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        debounce: debounce(duration: 50.millis),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.retry, isNull);
      expect(receivedContext!.debounce, isNotNull);
    });

    test('retry context is null when only fresh is configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        fresh: fresh(freshFor: 1.sec),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.retry, isNull);
      expect(receivedContext!.fresh, isNotNull);
    });

    test('retry context is null when only checkInternet is configured', () async {
      Superpowers.clear(simulateInternet: () => true);
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        checkInternet: checkInternet,
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.retry, isNull);
      expect(receivedContext!.checkInternet, isNotNull);
    });

    test('retry context is null when only sequential is configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        sequential: sequential,
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.retry, isNull);
      expect(receivedContext!.sequential, isNotNull);
    });

    test('retry context is non-null when retry configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        retry: retry,
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.retry, isNotNull);
      expect(receivedContext!.retry!.config, isNotNull);
    });

    test('retry context has default config values', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        retry: retry,
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.retry!.config.maxRetries, 3);
      expect(receivedContext!.retry!.config.initialDelay,
          const Duration(milliseconds: 350));
      expect(receivedContext!.retry!.config.multiplier, 2.0);
      expect(receivedContext!.retry!.config.maxDelay, const Duration(seconds: 5));
      expect(receivedContext!.retry!.config.onRetry, isNull);
    });

    test('retry context has custom config values', () async {
      MixContext? receivedContext;
      void myOnRetry(int attempt, Duration delay, Object error, StackTrace stack) {}

      await mix.ctx(
        key: 'test',
        retry: retry(
          maxRetries: 5,
          initialDelay: const Duration(milliseconds: 100),
          multiplier: 3.0,
          maxDelay: const Duration(seconds: 10),
          onRetry: myOnRetry,
        ),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.retry!.config.maxRetries, 5);
      expect(receivedContext!.retry!.config.initialDelay,
          const Duration(milliseconds: 100));
      expect(receivedContext!.retry!.config.multiplier, 3.0);
      expect(
          receivedContext!.retry!.config.maxDelay, const Duration(seconds: 10));
      expect(receivedContext!.retry!.config.onRetry, myOnRetry);
    });

    test('retry context has unlimited maxRetries when using unlimited', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        retry: retry.unlimited,
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.retry!.config.maxRetries, -1);
    });

    test('retry attempts starts at 0 on first try', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        retry: retry(maxRetries: 3),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.retry!.attempt, 0);
    });

    test('retry attempts increments on each retry', () async {
      final attemptsList = <int>[];

      await mix.ctx(
        key: 'test',
        retry: retry(
          maxRetries: 3,
          initialDelay: const Duration(milliseconds: 10),
        ),
        (ctx) {
          attemptsList.add(ctx.retry!.attempt);
          if (attemptsList.length < 3) {
            throw Exception('Retry me');
          }
        },
      );

      // First try: attempts=0, then retry 1: attempts=1, then retry 2: attempts=2
      expect(attemptsList, [0, 1, 2]);
    });

    test('retry attempts reflects all retries when action finally succeeds',
        () async {
      final attemptsList = <int>[];

      await mix.ctx(
        key: 'test',
        retry: retry(
          maxRetries: 5,
          initialDelay: const Duration(milliseconds: 10),
        ),
        (ctx) {
          attemptsList.add(ctx.retry!.attempt);
          if (attemptsList.length < 4) {
            throw Exception('Retry me');
          }
          return 'success';
        },
      );

      expect(attemptsList, [0, 1, 2, 3]);
    });

    test('retry attempts reaches maxRetries+1 when all retries exhausted',
        () async {
      final attemptsList = <int>[];

      try {
        await mix.ctx(
          key: 'test',
          retry: retry(
            maxRetries: 2,
            initialDelay: const Duration(milliseconds: 10),
          ),
          (ctx) {
            attemptsList.add(ctx.retry!.attempt);
            throw Exception('Always fail');
          },
        );
      } catch (_) {}

      // First try: attempts=0, retry 1: attempts=1, retry 2: attempts=2
      expect(attemptsList, [0, 1, 2]);
    });

    test('retry context shows config from mix.ctx call', () async {
      MixContext? ctx1;
      MixContext? ctx2;

      await mix.ctx(
        key: 'test1',
        retry: retry(maxRetries: 3),
        (ctx) {
          ctx1 = ctx;
        },
      );

      await mix.ctx(
        key: 'test2',
        retry: retry(maxRetries: 10),
        (ctx) {
          ctx2 = ctx;
        },
      );

      expect(ctx1!.retry!.config.maxRetries, 3);
      expect(ctx2!.retry!.config.maxRetries, 10);
    });
  });

  // ============================================================
  // NONREENTRANT CONTEXT TESTS
  // ============================================================

  group('mix.ctx nonReentrant context', () {
    test('nonReentrant context is null when not configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.nonReentrant, isNull);
    });

    test('nonReentrant context is null when only retry is configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        retry: retry,
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.nonReentrant, isNull);
      expect(receivedContext!.retry, isNotNull);
    });

    test('nonReentrant context is null when only throttle is configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        throttle: throttle(duration: 100.millis),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.nonReentrant, isNull);
      expect(receivedContext!.throttle, isNotNull);
    });

    test('nonReentrant context is null when only debounce is configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        debounce: debounce(duration: 50.millis),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.nonReentrant, isNull);
      expect(receivedContext!.debounce, isNotNull);
    });

    test('nonReentrant context is null when only fresh is configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        fresh: fresh(freshFor: 1.sec),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.nonReentrant, isNull);
      expect(receivedContext!.fresh, isNotNull);
    });

    test('nonReentrant context is null when only checkInternet is configured',
        () async {
      Superpowers.clear(simulateInternet: () => true);
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        checkInternet: checkInternet,
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.nonReentrant, isNull);
      expect(receivedContext!.checkInternet, isNotNull);
    });

    test('nonReentrant context is null when only sequential is configured',
        () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        sequential: sequential,
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.nonReentrant, isNull);
      expect(receivedContext!.sequential, isNotNull);
    });

    test('nonReentrant context is non-null when configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        nonReentrant: nonReentrant,
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.nonReentrant, isNotNull);
      expect(receivedContext!.nonReentrant!.config, isNotNull);
    });

    test('nonReentrant context has null key by default', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        nonReentrant: nonReentrant,
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.nonReentrant!.config.key, isNull);
    });

    test('nonReentrant context has custom key', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        nonReentrant: nonReentrant(key: 'customKey'),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.nonReentrant!.config.key, 'customKey');
    });

    test('nonReentrant context has tuple key', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        nonReentrant: nonReentrant(key: ('MyAction', 123)),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.nonReentrant!.config.key, ('MyAction', 123));
    });
  });

  // ============================================================
  // THROTTLE CONTEXT TESTS
  // ============================================================

  group('mix.ctx throttle context', () {
    test('throttle context is null when not configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.throttle, isNull);
    });

    test('throttle context is null when only retry is configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        retry: retry,
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.throttle, isNull);
      expect(receivedContext!.retry, isNotNull);
    });

    test('throttle context is null when only nonReentrant is configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        nonReentrant: nonReentrant,
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.throttle, isNull);
      expect(receivedContext!.nonReentrant, isNotNull);
    });

    test('throttle context is null when only debounce is configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        debounce: debounce(duration: 50.millis),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.throttle, isNull);
      expect(receivedContext!.debounce, isNotNull);
    });

    test('throttle context is null when only fresh is configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        fresh: fresh(freshFor: 1.sec),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.throttle, isNull);
      expect(receivedContext!.fresh, isNotNull);
    });

    test('throttle context is null when only checkInternet is configured', () async {
      Superpowers.clear(simulateInternet: () => true);
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        checkInternet: checkInternet,
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.throttle, isNull);
      expect(receivedContext!.checkInternet, isNotNull);
    });

    test('throttle context is null when only sequential is configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        sequential: sequential,
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.throttle, isNull);
      expect(receivedContext!.sequential, isNotNull);
    });

    test('throttle context is non-null when configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        throttle: throttle(duration: 100.millis),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.throttle, isNotNull);
      expect(receivedContext!.throttle!.config, isNotNull);
    });

    test('throttle context has default config values', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        throttle: throttle(),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.throttle!.config.key, isNull);
      expect(receivedContext!.throttle!.config.duration, const Duration(seconds: 1));
      expect(receivedContext!.throttle!.config.removeLockOnError, false);
      expect(receivedContext!.throttle!.config.ignoreThrottle, false);
    });

    test('throttle context has custom duration', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        throttle: throttle(duration: 500.millis),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.throttle!.config.duration, 500.millis);
    });

    test('throttle context has custom key', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        throttle: throttle(duration: 100.millis, key: 'myThrottleKey'),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.throttle!.config.key, 'myThrottleKey');
    });

    test('throttle context has removeLockOnError set to true', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        throttle: throttle(duration: 100.millis, removeLockOnError: true),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.throttle!.config.removeLockOnError, true);
    });

    test('throttle context has ignoreThrottle set to true', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        throttle: throttle(duration: 100.millis, ignoreThrottle: true),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.throttle!.config.ignoreThrottle, true);
    });

    test('throttle context has all custom config values', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        throttle: throttle(
          key: 'customKey',
          duration: 2.sec,
          removeLockOnError: true,
          ignoreThrottle: true,
        ),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.throttle!.config.key, 'customKey');
      expect(receivedContext!.throttle!.config.duration, 2.sec);
      expect(receivedContext!.throttle!.config.removeLockOnError, true);
      expect(receivedContext!.throttle!.config.ignoreThrottle, true);
    });
  });

  // ============================================================
  // DEBOUNCE CONTEXT TESTS
  // ============================================================

  group('mix.ctx debounce context', () {
    test('debounce context is null when not configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.debounce, isNull);
    });

    test('debounce context is null when only retry is configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        retry: retry,
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.debounce, isNull);
      expect(receivedContext!.retry, isNotNull);
    });

    test('debounce context is null when only nonReentrant is configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        nonReentrant: nonReentrant,
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.debounce, isNull);
      expect(receivedContext!.nonReentrant, isNotNull);
    });

    test('debounce context is null when only throttle is configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        throttle: throttle(duration: 100.millis),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.debounce, isNull);
      expect(receivedContext!.throttle, isNotNull);
    });

    test('debounce context is null when only fresh is configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        fresh: fresh(freshFor: 1.sec),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.debounce, isNull);
      expect(receivedContext!.fresh, isNotNull);
    });

    test('debounce context is null when only checkInternet is configured', () async {
      Superpowers.clear(simulateInternet: () => true);
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        checkInternet: checkInternet,
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.debounce, isNull);
      expect(receivedContext!.checkInternet, isNotNull);
    });

    test('debounce context is null when only sequential is configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        sequential: sequential,
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.debounce, isNull);
      expect(receivedContext!.sequential, isNotNull);
    });

    test('debounce context is non-null when configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        debounce: debounce(duration: 50.millis),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.debounce, isNotNull);
      expect(receivedContext!.debounce!.config, isNotNull);
    });

    test('debounce context has default config values', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        debounce: debounce(),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.debounce!.config.key, isNull);
      expect(
          receivedContext!.debounce!.config.duration, const Duration(milliseconds: 300));
    });

    test('debounce context has custom duration', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        debounce: debounce(duration: 100.millis),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.debounce!.config.duration, 100.millis);
    });

    test('debounce context has custom key', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        debounce: debounce(duration: 50.millis, key: 'searchDebounce'),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.debounce!.config.key, 'searchDebounce');
    });

    test('debounce context has all custom config values', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        debounce: debounce(key: 'myKey', duration: 200.millis),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.debounce!.config.key, 'myKey');
      expect(receivedContext!.debounce!.config.duration, 200.millis);
    });
  });

  // ============================================================
  // FRESH CONTEXT TESTS
  // ============================================================

  group('mix.ctx fresh context', () {
    test('fresh context is null when not configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.fresh, isNull);
    });

    test('fresh context is null when only retry is configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        retry: retry,
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.fresh, isNull);
      expect(receivedContext!.retry, isNotNull);
    });

    test('fresh context is null when only nonReentrant is configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        nonReentrant: nonReentrant,
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.fresh, isNull);
      expect(receivedContext!.nonReentrant, isNotNull);
    });

    test('fresh context is null when only throttle is configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        throttle: throttle(duration: 100.millis),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.fresh, isNull);
      expect(receivedContext!.throttle, isNotNull);
    });

    test('fresh context is null when only debounce is configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        debounce: debounce(duration: 50.millis),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.fresh, isNull);
      expect(receivedContext!.debounce, isNotNull);
    });

    test('fresh context is null when only checkInternet is configured', () async {
      Superpowers.clear(simulateInternet: () => true);
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        checkInternet: checkInternet,
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.fresh, isNull);
      expect(receivedContext!.checkInternet, isNotNull);
    });

    test('fresh context is null when only sequential is configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        sequential: sequential,
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.fresh, isNull);
      expect(receivedContext!.sequential, isNotNull);
    });

    test('fresh context is non-null when configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        fresh: fresh(freshFor: 1.sec),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.fresh, isNotNull);
      expect(receivedContext!.fresh!.config, isNotNull);
    });

    test('fresh context has default config values', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        fresh: fresh(),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.fresh!.config.key, isNull);
      expect(receivedContext!.fresh!.config.freshFor, const Duration(seconds: 1));
      expect(receivedContext!.fresh!.config.ignoreFresh, false);
    });

    test('fresh context has custom freshFor duration', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        fresh: fresh(freshFor: 5.sec),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.fresh!.config.freshFor, 5.sec);
    });

    test('fresh context has custom key', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        fresh: fresh(freshFor: 1.sec, key: 'userDataFresh'),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.fresh!.config.key, 'userDataFresh');
    });

    test('fresh context has ignoreFresh set to true', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        fresh: fresh(freshFor: 1.sec, ignoreFresh: true),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.fresh!.config.ignoreFresh, true);
    });

    test('fresh context has all custom config values', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        fresh: fresh(key: 'customFresh', freshFor: 10.sec, ignoreFresh: true),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.fresh!.config.key, 'customFresh');
      expect(receivedContext!.fresh!.config.freshFor, 10.sec);
      expect(receivedContext!.fresh!.config.ignoreFresh, true);
    });
  });

  // ============================================================
  // CHECKINTERNET CONTEXT TESTS
  // ============================================================

  group('mix.ctx checkInternet context', () {
    test('checkInternet context is null when not configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.checkInternet, isNull);
    });

    test('checkInternet context is null when only retry is configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        retry: retry,
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.checkInternet, isNull);
      expect(receivedContext!.retry, isNotNull);
    });

    test('checkInternet context is null when only nonReentrant is configured',
        () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        nonReentrant: nonReentrant,
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.checkInternet, isNull);
      expect(receivedContext!.nonReentrant, isNotNull);
    });

    test('checkInternet context is null when only throttle is configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        throttle: throttle(duration: 100.millis),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.checkInternet, isNull);
      expect(receivedContext!.throttle, isNotNull);
    });

    test('checkInternet context is null when only debounce is configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        debounce: debounce(duration: 50.millis),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.checkInternet, isNull);
      expect(receivedContext!.debounce, isNotNull);
    });

    test('checkInternet context is null when only fresh is configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        fresh: fresh(freshFor: 1.sec),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.checkInternet, isNull);
      expect(receivedContext!.fresh, isNotNull);
    });

    test('checkInternet context is null when only sequential is configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        sequential: sequential,
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.checkInternet, isNull);
      expect(receivedContext!.sequential, isNotNull);
    });

    test('checkInternet context is non-null when configured', () async {
      Superpowers.clear(simulateInternet: () => true);
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        checkInternet: checkInternet,
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.checkInternet, isNotNull);
      expect(receivedContext!.checkInternet!.config, isNotNull);
    });

    test('checkInternet context has default config values', () async {
      Superpowers.clear(simulateInternet: () => true);
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        checkInternet: checkInternet,
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.checkInternet!.config.abortSilently, false);
      expect(receivedContext!.checkInternet!.config.ifOpenDialog, true);
      expect(receivedContext!.checkInternet!.config.maxRetryDelay,
          const Duration(seconds: 1));
    });

    test('checkInternet context has abortSilently set to true', () async {
      Superpowers.clear(simulateInternet: () => true);
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        checkInternet: checkInternet(abortSilently: true),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.checkInternet!.config.abortSilently, true);
    });

    test('checkInternet context has ifOpenDialog set to false', () async {
      Superpowers.clear(simulateInternet: () => true);
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        checkInternet: checkInternet(ifOpenDialog: false),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.checkInternet!.config.ifOpenDialog, false);
    });

    test('checkInternet context has custom maxRetryDelay', () async {
      Superpowers.clear(simulateInternet: () => true);
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        checkInternet: checkInternet(maxRetryDelay: 5.sec),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.checkInternet!.config.maxRetryDelay, 5.sec);
    });

    test('checkInternet context has all custom config values', () async {
      Superpowers.clear(simulateInternet: () => true);
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        checkInternet: checkInternet(
          abortSilently: true,
          ifOpenDialog: false,
          maxRetryDelay: 3.sec,
        ),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.checkInternet!.config.abortSilently, true);
      expect(receivedContext!.checkInternet!.config.ifOpenDialog, false);
      expect(receivedContext!.checkInternet!.config.maxRetryDelay, 3.sec);
    });
  });

  // ============================================================
  // SEQUENTIAL CONTEXT TESTS
  // ============================================================

  group('mix.ctx sequential context', () {
    test('sequential context is null when not configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.sequential, isNull);
    });

    test('sequential context is null when only retry is configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        retry: retry,
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.sequential, isNull);
      expect(receivedContext!.retry, isNotNull);
    });

    test('sequential context is null when only nonReentrant is configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        nonReentrant: nonReentrant,
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.sequential, isNull);
      expect(receivedContext!.nonReentrant, isNotNull);
    });

    test('sequential context is null when only throttle is configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        throttle: throttle(duration: 100.millis),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.sequential, isNull);
      expect(receivedContext!.throttle, isNotNull);
    });

    test('sequential context is null when only debounce is configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        debounce: debounce(duration: 50.millis),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.sequential, isNull);
      expect(receivedContext!.debounce, isNotNull);
    });

    test('sequential context is null when only fresh is configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        fresh: fresh(freshFor: 1.sec),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.sequential, isNull);
      expect(receivedContext!.fresh, isNotNull);
    });

    test('sequential context is null when only checkInternet is configured', () async {
      Superpowers.clear(simulateInternet: () => true);
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        checkInternet: checkInternet,
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.sequential, isNull);
      expect(receivedContext!.checkInternet, isNotNull);
    });

    test('sequential context is non-null when configured', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        sequential: sequential,
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.sequential, isNotNull);
      expect(receivedContext!.sequential!.config, isNotNull);
    });

    test('sequential context has default config values', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        sequential: sequential,
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.sequential!.config.key, isNull);
      expect(receivedContext!.sequential!.config.maxQueueSize, isNull);
      expect(receivedContext!.sequential!.config.queueTimeout, isNull);
    });

    test('sequential context has custom key', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        sequential: sequential(key: 'myQueue'),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.sequential!.config.key, 'myQueue');
    });

    test('sequential context has tuple key', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        sequential: sequential(key: ('ChatQueue', 456)),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.sequential!.config.key, ('ChatQueue', 456));
    });

    test('sequential context has custom maxQueueSize', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        sequential: sequential(maxQueueSize: 10),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.sequential!.config.maxQueueSize, 10);
    });

    test('sequential context has custom queueTimeout', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        sequential: sequential(queueTimeout: 30.sec),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.sequential!.config.queueTimeout, 30.sec);
    });

    test('sequential context has all custom config values', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        sequential: sequential(
          key: 'customQueue',
          maxQueueSize: 5,
          queueTimeout: 15.sec,
        ),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.sequential!.config.key, 'customQueue');
      expect(receivedContext!.sequential!.config.maxQueueSize, 5);
      expect(receivedContext!.sequential!.config.queueTimeout, 15.sec);
    });
  });

  // ============================================================
  // MULTIPLE CONTEXTS COMBINATIONS
  // ============================================================

  group('mix.ctx multiple contexts combinations', () {
    test('retry + nonReentrant: both contexts present, others null', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        retry: retry(maxRetries: 2),
        nonReentrant: nonReentrant(key: 'myKey'),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.retry, isNotNull);
      expect(receivedContext!.retry!.config.maxRetries, 2);
      expect(receivedContext!.nonReentrant, isNotNull);
      expect(receivedContext!.nonReentrant!.config.key, 'myKey');
      expect(receivedContext!.throttle, isNull);
      expect(receivedContext!.debounce, isNull);
      expect(receivedContext!.fresh, isNull);
      expect(receivedContext!.checkInternet, isNull);
      expect(receivedContext!.sequential, isNull);
    });

    test('throttle + debounce: both contexts present, others null', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        throttle: throttle(duration: 500.millis),
        debounce: debounce(duration: 200.millis),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.throttle, isNotNull);
      expect(receivedContext!.throttle!.config.duration, 500.millis);
      expect(receivedContext!.debounce, isNotNull);
      expect(receivedContext!.debounce!.config.duration, 200.millis);
      expect(receivedContext!.retry, isNull);
      expect(receivedContext!.nonReentrant, isNull);
      expect(receivedContext!.fresh, isNull);
      expect(receivedContext!.checkInternet, isNull);
      expect(receivedContext!.sequential, isNull);
    });

    test('fresh + checkInternet: both contexts present, others null', () async {
      Superpowers.clear(simulateInternet: () => true);
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        fresh: fresh(freshFor: 5.sec),
        checkInternet: checkInternet(abortSilently: true),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.fresh, isNotNull);
      expect(receivedContext!.fresh!.config.freshFor, 5.sec);
      expect(receivedContext!.checkInternet, isNotNull);
      expect(receivedContext!.checkInternet!.config.abortSilently, true);
      expect(receivedContext!.retry, isNull);
      expect(receivedContext!.nonReentrant, isNull);
      expect(receivedContext!.throttle, isNull);
      expect(receivedContext!.debounce, isNull);
      expect(receivedContext!.sequential, isNull);
    });

    test('sequential + retry: both contexts present, others null', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        sequential: sequential(maxQueueSize: 3),
        retry: retry(maxRetries: 5),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.sequential, isNotNull);
      expect(receivedContext!.sequential!.config.maxQueueSize, 3);
      expect(receivedContext!.retry, isNotNull);
      expect(receivedContext!.retry!.config.maxRetries, 5);
      expect(receivedContext!.nonReentrant, isNull);
      expect(receivedContext!.throttle, isNull);
      expect(receivedContext!.debounce, isNull);
      expect(receivedContext!.fresh, isNull);
      expect(receivedContext!.checkInternet, isNull);
    });

    test('all contexts present when all features configured', () async {
      Superpowers.clear(simulateInternet: () => true);
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        retry: retry(maxRetries: 3),
        nonReentrant: nonReentrant(key: 'nrKey'),
        throttle: throttle(duration: 100.millis),
        debounce: debounce(duration: 50.millis),
        fresh: fresh(freshFor: 1.sec),
        checkInternet: checkInternet,
        sequential: sequential,
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.retry, isNotNull);
      expect(receivedContext!.retry!.config.maxRetries, 3);
      expect(receivedContext!.nonReentrant, isNotNull);
      expect(receivedContext!.nonReentrant!.config.key, 'nrKey');
      expect(receivedContext!.throttle, isNotNull);
      expect(receivedContext!.throttle!.config.duration, 100.millis);
      expect(receivedContext!.debounce, isNotNull);
      expect(receivedContext!.debounce!.config.duration, 50.millis);
      expect(receivedContext!.fresh, isNotNull);
      expect(receivedContext!.fresh!.config.freshFor, 1.sec);
      expect(receivedContext!.checkInternet, isNotNull);
      expect(receivedContext!.sequential, isNotNull);
    });

    test('three contexts: retry + debounce + sequential', () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        retry: retry(maxRetries: 4, initialDelay: 50.millis),
        debounce: debounce(duration: 100.millis, key: 'debounceKey'),
        sequential: sequential(maxQueueSize: 5, queueTimeout: 10.sec),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.retry, isNotNull);
      expect(receivedContext!.retry!.config.maxRetries, 4);
      expect(receivedContext!.retry!.config.initialDelay, 50.millis);
      expect(receivedContext!.debounce, isNotNull);
      expect(receivedContext!.debounce!.config.duration, 100.millis);
      expect(receivedContext!.debounce!.config.key, 'debounceKey');
      expect(receivedContext!.sequential, isNotNull);
      expect(receivedContext!.sequential!.config.maxQueueSize, 5);
      expect(receivedContext!.sequential!.config.queueTimeout, 10.sec);
      expect(receivedContext!.nonReentrant, isNull);
      expect(receivedContext!.throttle, isNull);
      expect(receivedContext!.fresh, isNull);
      expect(receivedContext!.checkInternet, isNull);
    });
  });

  // ============================================================
  // CONTEXT INDEPENDENCE TESTS
  // ============================================================

  group('mix.ctx context independence', () {
    test('different mix.ctx calls have independent contexts', () async {
      MixContext? ctx1;
      MixContext? ctx2;

      await mix.ctx(
        key: 'test1',
        retry: retry(maxRetries: 1),
        throttle: throttle(duration: 100.millis),
        (ctx) {
          ctx1 = ctx;
        },
      );

      await mix.ctx(
        key: 'test2',
        retry: retry(maxRetries: 10),
        debounce: debounce(duration: 500.millis),
        (ctx) {
          ctx2 = ctx;
        },
      );

      // ctx1 has retry and throttle, no debounce
      expect(ctx1!.retry!.config.maxRetries, 1);
      expect(ctx1!.throttle!.config.duration, 100.millis);
      expect(ctx1!.debounce, isNull);

      // ctx2 has retry and debounce, no throttle
      expect(ctx2!.retry!.config.maxRetries, 10);
      expect(ctx2!.debounce!.config.duration, 500.millis);
      expect(ctx2!.throttle, isNull);
    });

    test('context from one call does not affect another call', () async {
      MixContext? firstContext;
      MixContext? secondContext;

      // First call with all features
      Superpowers.clear(simulateInternet: () => true);
      await mix.ctx(
        key: 'first',
        retry: retry,
        nonReentrant: nonReentrant,
        throttle: throttle(duration: 100.millis),
        debounce: debounce(duration: 50.millis),
        fresh: fresh(freshFor: 1.sec),
        checkInternet: checkInternet,
        sequential: sequential,
        (ctx) {
          firstContext = ctx;
        },
      );

      // Second call with no features
      await mix.ctx(
        key: 'second',
        (ctx) {
          secondContext = ctx;
        },
      );

      // First context should have all features
      expect(firstContext!.retry, isNotNull);
      expect(firstContext!.nonReentrant, isNotNull);
      expect(firstContext!.throttle, isNotNull);
      expect(firstContext!.debounce, isNotNull);
      expect(firstContext!.fresh, isNotNull);
      expect(firstContext!.checkInternet, isNotNull);
      expect(firstContext!.sequential, isNotNull);

      // Second context should have no features
      expect(secondContext!.retry, isNull);
      expect(secondContext!.nonReentrant, isNull);
      expect(secondContext!.throttle, isNull);
      expect(secondContext!.debounce, isNull);
      expect(secondContext!.fresh, isNull);
      expect(secondContext!.checkInternet, isNull);
      expect(secondContext!.sequential, isNull);
    });
  });

  // ============================================================
  // SYNC VS ASYNC EXECUTION PATH TESTS
  // ============================================================

  group('mix.ctx sync execution', () {
    test('sync action without async features executes synchronously', () {
      var executed = false;
      MixContext? receivedContext;

      final result = mix.ctx<int>(
        key: 'test',
        (ctx) {
          executed = true;
          receivedContext = ctx;
          return 42;
        },
      );

      expect(executed, true);
      expect(result, isNot(isA<Future>()));
      expect(result, 42);
      expect(receivedContext, isNotNull);
    });

    test('sync action with nonReentrant executes synchronously', () {
      var executed = false;

      final result = mix.ctx<int>(
        key: 'test',
        nonReentrant: nonReentrant,
        (ctx) {
          executed = true;
          expect(ctx.nonReentrant, isNotNull);
          return 42;
        },
      );

      expect(executed, true);
      expect(result, isNot(isA<Future>()));
      expect(result, 42);
    });

    test('sync action with throttle executes synchronously', () {
      var executed = false;

      final result = mix.ctx<int>(
        key: 'test',
        throttle: throttle(duration: 100.millis),
        (ctx) {
          executed = true;
          expect(ctx.throttle, isNotNull);
          return 42;
        },
      );

      expect(executed, true);
      expect(result, isNot(isA<Future>()));
      expect(result, 42);
    });

    test('sync action with fresh executes synchronously', () {
      var executed = false;

      final result = mix.ctx<int>(
        key: 'test',
        fresh: fresh(freshFor: 100.millis),
        (ctx) {
          executed = true;
          expect(ctx.fresh, isNotNull);
          return 42;
        },
      );

      expect(executed, true);
      expect(result, isNot(isA<Future>()));
      expect(result, 42);
    });

    test('sync action with nonReentrant+throttle+fresh executes synchronously', () {
      var executed = false;

      final result = mix.ctx<int>(
        key: 'test',
        nonReentrant: nonReentrant,
        throttle: throttle(duration: 100.millis),
        fresh: fresh(freshFor: 100.millis),
        (ctx) {
          executed = true;
          expect(ctx.nonReentrant, isNotNull);
          expect(ctx.throttle, isNotNull);
          expect(ctx.fresh, isNotNull);
          return 42;
        },
      );

      expect(executed, true);
      expect(result, isNot(isA<Future>()));
      expect(result, 42);
    });
  });

  group('mix.ctx async execution', () {
    test('sync action with debounce returns Future', () async {
      MixContext? receivedContext;

      final result = mix.ctx<int>(
        key: 'test',
        debounce: debounce(duration: 10.millis),
        (ctx) {
          receivedContext = ctx;
          return 42;
        },
      );

      expect(result, isA<Future>());
      expect(await result, 42);
      expect(receivedContext!.debounce, isNotNull);
    });

    test('sync action with retry returns Future', () async {
      MixContext? receivedContext;

      final result = mix.ctx<int>(
        key: 'test',
        retry: retry,
        (ctx) {
          receivedContext = ctx;
          return 42;
        },
      );

      expect(result, isA<Future>());
      expect(await result, 42);
      expect(receivedContext!.retry, isNotNull);
    });

    test('sync action with sequential returns Future', () async {
      MixContext? receivedContext;

      final result = mix.ctx<int>(
        key: 'test',
        sequential: sequential,
        (ctx) {
          receivedContext = ctx;
          return 42;
        },
      );

      expect(result, isA<Future>());
      expect(await result, 42);
      expect(receivedContext!.sequential, isNotNull);
    });

    test('sync action with checkInternet returns Future', () async {
      Superpowers.clear(simulateInternet: () => true);
      MixContext? receivedContext;

      final result = mix.ctx<int>(
        key: 'test',
        checkInternet: checkInternet,
        (ctx) {
          receivedContext = ctx;
          return 42;
        },
      );

      expect(result, isA<Future>());
      expect(await result, 42);
      expect(receivedContext!.checkInternet, isNotNull);
    });
  });

  // ============================================================
  // LIFECYCLE CALLBACKS TESTS
  // ============================================================

  group('mix.ctx with lifecycle callbacks', () {
    test('before and after callbacks work', () async {
      var beforeCalled = false;
      var afterCalled = false;

      await mix.ctx(
        key: 'test',
        config: MixConfig(
          before: () {
            beforeCalled = true;
          },
          after: () {
            afterCalled = true;
          },
        ),
        (ctx) {},
      );

      expect(beforeCalled, true);
      expect(afterCalled, true);
    });

    test('wrapRun callback works', () async {
      var wrapRunCalled = false;
      MixContext? receivedContext;

      await mix.ctx<int>(
        key: 'test',
        config: MixConfig(wrapRun: (action) {
          wrapRunCalled = true;
          return action();
        }),
        (ctx) {
          receivedContext = ctx;
          return 42;
        },
      );

      expect(wrapRunCalled, true);
      expect(receivedContext, isNotNull);
    });

    test('catchError callback works', () async {
      var catchErrorCalled = false;

      await mix.ctx(
        key: 'test',
        config: MixConfig(catchError: (e, s) {
          catchErrorCalled = true;
          // Return normally to suppress error
        }),
        (ctx) {
          throw Exception('Test error');
        },
      );

      expect(catchErrorCalled, true);
    });

    test('context is available in action when lifecycle callbacks are used',
        () async {
      MixContext? receivedContext;

      await mix.ctx(
        key: 'test',
        retry: retry(maxRetries: 2),
        throttle: throttle(duration: 100.millis),
        config: MixConfig(
          before: () {},
          after: () {},
          wrapRun: (action) => action(),
        ),
        (ctx) {
          receivedContext = ctx;
        },
      );

      expect(receivedContext!.retry, isNotNull);
      expect(receivedContext!.retry!.config.maxRetries, 2);
      expect(receivedContext!.throttle, isNotNull);
      expect(receivedContext!.throttle!.config.duration, 100.millis);
    });
  });

  // ============================================================
  // ABORT BEHAVIOR TESTS
  // ============================================================

  group('mix.ctx abort behavior', () {
    test('aborted by nonReentrant returns null', () async {
      final completer = Completer<void>();

      // Start blocking action
      final future1 = mix.ctx<void>(
        key: 'test',
        nonReentrant: nonReentrant,
        (ctx) async {
          await completer.future;
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // This should be aborted
      final result = mix.ctx<int>(
        key: 'test',
        nonReentrant: nonReentrant,
        (ctx) => 42,
      );

      expect(result, null);

      completer.complete();
      await future1;
    });

    test('aborted by throttle returns null', () {
      // First call sets throttle
      mix.ctx<void>(
        key: 'test',
        throttle: throttle(duration: 1.sec),
        (ctx) {},
      );

      // Second call should be aborted
      final result = mix.ctx<int>(
        key: 'test',
        throttle: throttle(duration: 1.sec),
        (ctx) => 42,
      );

      expect(result, null);
    });

    test('aborted by fresh returns null', () {
      // First call sets fresh
      mix.ctx<void>(
        key: 'test',
        fresh: fresh(freshFor: 1.sec),
        (ctx) {},
      );

      // Second call should be aborted
      final result = mix.ctx<int>(
        key: 'test',
        fresh: fresh(freshFor: 1.sec),
        (ctx) => 42,
      );

      expect(result, null);
    });
  });

  // ============================================================
  // WITHRETRYATTEMPTS METHOD TESTS
  // ============================================================
  // REAL-WORLD EXAMPLES
  // ============================================================

  group('mix.ctx real-world examples', () {
    test('showing retry progress to user', () async {
      final messages = <String>[];

      await mix.ctx(
        key: 'fetchData',
        retry: retry(
          maxRetries: 2,
          initialDelay: const Duration(milliseconds: 10),
        ),
        (ctx) {
          final attempt = ctx.retry!.attempt;
          final maxRetries = ctx.retry!.config.maxRetries; // No ! needed - ResolvedRetryConfig
          messages.add('Attempt ${attempt + 1} of ${maxRetries + 1}');

          if (attempt < 2) {
            throw Exception('Simulated failure');
          }
        },
      );

      expect(messages, [
        'Attempt 1 of 3',
        'Attempt 2 of 3',
        'Attempt 3 of 3',
      ]);
    });

    test('accessing config for conditional logic', () async {
      var shouldRetry = false;

      await mix.ctx(
        key: 'test',
        retry: retry(maxRetries: 5),
        (ctx) {
          // Decide based on config - no ! needed on maxRetries (ResolvedRetryConfig)
          shouldRetry = ctx.retry!.config.maxRetries > 3;
        },
      );

      expect(shouldRetry, true);
    });

    test('checking throttle config in action', () async {
      Duration? configuredDuration;

      await mix.ctx(
        key: 'test',
        throttle: throttle(duration: 2.sec),
        (ctx) {
          configuredDuration = ctx.throttle!.config.duration;
        },
      );

      expect(configuredDuration, 2.sec);
    });

    test('using context to log debounce settings', () async {
      final logs = <String>[];

      await mix.ctx(
        key: 'search',
        debounce: debounce(duration: 300.millis, key: 'searchDebounce'),
        (ctx) {
          logs.add('Debounce key: ${ctx.debounce!.config.key}');
          logs.add('Debounce duration: ${ctx.debounce!.config.duration}');
        },
      );

      expect(logs, [
        'Debounce key: searchDebounce',
        'Debounce duration: 0:00:00.300000',
      ]);
    });

    test('accessing sequential config for queue management', () async {
      int? maxSize;
      Duration? timeout;

      await mix.ctx(
        key: 'messageQueue',
        sequential: sequential(maxQueueSize: 50, queueTimeout: const Duration(minutes: 1)),
        (ctx) {
          maxSize = ctx.sequential!.config.maxQueueSize;
          timeout = ctx.sequential!.config.queueTimeout;
        },
      );

      expect(maxSize, 50);
      expect(timeout, const Duration(minutes: 1));
    });
  });

  group('mix.ctx sequential wasQueued and index', () {
    test('first call has wasQueued=false and index=0 (immediate)', () async {
      bool? wasQueued;
      int? index;

      await mix.ctx(
        key: 'test',
        sequential: sequential,
        (ctx) {
          wasQueued = ctx.sequential!.wasQueued;
          index = ctx.sequential!.index;
        },
      );

      expect(wasQueued, false);
      expect(index, 0);
    });

    test('second call has wasQueued=true and index=1 when first is still running',
        () async {
      final completer = Completer<void>();
      bool? wasQueued;
      int? index;

      // Start first call that blocks
      final future1 = mix.ctx<void>(
        key: 'test',
        sequential: sequential,
        (ctx) async {
          await completer.future;
        },
      );

      // Start second call while first is running
      final future2 = mix.ctx<void>(
        key: 'test',
        sequential: sequential,
        (ctx) {
          wasQueued = ctx.sequential!.wasQueued;
          index = ctx.sequential!.index;
        },
      );

      // Complete first call
      completer.complete();
      await future1;
      await future2;

      expect(wasQueued, true);
      expect(index, 1);
    });

    test('third call has wasQueued=true and index=2 when two calls are ahead',
        () async {
      final completer1 = Completer<void>();
      final completer2 = Completer<void>();
      final indices = <int>[];
      final wasQueuedList = <bool>[];

      // Start first call that blocks
      final future1 = mix.ctx<void>(
        key: 'test',
        sequential: sequential,
        (ctx) async {
          indices.add(ctx.sequential!.index);
          wasQueuedList.add(ctx.sequential!.wasQueued);
          await completer1.future;
        },
      );

      // Give time for first call to start
      await Future.delayed(const Duration(milliseconds: 10));

      // Start second call while first is running
      final future2 = mix.ctx<void>(
        key: 'test',
        sequential: sequential,
        (ctx) async {
          indices.add(ctx.sequential!.index);
          wasQueuedList.add(ctx.sequential!.wasQueued);
          await completer2.future;
        },
      );

      // Start third call while first two are in queue
      final future3 = mix.ctx<void>(
        key: 'test',
        sequential: sequential,
        (ctx) {
          indices.add(ctx.sequential!.index);
          wasQueuedList.add(ctx.sequential!.wasQueued);
        },
      );

      // Complete calls in order
      completer1.complete();
      await future1;
      completer2.complete();
      await future2;
      await future3;

      expect(indices, [0, 1, 2]);
      expect(wasQueuedList, [false, true, true]);
    });

    test('calls after queue is empty have wasQueued=false again', () async {
      final wasQueuedList = <bool>[];
      final indexList = <int>[];

      // First call
      await mix.ctx<void>(
        key: 'test',
        sequential: sequential,
        (ctx) {
          wasQueuedList.add(ctx.sequential!.wasQueued);
          indexList.add(ctx.sequential!.index);
        },
      );

      // Second call (after first completes)
      await mix.ctx<void>(
        key: 'test',
        sequential: sequential,
        (ctx) {
          wasQueuedList.add(ctx.sequential!.wasQueued);
          indexList.add(ctx.sequential!.index);
        },
      );

      // Both should be immediate since queue was empty
      expect(wasQueuedList, [false, false]);
      expect(indexList, [0, 0]);
    });

    test('different sequential keys have independent indices', () async {
      final completer = Completer<void>();
      int? indexA;
      int? indexB;

      // Start call on key A that blocks
      final futureA = mix.ctx<void>(
        key: 'test',
        sequential: sequential(key: 'A'),
        (ctx) async {
          indexA = ctx.sequential!.index;
          await completer.future;
        },
      );

      // Give time for first call to start
      await Future.delayed(const Duration(milliseconds: 10));

      // Call on key B should be immediate (different queue)
      await mix.ctx<void>(
        key: 'test',
        sequential: sequential(key: 'B'),
        (ctx) {
          indexB = ctx.sequential!.index;
        },
      );

      completer.complete();
      await futureA;

      expect(indexA, 0); // First in queue A
      expect(indexB, 0); // First in queue B (independent)
    });

    test('index reflects position even with maxQueueSize', () async {
      final completer = Completer<void>();
      final indices = <int>[];

      // Start first call that blocks
      final future1 = mix.ctx<void>(
        key: 'test',
        sequential: sequential(maxQueueSize: 2),
        (ctx) async {
          indices.add(ctx.sequential!.index);
          await completer.future;
        },
      );

      // Give time for first call to start
      await Future.delayed(const Duration(milliseconds: 10));

      // Queue up two more calls
      final future2 = mix.ctx<void>(
        key: 'test',
        sequential: sequential(maxQueueSize: 2),
        (ctx) {
          indices.add(ctx.sequential!.index);
        },
      );

      final future3 = mix.ctx<void>(
        key: 'test',
        sequential: sequential(maxQueueSize: 2),
        (ctx) {
          indices.add(ctx.sequential!.index);
        },
      );

      // Complete
      completer.complete();
      await future1;
      await future2;
      await future3;

      expect(indices, [0, 1, 2]);
    });

    test('dropped call never receives context (returns null)', () async {
      final completer = Completer<void>();
      var actionRanCount = 0;

      // Start first call that blocks
      final future1 = mix.ctx<void>(
        key: 'test',
        sequential: sequential(maxQueueSize: 0), // No queue allowed
        (ctx) async {
          actionRanCount++;
          await completer.future;
        },
      );

      // Give time for first call to start
      await Future.delayed(const Duration(milliseconds: 10));

      // Second call should be dropped (queue full)
      final result = await mix.ctx<int>(
        key: 'test',
        sequential: sequential(maxQueueSize: 0),
        (ctx) {
          actionRanCount++;
          return 42;
        },
      );

      completer.complete();
      await future1;

      expect(result, null); // Dropped
      expect(actionRanCount, 1); // Only first action ran
    });
  });

  // ============================================================
  // MIXCONFIG TESTS
  // ============================================================

  group('MixConfig', () {
    test('config with no retry does not enable retry', () async {
      var callCount = 0;

      try {
        await mix(
          key: 'test',
          config: const MixConfig(), // Empty config
          () {
            callCount++;
            throw Exception('Test error');
          },
        );
      } catch (_) {}

      expect(callCount, 1); // No retry, just one call
    });

    test('config.retry enables retry with defaults', () async {
      var callCount = 0;

      try {
        await mix(
          key: 'test',
          config: const MixConfig(retry: RetryConfig()),
          () {
            callCount++;
            throw Exception('Test error');
          },
        );
      } catch (_) {}

      // Default maxRetries is 3, so 1 initial + 3 retries = 4 calls
      expect(callCount, 4);
    });

    test('config.retry maxRetries is respected', () async {
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

      // maxRetries=5, so 1 initial + 5 retries = 6 calls
      expect(callCount, 6);
    });

    test('explicit retry overrides config.retry maxRetries', () async {
      var callCount = 0;

      try {
        await mix(
          key: 'test',
          config: MixConfig(retry: RetryConfig(maxRetries: 10, initialDelay: 1.millis)),
          retry: RetryConfig(maxRetries: 2), // Override to 2
          () {
            callCount++;
            throw Exception('Test error');
          },
        );
      } catch (_) {}

      // Explicit maxRetries=2, so 1 initial + 2 retries = 3 calls
      expect(callCount, 3);
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
            maxRetries: 2, // Override maxRetries
            // initialDelay and multiplier should come from config
            onRetry: (attempt, delay, e, s) => delays.add(delay),
          ),
          () {
            throw Exception('Test error');
          },
        );
      } catch (_) {}

      // Should use config's initialDelay (50ms) and multiplier (3.0)
      expect(delays.length, 2);
      expect(delays[0], 50.millis); // First retry: initialDelay
      expect(delays[1], 150.millis); // Second retry: 50ms * 3.0
    });

    test('defaults are applied when neither config nor explicit specify a value',
        () async {
      final delays = <Duration>[];

      try {
        await mix(
          key: 'test',
          config: MixConfig(
            retry: RetryConfig(maxRetries: 2),
            // initialDelay not specified - should use default
          ),
          retry: RetryConfig(
            // maxRetries not specified - should use config's 2
            onRetry: (attempt, delay, e, s) => delays.add(delay),
          ),
          () {
            throw Exception('Test error');
          },
        );
      } catch (_) {}

      // Should use default initialDelay (350ms)
      expect(delays.length, 2);
      expect(delays[0], 350.millis);
    });

    test('mix.ctx context reflects merged config', () async {
      MixContext? ctx;

      await mix.ctx(
        key: 'test',
        config: MixConfig(
          retry: RetryConfig(maxRetries: 7, multiplier: 4.0),
        ),
        retry: RetryConfig(maxRetries: 3), // Override only maxRetries
        (context) {
          ctx = context;
        },
      );

      expect(ctx!.retry, isNotNull);
      expect(ctx!.retry!.config.maxRetries, 3); // From explicit
      expect(ctx!.retry!.config.multiplier, 4.0); // From config
      expect(ctx!.retry!.config.initialDelay, 350.millis); // From defaults
    });

    test('config alone (no explicit retry) uses defaults for unspecified', () async {
      MixContext? ctx;

      await mix.ctx(
        key: 'test',
        config: MixConfig(
          retry: RetryConfig(maxRetries: 5),
          // Only maxRetries specified
        ),
        (context) {
          ctx = context;
        },
      );

      expect(ctx!.retry, isNotNull);
      expect(ctx!.retry!.config.maxRetries, 5); // From config
      expect(ctx!.retry!.config.initialDelay, 350.millis); // From defaults
      expect(ctx!.retry!.config.multiplier, 2.0); // From defaults
      expect(ctx!.retry!.config.maxDelay, 5.sec); // From defaults
    });

    test('RetryConfig.merge works correctly', () {
      final base = RetryConfig(maxRetries: 3, initialDelay: 100.millis);
      final overlay = RetryConfig(maxRetries: 5, multiplier: 3.0);

      final merged = base.merge(overlay);

      expect(merged.maxRetries, 5); // From overlay
      expect(merged.initialDelay, 100.millis); // From base (overlay is null)
      expect(merged.multiplier, 3.0); // From overlay
      expect(merged.maxDelay, null); // Both null
    });

    test('RetryConfig.merge with null returns this', () {
      final config = RetryConfig(maxRetries: 3);
      final merged = config.merge(null);

      expect(identical(merged, config), true);
    });

    test('MixConfig.merge works correctly', () {
      final base = MixConfig(retry: RetryConfig(maxRetries: 3));
      final overlay = MixConfig(retry: RetryConfig(multiplier: 5.0));

      final merged = base.merge(overlay);

      expect(merged.retry!.maxRetries, 3); // From base
      expect(merged.retry!.multiplier, 5.0); // From overlay
    });

    test('MixConfig.merge with null returns this', () {
      final config = MixConfig(retry: RetryConfig(maxRetries: 3));
      final merged = config.merge(null);

      expect(identical(merged, config), true);
    });

    test('reusable config pattern works', () async {
      // Define a reusable config
      const serverCallConfig = MixConfig(
        retry: RetryConfig(
          maxRetries: 5,
          initialDelay: Duration(milliseconds: 100),
          multiplier: 2.0,
        ),
      );

      var callCount = 0;

      try {
        await mix(
          key: 'test',
          config: serverCallConfig,
          () {
            callCount++;
            throw Exception('Server error');
          },
        );
      } catch (_) {}

      // Uses config's maxRetries=5
      expect(callCount, 6);
    });

    test('config can be overridden per-call', () async {
      const serverCallConfig = MixConfig(
        retry: RetryConfig(
          maxRetries: 5,
          initialDelay: Duration(milliseconds: 100),
        ),
      );

      var callCount = 0;

      try {
        await mix(
          key: 'test',
          config: serverCallConfig,
          retry: RetryConfig(maxRetries: 1), // Override for this call only
          () {
            callCount++;
            throw Exception('Server error');
          },
        );
      } catch (_) {}

      // Uses explicit maxRetries=1
      expect(callCount, 2);
    });
  });
}
