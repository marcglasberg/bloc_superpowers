// Developed by Marcelo Glasberg (2026) https://glasberg.dev and https://github.com/marcglasberg
// For more info, see: https://pub.dartlang.org/packages/bloc_superpowers and http://blocsuperpowers.org
import 'dart:async';
import 'dart:collection';
import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:flutter/material.dart';
import 'package:bloc/bloc.dart';
import 'package:provider/provider.dart';

/// BuildContext extension for checking waiting/failed state of Cubit methods.
///
/// These methods automatically register the widget as a dependent of
/// [Superpowers], so the widget rebuilds when method state changes.
///
/// **Important:** [Superpowers] must be placed near the top of your widget
/// tree for these methods to trigger rebuilds.
///
extension SuperpowersContextExtension on BuildContext {
  /// Returns true if a [mix] call with the given key(s) is in progress.
  ///
  /// Automatically registers the widget for rebuilds when state changes.
  bool isWaiting(Object keyOrList) {
    _dependOnSuperpowers();
    return Superpowers.isWaiting(keyOrList);
  }

  /// Returns true if a [mix] call with the given key has failed.
  ///
  /// Automatically registers the widget for rebuilds when state changes.
  bool isFailed(Object keyOrList) {
    _dependOnSuperpowers();
    return Superpowers.isFailed(keyOrList);
  }

  /// Returns the [UserException] for a failed [mix] call, or null.
  ///
  /// Automatically registers the widget for rebuilds when state changes.
  UserException? getException(Object keyOrList) {
    _dependOnSuperpowers();
    return Superpowers.getException(keyOrList);
  }

  /// Clears the failed state for the given [mix] key(s).
  void clearException(Object keyOrList) =>
      Superpowers.clearException(keyOrList);

  /// Consume an effect from the state, and rebuild the widget when the effect
  /// is dispatched.
  ///
  /// Effects are one-time notifications that can be used to trigger side effects
  /// in widgets, such as showing a dialog, clearing a text field, or navigating
  /// to a new screen. Unlike regular state values, effects are automatically
  /// "consumed" (marked as spent) after being read, ensuring they only trigger
  /// once.
  ///
  /// This method selects an effect from the Cubit's state using the provided
  /// [selector] function, consumes it, and returns its value. The widget will
  /// rebuild whenever a new (unspent) effect is dispatched.
  ///
  /// **Return value:**
  /// - For effects with no generic type (`Effect`): Returns `true` if the effect
  ///   was dispatched, or `false` if it was already spent.
  /// - For effects with a value type (`Effect<R>`): Returns the effect's value if
  ///   it was dispatched, or `null` if it was already spent.
  ///
  /// **Example with a boolean (value-less) effect (clear text field):**
  ///
  /// In your state:
  /// ```dart
  /// class AppState {
  ///   final Effect clearTextEffect;
  ///   AppState({Effect? clearTextEffect})
  ///       : clearTextEffect = clearTextEffect ?? Effect.spent();
  /// }
  /// ```
  ///
  /// In your Cubit:
  /// ```dart
  /// void clearText() => emit(state.copy(clearTextEffect: Effect()));
  /// ```
  ///
  /// In your widget:
  /// ```dart
  /// Widget build(BuildContext context) {
  ///   var clearText = context.effect((AppCubit c) => c.state.clearTextEffect);
  ///   if (clearText == true) controller.clear();
  ///   ...
  /// }
  /// ```
  ///
  /// **Example with a typed effect (display text in text field):**
  ///
  /// In your state:
  /// ```dart
  /// class AppState {
  ///   final Effect<String> changeTextEffect;
  ///   AppState({Effect<String>? changeTextEffect})
  ///       : changeTextEffect = changeTextEffect ?? Effect.spent();
  /// }
  /// ```
  ///
  /// In your Cubit:
  /// ```dart
  /// Future<void> changeText() async {
  ///   String newText = await fetchTextFromApi();
  ///   emit(state.copy(changeTextEffect: Effect<String>(newText)));
  /// }
  /// ```
  ///
  /// In your widget:
  /// ```dart
  /// Widget build(BuildContext context) {
  ///   var newText = context.effect((AppCubit c) => c.state.changeTextEffect);
  ///   if (newText != null) controller.text = newText;
  ///   ...
  /// }
  /// ```
  ///
  /// **Important notes:**
  /// - Effects are consumed only once. After consumption, they are marked as
  ///   "spent" and won't trigger again until a new effect is dispatched.
  /// - Each effect can be consumed by **only one widget**. If you need multiple
  ///   widgets to react to the same trigger, use separate effects in the state.
  /// - Initialize effects in the state as spent: `Effect.spent()` or
  ///   `Effect<T>.spent()`.
  /// - The widget will rebuild when a new effect is dispatched, even if it has
  ///   the same internal value as a previous effect, because each effect instance
  ///   is unique.
  /// - The [selector] function must be pure and not cause side effects.
  ///
  /// See also:
  /// - [Effect] class documentation for more details on effect behavior.
  ///
  R? effect<C extends Cubit<Object?>, R>(Effect<R> Function(C cubit) selector) {
    final eff = select<C, Effect<R>>(selector);
    return eff.consume();
  }

