// Developed by Marcelo Glasberg (2026) https://glasberg.dev and https://github.com/marcglasberg
// For more info, see: https://pub.dartlang.org/packages/bloc_superpowers and http://blocsuperpowers.org
import 'dart:async';

import './mix.dart';

/// Configuration for retry behavior in [mix].
///
/// Use the [retry] constant for defaults, or call it to override specific values:
/// ```dart
/// mix() // don't retry
/// mix(retry: retry) // uses defaults
/// mix(retry: retry(maxRetries: 5)) // defaults, but override maxRetries
/// mix(retry: retry.unlimited) // defaults, but with unlimited retries
/// mix(retry: retry(maxDelay: 10.secs)) // override maxDelay with 10 seconds
/// ```
class RetryConfig {
  final int? maxRetries;
  final Duration? initialDelay;
  final double? multiplier;
  final Duration? maxDelay;

  final void Function(
      int attempt, Duration delay, Object error, StackTrace stack)? onRetry;

  const RetryConfig({
    this.maxRetries,
    this.initialDelay,
    this.multiplier,
    this.maxDelay,
    this.onRetry,
  });

  /// Default retry configuration values.
  ///
  /// You can customize these defaults for your app:
  /// ```dart
  /// RetryConfig.defaults = RetryConfig(
  ///   maxRetries: 5,
  ///   initialDelay: Duration(milliseconds: 500),
  ///   multiplier: 2.0,
  ///   maxDelay: Duration(seconds: 10),
  /// );
  /// ```
  ///
  /// All required fields (maxRetries, initialDelay, multiplier, maxDelay)
  /// must be non-null. An [ArgumentError] is thrown if any are missing.
  static RetryConfig get defaults => _defaults;

  static set defaults(RetryConfig value) {
    if (value.maxRetries == null ||
        value.initialDelay == null ||
        value.multiplier == null ||
        value.maxDelay == null) {
      throw ArgumentError(
          'RetryConfig.defaults must have all required fields set: '
          'maxRetries, initialDelay, multiplier, maxDelay');
    }
    _defaults = value;
  }

  static RetryConfig _defaults = const RetryConfig(
    maxRetries: 3,
    initialDelay: Duration(milliseconds: 350),
    multiplier: 2.0,
    maxDelay: Duration(seconds: 5),
  );

  /// Merges [other] on top of this. Non-null values in [other] win.
  RetryConfig merge(RetryConfig? other) {
    if (other == null) return this;
    return RetryConfig(
      maxRetries: other.maxRetries ?? maxRetries,
      initialDelay: other.initialDelay ?? initialDelay,
      multiplier: other.multiplier ?? multiplier,
      maxDelay: other.maxDelay ?? maxDelay,
      onRetry: other.onRetry ?? onRetry,
    );
  }

  /// A [RetryConfig] that retries indefinitely.
  /// Usages:
  /// ```dart
  /// retry.unlimited` // default values with unlimited retries
  /// retry(maxDelay: 1.sec).unlimited` // override maxDelay, and unlimited retries
  /// retry.unlimited(maxDelay: 1.sec)` // override maxDelay, and unlimited retries
  /// ```
  RetryConfig get unlimited => call(maxRetries: -1);

  RetryConfig call({
    int? maxRetries,
    Duration? initialDelay,
    double? multiplier,
    Duration? maxDelay,
    void Function(int attempt, Duration delay, Object error, StackTrace stack)?
        onRetry,
  }) =>
      RetryConfig(
        maxRetries: maxRetries ?? this.maxRetries,
        initialDelay: initialDelay ?? this.initialDelay,
        multiplier: multiplier ?? this.multiplier,
        maxDelay: maxDelay ?? this.maxDelay,
        onRetry: onRetry ?? this.onRetry,
      );

  /// Creates a [ResolvedRetryConfig] from this config.
  ///
  /// All required fields must be non-null (typically after merging with defaults).
  /// Throws [StateError] if any required field is null.
  ResolvedRetryConfig resolve() => ResolvedRetryConfig(this);
}

/// Resolved retry configuration with non-nullable required fields.
///
/// This is the "output" version of [RetryConfig] that is used in [RetryContext]
/// after the config has been merged with defaults. Users accessing the config
/// in their callbacks get non-nullable fields without needing null assertions.
///
/// Created via [RetryConfig.resolve] after merging with [RetryConfig.defaults].
class ResolvedRetryConfig {
  /// Maximum number of retry attempts. Use -1 for unlimited retries.
  final int maxRetries;

  /// Initial delay before the first retry.
  final Duration initialDelay;

