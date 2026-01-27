// Developed by Marcelo Glasberg (2026) https://glasberg.dev and https://github.com/marcglasberg
// For more info, see: https://pub.dartlang.org/packages/bloc_superpowers and http://blocsuperpowers.org
import 'dart:async';
import 'package:bloc_superpowers/src/mix.dart';

/// A pre-configured version of the [mix] function.
///
/// `MixPreset` allows you to create reusable, callable configurations for [mix].
/// Store common parameter values once, then invoke the preset like a function.
/// Explicit parameters passed at call time override the preset values.
///
/// **Resolution order** (lowest to highest priority):
/// 1. Built-in defaults (e.g., `RetryConfig.defaults`)
/// 2. Preset values (stored in `MixPreset`)
/// 3. Explicit parameters passed when calling the preset
///
/// **Example:**
/// ```dart
/// // Create presets for different use cases
/// const apiCall = MixPreset(
///   retry: retry,
///   checkInternet: checkInternet,
///   catchError: _handleApiError,
/// );
///
/// const backgroundSync = MixPreset(
///   checkInternet: checkInternet(abortSilently: true),
///   nonReentrant: nonReentrant,
/// );
///
/// // Use the preset - retry and checkInternet come from preset
/// await apiCall(
///   key: 'fetchUser',
///   () async {
///     return await api.fetchUser();
/// });
///
/// // Override specific values when needed
/// await apiCall(
///   key: 'fetchCritical',
///   retry: retry.unlimited,
///   () async {
///     return await api.fetchCritical();
/// });
/// ```
///
/// **Composing presets:**
/// ```dart
/// const basePreset = MixPreset(retry: retry);
/// final extendedPreset = basePreset.merge(MixPreset(checkInternet: checkInternet));
/// ```
///
/// See [mix] for detailed documentation on all parameters.
class MixPreset {
  /// Default key used when no key is provided at call time.
  /// If null, the `key` parameter is required when calling the preset.
  final Object? key;

  /// Retry configuration preset.
  final RetryConfig? retry;

  /// Internet connectivity check configuration preset.
  final CheckInternetConfig? checkInternet;

  /// Non-reentrant protection configuration preset.
  final NonReentrantConfig? nonReentrant;

  /// Sequential execution configuration preset.
  final SequentialConfig? sequential;

  /// Throttle (rate limiting) configuration preset.
  final ThrottleConfig? throttle;

  /// Debounce configuration preset.
  final DebounceConfig? debounce;

  /// Fresh (cache invalidation) configuration preset.
  final FreshConfig? fresh;

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

  /// Creates a preset with the given default values.
  ///
  /// All parameters are optional. When the preset is called, any parameter
  /// not provided at call time will use the preset value (if set).
  const MixPreset({
    this.key,
    this.retry,
    this.checkInternet,
    this.nonReentrant,
    this.sequential,
    this.throttle,
    this.debounce,
    this.fresh,
    this.before,
    this.after,
    this.wrapRun,
    this.catchError,
  });