  /// Consume a queue of effects, triggering side effects in the UI layer.
  ///
  /// The Cubit provides a list of effect objects via [EffectQueue], and
  /// the [handler] function interprets each effect (e.g., showing a toast,
  /// dialog, or navigating). This keeps business logic in the Cubit and
  /// UI concerns in the widget.
  ///
  /// By default ([onePerFrame] = true), effects are handled one per frame:
  /// 1. First effect is handled after build completes
  /// 2. Emits remaining effects, triggering a rebuild
  /// 3. Repeats until all effects are consumed
  ///
  /// If [onePerFrame] = false, all effects are handled in order in a single
  /// post-frame callback. This is faster but all effects happen at once.
  ///
  /// **Example - Define your UI effects:**
  /// ```dart
  /// sealed class UiEffect {}
  /// class ShowToast extends UiEffect { final String message; ShowToast(this.message); }
  /// class ShowDialog extends UiEffect { final String title; ShowDialog(this.title); }
  /// class Navigate extends UiEffect { final String route; Navigate(this.route); }
  /// ```
  ///
  /// **Example - In your state:**
  /// ```dart
  /// class AppState {
  ///   final EffectQueue<UiEffect> effectQueue;
  ///   AppState({EffectQueue<UiEffect>? effectQueue})
  ///       : effectQueue = effectQueue ?? EffectQueue.spent();
  /// }
  /// ```
  ///
  /// **Example - In your Cubit (clean, no UI code):**
  /// ```dart
  /// void triggerEffects() {
  ///   emit(state.copyWith(
  ///     effectQueue: EffectQueue<UiEffect>(
  ///       [ShowToast('Saved!'), ShowDialog('Continue?'), Navigate('/next')],
  ///       (remaining) => emit(state.copyWith(effectQueue: remaining)),
  ///     ),
  ///   ));
  /// }
  /// ```
  ///
  /// **Example - In your widget (handler interprets effects):**
  /// ```dart
  /// Widget build(BuildContext context) {
  ///   context.effectQueue<AppCubit, UiEffect>(
  ///     (c) => c.state.effectQueue,
  ///     (ctx, effect) => switch (effect) {
  ///       ShowToast(:final message) => ScaffoldMessenger.of(ctx).showSnackBar(...),
  ///       ShowDialog(:final title) => showDialog(context: ctx, ...),
  ///       Navigate(:final route) => Navigator.pushNamed(ctx, route),
  ///     },
  ///     onePerFrame: false,  // Optional: process all effects in one frame
  ///   );
  ///   return MyContent();
  /// }
  /// ```
  void effectQueue<C extends Cubit<Object?>, E>(
    EffectQueue<E> Function(C cubit) selector,
    void Function(BuildContext context, E effect) handler, {
    bool onePerFrame = true,
  }) {
    final queue = select<C, EffectQueue<E>>(selector);
    queue.consumeOne(this, handler, onePerFrame: onePerFrame);
  }

