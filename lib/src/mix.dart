// Developed by Marcelo Glasberg (2026) https://glasberg.dev and https://github.com/marcglasberg
// For more info, see: https://pub.dartlang.org/packages/bloc_superpowers and http://blocsuperpowers.org
import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
export 'package:bloc_superpowers/src/config_classes.dart';
export 'package:bloc_superpowers/src/context_classes.dart';

extension IntDurationExtension on int {
  Duration get millis => Duration(milliseconds: this);

  Duration get sec => Duration(seconds: this);
}

// ==================== Configuration Presets ====================

/// Default retry configuration preset.
///
/// Use directly for defaults, or call it to override specific values:
/// ```dart
/// mix(retry: retry) // uses defaults (3 retries, 350ms initial delay)
/// mix(retry: retry(maxRetries: 5)) // override maxRetries
/// mix(retry: retry(maxDelay: Duration(seconds: 10))) // override maxDelay
/// ```
const retry = RetryConfig();

/// Default internet check configuration preset.
///
/// Use directly for defaults, or call it to override specific values:
/// ```dart
/// mix(checkInternet: checkInternet) // uses defaults (abortSilently: false, ifOpenDialog: true)
/// mix(checkInternet: checkInternet(abortSilently: true)) // abort silently if no internet
/// mix(checkInternet: checkInternet(ifOpenDialog: false)) // throw without dialog
/// ```
const checkInternet = CheckInternetConfig();

/// Factory for creating NonReentrantConfig instances.
///
/// ```dart
/// mix(nonReentrant: nonReentrant(key: 'saveUser'), () async { ... });
/// ```
const nonReentrant = NonReentrantConfig();

/// Factory for creating ThrottleConfig instances.
///
/// ```dart
/// mix(throttle: throttle(key: 'refresh', throttle: 2000), () async { ... });
/// mix(throttle: throttle(key: 'submit', throttle: 1000, removeLockOnError: true), () async { ... });
/// ```
const throttle = ThrottleConfig();

/// Factory for creating DebounceConfig instances.
///
/// ```dart
/// mix(debounce: debounce(key: 'search', debounce: 300), () async { ... });
/// ```
const debounce = DebounceConfig();

/// Factory for creating FreshConfig instances.
///
/// ```dart
/// mix(fresh: fresh(key: 'loadUser', freshFor: 5000), () async { ... });
/// mix(fresh: fresh(key: 'loadUser', freshFor: 5000, ignoreFresh: true), () async { ... }); // force refresh
/// ```
const fresh = FreshConfig();

/// Factory for creating SequentialConfig instances.
///
/// Queues method calls and processes them one after another.
/// Unlike [nonReentrant] which drops subsequent calls, [sequential] ensures
/// every call eventually executes, in the order they were made.
///
/// ```dart
/// mix(sequential: sequential, () async { ... }); // uses defaults
/// mix(sequential: sequential(key: (ChatCubit, chatId)), () async { ... }); // separate queues per chat
/// mix(sequential: sequential(maxQueueSize: 10), () async { ... }); // limit queue size
/// mix(sequential: sequential(queueTimeout: 30.sec), () async { ... }); // timeout queued calls
/// ```
const sequential = SequentialConfig();

// ==================== Config Resolution ====================

/// Casts a generic wrapRun function to the specific type T.
///
/// This is needed because MixConfig stores wrapRun as `FutureOr<dynamic> Function(...)`
/// but mix<T> needs `FutureOr<T> Function(...)`.
FutureOr<T> Function(FutureOr<T> Function())? _castWrapRun<T>(
  FutureOr<dynamic> Function(FutureOr<dynamic> Function())? wrapRun,
) {
  if (wrapRun == null) return null;
  return (action) {
    final result = wrapRun(action);
    // Handle both sync and async results from wrapRun
    if (result is Future) {
      return result.then((value) => value as T);
    }
    return result as T;
  };
}

/// Resolves the effective retry config using merge order: default → config → explicit.
///
/// Returns null if both [configRetry] and [explicitRetry] are null (retry is off).
/// Otherwise, merges the configs with defaults to produce a fully-resolved config.
RetryConfig? _resolveRetryConfig(
    RetryConfig? configRetry, RetryConfig? explicitRetry) {
  if (configRetry == null && explicitRetry == null) return null;
  return RetryConfig.defaults.merge(configRetry).merge(explicitRetry);
}

/// Resolves the effective checkInternet config using merge order: default → config → explicit.
CheckInternetConfig? _resolveCheckInternetConfig(
    CheckInternetConfig? configCheckInternet,
    CheckInternetConfig? explicitCheckInternet) {
  if (configCheckInternet == null && explicitCheckInternet == null) return null;
  return CheckInternetConfig.defaults
      .merge(configCheckInternet)
      .merge(explicitCheckInternet);
}

/// Resolves the effective nonReentrant config using merge order: default → config → explicit.
NonReentrantConfig? _resolveNonReentrantConfig(
    NonReentrantConfig? configNonReentrant,
    NonReentrantConfig? explicitNonReentrant) {
  if (configNonReentrant == null && explicitNonReentrant == null) return null;
  return NonReentrantConfig.defaults
      .merge(configNonReentrant)
      .merge(explicitNonReentrant);
}

/// Resolves the effective throttle config using merge order: default → config → explicit.
ThrottleConfig? _resolveThrottleConfig(
    ThrottleConfig? configThrottle, ThrottleConfig? explicitThrottle) {
  if (configThrottle == null && explicitThrottle == null) return null;
  return ThrottleConfig.defaults.merge(configThrottle).merge(explicitThrottle);
}

/// Resolves the effective debounce config using merge order: default → config → explicit.
DebounceConfig? _resolveDebounceConfig(
    DebounceConfig? configDebounce, DebounceConfig? explicitDebounce) {
  if (configDebounce == null && explicitDebounce == null) return null;
  return DebounceConfig.defaults.merge(configDebounce).merge(explicitDebounce);
}

/// Resolves the effective fresh config using merge order: default → config → explicit.
FreshConfig? _resolveFreshConfig(
    FreshConfig? configFresh, FreshConfig? explicitFresh) {
  if (configFresh == null && explicitFresh == null) return null;
  return FreshConfig.defaults.merge(configFresh).merge(explicitFresh);
}

/// Resolves the effective sequential config using merge order: default → config → explicit.
SequentialConfig? _resolveSequentialConfig(
    SequentialConfig? configSequential, SequentialConfig? explicitSequential) {
  if (configSequential == null && explicitSequential == null) return null;
  return SequentialConfig.defaults
      .merge(configSequential)
      .merge(explicitSequential);
}

/// The set of keys that are currently running (for nonReentrant support).
/// Stored in Superpowers.props so it's cleared by Superpowers.clear().
const _nonReentrantPropKey = '_mix_nonReentrantKeySet';

Set<Object> _getNonReentrantKeySet() {
  var set = Superpowers.prop<Set<Object>?>(_nonReentrantPropKey);
  if (set == null) {
    set = {};
    Superpowers.setProp(_nonReentrantPropKey, set);
  }
  return set;
}

/// The map of keys to their expiry times (for fresh support).
/// Stored in Superpowers.props so it's cleared by Superpowers.clear().
const _freshPropKey = '_mix_freshKeyMap';

Map<Object, DateTime> _getFreshKeyMap() {
  var map = Superpowers.prop<Map<Object, DateTime>?>(_freshPropKey);
  if (map == null) {
    map = {};
    Superpowers.setProp(_freshPropKey, map);
  }
  return map;
}

/// Removes expired keys from the fresh map.
void _pruneFreshKeys() {
  final now = DateTime.now().toUtc();
  _getFreshKeyMap().removeWhere((_, expiresAt) => !expiresAt.isAfter(now));
}

/// Removes a specific fresh key, making actions with that key stale immediately.
///
/// Call this when you want to invalidate cached freshness for a specific key.
/// For example, after updating user data, you might want to invalidate the
/// "load user" fresh key so the next load actually fetches from the server.
///
/// ```dart
/// // After editing profile, invalidate the load action's freshness
/// await mix(() async {
///   await api.updateProfile(data);
///   removeFreshKey((LoadProfile, userId));
/// });
/// ```
void removeFreshKey(Object key) {
  _getFreshKeyMap().remove(key);
}

/// Removes all fresh keys, making all actions stale immediately.
///
/// Call this when you want to invalidate all cached freshness.
/// For example, after user logout, you might want to clear all fresh keys
/// so the next login fetches fresh data.
///
/// ```dart
/// // On logout, clear all fresh keys
/// await mix(() async {
///   await auth.logout();
///   removeAllFreshKeys();
/// });
/// ```
void removeAllFreshKeys() {
  _getFreshKeyMap().clear();
}

/// The map of keys to their expiry times (for throttle support).
/// Stored in Superpowers.props so it's cleared by Superpowers.clear().
const _throttlePropKey = '_mix_throttleLockMap';

Map<Object, DateTime> _getThrottleLockMap() {
  var map = Superpowers.prop<Map<Object, DateTime>?>(_throttlePropKey);
  if (map == null) {
    map = {};
    Superpowers.setProp(_throttlePropKey, map);
  }
  return map;
}

/// Removes expired locks from the throttle map.
void _pruneThrottleLocks() {
  final now = DateTime.now().toUtc();
  _getThrottleLockMap().removeWhere((_, expiresAt) => !expiresAt.isAfter(now));
}

