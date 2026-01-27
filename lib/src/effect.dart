// Developed by Marcelo Glasberg (2026) https://glasberg.dev and https://github.com/marcglasberg
// For more info, see: https://pub.dartlang.org/packages/bloc_superpowers and http://blocsuperpowers.org

import 'package:flutter/widgets.dart';

/// Effects are one-time notifications stored in your state, used to trigger
/// side effects in widgets such as showing dialogs, clearing text fields,
/// or navigating to new screens.
///
/// Unlike regular state values, effects are automatically "consumed" (marked as
/// spent) after being read, ensuring they only trigger once.
///
/// ## Usage
///
/// **Example with a boolean (value-less) effect:**
///
/// ```dart
/// // In your state
/// class AppState {
///   final Effect clearTextEffect;
///   AppState({Effect? clearTextEffect})
///       : clearTextEffect = clearTextEffect ?? Effect.spent();
///
///   AppState copyWith({Effect? clearTextEffect}) =>
///       AppState(clearTextEffect: clearTextEffect ?? this.clearTextEffect);
/// }
///
/// // In your Cubit method, create a new effect
/// void clearText() {
///   emit(state.copyWith(clearTextEffect: Effect()));
/// }
///
/// // In your widget - consume the effect
/// Widget build(BuildContext context) {
///   var clearText = context.effect((AppCubit c) => c.state.clearTextEffect);
///   if (clearText == true) controller.clear();
///   return TextField(controller: controller);
/// }
/// ```
///
/// **Example with a typed effect:**
///
/// ```dart
/// // In your state
/// class AppState {
///   final Effect<String> messageEffect;
///   AppState({Effect<String>? messageEffect})
///       : messageEffect = messageEffect ?? Effect.spent();
/// }
///
/// // In your Cubit method
/// void showMessage(String message) {
///   emit(state.copyWith(messageEffect: Effect(message)));
/// }
///
/// // In your widget
/// Widget build(BuildContext context) {
///   var message = context.effect((AppCubit c) => c.state.messageEffect);
///   if (message != null) showSnackBar(context, message);
///   return MyContent();
/// }
/// ```
///
/// ## Return Values
///
/// - For effects with **no generic type** (`Effect`): `consume()` returns **true**
///   if the effect was dispatched, or **false** if it was already spent.
///
/// - For effects with **a value type** (`Effect<T>`): `consume()` returns the
///   **value** if the effect was dispatched, or **null** if it was already spent.
///
/// ## Important Notes
///
/// - Effects are consumed only once. After consumption, they are marked as "spent".
/// - Each effect can be consumed by **one single widget**.
/// - Always initialize effects as spent: `Effect.spent()` or `Effect<T>.spent()`.
/// - The widget will rebuild when a new effect is dispatched, even if it has the
///   same internal value as a previous effect, because each effect instance is
///   unique.
///
class Effect<T> {
  bool _spent;
  final T? _value;

  /// Creates an effect that is NOT spent.
  ///
  /// For value-less effects, use `Effect()`.
  /// For typed effects, use `Effect<T>(value)`.
  ///
  /// Note: For `Effect<bool>()` with no value provided, the value defaults to
  /// `true` (not `null`), so that `consume()` returns `true` as expected.
  Effect([T? value])
      : _value = (T == bool && value == null) ? (true as T) : value,
        _spent = false;

  /// Creates an effect that is already spent.
  ///
  /// Use this as the initial value in state classes:
  /// ```dart
  /// class AppState {
  ///   final Effect clearTextEffect;
  ///   AppState({Effect? clearTextEffect})
  ///       : clearTextEffect = clearTextEffect ?? Effect.spent();
  /// }
  /// ```
  Effect.spent()
      : _value = null,
        _spent = true;

  /// Returns true if the effect has been consumed.
  bool get isSpent => _spent;

  /// Returns true if the effect has NOT been consumed.
  bool get isNotSpent => !isSpent;

  /// Returns the effect state and consumes the effect.
  ///
  /// After consumption, the effect is marked as spent and will not trigger again.
  ///
  /// - For effects with no generic type (`Effect`): Returns **true** if the effect
  ///   was dispatched, or **false** if it was already spent.
  ///
  /// - For effects with a value type (`Effect<T>`): Returns the **value** if the
  ///   effect was dispatched, or **null** if it was already spent.
  T? consume() {
    T? result = state;
    _spent = true;
    return result;
  }

  /// Returns the effect state without consuming it.
  ///
  /// Unlike [consume], this method does not mark the effect as spent, so the
  /// effect can be read multiple times.
  ///
  /// This is useful in rare cases where you need to check the effect value
  /// without consuming it, but most use cases should use [consume].
  T? get state {
    if (T == dynamic && _value == null) {
      if (_spent)
        return (false as T);
      else {
        return (true as T);
      }
    } else {
      if (_spent)
        return null;
      else {
        return _value;
      }
    }
  }

  @override
  String toString() => 'Effect('
      '${state.toString()}'
      '${_spent == true ? ', spent' : ''}'
      ')';