  /// Registers this widget as a dependent of [Superpowers].
  /// Throws a [FlutterError] if [Superpowers] is not in the widget tree.
  void _dependOnSuperpowers() {
    final inherited =
        dependOnInheritedWidgetOfExactType<_SuperpowersInherited>();
    if (inherited == null) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('Superpowers widget not found in widget tree.'),
        ErrorDescription(
          'context.isWaiting(), context.isFailed(), and context.getException() '
          'require the Superpowers widget to be an ancestor in the widget tree '
          'for automatic rebuilds when mix() call state changes.',
        ),
        ErrorHint(
          'Wrap your app with Superpowers:\n\n'
          '  Superpowers(\n'
          '    child: MaterialApp(...),\n'
          '  )',
        ),
      ]);
    }
  }
}

// ---------- RunStatus ----------

/// Tracks the run status of a [Method].
class RunStatus {
  const RunStatus({
    this.isDispatched = false,
    this.hasFinishedBefore = false,
    this.hasFinishedRun = false,
    this.hasFinishedAfter = false,
    this.isAborted = false,
    this.originalError,
    this.wrappedError,
  });

  /// True if the method was dispatched (run() was called on Superpowers).
  final bool isDispatched;

  /// True when [before] finished executing without error.
  final bool hasFinishedBefore;

  /// True when [run] finished executing without error.
  final bool hasFinishedRun;

  /// True when [after] finished executing.
  final bool hasFinishedAfter;

  /// True if [abort] returned true, skipping execution entirely.
  final bool isAborted;

  /// The original error thrown by [before] or [run], before [wrapError] processing.
  final Object? originalError;

  /// The final error after [wrapError] processing. Null if error was suppressed.
  final Object? wrappedError;

  /// True if method completed successfully (no errors in before/run).
  bool get isCompletedOk => isCompleted && originalError == null;

  /// True if method completed but with an error.
  bool get isCompletedFailed => isCompleted && originalError != null;

  /// True if the method has finished executing (after was called).
  bool get isCompleted => hasFinishedAfter;

  @override
  String toString() => 'RunStatus('
      'isDispatched: $isDispatched, '
      'hasFinishedBefore: $hasFinishedBefore, '
      'hasFinishedRun: $hasFinishedRun, '
      'hasFinishedAfter: $hasFinishedAfter, '
      'isAborted: $isAborted, '
      'originalError: $originalError, '
      'wrappedError: $wrappedError)';
}

// ---------- Superpowers ----------

/// A widget that enables `context.isWaiting`, `context.isFailed`, and
/// `context.getException` to trigger widget rebuilds when method state changes.
///
/// Place this widget near the top of your widget tree, typically wrapping
/// your [MaterialApp] or [CupertinoApp]:
///
/// ```dart
/// void main() {
///   runApp(
///     Superpowers(
///       child: MaterialApp(
///         home: UserExceptionDialog(
///           child: MyHomePage(),
///         ),
///       ),
///     ),
///   );
/// }
/// ```
///
/// Then in your widgets, simply use the context extensions:
///
/// ```dart
/// Widget build(BuildContext context) {
///   if (context.isWaiting(FetchUserAction)) return CircularProgressIndicator();
///   if (context.isFailed(FetchUserAction)) return Text('Error: ${context.getException(FetchUserAction)?.message}');
///   return UserProfile();
/// }
/// ```
///
/// You can also check multiple method types:
///
/// ```dart
/// if (context.isWaiting([FetchUserAction, FetchPostsAction])) {
///   return CircularProgressIndicator();
/// }
/// ```
class Superpowers extends StatefulWidget {
  /// The child widget tree.
  final Widget child;

  const Superpowers({required this.child, super.key});

  @override
  State<Superpowers> createState() => _SuperpowersState();

  /// Function that returns the simulated internet state.
  /// - Returns `true` to simulate internet being ON
  /// - Returns `false` to simulate internet being OFF
  /// - Returns `null` to use the real connectivity check (default)
  static bool? Function() _simulateInternet = () => null;

  /// Returns the simulated internet state for use by connectivity checks.
  ///
  /// - `true`: Simulate internet being ON
  /// - `false`: Simulate internet being OFF
  /// - `null`: Use the real connectivity check (default)
  ///
  /// This is cleared via [Superpowers.clear] and used by the [mix] param
  /// `checkInternet`.
  static bool? get simulateInternet => _simulateInternet();

  // -------- Props (Key-Value Storage) --------