  /// Multiplier for exponential backoff. Each retry delay is multiplied by this.
  final double multiplier;

  /// Maximum delay between retries (caps the exponential growth).
  final Duration maxDelay;

  /// Optional callback called before each retry attempt.
  final void Function(
      int attempt, Duration delay, Object error, StackTrace stack)? onRetry;

  /// Creates a resolved config from a [RetryConfig].
  ///
  /// All required fields in [config] must be non-null.
  /// Throws [StateError] if any required field is null.
  ResolvedRetryConfig(RetryConfig config)
      : maxRetries = config.maxRetries ??
            (throw StateError('RetryConfig.maxRetries must not be null')),
        initialDelay = config.initialDelay ??
            (throw StateError('RetryConfig.initialDelay must not be null')),
        multiplier = config.multiplier ??
            (throw StateError('RetryConfig.multiplier must not be null')),
        maxDelay = config.maxDelay ??
            (throw StateError('RetryConfig.maxDelay must not be null')),
        onRetry = config.onRetry;
}

/// Configuration for internet connectivity checking in [mix].
///
/// Use the [checkInternet] constant for defaults, or call it to override specific values:
/// ```dart
/// mix(checkInternet: checkInternet) // uses defaults (abortSilently: false, ifOpenDialog: true)
/// mix(checkInternet: checkInternet(abortSilently: true)) // abort silently if no internet
/// mix(checkInternet: checkInternet(ifOpenDialog: false)) // throw without dialog
/// ```
class CheckInternetConfig {
  /// If `true`, returns null immediately without any exception when there is no internet.
  /// If `false`, throws a [ConnectionException].
  final bool? abortSilently;

  /// Only applies when [abortSilently] is `false`. If `true` (default), the
  /// [ConnectionException] is added to [Superpowers]'s error queue for dialog display.
  /// If `false`, the exception is rethrown for manual handling.
  final bool? ifOpenDialog;

  /// The maximum delay between retries when there is no internet.
  /// Only applies when combined with [RetryConfig] and [abortSilently] is `false`.
  /// Default is 1 second.
  final Duration? maxRetryDelay;

  /// Called when a call is blocked because there is no internet connection.
  /// This is called regardless of whether [abortSilently] is true or false.
  final void Function()? onNoInternet;

  const CheckInternetConfig({
    this.abortSilently,
    this.ifOpenDialog,
    this.maxRetryDelay,
    this.onNoInternet,
  });

  /// Default checkInternet configuration values.
  ///
  /// You can customize these defaults for your app:
  /// ```dart
  /// CheckInternetConfig.defaults = CheckInternetConfig(
  ///   abortSilently: true,
  ///   ifOpenDialog: false,
  ///   maxRetryDelay: Duration(seconds: 2),
  /// );
  /// ```
  ///
  /// All required fields (abortSilently, ifOpenDialog, maxRetryDelay)
  /// must be non-null. An [ArgumentError] is thrown if any are missing.
  static CheckInternetConfig get defaults => _defaults;

  static set defaults(CheckInternetConfig value) {
    if (value.abortSilently == null ||
        value.ifOpenDialog == null ||
        value.maxRetryDelay == null) {
      throw ArgumentError(
          'CheckInternetConfig.defaults must have all required fields set: '
          'abortSilently, ifOpenDialog, maxRetryDelay');
    }
    _defaults = value;
  }

  static CheckInternetConfig _defaults = const CheckInternetConfig(
    abortSilently: false,
    ifOpenDialog: true,
    maxRetryDelay: Duration(seconds: 1),
  );

  /// Merges [other] on top of this. Non-null values in [other] win.
  CheckInternetConfig merge(CheckInternetConfig? other) {
    if (other == null) return this;
    return CheckInternetConfig(
      abortSilently: other.abortSilently ?? abortSilently,
      ifOpenDialog: other.ifOpenDialog ?? ifOpenDialog,
      maxRetryDelay: other.maxRetryDelay ?? maxRetryDelay,
      onNoInternet: other.onNoInternet ?? onNoInternet,
    );
  }

  CheckInternetConfig call({
    bool? abortSilently,
    bool? ifOpenDialog,
    Duration? maxRetryDelay,
    void Function()? onNoInternet,
  }) =>
      CheckInternetConfig(
        abortSilently: abortSilently ?? this.abortSilently,
        ifOpenDialog: ifOpenDialog ?? this.ifOpenDialog,
        maxRetryDelay: maxRetryDelay ?? this.maxRetryDelay,
        onNoInternet: onNoInternet ?? this.onNoInternet,
      );

