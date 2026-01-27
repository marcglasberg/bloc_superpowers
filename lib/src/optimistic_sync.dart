// Developed by Marcelo Glasberg (2026) https://glasberg.dev and https://github.com/marcglasberg
// For more info, see: https://pub.dartlang.org/packages/bloc_superpowers and http://blocsuperpowers.org
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';

/// The set of keys that are currently locked (requests in flight).
/// Stored in Superpowers.props so it's cleared by Superpowers.clear().
/// Uses the same key as the OptimisticSync mixin for consistency.
const _propKey = '_optimisticSyncKeySet';

Set<Object?> _getOptimisticSyncKeySet() {
  var set = Superpowers.prop<Set<Object?>?>(_propKey);
  if (set == null) {
    set = {};
    Superpowers.setProp(_propKey, set);
  }
  return set;
}

/// Default implementation of ifShouldSendAnotherRequest.
/// Returns true if stateValue differs from sentValue.
bool _defaultIfShouldSendAnotherRequest<T>({
  required T stateValue,
  required T sentValue,
  required int requestCount,
  required int maxFollowUpRequests,
}) {
  // Safety check to avoid infinite loops.
  if ((maxFollowUpRequests != -1) && (requestCount > maxFollowUpRequests)) {
    throw StateError('Too many follow-up requests (> $maxFollowUpRequests).');
  }

  if (stateValue is ImmutableCollection && sentValue is ImmutableCollection) {
    return !stateValue.same(sentValue);
  } else {
    return stateValue != sentValue;
  }
}

/// Extension on [Cubit] that provides an optimistic sync method.
///
/// This allows any Cubit subclass to use optimistic updates with automatic
/// follow-up requests for eventual consistency, directly from within its methods.
extension OptimisticSyncExtension<S> on Cubit<S> {
  /// Executes an optimistic sync with automatic follow-up requests.
  ///
  /// This method is designed for user interactions (like toggling a "like" button)
  /// where the UI should update immediately and the server should be eventually
  /// consistent. Unlike [optimisticCommand], this method:
  ///
  /// - ALWAYS applies the optimistic value, even when another request is in flight
  /// - Does NOT abort concurrent dispatches - they just return without sending
  /// - Sends follow-up requests if the state changed while a request was in flight
  /// - Has an [onFinish] callback instead of automatic rollback
  ///
  /// This guarantees a very good user experience because there is immediate
  /// feedback on every interaction, while ensuring only ONE request is in flight
  /// at a time per key.
  ///
  /// **Required parameters:**
  ///
  /// - [valueToApply] - Returns the value to apply optimistically.
  /// - [applyOptimisticValueToState] - Applies the optimistic value to state.
  /// - [getValueFromState] - Extracts the value from state.
  /// - [sendValueToServer] - Sends the value to the server.
  /// - [key] - Key for coalescing concurrent requests. Requests with the same
  ///   key share a lock. Can be any Object with proper equality (String, record, etc.).
  ///
  /// **Optional parameters:**
  ///
  /// - [applyServerResponseToState] - Applies the server response to state.
  ///   Only called when state stabilizes and [sendValueToServer] returned non-null.
  ///   Return null to skip applying.
  /// - [onFinish] - Called when synchronization completes (success or failure).
  ///   Receives the optimisticValue and error (null on success).
  ///   If it returns a non-null state, it will be applied.
  /// - [ifShouldSendAnotherRequest] - Custom logic for deciding follow-up requests.
  /// - [maxFollowUpRequests] - Safety limit for follow-up requests (default 10000).
  ///
  /// **Example (like button):**
  ///
  /// ```dart
  /// class ItemCubit extends Cubit<ItemState> {
  ///   ItemCubit() : super(ItemState());
  ///
  ///   void toggleLike(String itemId) {
  ///     optimisticSync(
  ///       key: ('toggleLike', itemId),
  ///       valueToApply: () => !state.items[itemId].isLiked,
  ///       applyOptimisticValueToState: (state, isLiked) =>
  ///           state.copyWith(items: state.items.setLiked(itemId, isLiked)),
  ///       getValueFromState: (state) => state.items[itemId].isLiked,
  ///       sendValueToServer: (isLiked) async {
  ///         await api.setLiked(itemId, isLiked);
  ///         return null;
  ///       },
  ///     );
  ///   }
  /// }
  /// ```
  ///
  /// **How it works:**
  ///
  /// 1. When called, ALWAYS applies the optimistic value immediately
  /// 2. If another request is already in flight for this key, returns without
  ///    sending a new request (the in-flight request will check for changes)
  /// 3. Otherwise, acquires a lock and sends the request to the server
  /// 4. When the request completes, checks if the state changed while in flight
  /// 5. If state changed, sends a follow-up request with the current state value
  /// 6. When state stabilizes, optionally applies the server response, releases
  ///    the lock, and calls [onFinish]
  Future<void> optimisticSync<T>({
    // Required parameters: equivalent to mixin's abstract methods
    required T Function() valueToApply,
    required S Function(S state, T optimisticValue) applyOptimisticValueToState,
    required T Function(S state) getValueFromState,
    required Future<Object?> Function(T value) sendValueToServer,
    required Object key,

    // Optional parameters
    S? Function(S state, Object serverResponse)? applyServerResponseToState,
    Future<S?> Function(T optimisticValue, Object? error)? onFinish,
    bool Function({
      required T stateValue,
      required T sentValue,
      required int requestCount,
    })? ifShouldSendAnotherRequest,
    int maxFollowUpRequests = 10000,
  }) async {
    final keySet = _getOptimisticSyncKeySet();

    // Compute the optimistic value once at the start.
    final T optimisticValue = valueToApply();

    // Always apply optimistic update immediately.
    emit(applyOptimisticValueToState(state, optimisticValue));

    // If locked, another request is in flight. The optimistic update is
    // already applied, so just return. When the in-flight request completes,
    // it will check if a follow-up is needed.
    if (keySet.contains(key)) {
      return;
    }

    // Acquire lock and send request.
    keySet.add(key);
    await _sendAndFollowUp<T>(
      key: key,
      optimisticValue: optimisticValue,
      getValueFromState: getValueFromState,
      sendValueToServer: sendValueToServer,
      applyServerResponseToState: applyServerResponseToState,
      onFinish: onFinish,
      ifShouldSendAnotherRequest: ifShouldSendAnotherRequest,
      maxFollowUpRequests: maxFollowUpRequests,
    );
  }