  /// Key-value storage for global properties.
  /// Can store timers, streams, futures with automatic cleanup via [disposeProps].
  static final Map<Object?, Object?> _props = HashMap();

  /// Gets a property from the store.
  ///
  /// This can be used to save global values, scoped to the static Superpowers state.
  /// For example, you could save timers, streams or futures used by actions.
  ///
  /// ```dart
  /// Superpowers.setProp("timer", Timer(Duration(seconds: 1), () => print("tick")));
  /// var timer = Superpowers.prop<Timer>("timer");
  /// timer.cancel();
  /// ```
  ///
  /// See also: [setProp] and [disposeProps].
  static V prop<V>(Object? key) => _props[key] as V;

  /// Sets a property in the store.
  ///
  /// This can be used to save global values, scoped to the static Superpowers state.
  /// For example, you could save timers, streams or futures used by actions.
  ///
  /// ```dart
  /// Superpowers.setProp("timer", Timer(Duration(seconds: 1), () => print("tick")));
  /// var timer = Superpowers.prop<Timer>("timer");
  /// timer.cancel();
  /// ```
  ///
  /// See also: [prop] and [disposeProps].
  static void setProp(Object? key, Object? value) => _props[key] = value;

  /// Disposes and removes properties from the store.
  ///
  /// This method cleans up resources by stopping, closing, ignoring and removing
  /// timers, streams, sinks, and futures that are saved as properties.
  ///
  /// * If no predicate is provided, all properties which are [Timer], [Future],
  ///   [StreamSubscription], [StreamConsumer], or [Sink] will be closed/canceled
  ///   as appropriate, and then removed. Other properties will not be removed.
  ///
  /// * If a predicate is provided and returns `true` for a given property, that
  ///   property will be removed. If it's also a Timer/Future/Stream type, it will
  ///   be closed/canceled.
  ///
  /// * If a predicate returns `false`, that property will not be removed or closed.
  ///
  /// Example usage:
  /// ```dart
  /// // Dispose of all Timers, Futures, Streams, etc.
  /// Superpowers.disposeProps();
  ///
  /// // Dispose only Timers.
  /// Superpowers.disposeProps(({Object? key, Object? value}) => value is Timer);
  /// ```
  ///
  /// See also: [disposeProp] to dispose a single property by its key.
  static void disposeProps(
      [bool Function({Object? key, Object? value})? predicate]) {
    var keysToRemove = [];

    for (var MapEntry(key: key, value: value) in _props.entries) {
      final removeIt = predicate?.call(key: key, value: value) ?? true;

      if (removeIt) {
        final ifTimerFutureStream = _closeTimerFutureStream(value);

        // Removes the key if the predicate was provided and returned true,
        // or it was not provided but the value is Timer/Future/Stream.
        if ((predicate != null) || ifTimerFutureStream) keysToRemove.add(key);
      }
    }

    // After the iteration, remove all keys at the same time.
    for (var key in keysToRemove) {
      _props.remove(key);
    }
  }

  /// Disposes a single property identified by its key and removes it from props.
  ///
  /// This method will close/cancel/ignore the property if it's a Timer,
  /// Future, StreamSubscription, StreamConsumer, or Sink, and then remove it.
  ///
  /// Example usage:
  /// ```dart
  /// // Dispose a specific timer property
  /// Superpowers.disposeProp("myTimer");
  /// ```
  static void disposeProp(Object? keyToDispose) {
    disposeProps(({Object? key, Object? value}) => key == keyToDispose);
  }

  /// If [obj] is a timer, future or stream related, it will be closed/canceled/ignored,
  /// and `true` will be returned. For other object types, the method returns `false`.
  static bool _closeTimerFutureStream(Object? obj) {
    if (obj is Timer) {
      obj.cancel();
    } else if (obj is Future) {
      obj.ignore();
    } else if (obj is StreamSubscription) {
      obj.cancel();
    } else if (obj is StreamConsumer) {
      obj.close();
    } else if (obj is Sink) {
      obj.close();
    } else {
      return false;
    }

    return true;
  }

  // -------- Error Queue --------

  /// Error queue (bounded, FIFO) for UserExceptions.
  static final Queue<UserException> _errors = Queue<UserException>();