/// Removes a specific throttle lock, allowing the action to run immediately.
///
/// Call this when you want to clear the rate limit for a specific key.
/// For example, after a user explicitly requests a refresh, you might want
/// to clear the throttle lock so the refresh runs immediately.
///
/// ```dart
/// // User tapped "Refresh" button - allow immediate execution
/// removeThrottleLock(AutoRefresh);
/// await mix(() async {
///   await api.refreshData();
/// }, throttle: (key: AutoRefresh, throttle: 5000, removeLockOnError: null, ignoreThrottle: null));
/// ```
void removeThrottleLock(Object key) {
  _getThrottleLockMap().remove(key);
}

/// Removes all throttle locks, allowing all throttled actions to run immediately.
///
/// Call this when you want to clear all rate limits.
/// For example, after user logout, you might want to clear all throttle locks
/// so the next login starts fresh.
///
/// ```dart
/// // On logout, clear all throttle locks
/// await mix(() async {
///   await auth.logout();
///   removeAllThrottleLocks();
/// });
/// ```
void removeAllThrottleLocks() {
  _getThrottleLockMap().clear();
}

/// The map of keys to their run counters (for debounce support).
/// Stored in Superpowers.props so it's cleared by Superpowers.clear().
const _debouncePropKey = '_mix_debounceLockMap';

// A large number that JavaScript can still represent.
const _safeInteger = 9000000000000000;

Map<Object, int> _getDebounceLockMap() {
  var map = Superpowers.prop<Map<Object, int>?>(_debouncePropKey);
  if (map == null) {
    map = {};
    Superpowers.setProp(_debouncePropKey, map);
  }
  return map;
}

/// The map of keys to their sequential queue states (for sequential support).
/// Stored in Superpowers.props so it's cleared by Superpowers.clear().
const _sequentialPropKey = '_mix_sequentialStateMap';

/// Internal state for a sequential queue.
class _SequentialQueueState {
  /// The future representing the last scheduled operation in the queue.
  /// New operations chain onto this future.
  Future<void> lastFuture = Future.value();

  /// Number of operations currently in the queue (waiting + running).
  /// Used to enforce maxQueueSize.
  int pendingCount = 0;

  /// IDs of waiters in order (oldest first). Does not include the currently running call.
  /// Used for dropOldest feature to identify which waiter to supersede.
  final List<int> waiterIds = [];

  /// IDs that have been superseded and should abort when they wake up.
  /// When a waiter wakes up and finds their ID here, they abort without running.
  final Set<int> supersededIds = {};

  /// Counter for generating unique waiter IDs.
  int nextWaiterId = 0;
}

Map<Object, _SequentialQueueState> _getSequentialStateMap() {
  var map = Superpowers.prop<Map<Object, _SequentialQueueState>?>(_sequentialPropKey);
  if (map == null) {
    map = {};
    Superpowers.setProp(_sequentialPropKey, map);
  }
  return map;
}

/// Checks if there is internet connectivity.
/// Uses [Superpowers.simulateInternet] for testing, or real connectivity check.
Future<bool> _hasInternet() async {
  final simulation = Superpowers.simulateInternet;
  if (simulation != null) {
    return simulation;
  }

  final result = await Connectivity().checkConnectivity();
  return !result.contains(ConnectivityResult.none);
}

/// Internal exception used to trigger retry when there's no internet.
/// This is never shown to the user - it's caught and converted to ConnectionException.
class _NoInternetRetryException implements Exception {
  const _NoInternetRetryException();
}

/// A callable class that provides `mix()` and `mix.ctx()` methods.
///
/// Use `mix()` for simple actions, and `mix.ctx()` when you need access to
/// runtime context information (like retry attempt number).
///
/// **Example:**
/// ```dart
/// // Simple action
/// await mix(key: 'fetchUser', () async {
///   return await api.fetchUser();
/// });
///
/// // Action with context
/// await mix.ctx(key: 'fetchData', (ctx) async {
///   print('Attempt ${ctx.retry!.attempt}');
///   return await api.fetchData();
/// });
/// ```
class _Mix {
  const _Mix();

