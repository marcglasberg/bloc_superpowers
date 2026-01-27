// Developed by Marcelo Glasberg (2026) https://glasberg.dev and https://github.com/marcglasberg
// For more info, see: https://pub.dartlang.org/packages/bloc_superpowers and http://blocsuperpowers.org
import 'package:bloc_superpowers/bloc_superpowers.dart';

/// Context object passed to [mix.ctx] action callback.
///
/// Provides access to runtime context for each feature used in the mix call.
/// Each context property is non-null only if the corresponding feature was
/// configured in the mix call.
///
/// Example:
/// ```dart
/// await mix.ctx(
///   key: 'test',
///   retry: retry(maxRetries: 3),
///   (ctx) {
///     // ctx.retry is nullable (check if retry was configured)
///     // but ctx.retry!.config.maxRetries is non-nullable (ResolvedRetryConfig)
///     print('Attempt ${ctx.retry!.attempt + 1} of ${ctx.retry!.config.maxRetries + 1}');
///     // do something
///   },
/// );
/// ```
class MixContext {
  /// Context for retry feature. Non-null if [mix.ctx] was called with [retry].
  final RetryContext? retry;

  /// Context for nonReentrant feature. Non-null if [mix.ctx] was called with [nonReentrant].
  final NonReentrantContext? nonReentrant;

  /// Context for throttle feature. Non-null if [mix.ctx] was called with [throttle].
  final ThrottleContext? throttle;

  /// Context for debounce feature. Non-null if [mix.ctx] was called with [debounce].
  final DebounceContext? debounce;

  /// Context for fresh feature. Non-null if [mix.ctx] was called with [fresh].
  final FreshContext? fresh;

  /// Context for checkInternet feature. Non-null if [mix.ctx] was called with [checkInternet].
  final CheckInternetContext? checkInternet;

  /// Context for sequential feature. Non-null if [mix.ctx] was called with [sequential].
  final SequentialContext? sequential;

  const MixContext({
    this.retry,
    this.nonReentrant,
    this.throttle,
    this.debounce,
    this.fresh,
    this.checkInternet,
    this.sequential,
  });
}

/// Context for the retry feature.
///
/// Provides access to the retry configuration and the current attempt number.
class RetryContext {
  /// The resolved retry configuration with non-nullable required fields.
  ///
  /// This is the merged result of defaults, [MixConfig.retry], and explicit retry parameter.
  final ResolvedRetryConfig config;

  /// The number of retry attempts so far.
  ///
  /// - If the action has not been retried yet, it will be 0.
  /// - If the action finished successfully, it will be equal or less than [ResolvedRetryConfig.maxRetries].
  /// - If the action failed and gave up, it will be equal to [ResolvedRetryConfig.maxRetries] plus 1
  ///   (or keep incrementing if maxRetries is -1 for unlimited retries).
  final int attempt;

  const RetryContext({
    required this.config,
    this.attempt = 0,
  });
}

/// Context for the nonReentrant feature.
///
/// Provides access to the nonReentrant configuration.
class NonReentrantContext {
  /// The resolved nonReentrant configuration with merged defaults.
  ///
  /// This is the merged result of defaults, [MixConfig.nonReentrant], and explicit nonReentrant parameter.
  final ResolvedNonReentrantConfig config;

  const NonReentrantContext({required this.config});
}

/// Context for the throttle feature.
///
/// Provides access to the throttle configuration.
class ThrottleContext {
  /// The resolved throttle configuration with non-nullable required fields.
  ///
  /// This is the merged result of defaults, [MixConfig.throttle], and explicit throttle parameter.
  final ResolvedThrottleConfig config;

  const ThrottleContext({required this.config});
}

/// Context for the debounce feature.
///
/// Provides access to the debounce configuration.
class DebounceContext {
  /// The resolved debounce configuration with non-nullable required fields.
  ///
  /// This is the merged result of defaults, [MixConfig.debounce], and explicit debounce parameter.
  final ResolvedDebounceConfig config;

  const DebounceContext({required this.config});
}

/// Context for the fresh feature.
///
/// Provides access to the fresh configuration.
class FreshContext {
  /// The resolved fresh configuration with non-nullable required fields.
  ///
  /// This is the merged result of defaults, [MixConfig.fresh], and explicit fresh parameter.
  final ResolvedFreshConfig config;

  const FreshContext({required this.config});
}

/// Context for the checkInternet feature.
///
/// Provides access to the checkInternet configuration.
class CheckInternetContext {
  /// The resolved checkInternet configuration with non-nullable required fields.
  ///
  /// This is the merged result of defaults, [MixConfig.checkInternet], and explicit checkInternet parameter.
  final ResolvedCheckInternetConfig config;

  const CheckInternetContext({required this.config});
}

/// Context for the sequential feature.
///
/// Provides access to the sequential configuration and queue status.
class SequentialContext {
  /// The resolved sequential configuration with non-nullable required fields.
  ///
  /// This is the merged result of defaults, [MixConfig.sequential], and explicit sequential parameter.
  final ResolvedSequentialConfig config;

  /// Whether this call had to wait in the queue before executing.
  ///
  /// - `false` = executed immediately (first in queue or queue was empty)
  /// - `true` = waited for previous calls to complete
  ///
  /// This is equivalent to `index > 0`.
  final bool wasQueued;

  /// The position in the queue when this call was added.
  ///
  /// - `0` = executed immediately (no calls ahead)
  /// - `1` = one call was ahead in the queue
  /// - `N` = N calls were ahead in the queue
  ///
  /// Note: If the call was dropped due to [ResolvedSequentialConfig.maxQueueSize],
  /// the action never executes and this context is never received.
  final int index;

  const SequentialContext({
    required this.config,
    required this.wasQueued,
    required this.index,
  });

  /// Creates a SequentialContext with default values (immediate execution).
  factory SequentialContext.immediate(ResolvedSequentialConfig config) =>
      SequentialContext(config: config, wasQueued: false, index: 0);
}
