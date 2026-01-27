// Developed by Marcelo Glasberg (2026) https://glasberg.dev and https://github.com/marcglasberg
// For more info, see: https://pub.dartlang.org/packages/bloc_superpowers and http://blocsuperpowers.org
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';

/// The set of keys that are currently running (for non-reentrant support).
/// Stored in Superpowers.props so it's cleared by Superpowers.clear().
/// Uses the same key as the OptimisticCommand mixin for consistency.
const _propKey = '_optimisticCommandKeySet';

Set<Object?> _getNonReentrantKeySet() {
  var set = Superpowers.prop<Set<Object?>?>(_propKey);
  if (set == null) {
    set = {};
    Superpowers.setProp(_propKey, set);
  }
  return set;
}

/// Default implementation of shouldRollback.
/// Rollback only if the current value still matches the optimistic value.
bool _defaultShouldRollback({
  required Object? currentValue,
  required Object? initialValue,
  required Object? optimisticValue,
  required Object error,
}) {
  if (currentValue is ImmutableCollection &&
      optimisticValue is ImmutableCollection) {
    return currentValue.same(optimisticValue);
  } else {
    return currentValue == optimisticValue;
  }
}

/// Extension on [Cubit] that provides an optimistic command method.
///
/// This allows any Cubit subclass to use optimistic updates with automatic
/// rollback on failure, directly from within its methods.
extension OptimisticCommandExtension<S> on Cubit<S> {
  /// Executes an optimistic command with automatic rollback on failure.
  ///
  /// This method applies changes to the state immediately (optimistically) while
  /// sending the update to the server. If the server call fails, the change is
  /// automatically rolled back. It also includes non-reentrant behavior to prevent
  /// concurrent dispatches of the same action.
  ///
  /// **Required parameters:**
  ///
  /// - [optimisticValue] - Returns the value to apply optimistically.
  /// - [applyValueToState] - Applies a value to the state and returns the new state.
  /// - [getValueFromState] - Extracts the relevant value from the state.
  /// - [sendCommandToServer] - Sends the command to the server.
  /// - [key] - Key for inline state tracking (used by isWaitingInline/isFailedInline).
  ///   Can be any Object with proper equality (String, record, etc.).
  ///
  /// **Optional parameters:**
  ///
  /// - [nonReentrantKey] - Key for non-reentrant protection. Actions with the same
  ///   key cannot run concurrently. Defaults to [key] if not provided.
  /// - [applyServerResponseToState] - Apply the server response to state.
  /// - [reloadFromServer] - Reload data from the server after completion.
  /// - [rollbackState] - Customize how rollback is computed.
  /// - [shouldRollback] - Decide whether to rollback on failure.
  /// - [shouldReload] - Decide whether to reload from server.
  /// - [shouldApplyReload] - Decide whether to apply the reload result.
  /// - [applyReloadResultToState] - Apply reload result to state.
  ///
  /// **Example:**
  ///
  /// ```dart
  /// class TodoCubit extends Cubit<TodoState> {
  ///   TodoCubit() : super(TodoState());
  ///
  ///   void addTodo(Todo newTodo) {
  ///     optimisticCommand(
  ///       key: 'addTodo',
  ///       nonReentrantKey: ('AddTodo', newTodo.id),
  ///       optimisticValue: () => state.todos.add(newTodo),
  ///       applyValueToState: (state, value) =>
  ///           state.copyWith(todos: value as IList<Todo>),
  ///       getValueFromState: (state) => state.todos,
  ///       sendCommandToServer: (optimisticValue) async {
  ///         await api.addTodo(newTodo);
  ///         return null;
  ///       },
  ///     );
  ///   }
  /// }
  /// ```
  Future<void> optimisticCommand({
    // Required parameters: equivalent to mixin's abstract methods
    required Object? Function() optimisticValue,
    required S Function(S state, Object? value) applyValueToState,
    required Object? Function(S state) getValueFromState,
    required Future<Object?> Function(Object? optimisticValue)
        sendCommandToServer,
    required Object key,
    Object? nonReentrantKey,

    // Optional callbacks: equivalent to mixin's overridable methods
    S? Function(S state, Object serverResponse)? applyServerResponseToState,
    Future<Object?> Function()? reloadFromServer,
    S? Function({
      required S state,
      required Object? initialValue,
      required Object? optimisticValue,
      required Object error,
    })? rollbackState,
    bool Function({
      required Object? currentValue,
      required Object? initialValue,
      required Object? optimisticValue,
      required Object error,
    })? shouldRollback,
    bool Function({
      required Object? currentValue,
      required Object? lastAppliedValue,
      required Object? optimisticValue,
      required Object? rollbackValue,
      required Object? error,
    })? shouldReload,
    bool Function({
      required Object? currentValue,
      required Object? lastAppliedValue,
      required Object? optimisticValue,
      required Object? rollbackValue,
      required Object? reloadResult,
      required Object? error,
    })? shouldApplyReload,
    S? Function(S state, Object? reloadResult)? applyReloadResultToState,
  }) async {
    // -------- Non-reentrant check (from abort()) --------

    // Use key as nonReentrantKey if not provided
    final effectiveNonReentrantKey = nonReentrantKey ?? key;

    final keySet = _getNonReentrantKeySet();

    // If the key is already in the set, abort.
    if (keySet.contains(effectiveNonReentrantKey)) {
      return;
    }
    // Otherwise, add the key and allow execution.
    keySet.add(effectiveNonReentrantKey);

    // -------- Track inline state start --------
    Superpowers.onStart(key);

    Object? commandError;
    UserException? userExceptionForTracking;

    try {
      // -------- Main logic (from wrapRun()) --------

      // Capture initial state before any changes.
      final S initialState = state;
      final initialValue = getValueFromState(initialState);

      // Apply optimistic value immediately.
      final optimistic = optimisticValue();
      emit(applyValueToState(state, optimistic));

      Object? lastAppliedValue = optimistic; // what this action last wrote
      Object? rollbackValue; // value slice after rollback, if any

      try {
        // Send command to server.
        final serverResponse = await sendCommandToServer(optimistic);

        // Apply server response if not null.
        if (serverResponse != null) {
          final S? newState;
          if (applyServerResponseToState != null) {
            newState = applyServerResponseToState(state, serverResponse);
          } else {
            newState = null;
          }

          if (newState != null) {
            emit(newState);

            // Keep lastAppliedValue in sync with what we just wrote for the slice.
            lastAppliedValue = getValueFromState(newState);
          }
        }
      } catch (error) {
        commandError = error;

        // Decide if it is safe to rollback.
        final currentValue = getValueFromState(state);

        final doRollback = shouldRollback != null
            ? shouldRollback(
                currentValue: currentValue,
                initialValue: initialValue,
                optimisticValue: optimistic,
                error: error,
              )
            : _defaultShouldRollback(
                currentValue: currentValue,
                initialValue: initialValue,
                optimisticValue: optimistic,
                error: error,
              );

        if (doRollback) {
          final S? rollback;
          if (rollbackState != null) {
            rollback = rollbackState(
              state: state,
              initialValue: initialValue,
              optimisticValue: optimistic,
              error: error,
            );
          } else {
            // Default: restore initialValue
            rollback = applyValueToState(state, initialValue);
          }

          if (rollback != null) {
            emit(rollback);

            // Update "lastAppliedValue" to match what rollback wrote.
            rollbackValue = getValueFromState(rollback);
            lastAppliedValue = rollbackValue;
          }
        }

        rethrow;
      } finally {
        try {
          // Snapshot current value before deciding whether to reload.
          final Object? currentValueBefore = getValueFromState(state);

          final bool doReload;
          if (reloadFromServer == null) {
            doReload = false;
          } else if (shouldReload != null) {
            doReload = shouldReload(
              currentValue: currentValueBefore,
              lastAppliedValue: lastAppliedValue,
              optimisticValue: optimistic,
              rollbackValue: rollbackValue,
              error: commandError,
            );
          } else {
            // Default: reload only on error
            doReload = commandError != null;
          }

          if (doReload && reloadFromServer != null) {
            final Object? reloadResult = await reloadFromServer();

            // Re-read after await, because state may have changed while reloading.
            final Object? currentValueAfter = getValueFromState(state);

            final bool apply;
            if (shouldApplyReload != null) {
              apply = shouldApplyReload(
                currentValue: currentValueAfter,
                lastAppliedValue: lastAppliedValue,
                optimisticValue: optimistic,
                rollbackValue: rollbackValue,
                reloadResult: reloadResult,
                error: commandError,
              );
            } else {
              // Default: always apply reload result
              apply = true;
            }

            if (apply) {
              final S? newState;
              if (applyReloadResultToState != null) {
                newState = applyReloadResultToState(state, reloadResult);
              } else {
                // Default: use applyValueToState
                newState = applyValueToState(state, reloadResult);
              }
              if (newState != null) emit(newState);
            }
          }
        } on UnimplementedError catch (_) {
          // If reloadFromServer was not implemented, do nothing.
        } catch (reloadError) {
          // Important: Do not let reload failure hide the original command error.
          if (commandError == null) rethrow;
        }
      }
    } catch (error) {
      // Track UserException for inline tracking
      if (error is UserException) {
        userExceptionForTracking = error;
      }
      rethrow;
    } finally {
      // -------- Remove the key when the action finishes (from after()) --------
      keySet.remove(effectiveNonReentrantKey);

      // -------- Track inline state completion --------
      Superpowers.onComplete(
        key,
        commandError != null ? userExceptionForTracking : null,
      );
    }
  }
}