  /// Executes an action with optional retry, non-reentrant protection,
  /// lifecycle methods, and error handling.
  ///
  /// This is a standalone function that can be used in any context: regular
  /// Cubits, Blocs, or any async code that needs retry logic and lifecycle
  /// management.
  ///
  /// **Usage:**
  /// ```dart
  /// // Basic usage without retry
  /// await mix(
  ///   before: () => print('Starting...'),
  ///   after: () => print('Done!'),
  ///   () async {
  ///     await api.saveData();
  ///   },
  /// );
  ///
  /// // With retry configuration (using the retry preset)
  /// await mix(
  ///   retry: retry,  // Uses defaults (3 retries, 350ms initial delay)
  ///   before: () => emit(state.copyWith(loading: true)),
  ///   after: () => emit(state.copyWith(loading: false)),
  ///   catchError: (error, stack) => throw UserException('Save failed'),
  ///   () async {
  ///     await api.saveData();
  ///   },
  /// );
  ///
  /// // With custom retry configuration
  /// await mix(
  ///   retry: retry(
  ///     maxRetries: 5,
  ///     initialDelay: Duration(milliseconds: 500),
  ///     maxDelay: Duration(seconds: 10),
  ///     onRetry: (attempt, delay, error, stack) {
  ///       print('Retry $attempt after $delay');
  ///     },
  ///   ),
  ///   () async {
  ///     await api.saveData();
  ///   },
  /// );
  ///
  /// // With non-reentrant protection (prevents concurrent executions)
  /// await mix(
  ///   nonReentrant: nonReentrant(key: 'saveUser'),
  ///   () async {
  ///     await api.saveUser(user);
  ///   },
  /// );
  ///
  /// // Combining retry and non-reentrant
  /// await mix(
  ///   nonReentrant: nonReentrant(key: ('saveItem', itemId)),  // Parameterized key
  ///   retry: retry,  // Uses defaults
  ///   () async {
  ///     await api.saveItem(itemId);
  ///   },
  /// );
  ///
  /// // With fresh protection (prevents re-execution while result is still "fresh")
  /// await mix(
  ///   fresh: FreshConfig('loadUser', duration: 5.secs),
  ///   () async {
  ///     return await api.loadUser(userId);
  ///   },
  /// );
  ///
  /// // Combining fresh with retry (fresh check happens first, then retry on failure)
  /// await mix(
  ///   fresh: FreshConfig('loadData', duration: 10.secs),
  ///   retry: retry,
  ///   () async {
  ///     return await api.loadData();
  ///   },
  /// );
  ///
  /// // With throttle (rate limiting - only execute once per period)
  /// await mix(
  ///   throttle: ThrottleConfig('refresh', duration: 2.secs),
  ///   () async {
  ///     await api.refreshData();
  ///   },
  /// );
  ///
  /// // Throttle with removeLockOnError (allows retry after failure)
  /// await mix(
  ///   throttle: ThrottleConfig('submit', duration: 1.secs, removeLockOnError: true),
  ///   () async {
  ///     await api.submitForm();
  ///   },
  /// );
  ///
  /// // With debounce (delays execution, only last call in burst executes)
  /// await mix(
  ///   debounce: debounce(key: 'search', duration: 300.millis),
  ///   () async {
  ///     await api.search(query);
  ///   },
  /// );
  ///
  /// // Debounce for search-as-you-type
  /// await mix(
  ///   debounce: debounce(key: ('search', category), duration: 500.millis),
  ///   () async {
  ///     final results = await api.searchInCategory(category, query);
  ///     emit(state.copyWith(results: results));
  ///   },
  /// );
  ///
  /// // With checkInternet - shows dialog if no internet (like CheckInternet mixin)
  /// await mix(
  ///   checkInternet: checkInternet,  // Uses defaults (abortSilently: false, ifOpenDialog: true)
  ///   () async {
  ///     await api.fetchData();
  ///   },
  /// );
  ///
  /// // With checkInternet - throws without dialog (like CheckInternet + NoDialog)
  /// // Useful for handling errors via context.isFailed()
  /// await mix(
  ///   checkInternet: checkInternet(ifOpenDialog: false),
  ///   () async {
  ///     await api.fetchData();
  ///   },
  /// );
  ///
  /// // With checkInternet - aborts silently (like AbortWhenNoInternet mixin)
  /// await mix(
  ///   checkInternet: checkInternet(abortSilently: true),
  ///   () async {
  ///     await api.syncData();  // Background sync, ok to skip
  ///   },
  /// );
  ///
  /// // With checkInternet + retry - waits for internet indefinitely (like UnlimitedRetryCheckInternet)
  /// // Useful for critical operations that MUST succeed
  /// await mix(
  ///   checkInternet: checkInternet,
  ///   retry: retry(maxRetries: -1),  // Unlimited retries
  ///   () async {
  ///     await api.initializeApp();  // Must succeed before app can be used
  ///   },
  /// );
  ///
  /// // With key - enables isWaitingInline/isFailedInline tracking
  /// await mix(
  ///   key: 'saveUser',  // Track with this key
  ///   before: () => emit(state.copyWith(saving: true)),
  ///   after: () => emit(state.copyWith(saving: false)),
  ///   catchError: (error, stack) => throw UserException('Save failed'),
  ///   () async {
  ///     await api.saveUser(user);
  ///   },
  /// );
  ///
  /// // Then in a widget:
  /// // if (context.isWaitingInline('saveUser')) return CircularProgressIndicator();
  /// // if (context.isFailedInline('saveUser')) return Text('Error!');
  ///
  /// // With sequential - queues calls and processes them one at a time
  /// await mix(
  ///   key: this,
  ///   sequential: sequential,  // Queue and process in order
  ///   () async {
  ///     await api.processOrder(order);
  ///   },
  /// );
  ///
  /// // Sequential with separate queues per chat
  /// await mix(
  ///   key: this,
  ///   sequential: sequential(key: (ChatCubit, chatId)),  // Each chat has its own queue
  ///   () async {
  ///     await api.sendMessage(chatId, message);
  ///   },
  /// );
  ///
  /// // Sequential with queue size limit
  /// await mix(
  ///   key: this,
  ///   sequential: sequential(maxQueueSize: 10),  // Max 10 pending, then drop
  ///   () async {
  ///     await api.processOrder(order);
  ///   },
  /// );
  ///
  /// // Sequential with timeout
  /// await mix(
  ///   key: this,
  ///   sequential: sequential(queueTimeout: Duration(seconds: 30)),  // Drop if waiting > 30s
  ///   () async {
  ///     await api.processOrder(order);
  ///   },
  /// );
  ///
  /// // Sequential combined with retry (retry failures before moving to next in queue)
  /// await mix(
  ///   key: this,
  ///   sequential: sequential(key: (ChatCubit, chatId)),
  ///   retry: retry,
  ///   () async {
  ///     await api.sendMessage(chatId, message);
  ///   },
  /// );
  /// ```
  ///
  /// **Parameters:**
  /// - [action]: The function to execute (positional, trailing).
  /// - [key]: Enables state tracking via [Superpowers.isWaiting] and
  ///   [Superpowers.isFailed]. Can be any Object with proper equality (String, record, etc.).
  ///   Use in widgets with `context.isWaitingInline(key)` to show loading indicators,
  ///   or `context.isFailedInline(key)` to show errors.
  /// - [nonReentrant]: A [NonReentrantConfig] that prevents concurrent executions with the same key.
  ///   When a call with the same key is already running, subsequent calls return
  ///   immediately without executing. The key can be any Object with proper equality
  ///   (strings, enums, records, etc.). Pass `NonReentrantConfig(MyKey)` or `NonReentrantConfig((MyKey, id))`.
  /// - [sequential]: A [SequentialConfig] that queues calls and processes them one at a time.
  ///   Unlike [nonReentrant] which drops subsequent calls, [sequential] ensures every call
  ///   eventually executes, in the order they were made. Use the [sequential] preset for
  ///   defaults, or call it to override:
  ///   - `key`: Override key for queue isolation. If null, uses the mix key.
  ///   - `maxQueueSize`: Maximum queued calls (not counting the running one). When full,
  ///     new calls are dropped like [nonReentrant]. Default is unlimited.
  ///   - `queueTimeout`: Maximum time a call can wait in the queue before being discarded.
  ///     Default is unlimited.
  ///   **Combining with retry:** When both are set, if a call fails, it retries (per retry
  ///   settings) before the next queued call starts.
  /// - [fresh]: A [FreshConfig] that prevents re-execution while the result is still "fresh".
  ///   After successful completion, subsequent calls with the same key within the
  ///   [duration] period are aborted. If the action fails, freshness is rolled back to
  ///   allow immediate retry. Pass `FreshConfig(key, duration: Duration(...))`.
  ///   Set `ignoreFresh: true` to bypass the fresh check for this specific call (force
  ///   refresh). The action will run and set a new expiry, but if it fails, the key
  ///   becomes stale immediately. Use [removeFreshKey] or [removeAllFreshKeys] to
  ///   manually invalidate freshness from other actions.
  /// - [throttle]: A [ThrottleConfig] that rate-limits execution. The first call executes
  ///   immediately and sets a lock; subsequent calls with the same key are aborted until
  ///   the throttle period expires. Unlike fresh, the lock is set when the action *starts*,
  ///   not when it completes. Pass `ThrottleConfig(key, duration: Duration(...))`.
  ///   By default, the lock is NOT removed on error; set `removeLockOnError: true`
  ///   to allow immediate retry after failure. Set `ignoreThrottle: true` to bypass the
  ///   throttle check for this specific call (force execution).
  ///   Use [removeThrottleLock] or [removeAllThrottleLocks] to manually clear throttle locks.
  /// - [debounce]: A [DebounceConfig] that delays execution and allows superseding. When called,
  ///   waits for the debounce period; if another call with the same key occurs during the
  ///   wait, the earlier call is aborted and only the later one executes. Useful for
  ///   search-as-you-type scenarios. Pass `DebounceConfig(key, duration: Duration(...))`.
  /// - [checkInternet]: A [CheckInternetConfig] that checks for internet connectivity before running.
  ///   Use the [checkInternet] preset for defaults, or call it to override:
  ///   - `abortSilently`: If `true`, returns null immediately without any exception
  ///     (like [AbortWhenNoInternet] mixin). If `false` (default), throws a [ConnectionException].
  ///   - `ifOpenDialog`: Only applies when `abortSilently: false`. If `true` (default),
  ///     the [ConnectionException] is added to [Superpowers]'s error queue for dialog display.
  ///     If `false`, the exception is rethrown for manual handling via `context.isFailed()`.
  ///   - `maxRetryDelay`: The maximum delay between retries when there is no internet.
  ///     Default is 1 second. Only applies when combined with [retry] and `abortSilently: false`.
  ///   **When combined with [retry]:** If both are set (with `abortSilently: false`),
  ///   the internet check is included in the retry loop. "No internet" is treated as a
  ///   retriable failure - useful with `retry(maxRetries: -1)` for critical operations.
  ///   Use [Superpowers.clear] with `simulateInternet` for testing.
  /// - [retry]: A [RetryConfig] configuration. Use the [retry] preset for defaults, or call
  ///   it to override specific values: `retry(maxRetries: 5, maxDelay: Duration(seconds: 10))`.
  ///   - `maxRetries`: Maximum retry attempts, -1 for unlimited (default: 3).
  ///   - `initialDelay`: Delay before the first retry (default: 350ms).
  ///   - `multiplier`: Factor by which delay increases each retry (default: 2, min: 2).
  ///   - `maxDelay`: Cap on retry delay (default: 5 seconds).
  ///   - `onRetry`: Optional callback called before each retry with attempt info.
  /// - [before]: Optional callback called once before the first attempt.
  /// - [after]: Optional callback called once after all attempts complete (success or failure).
  /// - [wrapRun]: Optional callback that wraps each execution of [action]. Receives the action
  ///   as a parameter and MUST call it for the action to execute. Called on every attempt
  ///   (initial + retries). Useful for adding timing, logging, or other cross-cutting concerns.
  /// - [catchError]: Optional callback to handle errors. If it returns normally, the error
  ///   is suppressed. If it throws (any error, original or modified), that error is propagated
  ///   with the original stack trace. This follows the familiar try/catch pattern.
  ///
  /// **How it works:**
  /// 1. If [debounce] is provided, waits for the debounce period; if superseded, returns immediately.
  /// 2. If [checkInternet] is provided (without [retry], or with `abortSilently: true`):
  ///    throws [ConnectionException] or returns null if no internet.
  /// 3. If [sequential] is provided, checks if queue is full (returns if full), then waits for turn.
  ///    If [queueTimeout] is set and exceeded, returns immediately.
  /// 4. If [nonReentrant] is provided and key is already running, returns immediately.
  /// 5. If [throttle] is provided and key is still locked, returns immediately.
  /// 6. If [fresh] is provided and key is still fresh, returns immediately.
  /// 7. [before] is called once (if provided).
  /// 8. **If [checkInternet] + [retry] are both set (with `abortSilently: false`):**
  ///    Internet is checked before each attempt; "no internet" triggers retry.
  /// 9. First attempt: [wrapRun] wraps [action] (or [action] is called directly).
  /// 10. If [retry] is provided and action fails (or no internet), waits and retries with exponential backoff.
  /// 11. After all attempts fail (or on first failure if no retry), [catchError] is called.
  /// 12. [after] is called once (if provided), regardless of success or failure.
  /// 13. If [catchError] throws a [UserException] with [ifOpenDialog]=true,
  ///    it's added to [Superpowers]'s error queue and not rethrown.
  /// 14. If [nonReentrant] is provided, the key is removed from the running set.
  /// 15. If [fresh] is provided and action failed, freshness is rolled back.
  /// 16. If [throttle] is provided with `removeLockOnError: true` and action failed, lock is removed.
  /// 17. If [sequential] is provided, signals completion so next queued call can proceed.
  ///
  /// **Returns:** The result of [action] if successful, or `null` if aborted
  /// (e.g., due to no internet, debounce superseded, nonReentrant blocked, etc.).
  ///
  /// **Throws:** The last error if all retries are exhausted (unless suppressed by [catchError]).
  ///
  /// **Sync execution:** When no async features are used (debounce, checkInternet,
  /// sequential, retry) and the action is synchronous, `mix` executes synchronously.
  FutureOr<T?> call<T>(
    FutureOr<T> Function() action, {
    required Object key,
    MixConfig? config,
    NonReentrantConfig? nonReentrant,
    SequentialConfig? sequential,
    ThrottleConfig? throttle,
    DebounceConfig? debounce,
    FreshConfig? fresh,
    CheckInternetConfig? checkInternet,
    RetryConfig? retry,
    void Function(Object error, StackTrace stackTrace)? catchError,
  }) {
    // Resolve effective configs using merge order: default → config → explicit
    final effectiveRetry = _resolveRetryConfig(config?.retry, retry);
    final effectiveCheckInternet =
        _resolveCheckInternetConfig(config?.checkInternet, checkInternet);
    final effectiveNonReentrant =
        _resolveNonReentrantConfig(config?.nonReentrant, nonReentrant);
    final effectiveSequential =
        _resolveSequentialConfig(config?.sequential, sequential);
    final effectiveThrottle =
        _resolveThrottleConfig(config?.throttle, throttle);
    final effectiveDebounce =
        _resolveDebounceConfig(config?.debounce, debounce);
    final effectiveFresh = _resolveFreshConfig(config?.fresh, fresh);

    // Resolve callbacks from config
    final effectiveBefore = config?.before;
    final effectiveAfter = config?.after;
    final effectiveWrapRun = _castWrapRun<T>(config?.wrapRun);
    final effectiveCatchError = catchError ?? config?.catchError;

    // If any async feature is used, delegate to async implementation
    if (effectiveDebounce != null ||
        effectiveCheckInternet != null ||
        effectiveSequential != null ||
        effectiveRetry != null) {
      return _mixAsync(
        action: action,
        key: key,
        nonReentrant: effectiveNonReentrant,
        sequential: effectiveSequential,
        throttle: effectiveThrottle,
        debounce: effectiveDebounce,
        fresh: effectiveFresh,
        checkInternet: effectiveCheckInternet,
        retry: effectiveRetry,
        before: effectiveBefore,
        after: effectiveAfter,
        wrapRun: effectiveWrapRun,
        catchError: effectiveCatchError,
      );
    }

    // Sync path: no async features used
    return _mixSync(
      action: action,
      key: key,
      nonReentrant: effectiveNonReentrant,
      throttle: effectiveThrottle,
      fresh: effectiveFresh,
      before: effectiveBefore,
      after: effectiveAfter,
      wrapRun: effectiveWrapRun,
      catchError: effectiveCatchError,
    );
  }