  /// Calls [mix] with the preset values merged with explicit parameters.
  ///
  /// Explicit parameters override preset values. The [action] is required.
  /// The [key] is required unless a default key was set in the preset.
  ///
  /// **Example:**
  /// ```dart
  /// const myPreset = MixPreset(retry: retry);
  ///
  /// // key is required at call time
  /// await myPreset(key: 'myAction', () async { ... });
  ///
  /// // Or preset a default key
  /// const keyedPreset = MixPreset(key: 'defaultKey', retry: retry);
  /// await keyedPreset(() async { ... }); // Uses 'defaultKey'
  /// await keyedPreset(key: 'override', () async { ... }); // Uses 'override'
  /// ```
  FutureOr<T?> call<T>(
    FutureOr<T> Function() action, {
    Object? key,
    RetryConfig? retry,
    CheckInternetConfig? checkInternet,
    NonReentrantConfig? nonReentrant,
    SequentialConfig? sequential,
    ThrottleConfig? throttle,
    DebounceConfig? debounce,
    FreshConfig? fresh,
    FutureOr<void> Function()? before,
    FutureOr<void> Function()? after,
    FutureOr<T> Function(FutureOr<T> Function() action)? wrapRun,
    void Function(Object error, StackTrace stackTrace)? catchError,
  }) {
    final effectiveKey = key ?? this.key;
    if (effectiveKey == null) {
      throw ArgumentError(
        'MixPreset: key is required. Either provide it at call time '
        'or set a default key in the preset constructor.',
      );
    }

    // Merge callbacks into config (explicit overrides preset)
    // Cast wrapRun to dynamic type for MixConfig
    FutureOr<dynamic> Function(FutureOr<dynamic> Function())? effectiveWrapRun;
    if (wrapRun != null) {
      effectiveWrapRun = (action) => wrapRun(action as FutureOr<T> Function());
    } else {
      effectiveWrapRun = this.wrapRun;
    }

    final callbackConfig = MixConfig(
      before: before ?? this.before,
      after: after ?? this.after,
      wrapRun: effectiveWrapRun,
      catchError: catchError ?? this.catchError,
    );

    return mix<T>(
      action,
      key: effectiveKey,
      config: callbackConfig,
      retry: retry ?? this.retry,
      checkInternet: checkInternet ?? this.checkInternet,
      nonReentrant: nonReentrant ?? this.nonReentrant,
      sequential: sequential ?? this.sequential,
      throttle: throttle ?? this.throttle,
      debounce: debounce ?? this.debounce,
      fresh: fresh ?? this.fresh,
    );
  }

  /// Calls [mix.ctx] with the preset values merged with explicit parameters.
  ///
  /// Like [call], but the action receives a [MixContext] with runtime information.
  ///
  /// **Example:**
  /// ```dart
  /// const myPreset = MixPreset(retry: retry(maxRetries: 3));
  ///
  /// await myPreset.ctx(key: 'fetchData', (ctx) async {
  ///   print('Attempt ${ctx.retry!.attempt} of ${ctx.retry!.config.maxRetries}');
  ///   return await api.fetchData();
  /// });
  /// ```
  FutureOr<T?> ctx<T>(
    FutureOr<T> Function(MixContext ctx) action, {
    Object? key,
    RetryConfig? retry,
    CheckInternetConfig? checkInternet,
    NonReentrantConfig? nonReentrant,
    SequentialConfig? sequential,
    ThrottleConfig? throttle,
    DebounceConfig? debounce,
    FreshConfig? fresh,
    FutureOr<void> Function()? before,
    FutureOr<void> Function()? after,
    FutureOr<T> Function(FutureOr<T> Function() action)? wrapRun,
    void Function(Object error, StackTrace stackTrace)? catchError,
  }) {
    final effectiveKey = key ?? this.key;
    if (effectiveKey == null) {
      throw ArgumentError(
        'MixPreset: key is required. Either provide it at call time '
        'or set a default key in the preset constructor.',
      );
    }

    // Merge callbacks into config (explicit overrides preset)
    // Cast wrapRun to dynamic type for MixConfig
    FutureOr<dynamic> Function(FutureOr<dynamic> Function())? effectiveWrapRun;
    if (wrapRun != null) {
      effectiveWrapRun = (action) => wrapRun(action as FutureOr<T> Function());
    } else {
      effectiveWrapRun = this.wrapRun;
    }

    final callbackConfig = MixConfig(
      before: before ?? this.before,
      after: after ?? this.after,
      wrapRun: effectiveWrapRun,
      catchError: catchError ?? this.catchError,
    );

    return mix.ctx<T>(
      action,
      key: effectiveKey,
      config: callbackConfig,
      retry: retry ?? this.retry,
      checkInternet: checkInternet ?? this.checkInternet,
      nonReentrant: nonReentrant ?? this.nonReentrant,
      sequential: sequential ?? this.sequential,
      throttle: throttle ?? this.throttle,
      debounce: debounce ?? this.debounce,
      fresh: fresh ?? this.fresh,
    );
  }