  /// Creates a [ResolvedCheckInternetConfig] from this config.
  ///
  /// All required fields must be non-null (typically after merging with defaults).
  /// Throws [StateError] if any required field is null.
  ResolvedCheckInternetConfig resolve() => ResolvedCheckInternetConfig(this);
}

/// Resolved checkInternet configuration with non-nullable required fields.
///
/// This is the "output" version of [CheckInternetConfig] that is used in [CheckInternetContext]
/// after the config has been merged with defaults. Users accessing the config
/// in their callbacks get non-nullable fields without needing null assertions.
///
/// Created via [CheckInternetConfig.resolve] after merging with [CheckInternetConfig.defaults].
class ResolvedCheckInternetConfig {
  /// If `true`, returns null immediately without any exception when there is no internet.
  /// If `false`, throws a [ConnectionException].
  final bool abortSilently;

  /// Only applies when [abortSilently] is `false`. If `true`, the
  /// [ConnectionException] is added to [Superpowers]'s error queue for dialog display.
  /// If `false`, the exception is rethrown for manual handling.
  final bool ifOpenDialog;

  /// The maximum delay between retries when there is no internet.
  final Duration maxRetryDelay;

  /// Optional callback called when there is no internet connection.
  final void Function()? onNoInternet;

  /// Creates a resolved config from a [CheckInternetConfig].
  ///
  /// All required fields in [config] must be non-null.
  /// Throws [StateError] if any required field is null.
  ResolvedCheckInternetConfig(CheckInternetConfig config)
      : abortSilently = config.abortSilently ??
            (throw StateError(
                'CheckInternetConfig.abortSilently must not be null')),
        ifOpenDialog = config.ifOpenDialog ??
            (throw StateError(
                'CheckInternetConfig.ifOpenDialog must not be null')),
        maxRetryDelay = config.maxRetryDelay ??
            (throw StateError(
                'CheckInternetConfig.maxRetryDelay must not be null')),
        onNoInternet = config.onNoInternet;
}

/// Configuration for non-reentrant protection in [mix].
///
/// Prevents concurrent executions with the same key. When a call with the same
/// key is already running, subsequent calls return immediately without executing.
///
///
/// ```dart
/// mix(nonReentrant: nonReentrant(key: 'saveUser'))
/// mix(nonReentrant: nonReentrant(key: (SaveUser, itemId))
/// ```
class NonReentrantConfig {
  final Object? key;

  /// Called when a call is blocked because another execution with the same key
  /// is already in progress. Receives the effective key that was blocked.
  final void Function(Object key)? onBlocked;

  const NonReentrantConfig({this.key, this.onBlocked});

  /// Default nonReentrant configuration values.
  ///
  /// Since NonReentrantConfig has no required fields, defaults is an empty config.
  static NonReentrantConfig get defaults => _defaults;

  static set defaults(NonReentrantConfig value) {
    _defaults = value;
  }

  static NonReentrantConfig _defaults = const NonReentrantConfig();

  /// Merges [other] on top of this. Non-null values in [other] win.
  NonReentrantConfig merge(NonReentrantConfig? other) {
    if (other == null) return this;
    return NonReentrantConfig(
      key: other.key ?? key,
      onBlocked: other.onBlocked ?? onBlocked,
    );
  }

  NonReentrantConfig call(
          {Object? key, void Function(Object key)? onBlocked}) =>
      NonReentrantConfig(
        key: key ?? this.key,
        onBlocked: onBlocked ?? this.onBlocked,
      );

  /// Creates a [ResolvedNonReentrantConfig] from this config.
  ResolvedNonReentrantConfig resolve() => ResolvedNonReentrantConfig(this);
}

/// Resolved nonReentrant configuration.
///
/// This is the "output" version of [NonReentrantConfig] that is used in [NonReentrantContext]
/// after the config has been merged with defaults. Since NonReentrantConfig has no required
/// fields, all fields remain nullable.
///
/// Created via [NonReentrantConfig.resolve] after merging with [NonReentrantConfig.defaults].
class ResolvedNonReentrantConfig {
  /// Override key for non-reentrant isolation. If null, uses the mix key.
  final Object? key;

  /// Optional callback called when a call is blocked.
  final void Function(Object key)? onBlocked;

  /// Creates a resolved config from a [NonReentrantConfig].
  ResolvedNonReentrantConfig(NonReentrantConfig config)
      : key = config.key,
        onBlocked = config.onBlocked;
}