  /// Like [call], but passes a [MixContext] to the action callback.
  ///
  /// Use this when you need access to runtime context information, such as
  /// the current retry attempt number.
  ///
  /// **Example:**
  /// ```dart
  /// await mix.ctx(
  ///   key: 'fetchData',
  ///   retry: retry(maxRetries: 3),
  ///   (ctx) async {
  ///     print('Attempt ${ctx.retry!.attempts} of ${ctx.retry!.config.maxRetries}');
  ///     return await api.fetchData();
  ///   },
  /// );
  /// ```
  ///
  /// The context provides access to the configuration for each feature:
  /// - `ctx.retry` - RetryContext with `attempts` and `config`
  /// - `ctx.nonReentrant` - NonReentrantContext with `config`
  /// - `ctx.throttle` - ThrottleContext with `config`
  /// - `ctx.debounce` - DebounceContext with `config`
  /// - `ctx.fresh` - FreshContext with `config`
  /// - `ctx.checkInternet` - CheckInternetContext with `config`
  /// - `ctx.sequential` - SequentialContext with `config`
  ///
  /// Each context property is non-null only if the corresponding feature was
  /// configured in the mix.ctx call.
  ///
  /// See [call] for detailed documentation on all parameters.
  FutureOr<T?> ctx<T>(
    FutureOr<T> Function(MixContext ctx) action, {
    required Object key,
    MixConfig? config,
    NonReentrantConfig? nonReentrant,
    SequentialConfig? sequential,
    ThrottleConfig? throttle,
    DebounceConfig? debounce,
    FreshConfig? fresh,
    CheckInternetConfig? checkInternet,
    RetryConfig? retry,
    void Function(Object error, StackTrace stackTrace)? catchError,
  }) {
    // Resolve effective configs using merge order: default → config → explicit
    final effectiveRetry = _resolveRetryConfig(config?.retry, retry);
    final effectiveCheckInternet =
        _resolveCheckInternetConfig(config?.checkInternet, checkInternet);
    final effectiveNonReentrant =
        _resolveNonReentrantConfig(config?.nonReentrant, nonReentrant);
    final effectiveSequential =
        _resolveSequentialConfig(config?.sequential, sequential);
    final effectiveThrottle =
        _resolveThrottleConfig(config?.throttle, throttle);
    final effectiveDebounce =
        _resolveDebounceConfig(config?.debounce, debounce);
    final effectiveFresh = _resolveFreshConfig(config?.fresh, fresh);

    // Resolve callbacks from config
    final effectiveBefore = config?.before;
    final effectiveAfter = config?.after;
    final effectiveWrapRun = _castWrapRun<T>(config?.wrapRun);
    final effectiveCatchError = catchError ?? config?.catchError;

    // Create the base context (sequential context is set in _mixCtxAsync with queue info)
    final baseContext = MixContext(
      retry: effectiveRetry != null
          ? RetryContext(config: effectiveRetry.resolve())
          : null,
      nonReentrant: effectiveNonReentrant != null
          ? NonReentrantContext(config: effectiveNonReentrant.resolve())
          : null,
      throttle: effectiveThrottle != null
          ? ThrottleContext(config: effectiveThrottle.resolve())
          : null,
      debounce: effectiveDebounce != null
          ? DebounceContext(config: effectiveDebounce.resolve())
          : null,
      fresh: effectiveFresh != null
          ? FreshContext(config: effectiveFresh.resolve())
          : null,
      checkInternet: effectiveCheckInternet != null
          ? CheckInternetContext(config: effectiveCheckInternet.resolve())
          : null,
      sequential: null, // Set in _mixCtxAsync with queue index info
    );

    // If any async feature is used, delegate to async implementation
    if (effectiveDebounce != null ||
        effectiveCheckInternet != null ||
        effectiveSequential != null ||
        effectiveRetry != null) {
      return _mixCtxAsync(
        action: action,
        baseContext: baseContext,
        key: key,
        nonReentrant: effectiveNonReentrant,
        sequential: effectiveSequential,
        throttle: effectiveThrottle,
        debounce: effectiveDebounce,
        fresh: effectiveFresh,
        checkInternet: effectiveCheckInternet,
        retry: effectiveRetry,
        before: effectiveBefore,
        after: effectiveAfter,
        wrapRun: effectiveWrapRun,
        catchError: effectiveCatchError,
      );
    }

    // Sync path: no async features used - context doesn't change
    return _mixSync(
      action: () => action(baseContext),
      key: key,
      nonReentrant: effectiveNonReentrant,
      throttle: effectiveThrottle,
      fresh: effectiveFresh,
      before: effectiveBefore,
      after: effectiveAfter,
      wrapRun: effectiveWrapRun,
      catchError: effectiveCatchError,
    );
  }
}

/// The global [mix] instance.
///
/// Use `mix()` for simple actions, and `mix.ctx()` when you need access to
/// runtime context information (like retry attempt number).
///
/// **Example:**
/// ```dart
/// // Simple action
/// await mix(key: 'fetchUser', () async {
///   return await api.fetchUser();
/// });
///
/// // Action with context
/// await mix.ctx(key: 'fetchData', (ctx) async {
///   print('Attempt ${ctx.retry!.attempt}');
///   return await api.fetchData();
/// });
/// ```
const mix = _Mix();

/// Synchronous implementation of mix for when no async features are used.
/// Returns T? because the action may be aborted (returning null).
FutureOr<T?> _mixSync<T>({
  required FutureOr<T> Function() action,
  required Object key,
  NonReentrantConfig? nonReentrant,
  ThrottleConfig? throttle,
  FreshConfig? fresh,
  FutureOr<void> Function()? before,
  FutureOr<void> Function()? after,
  FutureOr<T> Function(FutureOr<T> Function())? wrapRun,
  void Function(Object error, StackTrace stackTrace)? catchError,
}) {
  // Normalize key: if it's a Cubit/Bloc instance, use its runtimeType instead.
  final Object effectiveKey = key is BlocBase ? key.runtimeType : key;

  // Resolve effective keys
  final nonReentrantKey = nonReentrant?.key ?? effectiveKey;
  final throttleKey = throttle?.key ?? effectiveKey;
  final freshKey = fresh?.key ?? effectiveKey;

  // Track inline state (for isWaitingInline/isFailedInline)
  Superpowers.onStart(effectiveKey);

  // Handle non-reentrant check
  if (nonReentrant != null) {
    final keySet = _getNonReentrantKeySet();
    if (keySet.contains(nonReentrantKey)) {
      nonReentrant.onBlocked?.call(nonReentrantKey);
      Superpowers.onComplete(effectiveKey, null);
      return null;
    }
    keySet.add(nonReentrantKey);
  }

  // Handle throttle check
  if (throttle != null) {
    final throttleMap = _getThrottleLockMap();
    final now = DateTime.now().toUtc();
    final expiresAt = throttleMap[throttleKey];

    if (throttle.ignoreThrottle!) {
      throttleMap[throttleKey] = now.add(throttle.duration!);
    } else if (expiresAt != null && expiresAt.isAfter(now)) {
      throttle.onThrottled?.call(throttleKey, expiresAt.difference(now));
      if (nonReentrant != null)
        _getNonReentrantKeySet().remove(nonReentrantKey);
      Superpowers.onComplete(effectiveKey, null);
      return null;
    } else {
      throttleMap[throttleKey] = now.add(throttle.duration!);
    }
  }

  // Handle fresh check
  DateTime? previousFreshExpiry;
  DateTime? newFreshExpiry;
  if (fresh != null) {
    final freshMap = _getFreshKeyMap();
    final now = DateTime.now().toUtc();
    previousFreshExpiry = freshMap[freshKey];

    if (fresh.ignoreFresh!) {
      newFreshExpiry = now.add(fresh.freshFor!);
      freshMap[freshKey] = newFreshExpiry;
      previousFreshExpiry = null;
    } else if (previousFreshExpiry != null &&
        previousFreshExpiry.isAfter(now)) {
      fresh.onFresh?.call(freshKey, previousFreshExpiry.difference(now));
      if (nonReentrant != null)
        _getNonReentrantKeySet().remove(nonReentrantKey);
      if (throttle != null) {
        _getThrottleLockMap().remove(throttleKey);
        _pruneThrottleLocks();
      }
      Superpowers.onComplete(effectiveKey, null);
      return null;
    } else {
      newFreshExpiry = now.add(fresh.freshFor!);
      freshMap[freshKey] = newFreshExpiry;
    }
  }

  bool actionFailed = false;
  UserException? inlineUserException;

  /// Cleanup function to be called on completion
  void cleanup() {
    if (nonReentrant != null) {
      _getNonReentrantKeySet().remove(nonReentrantKey);
    }

    if (fresh != null && actionFailed) {
      final freshMap = _getFreshKeyMap();
      if (freshMap[freshKey] == newFreshExpiry) {
        if (previousFreshExpiry == null) {
          freshMap.remove(freshKey);
        } else {
          freshMap[freshKey] = previousFreshExpiry;
        }
      }
    }

    if (fresh != null) _pruneFreshKeys();

    if (throttle != null) {
      if (actionFailed && throttle.removeLockOnError!) {
        _getThrottleLockMap().remove(throttleKey);
      }
      _pruneThrottleLocks();
    }

    Superpowers.onComplete(effectiveKey, actionFailed ? inlineUserException : null);
  }

  // Call before() once at the start
  if (before != null) {
    try {
      final beforeResult = before();
      if (beforeResult is Future) {
        // before() is async, need to continue asynchronously
        return beforeResult.then((_) {
          return _executeSyncAction<T>(
            action: action,
            wrapRun: wrapRun,
            after: after,
            catchError: catchError,
            cleanup: cleanup,
            setActionFailed: (failed) => actionFailed = failed,
            setInlineUserException: (e) => inlineUserException = e,
          );
        }).catchError((error, stack) {
          if (error is! AbortException) actionFailed = true;
          // Get the UserException first (if any), then cleanup
          // Use try-finally to ensure cleanup is called even if _handleFinalError rethrows
          try {
            inlineUserException =
                _handleFinalError(error, stack, after, catchError);
          } finally {
            cleanup();
          }
          return null;
        });
      }
    } catch (error, stack) {
      if (error is! AbortException) actionFailed = true;
      // Get the UserException first (if any), then cleanup
      // Use try-finally to ensure cleanup is called even if _handleFinalError rethrows
      try {
        inlineUserException = _handleFinalError(error, stack, after, catchError);
      } finally {
        cleanup();
      }
      return null;
    }
  }

  // Execute action synchronously
  return _executeSyncAction<T>(
    action: action,
    wrapRun: wrapRun,
    after: after,
    catchError: catchError,
    cleanup: cleanup,
    setActionFailed: (failed) => actionFailed = failed,
    setInlineUserException: (e) => inlineUserException = e,
  );
}