  /// Stream controller for notifying listeners when UserExceptions are added.
  static final StreamController<UserException> _userExceptionController =
      StreamController<UserException>.broadcast();

  /// Maximum number of errors to keep in the queue.
  static int _maxErrorsQueued = 10;

  /// Stream of [UserException]s for UI to listen to.
  /// Use this with [UserExceptionDialog] to show error dialogs.
  static Stream<UserException> get onUserException =>
      _userExceptionController.stream;

  /// Returns a copy of the error queue (read-only).
  static Queue<UserException> get errors => Queue<UserException>.of(_errors);

  /// Gets and removes the first error from the queue.
  /// Returns null if the queue is empty.
  static UserException? getAndRemoveFirstError() =>
      _errors.isEmpty ? null : _errors.removeFirst();

  /// Clears all errors from the queue.
  static void clearErrors() => _errors.clear();

  /// Adds a [UserException] to the error queue.
  /// This is also used by the standalone [retry] function.
  static void addUserException(UserException error) => _addError(error);

  static void _addError(UserException error) {
    if (_errors.length >= _maxErrorsQueued) _errors.removeFirst();
    _errors.addLast(error);
    _userExceptionController.add(error);
  }

  // -------- Global Error Handler --------

  /// Global error handler called after all local [catchError] handlers.
  ///
  /// Only invoked if the error propagates (wasn't suppressed by local handlers).
  /// The [key] parameter is the effective key from the [mix] call, useful for logging.
  ///
  /// Use cases:
  /// - Centralized error logging
  /// - Converting third-party exceptions (FirebaseException, DioException) to [UserException]
  ///
  /// Example:
  /// ```dart
  /// Superpowers.globalCatchError = (error, stack, key) {
  ///   logError(error, stack, key: key);  // Log with context
  ///
  ///   if (error is UserException) throw error;  // Already user-friendly
  ///
  ///   if (error is FirebaseAuthException) {
  ///     throw UserException(_mapFirebaseError(error)).addCause(error);
  ///   }
  ///
  ///   // Unknown error - generic message
  ///   throw UserException('Something went wrong').addCause(error);
  /// };
  /// ```
  static void Function(Object error, StackTrace stackTrace, Object key)?
      globalCatchError;

  // -------- Mix Observer --------

  /// Global observer for [mix] calls, useful for metrics and analytics.
  ///
  /// Called twice for each [mix] call:
  /// - At start: [isStart] is true, [error], [stackTrace], and [duration] are null
  /// - At end: [isStart] is false, [duration] contains elapsed time,
  ///   [error] and [stackTrace] are set if the action failed
  ///
  /// The [metrics] parameter contains the result of the `metrics` callback
  /// passed to [mix], or the error if the callback threw. This is calculated
  /// separately at start and end, so it can reflect state changes.
  ///
  /// Example:
  /// ```dart
  /// Superpowers.observer = (isStart, key, metrics, error, stackTrace, duration) {
  ///   if (isStart) {
  ///     analytics.startOperation(key.toString());
  ///   } else {
  ///     analytics.endOperation(
  ///       key.toString(),
  ///       duration: duration,
  ///       success: error == null,
  ///       state: metrics, // Cubit state if metrics: () => this was passed
  ///     );
  ///   }
  /// };
  /// ```
  static void Function(
    bool isStart,
    Object key,
    Object? metrics,
    Object? error,
    StackTrace? stackTrace,
    Duration? duration,
  )? observer;

  /// Stream controller for notifying listeners when method state changes.
  static final StreamController<void> _stateController =
      StreamController<void>.broadcast();

  /// Stream that emits when method waiting/failed state changes.
  static Stream<void> get onStateChange => _stateController.stream;

  /// Keys currently being processed by mix(), with count of concurrent calls.
  /// Using a counter allows tracking multiple concurrent mix calls with the same key.
  static final Map<Object, int> _inProgress = HashMap();

  /// Optimization: keys ever checked with [isWaiting].
  /// Only these keys trigger [onStateChange] notifications.
  static final Set<Object> _awaitable = HashSet();

  /// Failed inline actions: key -> last UserException.
  static final Map<Object, UserException> _failed = HashMap();