/// Configuration for throttle (rate limiting) in [mix].
///
/// The first call executes immediately and sets a lock; subsequent calls with
/// the same key are aborted until the throttle period expires.
///
/// ```dart
/// mix(throttle: throttle('refresh', duration: 1.sec)
/// mix(throttle: throttle('submit', duration: 1.sec), removeLockOnError: true)
/// ```
class ThrottleConfig {
  final Object? key;

  /// The throttle duration.
  final Duration? duration;

  /// If `true`, the lock is removed on error, allowing immediate retry after failure.
  final bool? removeLockOnError;

  /// If `true`, bypasses the throttle check for this specific call (force execution).
  final bool? ignoreThrottle;

  /// Called when a call is throttled (blocked due to rate limiting).
  /// Receives the effective key and the remaining time until the lock expires.
  final void Function(Object key, Duration remainingTime)? onThrottled;

  const ThrottleConfig({
    this.key,
    this.duration,
    this.removeLockOnError,
    this.ignoreThrottle,
    this.onThrottled,
  });

  /// Default throttle configuration values.
  ///
  /// You can customize these defaults for your app:
  /// ```dart
  /// ThrottleConfig.defaults = ThrottleConfig(
  ///   duration: Duration(seconds: 2),
  ///   removeLockOnError: true,
  /// );
  /// ```
  ///
  /// All required fields (duration, removeLockOnError, ignoreThrottle)
  /// must be non-null. An [ArgumentError] is thrown if any are missing.
  static ThrottleConfig get defaults => _defaults;

  static set defaults(ThrottleConfig value) {
    if (value.duration == null ||
        value.removeLockOnError == null ||
        value.ignoreThrottle == null) {
      throw ArgumentError(
          'ThrottleConfig.defaults must have all required fields set: '
          'duration, removeLockOnError, ignoreThrottle');
    }
    _defaults = value;
  }

  static ThrottleConfig _defaults = const ThrottleConfig(
    duration: Duration(seconds: 1),
    removeLockOnError: false,
    ignoreThrottle: false,
  );

  /// Merges [other] on top of this. Non-null values in [other] win.
  ThrottleConfig merge(ThrottleConfig? other) {
    if (other == null) return this;
    return ThrottleConfig(
      key: other.key ?? key,
      duration: other.duration ?? duration,
      removeLockOnError: other.removeLockOnError ?? removeLockOnError,
      ignoreThrottle: other.ignoreThrottle ?? ignoreThrottle,
      onThrottled: other.onThrottled ?? onThrottled,
    );
  }

  ThrottleConfig call({
    Object? key,
    Duration? duration,
    bool? removeLockOnError,
    bool? ignoreThrottle,
    void Function(Object key, Duration remainingTime)? onThrottled,
  }) =>
      ThrottleConfig(
        key: key ?? this.key,
        duration: duration ?? this.duration,
        removeLockOnError: removeLockOnError ?? this.removeLockOnError,
        ignoreThrottle: ignoreThrottle ?? this.ignoreThrottle,
        onThrottled: onThrottled ?? this.onThrottled,
      );

  /// Creates a [ResolvedThrottleConfig] from this config.
  ///
  /// All required fields must be non-null (typically after merging with defaults).
  /// Throws [StateError] if any required field is null.
  ResolvedThrottleConfig resolve() => ResolvedThrottleConfig(this);
}

/// Resolved throttle configuration with non-nullable required fields.
///
/// This is the "output" version of [ThrottleConfig] that is used in [ThrottleContext]
/// after the config has been merged with defaults. Users accessing the config
/// in their callbacks get non-nullable fields without needing null assertions.
///
/// Created via [ThrottleConfig.resolve] after merging with [ThrottleConfig.defaults].
class ResolvedThrottleConfig {
  /// Override key for throttle isolation. If null, uses the mix key.
  final Object? key;

  /// The throttle duration.
  final Duration duration;

  /// If `true`, the lock is removed on error, allowing immediate retry after failure.
  final bool removeLockOnError;

  /// If `true`, bypasses the throttle check for this specific call (force execution).
  final bool ignoreThrottle;

  /// Optional callback called when a call is throttled.
  final void Function(Object key, Duration remainingTime)? onThrottled;

  /// Creates a resolved config from a [ThrottleConfig].
  ///
  /// All required fields in [config] must be non-null.
  /// Throws [StateError] if any required field is null.
  ResolvedThrottleConfig(ThrottleConfig config)
      : key = config.key,
        duration = config.duration ??
            (throw StateError('ThrottleConfig.duration must not be null')),
        removeLockOnError = config.removeLockOnError ??
            (throw StateError(
                'ThrottleConfig.removeLockOnError must not be null')),
        ignoreThrottle = config.ignoreThrottle ??
            (throw StateError(
                'ThrottleConfig.ignoreThrottle must not be null')),
        onThrottled = config.onThrottled;
}