/// Executes the action, handling both sync and async results.
/// Returns T? because the action may fail (returning null on error).
FutureOr<T?> _executeSyncAction<T>({
  required FutureOr<T> Function() action,
  required FutureOr<T> Function(FutureOr<T> Function())? wrapRun,
  required FutureOr<void> Function()? after,
  required void Function(Object error, StackTrace stackTrace)? catchError,
  required void Function() cleanup,
  required void Function(bool) setActionFailed,
  required void Function(UserException?) setInlineUserException,
}) {
  try {
    final FutureOr<T> result;
    if (wrapRun != null) {
      result = wrapRun(action);
    } else {
      result = action();
    }

    if (result is Future<T>) {
      // Action is async, handle with .then()
      // Cast to Future<T?> to allow returning null in catchError
      return (result as Future<T?>).then<T?>((value) {
        _runAfter(after);
        cleanup();
        return value;
      }).catchError((error, stack) {
        if (error is! AbortException) setActionFailed(true);
        // Get the UserException first (if any), then cleanup
        // Use try-finally to ensure cleanup is called even if _handleFinalError rethrows
        try {
          setInlineUserException(
              _handleFinalError(error, stack, after, catchError));
        } finally {
          cleanup();
        }
        return null;
      });
    } else {
      // Action is sync
      _runAfter(after);
      cleanup();
      return result;
    }
  } catch (error, stack) {
    if (error is! AbortException) setActionFailed(true);
    // Get the UserException first (if any), then cleanup
    // Use try-finally to ensure cleanup is called even if _handleFinalError rethrows
    try {
      setInlineUserException(_handleFinalError(error, stack, after, catchError));
    } finally {
      cleanup();
    }
    return null;
  }
}