  /// Creates a new preset by merging [other] on top of this preset.
  ///
  /// Non-null values in [other] override values in this preset.
  ///
  /// **Example:**
  /// ```dart
  /// const basePreset = MixPreset(retry: retry, before: _logStart);
  /// final extendedPreset = basePreset.merge(MixPreset(
  ///   checkInternet: checkInternet,
  ///   before: _differentLogStart, // Overrides basePreset.before
  /// ));
  /// ```
  MixPreset merge(MixPreset? other) {
    if (other == null) return this;
    return MixPreset(
      key: other.key ?? key,
      retry: other.retry ?? retry,
      checkInternet: other.checkInternet ?? checkInternet,
      nonReentrant: other.nonReentrant ?? nonReentrant,
      sequential: other.sequential ?? sequential,
      throttle: other.throttle ?? throttle,
      debounce: other.debounce ?? debounce,
      fresh: other.fresh ?? fresh,
      before: other.before ?? before,
      after: other.after ?? after,
      wrapRun: other.wrapRun ?? wrapRun,
      catchError: other.catchError ?? catchError,
    );
  }

  /// Creates a new preset with the specified values overriding this preset.
  ///
  /// This is a convenience method equivalent to creating a new [MixPreset]
  /// and merging it.
  ///
  /// **Example:**
  /// ```dart
  /// const basePreset = MixPreset(retry: retry);
  /// final withInternet = basePreset.copyWith(checkInternet: checkInternet);
  /// ```
  MixPreset copyWith({
    Object? key,
    RetryConfig? retry,
    CheckInternetConfig? checkInternet,
    NonReentrantConfig? nonReentrant,
    SequentialConfig? sequential,
    ThrottleConfig? throttle,
    DebounceConfig? debounce,
    FreshConfig? fresh,
    FutureOr<void> Function()? before,
    FutureOr<void> Function()? after,
    FutureOr<dynamic> Function(FutureOr<dynamic> Function() action)? wrapRun,
    void Function(Object error, StackTrace stackTrace)? catchError,
  }) {
    return MixPreset(
      key: key ?? this.key,
      retry: retry ?? this.retry,
      checkInternet: checkInternet ?? this.checkInternet,
      nonReentrant: nonReentrant ?? this.nonReentrant,
      sequential: sequential ?? this.sequential,
      throttle: throttle ?? this.throttle,
      debounce: debounce ?? this.debounce,
      fresh: fresh ?? this.fresh,
      before: before ?? this.before,
      after: after ?? this.after,
      wrapRun: wrapRun ?? this.wrapRun,
      catchError: catchError ?? this.catchError,
    );
  }

  /// Creates a preset that injects parameters into every action.
  ///
  /// This is a convenience factory for creating [MixPresetWithParams] with a
  /// cleaner API. The returned preset can be called like a function, where the
  /// action receives injected params of type [P].
  ///
  /// **Type parameters:**
  /// - [P]: The type of params injected into the action (what the user receives)
  /// - [C]: The type of config the user can pass at call time (optional)
  ///
  /// **Example - API call with environment config:**
  /// ```dart
  /// final apiCall = MixPreset.withUserContext<
  ///   ({String baseUrl, void Function(String) log}),  // P - injected params
  ///   ({String env, bool verbose})                     // C - user config
  /// >(
  ///   params: (ctx, config) => (
  ///     baseUrl: config.env == 'prod'
  ///         ? 'https://api.example.com'
  ///         : 'https://staging.example.com',
  ///     log: (msg) {
  ///       if (config.verbose) print('[API] $msg');
  ///     },
  ///   ),
  ///   defaultConfig: (env: 'dev', verbose: false),
  ///   retry: retry,
  /// );
  ///
  /// // Use the preset
  /// await apiCall(
  ///   key: 'fetchUsers',
  ///   config: (env: 'prod', verbose: true),
  ///   (ctx) async {
  ///     ctx.log('Fetching users...');
  ///     return await http.get('${ctx.baseUrl}/users');
  ///   },
  /// );
  /// ```
  ///
  /// **Parameters:**
  /// - [params]: Function that builds params from [MixContext] and user config.
  ///   Called fresh on each attempt (including retries) with updated context.
  /// - [defaultConfig]: Optional default config when user doesn't provide one.
  ///   If null and user doesn't provide config, an error is thrown.
  /// - [key]: Optional default key used when no key is provided at call time.
  /// - Other parameters configure the mix behavior (retry, throttle, etc.)
  ///
  /// See [MixPreset] for the simpler version without params/config.
  /// See [mix] for detailed documentation on all configuration options.
  static MixPresetWithParams<P, C> withUserContext<P, C>({
    required P Function(MixContext ctx, C config) params,
    C? defaultConfig,
    Object? key,
    RetryConfig? retry,
    CheckInternetConfig? checkInternet,
    NonReentrantConfig? nonReentrant,
    SequentialConfig? sequential,
    ThrottleConfig? throttle,
    DebounceConfig? debounce,
    FreshConfig? fresh,
    FutureOr<void> Function()? before,
    FutureOr<void> Function()? after,
    FutureOr<dynamic> Function(FutureOr<dynamic> Function() action)? wrapRun,
    void Function(Object error, StackTrace stackTrace)? catchError,
  }) {
    return MixPresetWithParams<P, C>(
      params: params,
      defaultConfig: defaultConfig,
      key: key,
      retry: retry,
      checkInternet: checkInternet,
      nonReentrant: nonReentrant,
      sequential: sequential,
      throttle: throttle,
      debounce: debounce,
      fresh: fresh,
      before: before,
      after: after,
      wrapRun: wrapRun,
      catchError: catchError,
    );
  }
}