/// Configuration for debounce in [mix].
///
/// Delays execution and allows superseding. When called, waits for the debounce
/// period; if another call with the same key occurs during the wait, the earlier
/// call is aborted and only the later one executes.
///
/// ```dart
/// mix(debounce: debounce(key: 'search', duration: 300.millis)
/// ```
class DebounceConfig {
  final Object? key;

  /// The debounce period.
  final Duration? duration;

  /// Called when a call is superseded by a newer call with the same key.
  /// Receives the effective key that was superseded.
  final void Function(Object key)? onSuperseded;

  const DebounceConfig({
    this.key,
    this.duration,
    this.onSuperseded,
  });

  /// Default debounce configuration values.
  ///
  /// You can customize these defaults for your app:
  /// ```dart
  /// DebounceConfig.defaults = DebounceConfig(
  ///   duration: Duration(milliseconds: 500),
  /// );
  /// ```
  ///
  /// The duration field must be non-null. An [ArgumentError] is thrown if missing.
  static DebounceConfig get defaults => _defaults;

  static set defaults(DebounceConfig value) {
    if (value.duration == null) {
      throw ArgumentError(
          'DebounceConfig.defaults must have all required fields set: duration');
    }
    _defaults = value;
  }

  static DebounceConfig _defaults = const DebounceConfig(
    duration: Duration(milliseconds: 300),
  );

  /// Merges [other] on top of this. Non-null values in [other] win.
  DebounceConfig merge(DebounceConfig? other) {
    if (other == null) return this;
    return DebounceConfig(
      key: other.key ?? key,
      duration: other.duration ?? duration,
      onSuperseded: other.onSuperseded ?? onSuperseded,
    );
  }

  DebounceConfig call({
    Object? key,
    Duration? duration,
    void Function(Object key)? onSuperseded,
  }) =>
      DebounceConfig(
        key: key ?? this.key,
        duration: duration ?? this.duration,
        onSuperseded: onSuperseded ?? this.onSuperseded,
      );

  /// Creates a [ResolvedDebounceConfig] from this config.
  ///
  /// All required fields must be non-null (typically after merging with defaults).
  /// Throws [StateError] if any required field is null.
  ResolvedDebounceConfig resolve() => ResolvedDebounceConfig(this);
}

/// Resolved debounce configuration with non-nullable required fields.
///
/// This is the "output" version of [DebounceConfig] that is used in [DebounceContext]
/// after the config has been merged with defaults. Users accessing the config
/// in their callbacks get non-nullable fields without needing null assertions.
///
/// Created via [DebounceConfig.resolve] after merging with [DebounceConfig.defaults].
class ResolvedDebounceConfig {
  /// Override key for debounce isolation. If null, uses the mix key.
  final Object? key;

  /// The debounce period.
  final Duration duration;

  /// Optional callback called when a call is superseded.
  final void Function(Object key)? onSuperseded;

  /// Creates a resolved config from a [DebounceConfig].
  ///
  /// All required fields in [config] must be non-null.
  /// Throws [StateError] if any required field is null.
  ResolvedDebounceConfig(DebounceConfig config)
      : key = config.key,
        duration = config.duration ??
            (throw StateError('DebounceConfig.duration must not be null')),
        onSuperseded = config.onSuperseded;
}

/// Configuration for fresh (cache invalidation) in [mix].
///
/// Prevents re-execution while the result is still "fresh". After successful
/// completion, subsequent calls with the same key within the [duration] period
/// are aborted.
///
/// ```dart
/// mix(fresh: fresh(key: 'loadUser', duration: 5.sec)
/// mix(fresh: fresh(key: ('LoadUser', userId), duration: 5.sec)
/// ```
class FreshConfig {
  final Object? key;

  /// The duration for which the result is considered fresh.
  final Duration? freshFor;

  /// If `true`, bypasses the fresh check for this specific call (force refresh).
  final bool? ignoreFresh;

  /// Called when a call is skipped because the data is still fresh.
  /// Receives the effective key and the remaining time until the data becomes stale.
  final void Function(Object key, Duration remainingFreshTime)? onFresh;

  const FreshConfig({
    this.key,
    this.freshFor,
    this.ignoreFresh,
    this.onFresh,
  });

