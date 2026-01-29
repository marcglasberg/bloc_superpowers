/// A Dart/Flutter package that enhances Cubit state management with powerful features.
///
/// **bloc_superpowers** adds automatic loading/error tracking, retry logic with exponential
/// backoff, debounce/throttle, caching, optimistic UI updates, and one-time effects to your
/// Cubits through the [mix] function.
///
/// ## Getting Started
///
/// Wrap your app with the [Superpowers] widget:
/// ```dart
/// Superpowers(
///   child: MaterialApp(...),
/// )
/// ```
///
/// Then use [mix] in your Cubits:
/// ```dart
/// Future<void> loadUser() => mix(
///   key: this,
///   retry: retry,
///   () async {
///     final user = await api.getUser();
///     emit(state.copyWith(user: user));
///   },
/// );
/// ```
///
/// ## Key Features
///
/// - **Automatic loading/error tracking**: Use `context.isWaiting(key)` and `context.isFailed(key)`
/// - **Retry with backoff**: `retry: retry(maxRetries: 5)`
/// - **Throttle/Debounce**: `throttle: throttle(duration: 1.sec)`, `debounce: debounce(duration: 300.millis)`
/// - **Freshness caching**: `fresh: fresh(freshFor: 5.sec)`
/// - **Sequential execution**: `sequential: sequential`
/// - **Internet checking**: `checkInternet: checkInternet`
/// - **One-time effects**: Use [Effect] and `context.effect()` instead of BlocListener
///
/// For more info, see: https://blocsuperpowers.org
library;

export 'src/abort_exception.dart';
export 'src/advanced_user_exception.dart';
export 'src/connection_exception.dart';
export 'src/effect.dart';
export 'src/superpowers.dart';
export 'src/mix.dart';
export 'src/mix_preset.dart' hide MixPresetWithParams;
export 'src/optimistic_command.dart';
export 'src/optimistic_sync.dart';
export 'src/optimistic_sync_with_push.dart';
export 'src/user_exception.dart';
export 'src/user_exception_dialog.dart';
export 'src/user_exception_toast.dart';