/// A pre-configured version of [mix] that injects parameters into the action.
///
/// `MixPresetWithParams<P, C>` allows the preset creator to inject dependencies
/// (params of type [P]) that the action receives at runtime. The preset user
/// can optionally pass a config of type [C] that influences how params are built.
///
/// **Type parameters:**
/// - [P]: The type of params injected into the action (what the user receives)
/// - [C]: The type of config the user can pass at call time (optional)
///
/// **Design philosophy:**
/// - **Preset creator** decides HOW things work (retry, throttle, params structure)
/// - **Preset user** provides WHAT values to use (config) and the action
///
/// **Example - API call with user-configurable environment:**
/// ```dart
/// // Creator sets up the preset
/// final apiCall = MixPresetWithParams<
///   ({String baseUrl, void Function(String) log}),  // P - injected params
///   ({String env, bool verbose})                     // C - user config
/// >(
///   params: (ctx, config) => (
///     baseUrl: config.env == 'prod'
///         ? 'https://api.example.com'
///         : 'https://staging.example.com',
///     log: (msg) {
///       if (config.verbose) {
///         final attempt = ctx.retry?.attempt ?? 0;
///         debugPrint('[API Attempt $attempt] $msg');
///       }
///     },
///   ),
///   defaultConfig: (env: 'dev', verbose: false),
///   retry: retry,
///   checkInternet: checkInternet,
/// );
///
/// // User provides config and action
/// await apiCall(
///   key: 'fetchUsers',
///   config: (env: 'prod', verbose: true),
///   (ctx) async {
///     ctx.log('Fetching users...');
///     return await http.get('${ctx.baseUrl}/users');
///   },
/// );
///
/// // Or use default config
/// await apiCall(key: 'fetchData', (ctx) async {
///   return await http.get('${ctx.baseUrl}/data');
/// });
/// ```
///
/// **Params and config have access to [MixContext]:**
/// The [params] function receives both [MixContext] and user [config], allowing
/// injected functions to access retry attempts, sequential queue info, and
/// user-provided configuration. Params are rebuilt on each retry with updated context.
///
/// **catchError composition:**
/// If both preset-level and call-level [catchError] are defined, they are composed:
/// the preset's catchError runs first. If it returns normally (suppresses), the user's
/// catchError is not called. If it throws, the user's catchError receives the thrown error.
///
/// ```dart
/// final preset = MixPresetWithParams<..., ...>(
///   catchError: (e, s) => throw UserException('API Error: $e'),  // Runs first
///   ...
/// );
///
/// preset(
///   key: 'x',
///   catchError: (e, s) {  // Receives error from preset's catchError
///     logError(e);
///     throw e;  // Or transform further
///   },
///   (ctx) => ...,
/// );
/// ```
///
/// See [MixPreset] for the simpler version without params/config.
/// See [mix] for detailed documentation on all configuration options.
class MixPresetWithParams<P, C> {
  /// Function that builds params for each call.
  ///
  /// Receives [MixContext] (for retry attempts, etc.) and user [config].
  /// Called fresh on each attempt (including retries) with updated context.
  final P Function(MixContext ctx, C config) params;