  /// Optimization: keys ever checked with [isFailed] or [getException].
  /// Only these keys are tracked in [_failed].
  static final Set<Object> _checkFailed = HashSet();

  /// Returns true if a [mix] call with the given key(s) is currently in progress.
  ///
  /// Accepts:
  /// - Any [Object] as key: `Superpowers.isWaiting'saveUser')` or
  ///   `Superpowers.isWaiting('saveUser', itemId))`
  /// - An [Iterable] of keys: `Superpowers.isWaiting['saveUser', 'loadUser'])`
  ///
  /// Registers the key for rebuild notifications (optimization).
  static bool isWaiting(Object keyOrList) {
    if (keyOrList is Iterable) {
      bool waiting = false;
      for (var key in keyOrList) {
        _awaitable.add(key);
        if (!waiting) {
          waiting = (_inProgress[key] ?? 0) > 0;
        }
      }
      return waiting;
    }
    // Single key
    _awaitable.add(keyOrList);
    return (_inProgress[keyOrList] ?? 0) > 0;
  }

  /// Returns true if a [mix] call with the given key has failed.
  ///
  /// Only returns true if the error is a [UserException].
  /// Use [getException] to get the actual exception.
  static bool isFailed(Object keyOrList) => getException(keyOrList) != null;

  /// Returns the [UserException] for a failed [mix] call, or null.
  ///
  /// Accepts:
  /// - Any [Object] as key: `Superpowers.getException('saveUser')` or
  ///   `Superpowers.getException(('saveUser', itemId))`
  /// - An [Iterable] of keys: `Superpowers.getException(['saveUser', 'loadUser'])`
  ///
  /// Returns the first matching exception when given a list.
  static UserException? getException(Object keyOrList) {
    if (keyOrList is Iterable) {
      for (var key in keyOrList) {
        _checkFailed.add(key);
        var error = _failed[key];
        if (error != null) return error;
      }
      return null;
    }
    // Single key
    _checkFailed.add(keyOrList);
    return _failed[keyOrList];
  }

  /// Clears the failed state for the given [mix] key(s).
  ///
  /// Call this to reset the [isFailed] / [getException] state after
  /// handling an error (e.g., after showing an error message to the user).
  static void clearException(Object keyOrList) {
    bool removed = false;
    if (keyOrList is Iterable) {
      for (var key in keyOrList) {
        if (_failed.remove(key) != null) {
          removed = true;
        }
      }
    } else {
      removed = _failed.remove(keyOrList) != null;
    }
    if (removed) _stateController.add(null);
  }

  /// Called when a [mix] function call with a key STARTS executing.
  /// Used internally by [mix]. Use [isWaiting] to check the state.
  static void onStart(Object key) {
    // Clear previous failure for this key (if UI cares about it)
    bool clearedFailure = false;
    if (_checkFailed.contains(key)) {
      clearedFailure = _failed.remove(key) != null;
    }

    // Increment the counter for this key
    final currentCount = _inProgress[key] ?? 0;
    _inProgress[key] = currentCount + 1;

    // Notify UI if this key is being waited on or failure was cleared
    // Only notify on first call (when going from 0 to 1)
    if (clearedFailure || (currentCount == 0 && _awaitable.contains(key))) {
      _stateController.add(null);
    }
  }

  /// Called when a [mix] function call with a key FINISHES executing.
  /// Used internally by [mix]. Use [isWaiting] to check the state.
  static void onComplete(Object key, UserException? error) {
    // Decrement the counter for this key
    final currentCount = _inProgress[key] ?? 0;
    final newCount = currentCount - 1;

    if (newCount <= 0) {
      _inProgress.remove(key);
    } else {
      _inProgress[key] = newCount;
    }

    // If action failed with UserException, store it
    // Note: Unlike Method tracking, we always store inline failures for usability.
    // Users shouldn't have to call isFailedInline before the action runs.
    if (error != null) {
      _failed[key] = error;
    }

    // Notify UI if this key is being waited on (only when going to 0)
    // or if there's an error and UI cares about failures
    final shouldNotify = (newCount <= 0 && _awaitable.contains(key)) ||
        (error != null && _checkFailed.contains(key));
    if (shouldNotify) {
      _stateController.add(null);
    }
  }