/// Async implementation of mix for when async features are used.
Future<T?> _mixAsync<T>({
  required FutureOr<T> Function() action,
  required Object key,
  NonReentrantConfig? nonReentrant,
  SequentialConfig? sequential,
  ThrottleConfig? throttle,
  DebounceConfig? debounce,
  FreshConfig? fresh,
  CheckInternetConfig? checkInternet,
  RetryConfig? retry,
  FutureOr<void> Function()? before,
  FutureOr<void> Function()? after,
  FutureOr<T> Function(FutureOr<T> Function() action)? wrapRun,
  void Function(Object error, StackTrace stackTrace)? catchError,
}) async {
  // Normalize key: if it's a Cubit/Bloc instance, use its runtimeType instead.
  // This allows users to pass `this` from within a Cubit/Bloc method and have
  // it work correctly with `context.isWaiting(MyCubit)`.
  final Object effectiveKey = key is BlocBase ? key.runtimeType : key;

  // Resolve effective keys: use config-specific key if provided, otherwise use default key
  final debounceKey = debounce?.key ?? effectiveKey;
  final nonReentrantKey = nonReentrant?.key ?? effectiveKey;
  final sequentialKey = sequential?.key ?? effectiveKey;
  final throttleKey = throttle?.key ?? effectiveKey;
  final freshKey = fresh?.key ?? effectiveKey;

  // Handle debounce check (must be first - delays and may abort if superseded)
  if (debounce != null) {
    final debounceMap = _getDebounceLockMap();

    // Increment and update the map with the new run count
    var beforeCount = (debounceMap[debounceKey] ?? 0) + 1;
    if (beforeCount > _safeInteger) beforeCount = 0;
    debounceMap[debounceKey] = beforeCount;

    // Wait for the debounce period
    await Future.delayed(debounce.duration!);

    var afterCount = debounceMap[debounceKey];

    // If the run count has changed, it means another action was dispatched
    // within the debounce period. Abort this one.
    if (afterCount != beforeCount) {
      debounce.onSuperseded?.call(debounceKey);
      return null;
    }

    // Otherwise, we remove the lock and proceed
    debounceMap.remove(debounceKey);
  }

  // Handle checkInternet check (after debounce, before other locks)
  // When retry is set and abortSilently is false, internet check moves inside retry loop
  final internetCheckInsideRetry =
      checkInternet != null && retry != null && !checkInternet.abortSilently!;

  if (checkInternet != null && !internetCheckInsideRetry) {
    final hasInternet = await _hasInternet();
    if (!hasInternet) {
      checkInternet.onNoInternet?.call();
      if (checkInternet.abortSilently!) {
        // AbortWhenNoInternet behavior: return null silently, no exception
        return null;
      } else {
        // CheckInternet behavior: throw ConnectionException
        // ifOpenDialog controls whether it's queued for dialog or rethrown
        final exception = ConnectionException.noConnectivity
            .withDialog(checkInternet.ifOpenDialog!);

        // Route through normal error handling so catchError can process it
        _handleFinalError(
          exception,
          StackTrace.current,
          after,
          catchError,
        );
        return null;
      }
    }
  }

  // Sequential queue state (set up early for queue full check)
  _SequentialQueueState? sequentialState;
  Completer<void>? sequentialCompleter;

  // Handle sequential queue full check (before onStart - if full, abort without tracking)
  if (sequential != null) {
    final sequentialMap = _getSequentialStateMap();
    sequentialState =
        sequentialMap.putIfAbsent(sequentialKey, () => _SequentialQueueState());

    // Check if queue is full (pendingCount > maxQueueSize means maxQueueSize are waiting + 1 running)
    final maxQueueSize = sequential.maxQueueSize;
    if (maxQueueSize != null && sequentialState.pendingCount > maxQueueSize) {
      // If dropOldest is true and there are waiters, supersede the oldest one
      if (sequential.dropOldest! && sequentialState.waiterIds.isNotEmpty) {
        final oldestWaiterId = sequentialState.waiterIds.removeAt(0);
        sequentialState.supersededIds.add(oldestWaiterId);
        sequentialState.pendingCount--; // Free up space for the new call
        sequential.onDropped
            ?.call(sequentialKey, SequentialDropReason.superseded);
      } else {
        // No waiters to supersede or dropOldest is false - drop the new call
        sequential.onDropped
            ?.call(sequentialKey, SequentialDropReason.queueFull);
        return null;
      }
    }
  }

  // Track inline state (for isWaitingInline/isFailedInline)
  Superpowers.onStart(effectiveKey);

  // Handle sequential queue wait (after onStart - so waiting shows as "in progress")
  DateTime? sequentialQueuedAt;
  int? myWaiterId;
  if (sequential != null && sequentialState != null) {
    final queuePosition = sequentialState
        .pendingCount; // Position before incrementing (0 = immediate)
    sequentialState.pendingCount++;
    sequentialQueuedAt = DateTime.now();
    final previousFuture = sequentialState.lastFuture;
    sequentialCompleter = Completer<void>();
    sequentialState.lastFuture = sequentialCompleter.future;

    // Notify and track if this call has to wait (position > 0 means there's at least one ahead)
    if (queuePosition > 0) {
      myWaiterId = sequentialState.nextWaiterId++;
      sequentialState.waiterIds.add(myWaiterId);
      sequential.onQueued?.call(sequentialKey, queuePosition);
    }

    // Wait for our turn in the queue
    await previousFuture;

    // Check if we were superseded while waiting (dropOldest feature)
    if (myWaiterId != null &&
        sequentialState.supersededIds.contains(myWaiterId)) {
      sequentialState.supersededIds.remove(myWaiterId);
      // Note: pendingCount was already decremented when we were superseded,
      // and onDropped was already called. Just complete and return.
      sequentialCompleter.complete();
      Superpowers.onComplete(effectiveKey, null);
      return null;
    }

    // Remove ourselves from waiterIds since we woke up normally
    if (myWaiterId != null) {
      sequentialState.waiterIds.remove(myWaiterId);
    }

    // Check if we've waited too long (queueTimeout)
    final queueTimeout = sequential.queueTimeout;
    if (queueTimeout != null) {
      final waitedDuration = DateTime.now().difference(sequentialQueuedAt);
      if (waitedDuration > queueTimeout) {
        // Timed out - clean up and abort
        sequential.onDropped?.call(sequentialKey, SequentialDropReason.timeout);
        sequentialState.pendingCount--;
        sequentialCompleter.complete();
        Superpowers.onComplete(effectiveKey, null);
        return null;
      }
    }
  }

  // Outer try-finally ensures sequential cleanup even if nonReentrant/throttle/fresh abort
  try {
    // Handle non-reentrant check
    if (nonReentrant != null) {
      final keySet = _getNonReentrantKeySet();

      // If the key is already running, abort immediately
      if (keySet.contains(nonReentrantKey)) {
        nonReentrant.onBlocked?.call(nonReentrantKey);
        Superpowers.onComplete(effectiveKey, null);
        return null;
      }

      // Add the key to mark this operation as running
      keySet.add(nonReentrantKey);
    }

    // Handle throttle check
    if (throttle != null) {
      final throttleMap = _getThrottleLockMap();
      final now = DateTime.now().toUtc();
      final expiresAt = throttleMap[throttleKey];

      // If ignoreThrottle is true, bypass the lock check (force execution)
      if (throttle.ignoreThrottle!) {
        // Set new lock expiry and proceed (bypasses existing lock)
        throttleMap[throttleKey] = now.add(throttle.duration!);
      }
      // If there is a lock and it hasn't expired yet, abort
      else if (expiresAt != null && expiresAt.isAfter(now)) {
        throttle.onThrottled?.call(throttleKey, expiresAt.difference(now));
        // Clean up nonReentrant lock set earlier
        if (nonReentrant != null) {
          _getNonReentrantKeySet().remove(nonReentrantKey);
        }
        Superpowers.onComplete(effectiveKey, null);
        return null;
      }
      // No lock or expired, set new lock expiry and proceed
      else {
        throttleMap[throttleKey] = now.add(throttle.duration!);
      }
    }

    // Handle fresh check
    DateTime? previousFreshExpiry;
    DateTime? newFreshExpiry;
    if (fresh != null) {
      final freshMap = _getFreshKeyMap();
      final now = DateTime.now().toUtc();
      previousFreshExpiry = freshMap[freshKey];

      // If ignoreFresh is true, bypass the fresh check (force refresh)
      if (fresh.ignoreFresh!) {
        // Set new expiry and proceed (previousFreshExpiry = null so it becomes stale on failure)
        newFreshExpiry = now.add(fresh.freshFor!);
        freshMap[freshKey] = newFreshExpiry;
        previousFreshExpiry = null; // Make it stale if the action fails
      }
      // If there is an expiry and it hasn't expired yet, abort
      else if (previousFreshExpiry != null &&
          previousFreshExpiry.isAfter(now)) {
        fresh.onFresh?.call(freshKey, previousFreshExpiry.difference(now));
        // Clean up nonReentrant and throttle locks set earlier
        if (nonReentrant != null) {
          _getNonReentrantKeySet().remove(nonReentrantKey);
        }
        if (throttle != null) {
          _getThrottleLockMap().remove(throttleKey);
          _pruneThrottleLocks();
        }
        Superpowers.onComplete(effectiveKey, null);
        return null;
      }
      // No expiry or it has expired, set new expiry and proceed
      else {
        newFreshExpiry = now.add(fresh.freshFor!);
        freshMap[freshKey] = newFreshExpiry;
      }
    }

    bool actionFailed = false;
    UserException? inlineUserException;

    try {
      // Call before() once at the start
      if (before != null) {
        try {
          final result = before();
          if (result is Future) await result;
        } catch (error, stack) {
          // AbortException is not a failure - it's an intentional silent abort
          if (error is! AbortException) actionFailed = true;
          // Handle error from before()
          inlineUserException =
              _handleFinalError(error, stack, after, catchError);
          return null;
        }
      }

      // Build the effective wrapRun by composing user's wrapRun with retry logic
      // When internetCheckInsideRetry is true, internet check is included in retry loop
      final effectiveWrapRun = _buildEffectiveWrapRun<T>(
        action: action,
        retryConfig: retry,
        userWrapRun: wrapRun,
        internetCheckConfig: internetCheckInsideRetry ? checkInternet : null,
        maxRetryDelay: checkInternet?.maxRetryDelay,
      );

      try {
        // Execute action via effectiveWrapRun
        final FutureOr<T> result = effectiveWrapRun();
        final T finalResult;
        if (result is Future<T>) {
          finalResult = await result;
        } else {
          finalResult = result;
        }

        // Call after() on success
        _runAfter(after);
        return finalResult;
      } catch (error, stack) {
        // AbortException is not a failure - it's an intentional silent abort
        if (error is! AbortException) actionFailed = true;
        // Handle final error (after all retries exhausted)
        inlineUserException = _handleFinalError(error, stack, after, catchError);
        return null;
      }
    } finally {
      // Remove the nonReentrant key when done (success or failure)
      if (nonReentrant != null) {
        _getNonReentrantKeySet().remove(nonReentrantKey);
      }

      // Handle fresh rollback on failure
      if (fresh != null && actionFailed) {
        final freshMap = _getFreshKeyMap();
        // Only rollback if the map still contains our expiry
        if (freshMap[freshKey] == newFreshExpiry) {
          if (previousFreshExpiry == null) {
            // No previous expiry: remove key (make stale)
            freshMap.remove(freshKey);
          } else {
            // Restore previous expiry
            freshMap[freshKey] = previousFreshExpiry;
          }
        }
      }

      // Prune expired fresh keys periodically
      if (fresh != null) {
        _pruneFreshKeys();
      }

      // Handle throttle lock removal on error
      if (throttle != null) {
        if (actionFailed && throttle.removeLockOnError!) {
          _getThrottleLockMap().remove(throttleKey);
        }
        // Prune expired throttle locks periodically
        _pruneThrottleLocks();
      }

      // Track inline completion (for isWaitingInline/isFailedInline)
      Superpowers.onComplete(effectiveKey, actionFailed ? inlineUserException : null);
    }
  } finally {
    // Sequential cleanup - must run even if nonReentrant/throttle/fresh abort
    // This ensures the next queued operation can proceed
    if (sequentialCompleter != null && !sequentialCompleter.isCompleted) {
      sequentialState!.pendingCount--;
      sequentialCompleter.complete();
    }
  }
}