  /// Default config used when user doesn't provide one at call time.
  /// If null and user doesn't provide config, an error is thrown.
  final C? defaultConfig;

  /// Default key used when no key is provided at call time.
  final Object? key;

  /// Retry configuration (set by preset creator, not overridable at call time).
  final RetryConfig? retry;

  /// Internet connectivity check configuration.
  final CheckInternetConfig? checkInternet;

  /// Non-reentrant protection configuration.
  final NonReentrantConfig? nonReentrant;

  /// Sequential execution configuration.
  final SequentialConfig? sequential;

  /// Throttle (rate limiting) configuration.
  final ThrottleConfig? throttle;

  /// Debounce configuration.
  final DebounceConfig? debounce;

  /// Fresh (cache invalidation) configuration.
  final FreshConfig? fresh;

  /// Callback called once before the first attempt.
  final FutureOr<void> Function()? before;

  /// Callback called once after all attempts complete (success or failure).
  final FutureOr<void> Function()? after;

  /// Callback that wraps each execution of the action.
  final FutureOr<dynamic> Function(FutureOr<dynamic> Function() action)?
      wrapRun;

  /// Default error handler. If user also provides catchError at call time,
  /// this runs first. If it returns normally (suppresses), user's is not called.
  /// If it throws, user's catchError receives the thrown error.
  final void Function(Object error, StackTrace stackTrace)? catchError;

  /// Creates a preset that injects [params] into every action.
  ///
  /// - [params]: Function that builds params from context and user config
  /// - [defaultConfig]: Optional default config when user doesn't provide one
  /// - [key]: Optional default key
  /// - Other parameters configure the mix behavior (retry, throttle, etc.)
  ///
  /// **Example:**
  /// ```dart
  /// final preset = MixPresetWithParams<String, ({bool verbose})>(
  ///   params: (ctx, config) => config.verbose ? 'debug-url' : 'prod-url',
  ///   defaultConfig: (verbose: false),
  ///   retry: retry,
  /// );
  /// ```
  const MixPresetWithParams({
    required this.params,
    this.defaultConfig,
    this.key,
    this.retry,
    this.checkInternet,
    this.nonReentrant,
    this.sequential,
    this.throttle,
    this.debounce,
    this.fresh,
    this.before,
    this.after,
    this.wrapRun,
    this.catchError,
  });

  /// Calls the preset with the given action and optional config.
  ///
  /// - [action]: Receives injected params of type [P]
  /// - [key]: Required unless a default key was set in the preset
  /// - [config]: User config of type [C], uses [defaultConfig] if not provided
  /// - [catchError]: Optional error handler, composed with preset's catchError
  ///
  /// **Example:**
  /// ```dart
  /// await myPreset(
  ///   key: 'fetchData',
  ///   config: (env: 'prod', verbose: true),
  ///   (ctx) async {
  ///     ctx.log('Working...');
  ///     return await doWork(ctx.baseUrl);
  ///   },
  /// );
  /// ```
  FutureOr<T?> call<T>(
    FutureOr<T> Function(P params) action, {
    Object? key,
    C? config,
    void Function(Object error, StackTrace stackTrace)? catchError,
  }) {
    final effectiveKey = key ?? this.key;
    if (effectiveKey == null) {
      throw ArgumentError(
        'MixPresetWithParams: key is required. Either provide it at call time '
        'or set a default key in the preset constructor.',
      );
    }

    final effectiveConfig = config ?? defaultConfig;
    if (effectiveConfig == null) {
      throw ArgumentError(
        'MixPresetWithParams: config is required. Either provide it at call time '
        'or set a defaultConfig in the preset constructor.',
      );
    }

    // Compose catchError: preset first, then user
    final composedCatchError = _composeCatchError(this.catchError, catchError);

    // Create config with callbacks
    final callbackConfig = MixConfig(
      before: before,
      after: after,
      wrapRun: wrapRun,
      catchError: composedCatchError,
    );

    return mix.ctx<T>(
      (ctx) => action(params(ctx, effectiveConfig)),
      key: effectiveKey,
      config: callbackConfig,
      retry: retry,
      checkInternet: checkInternet,
      nonReentrant: nonReentrant,
      sequential: sequential,
      throttle: throttle,
      debounce: debounce,
      fresh: fresh,
    );
  }