  /// Default fresh configuration values.
  ///
  /// You can customize these defaults for your app:
  /// ```dart
  /// FreshConfig.defaults = FreshConfig(
  ///   freshFor: Duration(seconds: 5),
  ///   ignoreFresh: false,
  /// );
  /// ```
  ///
  /// All required fields (freshFor, ignoreFresh) must be non-null.
  /// An [ArgumentError] is thrown if any are missing.
  static FreshConfig get defaults => _defaults;

  static set defaults(FreshConfig value) {
    if (value.freshFor == null || value.ignoreFresh == null) {
      throw ArgumentError(
          'FreshConfig.defaults must have all required fields set: '
          'freshFor, ignoreFresh');
    }
    _defaults = value;
  }

  static FreshConfig _defaults = const FreshConfig(
    freshFor: Duration(seconds: 1),
    ignoreFresh: false,
  );

  /// Merges [other] on top of this. Non-null values in [other] win.
  FreshConfig merge(FreshConfig? other) {
    if (other == null) return this;
    return FreshConfig(
      key: other.key ?? key,
      freshFor: other.freshFor ?? freshFor,
      ignoreFresh: other.ignoreFresh ?? ignoreFresh,
      onFresh: other.onFresh ?? onFresh,
    );
  }

  FreshConfig call({
    Object? key,
    Duration? freshFor,
    bool? ignoreFresh,
    void Function(Object key, Duration remainingFreshTime)? onFresh,
  }) =>
      FreshConfig(
        key: key ?? this.key,
        freshFor: freshFor ?? this.freshFor,
        ignoreFresh: ignoreFresh ?? this.ignoreFresh,
        onFresh: onFresh ?? this.onFresh,
      );

  /// Creates a [ResolvedFreshConfig] from this config.
  ///
  /// All required fields must be non-null (typically after merging with defaults).
  /// Throws [StateError] if any required field is null.
  ResolvedFreshConfig resolve() => ResolvedFreshConfig(this);
}

/// Resolved fresh configuration with non-nullable required fields.
///
/// This is the "output" version of [FreshConfig] that is used in [FreshContext]
/// after the config has been merged with defaults. Users accessing the config
/// in their callbacks get non-nullable fields without needing null assertions.
///
/// Created via [FreshConfig.resolve] after merging with [FreshConfig.defaults].
class ResolvedFreshConfig {
  /// Override key for fresh isolation. If null, uses the mix key.
  final Object? key;

  /// The duration for which the result is considered fresh.
  final Duration freshFor;

  /// If `true`, bypasses the fresh check for this specific call (force refresh).
  final bool ignoreFresh;

  /// Optional callback called when a call is skipped because data is still fresh.
  final void Function(Object key, Duration remainingFreshTime)? onFresh;

  /// Creates a resolved config from a [FreshConfig].
  ///
  /// All required fields in [config] must be non-null.
  /// Throws [StateError] if any required field is null.
  ResolvedFreshConfig(FreshConfig config)
      : key = config.key,
        freshFor = config.freshFor ??
            (throw StateError('FreshConfig.freshFor must not be null')),
        ignoreFresh = config.ignoreFresh ??
            (throw StateError('FreshConfig.ignoreFresh must not be null')),
        onFresh = config.onFresh;
}

/// Reason why a sequential call was dropped.
enum SequentialDropReason {
  /// The queue was full and the new call was dropped (default behavior).
  queueFull,

  /// The call was dropped because a newer call arrived and [SequentialConfig.dropOldest] is true.
  superseded,

  /// The call waited longer than queueTimeout in the queue.
  timeout,
}

/// Configuration for sequential execution in [mix].
///
/// Queues method calls and processes them one after another. Unlike
/// [NonReentrantConfig] which drops subsequent calls, sequential ensures
/// every call eventually executes, in the order they were made.
///
/// ```dart
/// mix(sequential: sequential) // uses defaults
/// mix(sequential: sequential(key: (ChatCubit, chatId))) // separate queues per chat
/// mix(sequential: sequential(maxQueueSize: 10)) // limit queue size
/// mix(sequential: sequential(queueTimeout: 30.sec)) // timeout queued calls
/// mix(sequential: sequential(maxQueueSize: 2, dropOldest: true)) // drop oldest when full
/// ```
class SequentialConfig {
  /// Override key for queue isolation. If null, uses the mix key.
  final Object? key;

  /// Maximum number of calls that can be queued (not including the one
  /// currently running). When the queue is full, new calls are dropped
  /// (or oldest calls are dropped if [dropOldest] is true).
  /// If null (default), the queue is unlimited.
  final int? maxQueueSize;