/// Async implementation of mix.ctx that tracks context (especially retry attempts).
Future<T?> _mixCtxAsync<T>({
  required FutureOr<T> Function(MixContext ctx) action,
  required MixContext baseContext,
  required Object key,
  NonReentrantConfig? nonReentrant,
  SequentialConfig? sequential,
  ThrottleConfig? throttle,
  DebounceConfig? debounce,
  FreshConfig? fresh,
  CheckInternetConfig? checkInternet,
  RetryConfig? retry,
  FutureOr<void> Function()? before,
  FutureOr<void> Function()? after,
  FutureOr<T> Function(FutureOr<T> Function() action)? wrapRun,
  void Function(Object error, StackTrace stackTrace)? catchError,
}) async {
  // Normalize key: if it's a Cubit/Bloc instance, use its runtimeType instead.
  final Object effectiveKey = key is BlocBase ? key.runtimeType : key;

  // Resolve effective keys
  final debounceKey = debounce?.key ?? effectiveKey;
  final nonReentrantKey = nonReentrant?.key ?? effectiveKey;
  final sequentialKey = sequential?.key ?? effectiveKey;
  final throttleKey = throttle?.key ?? effectiveKey;
  final freshKey = fresh?.key ?? effectiveKey;

  // Handle debounce check (must be first - delays and may abort if superseded)
  if (debounce != null) {
    final debounceMap = _getDebounceLockMap();
    var beforeCount = (debounceMap[debounceKey] ?? 0) + 1;
    if (beforeCount > _safeInteger) beforeCount = 0;
    debounceMap[debounceKey] = beforeCount;

    await Future.delayed(debounce.duration!);

    var afterCount = debounceMap[debounceKey];
    if (afterCount != beforeCount) {
      debounce.onSuperseded?.call(debounceKey);
      return null;
    }
    debounceMap.remove(debounceKey);
  }

  // Handle checkInternet check (after debounce, before other locks)
  final internetCheckInsideRetry =
      checkInternet != null && retry != null && !checkInternet.abortSilently!;

  if (checkInternet != null && !internetCheckInsideRetry) {
    final hasInternet = await _hasInternet();
    if (!hasInternet) {
      checkInternet.onNoInternet?.call();
      if (checkInternet.abortSilently!) {
        return null;
      } else {
        final exception = ConnectionException.noConnectivity
            .withDialog(checkInternet.ifOpenDialog!);
        _handleFinalError(exception, StackTrace.current, after, catchError);
        return null;
      }
    }
  }

  // Sequential queue state
  _SequentialQueueState? sequentialState;
  Completer<void>? sequentialCompleter;
  int sequentialIndex = 0;

  if (sequential != null) {
    final sequentialMap = _getSequentialStateMap();
    sequentialState =
        sequentialMap.putIfAbsent(sequentialKey, () => _SequentialQueueState());
    final maxQueueSize = sequential.maxQueueSize;
    if (maxQueueSize != null && sequentialState.pendingCount > maxQueueSize) {
      // If dropOldest is true and there are waiters, supersede the oldest one
      if (sequential.dropOldest! && sequentialState.waiterIds.isNotEmpty) {
        final oldestWaiterId = sequentialState.waiterIds.removeAt(0);
        sequentialState.supersededIds.add(oldestWaiterId);
        sequentialState.pendingCount--; // Free up space for the new call
        sequential.onDropped
            ?.call(sequentialKey, SequentialDropReason.superseded);
      } else {
        // No waiters to supersede or dropOldest is false - drop the new call
        sequential.onDropped
            ?.call(sequentialKey, SequentialDropReason.queueFull);
        return null;
      }
    }
  }

  Superpowers.onStart(effectiveKey);

  DateTime? sequentialQueuedAt;
  int? myWaiterId;
  if (sequential != null && sequentialState != null) {
    // Capture queue index BEFORE incrementing (0 = immediate, >0 = queued)
    sequentialIndex = sequentialState.pendingCount;
    sequentialState.pendingCount++;
    sequentialQueuedAt = DateTime.now();
    final previousFuture = sequentialState.lastFuture;
    sequentialCompleter = Completer<void>();
    sequentialState.lastFuture = sequentialCompleter.future;

    // Notify and track if this call has to wait (position > 0 means there's at least one ahead)
    if (sequentialIndex > 0) {
      myWaiterId = sequentialState.nextWaiterId++;
      sequentialState.waiterIds.add(myWaiterId);
      sequential.onQueued?.call(sequentialKey, sequentialIndex);
    }

    await previousFuture;

    // Check if we were superseded while waiting (dropOldest feature)
    if (myWaiterId != null &&
        sequentialState.supersededIds.contains(myWaiterId)) {
      sequentialState.supersededIds.remove(myWaiterId);
      // Note: pendingCount was already decremented when we were superseded,
      // and onDropped was already called. Just complete and return.
      sequentialCompleter.complete();
      Superpowers.onComplete(effectiveKey, null);
      return null;
    }

    // Remove ourselves from waiterIds since we woke up normally
    if (myWaiterId != null) {
      sequentialState.waiterIds.remove(myWaiterId);
    }

    final queueTimeout = sequential.queueTimeout;
    if (queueTimeout != null) {
      final waitedDuration = DateTime.now().difference(sequentialQueuedAt);
      if (waitedDuration > queueTimeout) {
        sequential.onDropped?.call(sequentialKey, SequentialDropReason.timeout);
        sequentialState.pendingCount--;
        sequentialCompleter.complete();
        Superpowers.onComplete(effectiveKey, null);
        return null;
      }
    }
  }

  // Create the context with sequential info (now that we know the queue index)
  final contextWithSequential = sequential != null
      ? MixContext(
          retry: baseContext.retry,
          nonReentrant: baseContext.nonReentrant,
          throttle: baseContext.throttle,
          debounce: baseContext.debounce,
          fresh: baseContext.fresh,
          checkInternet: baseContext.checkInternet,
          sequential: SequentialContext(
            config: sequential.resolve(),
            wasQueued: sequentialIndex > 0,
            index: sequentialIndex,
          ),
        )
      : baseContext;

  try {
    if (nonReentrant != null) {
      final keySet = _getNonReentrantKeySet();
      if (keySet.contains(nonReentrantKey)) {
        nonReentrant.onBlocked?.call(nonReentrantKey);
        Superpowers.onComplete(effectiveKey, null);
        return null;
      }
      keySet.add(nonReentrantKey);
    }

    if (throttle != null) {
      final throttleMap = _getThrottleLockMap();
      final now = DateTime.now().toUtc();
      final expiresAt = throttleMap[throttleKey];

      if (throttle.ignoreThrottle!) {
        throttleMap[throttleKey] = now.add(throttle.duration!);
      } else if (expiresAt != null && expiresAt.isAfter(now)) {
        throttle.onThrottled?.call(throttleKey, expiresAt.difference(now));
        if (nonReentrant != null) {
          _getNonReentrantKeySet().remove(nonReentrantKey);
        }
        Superpowers.onComplete(effectiveKey, null);
        return null;
      } else {
        throttleMap[throttleKey] = now.add(throttle.duration!);
      }
    }

    DateTime? previousFreshExpiry;
    DateTime? newFreshExpiry;
    if (fresh != null) {
      final freshMap = _getFreshKeyMap();
      final now = DateTime.now().toUtc();
      previousFreshExpiry = freshMap[freshKey];

      if (fresh.ignoreFresh!) {
        newFreshExpiry = now.add(fresh.freshFor!);
        freshMap[freshKey] = newFreshExpiry;
        previousFreshExpiry = null;
      } else if (previousFreshExpiry != null &&
          previousFreshExpiry.isAfter(now)) {
        fresh.onFresh?.call(freshKey, previousFreshExpiry.difference(now));
        if (nonReentrant != null) {
          _getNonReentrantKeySet().remove(nonReentrantKey);
        }
        if (throttle != null) {
          _getThrottleLockMap().remove(throttleKey);
          _pruneThrottleLocks();
        }
        Superpowers.onComplete(effectiveKey, null);
        return null;
      } else {
        newFreshExpiry = now.add(fresh.freshFor!);
        freshMap[freshKey] = newFreshExpiry;
      }
    }

    bool actionFailed = false;
    UserException? inlineUserException;

    try {
      if (before != null) {
        try {
          final result = before();
          if (result is Future) await result;
        } catch (error, stack) {
          if (error is! AbortException) actionFailed = true;
          inlineUserException =
              _handleFinalError(error, stack, after, catchError);
          return null;
        }
      }

      // Build the effective wrapRun with context tracking
      final effectiveWrapRun = _buildEffectiveWrapRunWithContext<T>(
        action: action,
        baseContext: contextWithSequential,
        retryConfig: retry,
        userWrapRun: wrapRun,
        internetCheckConfig: internetCheckInsideRetry ? checkInternet : null,
        maxRetryDelay: checkInternet?.maxRetryDelay,
      );

      try {
        final FutureOr<T> result = effectiveWrapRun();
        final T finalResult;
        if (result is Future<T>) {
          finalResult = await result;
        } else {
          finalResult = result;
        }

        _runAfter(after);
        return finalResult;
      } catch (error, stack) {
        if (error is! AbortException) actionFailed = true;
        inlineUserException = _handleFinalError(error, stack, after, catchError);
        return null;
      }
    } finally {
      if (nonReentrant != null) {
        _getNonReentrantKeySet().remove(nonReentrantKey);
      }

      if (fresh != null && actionFailed) {
        final freshMap = _getFreshKeyMap();
        if (freshMap[freshKey] == newFreshExpiry) {
          if (previousFreshExpiry == null) {
            freshMap.remove(freshKey);
          } else {
            freshMap[freshKey] = previousFreshExpiry;
          }
        }
      }

      if (fresh != null) {
        _pruneFreshKeys();
      }

      if (throttle != null) {
        if (actionFailed && throttle.removeLockOnError!) {
          _getThrottleLockMap().remove(throttleKey);
        }
        _pruneThrottleLocks();
      }

      Superpowers.onComplete(effectiveKey, actionFailed ? inlineUserException : null);
    }
  } finally {
    if (sequentialCompleter != null && !sequentialCompleter.isCompleted) {
      sequentialState!.pendingCount--;
      sequentialCompleter.complete();
    }
  }
}