  /// Creates a new preset by merging [other] on top of this preset.
  ///
  /// Non-null values in [other] override values in this preset.
  /// Note: The [params] function from [other] completely replaces this one.
  MixPresetWithParams<P, C> merge(MixPresetWithParams<P, C>? other) {
    if (other == null) return this;
    return MixPresetWithParams<P, C>(
      params: other.params,
      defaultConfig: other.defaultConfig ?? defaultConfig,
      key: other.key ?? key,
      retry: other.retry ?? retry,
      checkInternet: other.checkInternet ?? checkInternet,
      nonReentrant: other.nonReentrant ?? nonReentrant,
      sequential: other.sequential ?? sequential,
      throttle: other.throttle ?? throttle,
      debounce: other.debounce ?? debounce,
      fresh: other.fresh ?? fresh,
      before: other.before ?? before,
      after: other.after ?? after,
      wrapRun: other.wrapRun ?? wrapRun,
      catchError: other.catchError ?? catchError,
    );
  }

  /// Creates a new preset with the specified values overriding this preset.
  MixPresetWithParams<P, C> copyWith({
    P Function(MixContext ctx, C config)? params,
    C? defaultConfig,
    Object? key,
    RetryConfig? retry,
    CheckInternetConfig? checkInternet,
    NonReentrantConfig? nonReentrant,
    SequentialConfig? sequential,
    ThrottleConfig? throttle,
    DebounceConfig? debounce,
    FreshConfig? fresh,
    FutureOr<void> Function()? before,
    FutureOr<void> Function()? after,
    FutureOr<dynamic> Function(FutureOr<dynamic> Function() action)? wrapRun,
    void Function(Object error, StackTrace stackTrace)? catchError,
  }) {
    return MixPresetWithParams<P, C>(
      params: params ?? this.params,
      defaultConfig: defaultConfig ?? this.defaultConfig,
      key: key ?? this.key,
      retry: retry ?? this.retry,
      checkInternet: checkInternet ?? this.checkInternet,
      nonReentrant: nonReentrant ?? this.nonReentrant,
      sequential: sequential ?? this.sequential,
      throttle: throttle ?? this.throttle,
      debounce: debounce ?? this.debounce,
      fresh: fresh ?? this.fresh,
      before: before ?? this.before,
      after: after ?? this.after,
      wrapRun: wrapRun ?? this.wrapRun,
      catchError: catchError ?? this.catchError,
    );
  }

  /// Composes two catchError functions: preset runs first, then user.
  /// If either is null, returns the other (or null if both are null).
  ///
  /// With catchError semantics:
  /// - If preset returns normally (suppresses), user's catchError is not called
  /// - If preset throws, user's catchError receives the thrown error
  static void Function(Object, StackTrace)? _composeCatchError(
    void Function(Object, StackTrace)? presetCatchError,
    void Function(Object, StackTrace)? userCatchError,
  ) {
    if (presetCatchError == null) return userCatchError;
    if (userCatchError == null) return presetCatchError;

    // Compose: preset first, then user
    return (error, stackTrace) {
      try {
        presetCatchError(error, stackTrace);
        // Preset returned normally - error is suppressed, don't call user's
        return;
      } catch (thrownError) {
        // Preset threw an error - pass to user's catchError
        userCatchError(thrownError, stackTrace);
      }
    };
  }
}