  /// Maximum time a call can wait in the queue before being discarded.
  /// If null (default), calls wait indefinitely.
  final Duration? queueTimeout;

  /// If `true`, when the queue is full, the oldest waiting call is dropped
  /// to make room for the new one. This provides "latest wins" semantics
  /// while maintaining sequential execution.
  ///
  /// If `false` (default), new calls are dropped when the queue is full.
  ///
  /// Use cases for `dropOldest: true`:
  /// - User navigation: Follow user's latest selection, skip intermediate ones
  /// - Data refresh: Always process the most recent refresh request
  /// - Form auto-save: Ensure the latest state is saved
  final bool? dropOldest;

  /// Called when a call is added to the queue and has to wait.
  /// Receives the effective key and the position in the queue (1-indexed).
  final void Function(Object key, int queuePosition)? onQueued;

  /// Called when a call is dropped from the queue.
  /// Receives the effective key and the reason why it was dropped.
  final void Function(Object key, SequentialDropReason reason)? onDropped;

  const SequentialConfig({
    this.key,
    this.maxQueueSize,
    this.queueTimeout,
    this.dropOldest,
    this.onQueued,
    this.onDropped,
  });

  /// Default sequential configuration values.
  ///
  /// You can customize these defaults for your app:
  /// ```dart
  /// SequentialConfig.defaults = SequentialConfig(
  ///   dropOldest: true,
  /// );
  /// ```
  ///
  /// The dropOldest field must be non-null. An [ArgumentError] is thrown if missing.
  static SequentialConfig get defaults => _defaults;

  static set defaults(SequentialConfig value) {
    if (value.dropOldest == null) {
      throw ArgumentError(
          'SequentialConfig.defaults must have all required fields set: dropOldest');
    }
    _defaults = value;
  }

  static SequentialConfig _defaults = const SequentialConfig(
    dropOldest: false,
  );

  /// Merges [other] on top of this. Non-null values in [other] win.
  SequentialConfig merge(SequentialConfig? other) {
    if (other == null) return this;
    return SequentialConfig(
      key: other.key ?? key,
      maxQueueSize: other.maxQueueSize ?? maxQueueSize,
      queueTimeout: other.queueTimeout ?? queueTimeout,
      dropOldest: other.dropOldest ?? dropOldest,
      onQueued: other.onQueued ?? onQueued,
      onDropped: other.onDropped ?? onDropped,
    );
  }

  /// A [SequentialConfig] that keeps only the latest waiting call.
  ///
  /// When a new call arrives while one is running, any previously waiting
  /// call is superseded. Only the most recent call executes after the
  /// current one completes.
  ///
  /// This is similar to `bloc_concurrency`'s `restartable()`, but safer:
  /// - `restartable` aborts the currently running task
  /// - `latestWins` lets the running task complete, only supersedes waiting calls
  ///
  /// Usage:
  /// ```dart
  /// sequential.latestWins // keeps only the latest pending call
  /// sequential.latestWins(key: 'myKey') // with custom key
  /// sequential(queueTimeout: 5.sec).latestWins // with timeout, latest wins
  /// ```
  SequentialConfig get latestWins => call(maxQueueSize: 1, dropOldest: true);

  SequentialConfig call({
    Object? key,
    int? maxQueueSize,
    Duration? queueTimeout,
    bool? dropOldest,
    void Function(Object key, int queuePosition)? onQueued,
    void Function(Object key, SequentialDropReason reason)? onDropped,
  }) =>
      SequentialConfig(
        key: key ?? this.key,
        maxQueueSize: maxQueueSize ?? this.maxQueueSize,
        queueTimeout: queueTimeout ?? this.queueTimeout,
        dropOldest: dropOldest ?? this.dropOldest,
        onQueued: onQueued ?? this.onQueued,
        onDropped: onDropped ?? this.onDropped,
      );

  /// Creates a [ResolvedSequentialConfig] from this config.
  ///
  /// All required fields must be non-null (typically after merging with defaults).
  /// Throws [StateError] if any required field is null.
  ResolvedSequentialConfig resolve() => ResolvedSequentialConfig(this);
}

/// Resolved sequential configuration with non-nullable required fields.
///
/// This is the "output" version of [SequentialConfig] that is used in [SequentialContext]
/// after the config has been merged with defaults. Users accessing the config
/// in their callbacks get non-nullable fields without needing null assertions.
///
/// Created via [SequentialConfig.resolve] after merging with [SequentialConfig.defaults].
class ResolvedSequentialConfig {
  /// Override key for queue isolation. If null, uses the mix key.
  final Object? key;