/// Builds the effective wrapRun by composing retry logic with user's wrapRun.
///
/// The composition is: retryWrapRun(userWrapRun(action))
/// - User's wrapRun wraps each individual attempt
/// - Retry logic wraps everything and handles retries
///
/// When [internetCheckConfig] is provided, internet connectivity is checked before
/// each attempt. If there's no internet, [_NoInternetRetryException] is thrown
/// to trigger a retry. When all retries are exhausted, it's converted to
/// [ConnectionException].
///
/// When [maxRetryDelay] is provided, it is used as the maximum delay
/// between retries when there is no internet (instead of [maxDelay]).
/// This allows for quicker detection of when internet comes back.
FutureOr<T> Function() _buildEffectiveWrapRun<T>({
  required FutureOr<T> Function() action,
  RetryConfig? retryConfig,
  FutureOr<T> Function(FutureOr<T> Function())? userWrapRun,
  CheckInternetConfig? internetCheckConfig,
  Duration? maxRetryDelay,
}) {
  // If no retry config, just use user's wrapRun or identity
  if (retryConfig == null) {
    return () {
      if (userWrapRun != null) {
        return userWrapRun(action);
      } else {
        return action();
      }
    };
  }

  // Extract retry config (values are non-null after merge with defaults)
  final maxRetries = retryConfig.maxRetries!;
  final initialDelay = retryConfig.initialDelay!;
  var multiplier = retryConfig.multiplier!;
  final maxDelay = retryConfig.maxDelay!;
  final onRetry = retryConfig.onRetry;

  if (multiplier <= 1) multiplier = 2;

  // The maximum delay between retries when there is no internet. The default is 1 second.
  final effectiveMaxDelayNoInternet =
      maxRetryDelay ?? const Duration(seconds: 1);

  // Create retry wrapRun (similar to Retry mixin's wrapRun)
  return () {
    var attempts = 0;
    Duration? currentDelay;

    /// Calculates the next delay using exponential backoff.
    /// Uses [effectiveMaxDelayNoInternet] when there's no internet (shorter delays),
    /// and [maxDelay] for other errors (longer delays).
    Duration nextDelay({required bool hasInternet}) {
      currentDelay =
          (currentDelay == null) ? initialDelay : currentDelay! * multiplier;

      if (hasInternet) {
        if (currentDelay! > maxDelay) currentDelay = maxDelay;
      } else {
        if (currentDelay! > effectiveMaxDelayNoInternet) {
          currentDelay = effectiveMaxDelayNoInternet;
        }
      }
      return currentDelay!;
    }

    Future<T> executeWithRetry() async {
      try {
        // If internetCheckConfig is provided, check connectivity before each attempt
        if (internetCheckConfig != null) {
          final hasInternet = await _hasInternet();
          if (!hasInternet) {
            // Throw internal exception to trigger retry
            throw const _NoInternetRetryException();
          }
        }

        // Execute action via user's wrapRun (if provided) or directly
        final FutureOr<T> result;
        if (userWrapRun != null) {
          result = userWrapRun(action);
        } else {
          result = action();
        }
        if (result is Future<T>) {
          return await result;
        }
        return result;
      } catch (error, stack) {
        // AbortException should never be retried - rethrow immediately
        if (error is AbortException) rethrow;

        attempts++;

        // If maxRetries is negative, retry indefinitely.
        // If we've exceeded maxRetries, convert _NoInternetRetryException or rethrow.
        if ((maxRetries >= 0) && (attempts > maxRetries)) {
          if (error is _NoInternetRetryException &&
              internetCheckConfig != null) {
            // Call onNoInternet when all retries are exhausted due to no internet
            internetCheckConfig.onNoInternet?.call();
            // Convert to proper ConnectionException with user's ifOpenDialog setting
            throw ConnectionException.noConnectivity
                .withDialog(internetCheckConfig.ifOpenDialog!);
          }
          rethrow;
        }

        // Determine if this is a no-internet error (use shorter delays)
        final isNoInternet = error is _NoInternetRetryException;

        // Calculate and wait for the next delay
        final delay = nextDelay(hasInternet: !isNoInternet);

        // Notify listener before waiting (convert internal exception for callback)
        if (isNoInternet) {
          onRetry?.call(
              attempts, delay, ConnectionException.noConnectivity, stack);
        } else {
          onRetry?.call(attempts, delay, error, stack);
        }

        await Future.delayed(delay);

        // Retry the action
        return executeWithRetry();
      }
    }

    return executeWithRetry();
  };
}

/// Like [_buildEffectiveWrapRun] but tracks retry attempts in the context.
///
/// The action receives a [MixContext] with updated retry attempts on each attempt.
FutureOr<T> Function() _buildEffectiveWrapRunWithContext<T>({
  required FutureOr<T> Function(MixContext ctx) action,
  required MixContext baseContext,
  RetryConfig? retryConfig,
  FutureOr<T> Function(FutureOr<T> Function())? userWrapRun,
  CheckInternetConfig? internetCheckConfig,
  Duration? maxRetryDelay,
}) {
  // If no retry config, just use user's wrapRun or identity with base context
  if (retryConfig == null) {
    return () {
      if (userWrapRun != null) {
        return userWrapRun(() => action(baseContext));
      } else {
        return action(baseContext);
      }
    };
  }

  // Extract retry config (values are non-null after merge with defaults)
  final maxRetries = retryConfig.maxRetries!;
  final initialDelay = retryConfig.initialDelay!;
  var multiplier = retryConfig.multiplier!;
  final maxDelay = retryConfig.maxDelay!;
  final onRetry = retryConfig.onRetry;

  if (multiplier <= 1) multiplier = 2;

  // The maximum delay between retries when there is no internet. The default is 1 second.
  final effectiveMaxDelayNoInternet =
      maxRetryDelay ?? const Duration(seconds: 1);

  // Create retry wrapRun with context tracking
  return () {
    var attempts = 0;
    Duration? currentDelay;

    /// Calculates the next delay using exponential backoff.
    Duration nextDelay({required bool hasInternet}) {
      currentDelay =
          (currentDelay == null) ? initialDelay : currentDelay! * multiplier;

      if (hasInternet) {
        if (currentDelay! > maxDelay) currentDelay = maxDelay;
      } else {
        if (currentDelay! > effectiveMaxDelayNoInternet) {
          currentDelay = effectiveMaxDelayNoInternet;
        }
      }
      return currentDelay!;
    }

    Future<T> executeWithRetry() async {
      try {
        // If internetCheckConfig is provided, check connectivity before each attempt
        if (internetCheckConfig != null) {
          final hasInternet = await _hasInternet();
          if (!hasInternet) {
            // Throw internal exception to trigger retry
            throw const _NoInternetRetryException();
          }
        }

        // Create context with current attempts count
        final currentContext = (baseContext.retry == null)
            ? baseContext
            : MixContext(
                retry: RetryContext(
                  config: baseContext.retry!.config,
                  attempt: attempts,
                ),
                nonReentrant: baseContext.nonReentrant,
                throttle: baseContext.throttle,
                debounce: baseContext.debounce,
                fresh: baseContext.fresh,
                checkInternet: baseContext.checkInternet,
                sequential: baseContext.sequential,
              );

        // Execute action via user's wrapRun (if provided) or directly
        final FutureOr<T> result;
        if (userWrapRun != null) {
          result = userWrapRun(() => action(currentContext));
        } else {
          result = action(currentContext);
        }
        if (result is Future<T>) {
          return await result;
        }
        return result;
      } catch (error, stack) {
        // AbortException should never be retried - rethrow immediately
        if (error is AbortException) rethrow;

        attempts++;

        // If maxRetries is negative, retry indefinitely.
        // If we've exceeded maxRetries, convert _NoInternetRetryException or rethrow.
        if ((maxRetries >= 0) && (attempts > maxRetries)) {
          if (error is _NoInternetRetryException &&
              internetCheckConfig != null) {
            // Call onNoInternet when all retries are exhausted due to no internet
            internetCheckConfig.onNoInternet?.call();
            // Convert to proper ConnectionException with user's ifOpenDialog setting
            throw ConnectionException.noConnectivity
                .withDialog(internetCheckConfig.ifOpenDialog!);
          }
          rethrow;
        }

        // Determine if this is a no-internet error (use shorter delays)
        final isNoInternet = error is _NoInternetRetryException;

        // Calculate and wait for the next delay
        final delay = nextDelay(hasInternet: !isNoInternet);

        // Notify listener before waiting (convert internal exception for callback)
        if (isNoInternet) {
          onRetry?.call(
              attempts, delay, ConnectionException.noConnectivity, stack);
        } else {
          onRetry?.call(attempts, delay, error, stack);
        }

        await Future.delayed(delay);

        // Retry the action
        return executeWithRetry();
      }
    }

    return executeWithRetry();
  };
}

/// Handles the final error after all retries are exhausted.
/// Similar to Superpowers's _handleError method.
///
/// Returns the [UserException] if the processed error is a UserException
/// (for inline tracking purposes), or null otherwise.
///
/// The [catchError] callback follows try/catch semantics:
/// - If it returns normally, the error is suppressed
/// - If it throws (any error), that error is propagated with the original stack trace
UserException? _handleFinalError(
  Object error,
  StackTrace stackTrace,
  FutureOr<void> Function()? after,
  void Function(Object error, StackTrace stackTrace)? catchError,
) {
  // AbortException is handled specially: skip catchError, call after, don't rethrow
  if (error is AbortException) {
    _runAfter(after);
    return null;
  }

  // Process error through catchError using try/catch semantics:
  // - If catchError returns normally → suppress the error (processedError = null)
  // - If catchError throws → propagate that error (processedError = thrownError)
  Object? processedError;
  if (catchError != null) {
    try {
      catchError(error, stackTrace);
      // Returned normally - suppress the error
      processedError = null;
    } catch (thrownError) {
      // Threw an error - propagate it with original stack trace
      processedError = thrownError;
    }
  } else {
    // No catchError provided - propagate original error
    processedError = error;
  }

  // Always call after()
  _runAfter(after);

  // Handle the error based on type
  if (processedError == null) {
    // catchError returned normally - error was suppressed
    return null;
  }

  // UserExceptions with ifOpenDialog=true are queued for dialog display
  if (processedError is UserException && processedError.ifOpenDialog) {
    Superpowers.addUserException(processedError);
    // Don't rethrow - queued for UI display
    return processedError;
  }

  // Track UserExceptions even if they'll be rethrown (ifOpenDialog=false)
  final userExceptionForTracking =
      processedError is UserException ? processedError : null;

  // All other errors are rethrown with the original stack trace
  Error.throwWithStackTrace(processedError, stackTrace);

  // Note: This return is never reached due to rethrow above,
  // but Dart requires it for type safety
  return userExceptionForTracking;
}

/// Safely executes the after() callback.
void _runAfter(FutureOr<void> Function()? after) {
  if (after == null) return;
  try {
    final result = after();
    // Note: We don't await async after() to match Superpowers's sync behavior
    // If you need async cleanup, handle it within the callback
    if (result is Future) {
      result.catchError((e, s) {
        Zone.current.handleUncaughtError(e, s);
      });
    }
  } catch (error, stackTrace) {
    // after() should never throw, but if it does, report it
    // but don't propagate (to avoid masking original errors)
    Zone.current.handleUncaughtError(error, stackTrace);
  }
}