  /// Clears Superpowers static configuration.
  /// This is generally used to reset between tests, and it's not
  /// necessary to call it in production.
  ///
  /// Call this at app startup to configure error handling, or in test setUp
  /// to reset state between tests.
  ///
  /// ```dart
  /// // In main.dart:
  /// void main() {
  ///   Superpowers.clear(maxErrorsQueued: 20);
  ///   runApp(MyApp());
  /// }
  ///
  /// // In tests:
  /// setUp(() => Superpowers.clear());
  ///
  /// // Simulate no internet in tests:
  /// setUp(() => Superpowers.clear(simulateInternet: () => false));
  /// ```
  ///
  /// Parameters:
  /// - [maxErrorsQueued]: Maximum number of errors to keep in the queue (default: 10)
  /// - [simulateInternet]: Function to simulate internet connectivity for testing.
  ///   Returns `true` (internet ON), `false` (internet OFF), or `null` (use real check).
  @visibleForTesting
  static void clear({
    int maxErrorsQueued = 10,
    bool? Function()? simulateInternet,
  }) {
    // Reset internet simulation.
    _simulateInternet = simulateInternet ?? () => null;

    // Dispose and clear props.
    disposeProps();
    _props.clear();

    // Reset error queue.
    _errors.clear();
    _maxErrorsQueued = maxErrorsQueued;

    // Reset global error handler.
    globalCatchError = null;

    // Reset mix observer.
    observer = null;

    // Reset inline state tracking.
    _inProgress.clear();
    _awaitable.clear();
    _failed.clear();
    _checkFailed.clear();
  }

  /// Resets user-specific state while keeping app-level configuration.
  ///
  /// Call this when a user logs out to clean up their session data:
  /// - Disposes and clears all props (timers, streams, futures)
  /// - Clears the error queue
  /// - Clears waiting/failed state tracking
  ///
  /// Unlike [clear], this method preserves app-level configuration:
  /// - [globalCatchError] (your error handling setup)
  /// - [observer] (your analytics/metrics setup)
  /// - [maxErrorsQueued] setting
  ///
  /// The [delay] parameter (default 5 seconds) runs cleanup twice with a pause
  /// between, catching any in-flight Cubit operations. Set to [Duration.zero]
  /// for immediate cleanup without waiting.
  ///
  /// Example:
  /// ```dart
  /// Future<void> logout() async {
  ///   await Superpowers.prepareToLogout();
  ///   await authService.signOut();
  ///   Navigator.pushReplacementNamed(context, '/login');
  /// }
  /// ```
  static Future<void> prepareToLogout({
    Duration delay = const Duration(seconds: 5),
  }) async {
    // Dispose and clear props (timers, streams, futures from user session).
    disposeProps();
    _props.clear();

    // Clear error queue (errors from previous user session).
    _errors.clear();

    // Clear inline state tracking (waiting/failed from previous user).
    _inProgress.clear();
    _awaitable.clear();
    _failed.clear();
    _checkFailed.clear();

    // If delay is specified, clean up, wait half, then do another final
    // cleanup. This helps ensure any in-flight operations are cleared.
    if (delay.inMilliseconds > 0) {
      await Future.delayed(delay ~/ 2);
      prepareToLogout(delay: Duration.zero);
      await Future.delayed(delay ~/ 2);

      // Notify UI to rebuild (in case widgets are showing old waiting/failed state).
      _stateController.add(null);
    }
  }
}

class _SuperpowersState extends State<Superpowers> {
  StreamSubscription<void>? _subscription;

  /// Version counter that increments on each method state change.
  /// This forces the InheritedWidget to notify dependents.
  int _version = 0;

  @override
  void initState() {
    super.initState();
    _subscription = Superpowers.onStateChange.listen((_) {
      if (mounted) {
        setState(() {
          _version++;
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SuperpowersInherited(
      version: _version,
      child: widget.child,
    );
  }
}

/// Internal InheritedWidget that notifies dependents when method state changes.
class _SuperpowersInherited extends InheritedWidget {
  final int version;

  const _SuperpowersInherited({
    required this.version,
    required super.child,
  });

  @override
  bool updateShouldNotify(covariant _SuperpowersInherited oldWidget) {
    return version != oldWidget.version;
  }
}