  /// Maximum number of calls that can be queued. Null means unlimited.
  final int? maxQueueSize;

  /// Maximum time a call can wait in the queue. Null means indefinite.
  final Duration? queueTimeout;

  /// If `true`, oldest calls are dropped when queue is full.
  final bool dropOldest;

  /// Optional callback called when a call is added to the queue.
  final void Function(Object key, int queuePosition)? onQueued;

  /// Optional callback called when a call is dropped.
  final void Function(Object key, SequentialDropReason reason)? onDropped;

  /// Creates a resolved config from a [SequentialConfig].
  ///
  /// All required fields in [config] must be non-null.
  /// Throws [StateError] if any required field is null.
  ResolvedSequentialConfig(SequentialConfig config)
      : key = config.key,
        maxQueueSize = config.maxQueueSize,
        queueTimeout = config.queueTimeout,
        dropOldest = config.dropOldest ??
            (throw StateError('SequentialConfig.dropOldest must not be null')),
        onQueued = config.onQueued,
        onDropped = config.onDropped;
}

/// Pre-defined configuration for [mix] and [mix.ctx] functions.
///
/// Use this to define reusable configurations that can be shared across
/// multiple mix calls. Config values act as defaults that can be overridden
/// by explicit parameters in the mix call.
///
/// **Resolution order** (lowest to highest priority):
/// 1. Built-in defaults (e.g., `RetryConfig.defaults`)
/// 2. `config` parameter values
/// 3. Explicit parameters passed to `mix`/`mix.ctx`
///
/// **Example:**
/// ```dart
/// // Define reusable configs
/// class AppConfigs {
///   static const serverCall = MixConfig(
///     retry: RetryConfig(maxRetries: 5, multiplier: 3.0),
///     checkInternet: CheckInternetConfig(),
///   );
///
///   static final withLogging = MixConfig(
///     before: () => print('Starting...'),
///     after: () => print('Done!'),
///     catchError: (e, s) => throw UserException('API Error: $e'),
///   );
/// }
///
/// // Use config directly
/// mix(config: AppConfigs.serverCall, () async { ... });
///
/// // Override specific values
/// mix(
///   config: AppConfigs.serverCall,
///   retry: RetryConfig(maxRetries: 10),  // Overrides config's maxRetries
///   () async { ... },
/// );
/// // Result: maxRetries=10, multiplier=3.0 (from config)
/// ```
class MixConfig {
  final RetryConfig? retry;
  final CheckInternetConfig? checkInternet;
  final NonReentrantConfig? nonReentrant;
  final ThrottleConfig? throttle;
  final DebounceConfig? debounce;
  final FreshConfig? fresh;
  final SequentialConfig? sequential;

  /// Callback called once before the first attempt.
  final FutureOr<void> Function()? before;

  /// Callback called once after all attempts complete (success or failure).
  final FutureOr<void> Function()? after;

  /// Callback that wraps each execution of the action.
  final FutureOr<dynamic> Function(FutureOr<dynamic> Function() action)?
      wrapRun;

  /// Callback to handle errors. If it returns normally, the error is suppressed.
  /// If it throws (any error, original or modified), that error is propagated
  /// with the original stack trace. This follows the familiar try/catch pattern.
  final void Function(Object error, StackTrace stackTrace)? catchError;

  const MixConfig({
    this.retry,
    this.checkInternet,
    this.nonReentrant,
    this.throttle,
    this.debounce,
    this.fresh,
    this.sequential,
    this.before,
    this.after,
    this.wrapRun,
    this.catchError,
  });

  /// Merges [other] on top of this. Non-null values in [other] win.
  MixConfig merge(MixConfig? other) {
    if (other == null) return this;
    return MixConfig(
      retry: retry?.merge(other.retry) ?? other.retry,
      checkInternet:
          checkInternet?.merge(other.checkInternet) ?? other.checkInternet,
      nonReentrant:
          nonReentrant?.merge(other.nonReentrant) ?? other.nonReentrant,
      throttle: throttle?.merge(other.throttle) ?? other.throttle,
      debounce: debounce?.merge(other.debounce) ?? other.debounce,
      fresh: fresh?.merge(other.fresh) ?? other.fresh,
      sequential: sequential?.merge(other.sequential) ?? other.sequential,
      before: other.before ?? before,
      after: other.after ?? after,
      wrapRun: other.wrapRun ?? wrapRun,
      catchError: other.catchError ?? catchError,
    );
  }
}