  /// Consumes from more than one effect, prioritizing the first effect.
  ///
  /// If the first effect is not spent, it will be consumed, and the second will
  /// not. If the first effect is spent, the second one will be consumed.
  ///
  /// This is useful when you have multiple sources for the same effect and want
  /// to consume from whichever one is available.
  ///
  /// **Note:** If both effects are NOT spent, the method will have to be called
  /// twice to consume both. If both are spent, returns null.
  ///
  /// **Example:**
  /// ```dart
  /// String? message = Effect.consumeFrom(localMessageEffect, remoteMessageEffect);
  /// ```
  static T? consumeFrom<T>(Effect<T> effect1, Effect<T> effect2) {
    T? result = effect1.consume();
    result ??= effect2.consume();
    return result;
  }

  /// Special equality implementation for effects to ensure correct rebuild
  /// behavior.
  ///
  /// Effects use a custom equality check where:
  /// - **Unspent effects** are never considered equal to any other effect,
  ///   ensuring widgets always rebuild when a new effect is dispatched.
  /// - **Spent effects** are all considered equal to each other, since they are
  ///   "empty" and should not trigger rebuilds.
  ///
  /// This behavior is essential for Bloc's state comparison.
  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Effect &&
            runtimeType == other.runtimeType

            /// 1) Effects not spent are never considered equal to any other,
            /// and they will always "fire", forcing the widget to rebuild.
            /// 2) Spent effects are considered "empty", so they are all equal.
            &&
            (isSpent && other.isSpent);
  }

  /// 1) If two objects are equal according to the equals method, then hashcode
  /// of both must be the same. Since spent effects are all equal, they should
  /// produce the same hashcode.
  /// 2) If two objects are NOT equal, hashcode may be the same or not, but it's
  /// better when they are not the same. However, effects are mutable, and this
  /// could mean the hashcode of the state could be changed when an effect is
  /// consumed. To avoid this, we make effects always return the same hashCode.
  @override
  int get hashCode => 0;
}

/// A queue of effects to be executed sequentially.
///
/// The Cubit provides a list of effect objects (keeping business logic clean),
/// and the widget provides a handler function that interprets each effect
/// (keeping UI concerns in the UI layer).
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
class EffectQueue<E> {
  final List<E> _effects;
  final void Function(EffectQueue<E> remaining) _emitRemaining;

  /// Creates an effect queue with effects and a function to emit the
  /// remaining effects.
  ///
  /// The [emitRemaining] function should emit a new state containing an
  /// [EffectQueue] with the remaining effects. It will be called with
  /// the same [emitRemaining] function, so you don't need to handle recursion.
  EffectQueue(
    List<E> effects,
    void Function(EffectQueue<E> remaining) emitRemaining,
  )   : _effects = effects,
        _emitRemaining = emitRemaining;

  /// Creates a spent (empty) effect queue.
  EffectQueue.spent()
      : _effects = const [],
        _emitRemaining = _noOpEmitter;

  static void _noOpEmitter<T>(EffectQueue<T> _) {}

  /// Returns true if all effects have been consumed.
  bool get isSpent => _effects.isEmpty;

  /// Returns true if there are effects remaining.
  bool get isNotSpent => _effects.isNotEmpty;

  /// Handles effects and emits the remaining effects.
  ///
  /// This is called internally by `context.effectQueue(...)`.
  ///
  /// The [handler] function is provided by the widget and interprets each
  /// effect (e.g., showing a toast, dialog, or navigating).
  ///
  /// Effects are scheduled to run after the current frame completes
  /// (via [addPostFrameCallback]), since side effects like [showSnackBar],
  /// [showDialog], and [Navigator.push] cannot be called during build.
  ///
  /// If [onePerFrame] is true (default), only the first effect is handled,
  /// then remaining effects are emitted to trigger the next rebuild.
  ///
  /// If [onePerFrame] is false, all effects are handled in order, then
  /// an empty queue is emitted.
  void consumeOne(
    BuildContext context,
    void Function(BuildContext, E) handler, {
    bool onePerFrame = true,
  }) {
    if (_effects.isEmpty) return;

    if (onePerFrame) {
      // One effect per frame: handle first, emit remaining.
      final effect = _effects.first;
      final remaining = _effects.length > 1 ? _effects.sublist(1) : <E>[];

      WidgetsBinding.instance.addPostFrameCallback((_) {
        handler(context, effect);
        _emitRemaining(EffectQueue<E>(remaining, _emitRemaining));
      });
    } else {
      // All effects in one frame: handle all, emit spent.
      final effects = _effects;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final effect in effects) {
          handler(context, effect);
        }
        _emitRemaining(EffectQueue<E>.spent());
      });
    }
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is EffectQueue<E> &&
            runtimeType == other.runtimeType &&
            // Non-empty queues are never equal (always trigger rebuild).
            // Empty (spent) queues are all equal.
            (isSpent && other.isSpent);
  }

  @override
  int get hashCode => 0;
}