  /// Sends the request and handles follow-up requests if the state changed
  /// while the request was in flight.
  Future<void> _sendAndFollowUp<T>({
    required Object key,
    required T optimisticValue,
    required T Function(S state) getValueFromState,
    required Future<Object?> Function(T value) sendValueToServer,
    S? Function(S state, Object serverResponse)? applyServerResponseToState,
    Future<S?> Function(T optimisticValue, Object? error)? onFinish,
    bool Function({
      required T stateValue,
      required T sentValue,
      required int requestCount,
    })? ifShouldSendAnotherRequest,
    required int maxFollowUpRequests,
  }) async {
    final keySet = _getOptimisticSyncKeySet();
    T valueToSend = optimisticValue;
    int requestCount = 0;

    while (true) {
      requestCount++;

      try {
        // Send the value and get the server response (may be null).
        final Object? serverResponse = await sendValueToServer(valueToSend);

        // Read the current value from the state.
        final T stateValue = getValueFromState(state);

        // Check if we need a follow-up request.
        bool needFollowUp;
        if (ifShouldSendAnotherRequest != null) {
          needFollowUp = ifShouldSendAnotherRequest(
            stateValue: stateValue,
            sentValue: valueToSend,
            requestCount: requestCount,
          );
        } else {
          needFollowUp = _defaultIfShouldSendAnotherRequest<T>(
            stateValue: stateValue,
            sentValue: valueToSend,
            requestCount: requestCount,
            maxFollowUpRequests: maxFollowUpRequests,
          );
        }

        if (needFollowUp) valueToSend = stateValue;

        // If we need a follow-up, loop again without applying server response.
        if (needFollowUp) continue;

        // State is stable for this key. Now we may apply the server response.
        if (serverResponse != null) {
          final S? newState;
          if (applyServerResponseToState != null) {
            newState = applyServerResponseToState(state, serverResponse);
          } else {
            newState = null;
          }
          if (newState != null) emit(newState);
        }

        // Release lock and finish.
        keySet.remove(key);
        await _callOnFinish<T>(optimisticValue, null, onFinish);
        break;
      } catch (error) {
        // Request failed: release lock, run onFinish(error), then rethrow.
        keySet.remove(key);
        await _callOnFinish<T>(optimisticValue, error, onFinish);
        rethrow;
      }
    }
  }

  /// Calls [onFinish], applying the returned state if non-null.
  Future<void> _callOnFinish<T>(
    T optimisticValue,
    Object? error,
    Future<S?> Function(T optimisticValue, Object? error)? onFinish,
  ) async {
    if (onFinish != null) {
      final newState = await onFinish(optimisticValue, error);
      if (newState != null) emit(newState);
    }
  }
}
