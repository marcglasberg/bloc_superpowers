// Developed by Marcelo Glasberg (2026) https://glasberg.dev and https://github.com/marcglasberg
// For more info, see: https://pub.dartlang.org/packages/bloc_superpowers and http://blocsuperpowers.org
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
import 'dart:async';
import 'dart:math';
import 'package:bloc/bloc.dart';
import 'package:bloc_superpowers/bloc_superpowers.dart';

/// The set of keys that are currently locked (requests in flight).
/// Stored in Superpowers.props so it's cleared by Superpowers.clear().
/// Uses the same key as the OptimisticSyncWithPush mixin for consistency.
const _keySetPropKey = '_optimisticSyncWithPushKeySet';
const _revisionMapPropKey = '_optimisticSyncWithPushRevisionMap';

Set<Object?> _getOptimisticSyncKeySet() {
  var set = Superpowers.prop<Set<Object?>?>(_keySetPropKey);
  if (set == null) {
    set = {};
    Superpowers.setProp(_keySetPropKey, set);
  }
  return set;
}

Map<Object?, _RevisionEntry> _getRevisionMap() {
  var map =
      Superpowers.prop<Map<Object?, _RevisionEntry>?>(_revisionMapPropKey);
  if (map == null) {
    map = {};
    Superpowers.setProp(_revisionMapPropKey, map);
  }
  return map;
}

/// Internal class to store revision tracking data.
class _RevisionEntry {
  final int localRevision;
  final int serverRevision;
  final bool isPush;

  _RevisionEntry({
    required this.localRevision,
    required this.serverRevision,
    required this.isPush,
  });
}

/// The device ID is used to differentiate revisions from different devices.
/// The default is to use a random integer generated once per app run,
/// but you can override this by setting [optimisticSyncWithPushDeviceId].
int Function() optimisticSyncWithPushDeviceId = () {
  _deviceId ??=
      Random().nextInt(4294967296) + (Random().nextInt(10000) * 10000000000);
  return _deviceId!;
};

int? _deviceId;

/// Record type for push metadata containing server revision, local revision,
/// and device ID.
typedef PushMetadata = ({
  int serverRevision,
  int localRevision,
  int deviceId,
});

/// Extension on [Cubit] that provides optimistic sync with push methods.
///
/// This allows any Cubit subclass to use optimistic updates with server push
/// handling, directly from within its methods.
extension OptimisticSyncWithPushExtension<S> on Cubit<S> {
  /// Executes an optimistic sync with server push handling.
  ///
  /// This function is designed for actions where:
  ///
  /// 1. Your app receives server-pushed updates (WebSockets, Server-Sent Events
  ///    (SSE), Firebase) that may modify the same state this action controls.
  ///    It must be resilient to out-of-order delivery, and multiple devices can
  ///    modify the same data.
  ///
  /// 2. Non-blocking user interactions (like toggling a "like" button) should
  ///    update the UI immediately and send the updated value to the server,
  ///    making sure the server and the UI are eventually consistent.
  ///
  /// 3. You want "last write wins" semantics across devices. In other words,
  ///    with multiple devices, that's how we decide what truth is when two
  ///    devices disagree.
  ///
  /// In other words, it allows:
  /// - Optimistic UI
  /// - Multi device writes
  /// - Server push
  /// - Out of order delivery
  ///
  /// **IMPORTANT:** If your app does not receive server-pushed updates,
  /// use [optimisticSync] instead.
  ///
  /// **Required parameters:**
  ///
  /// - [valueToApply] - Returns the value to apply optimistically.
  /// - [applyOptimisticValueToState] - Applies the optimistic value to state.
  /// - [getValueFromState] - Extracts the value from state.
  /// - [sendValueToServer] - Sends the value to the server. Must call
  ///   `informServerRevision()` with the server revision from the response.
  /// - [getServerRevisionFromState] - Returns the server revision saved in
  ///   state for a given key. Return -1 if unknown.
  /// - [key] - Key for coalescing concurrent requests.
  ///
  /// **Optional parameters:**
  ///
  /// - [applyServerResponseToState] - Applies the server response to state.
  ///   Only called when state stabilizes and [sendValueToServer] returned non-null.
  /// - [onFinish] - Called when synchronization completes (success or failure).
  /// - [maxFollowUpRequests] - Safety limit for follow-up requests (default 10000).
  ///
  /// **Example (like button with server push):**
  ///
  /// ```dart
  /// class ItemCubit extends Cubit<ItemState> {
  ///   ItemCubit() : super(ItemState());
  ///
  ///   void toggleLike(String itemId) {
  ///     optimisticSyncWithPush(
  ///       key: ('toggleLike', itemId),
  ///       valueToApply: () => !state.items[itemId].isLiked,
  ///       applyOptimisticValueToState: (state, isLiked) =>
  ///           state.copyWith(items: state.items.setLiked(itemId, isLiked)),
  ///       getValueFromState: (state) => state.items[itemId].isLiked,
  ///       getServerRevisionFromState: (key) => state.revisions[key] ?? -1,
  ///       sendValueToServer: (isLiked, localRevision, deviceId, informServerRevision) async {
  ///         var response = await api.setLiked(itemId, isLiked, localRevision, deviceId);
  ///         if (!response.ok) throw Exception('Server error');
  ///         informServerRevision(response.serverRev);
  ///         return response.liked;
  ///       },
  ///       applyServerResponseToState: (state, serverResponse) =>
  ///           state.copyWith(items: state.items.setLiked(itemId, serverResponse as bool)),
  ///     );
  ///   }
  /// }
  /// ```
  ///
  /// **How it works:**
  ///
  /// 1. **Immediate UI feedback**: Every dispatch applies the optimistic value
  ///    to the state immediately.
  ///
  /// 2. **Single in-flight request**: Only one request is in flight at a time
  ///    per key. Other dispatches return without sending requests.
  ///
  /// 3. **Follow-up request**: If the state changed while a request was in flight,
  ///    a follow-up request is automatically sent.
  ///
  /// 4. **Push handling**: If a server push modified the state, no follow-up is
  ///    needed. This requires using [serverPush] for handling server pushes.
  ///
  /// 5. **Server response handling**: The server response is applied only when
  ///    the state stabilizes and the response is not stale.
  ///
  Future<void> optimisticSyncWithPush<T>({
    // Required parameters
    required T Function() valueToApply,
    required S Function(S state, T optimisticValue) applyOptimisticValueToState,
    required T Function(S state) getValueFromState,
    required Future<Object?> Function(
      T optimisticValue,
      int localRevision,
      int deviceId,
      void Function(int serverRevision) informServerRevision,
    ) sendValueToServer,
    required int Function(Object? key) getServerRevisionFromState,
    required Object key,

    // Optional parameters
    S? Function(S state, Object serverResponse)? applyServerResponseToState,
    Future<S?> Function(Object? error)? onFinish,
    int maxFollowUpRequests = 10000,
  }) async {
    final keySet = _getOptimisticSyncKeySet();
    final revisionMap = _getRevisionMap();

    // Compute and increment the local revision for this key.
    int? lazyLocalRevision;

    int getLocalRevision() {
      if (lazyLocalRevision == null) {
        final current = revisionMap[key];

        // Increment for this dispatch.
        lazyLocalRevision = (current?.localRevision ?? 0) + 1;

        final int fromMap = current?.serverRevision ?? -1;
        final int fromState = getServerRevisionFromState(key);
        final int seededServerRev = max(fromMap, fromState);

        revisionMap[key] = _RevisionEntry(
          localRevision: lazyLocalRevision!,
          serverRevision: seededServerRev,
          isPush: false,
        );
      }

      return lazyLocalRevision!;
    }

    int localRevision = getLocalRevision();

    // Compute the optimistic value once at the start.
    T value = valueToApply();

    // Always apply optimistic update immediately.
    emit(applyOptimisticValueToState(state, value));

    // If locked, another request is in flight. The optimistic update is
    // already applied, so just return. When the in-flight request completes,
    // it will check if a follow-up is needed.
    if (keySet.contains(key)) {
      return;
    }

    // Acquire lock.
    keySet.add(key);

    int requestCount = 0;

    while (true) {
      // Safety check to avoid infinite loops.
      requestCount++;
      if ((maxFollowUpRequests != -1) && (requestCount > maxFollowUpRequests)) {
        throw StateError(
            'Too many follow-up requests (> $maxFollowUpRequests).');
      }

      // Track the informed server revision for this request.
      int? informedServerRev;

      void informServerRevision(int revision) {
        informedServerRev = revision;

        final entry = revisionMap[key];

        final int fromMap = entry?.serverRevision ?? -1;
        final int fromState = getServerRevisionFromState(key);
        final int currentServerRev = max(fromMap, fromState);

        // Only move forward, but keep local intent info.
        if (revision > currentServerRev) {
          revisionMap[key] = _RevisionEntry(
            localRevision: entry?.localRevision ?? 0,
            serverRevision: revision,
            isPush: false,
          );
        }
      }

      try {
        // Send the value and get the server response (may be null).
        final Object? serverResponse = await sendValueToServer(
          value,
          localRevision,
          optimisticSyncWithPushDeviceId(),
          informServerRevision,
        );

        // Validate that the developer called informServerRevision().
        if (informedServerRev == null) {
          throw StateError(
            'The optimisticSyncWithPush function requires calling '
            'informServerRevision() inside sendValueToServer(). '
            'If you don\'t need server-push handling, use optimisticSync instead.',
          );
        }

        // Revision-based follow-up decision:
        // If localRevision advanced since this request started, the user changed
        // intent while the request was in flight, so we may need a follow-up.
        final entry = _getEntry(key, getServerRevisionFromState);
        final int currentLocalRev = entry.localRevision;
        final int currentServerRev = entry.serverRevision;
        final bool isPush = entry.isPush;

        // If the current value was created by the user locally (it's not
        // from push), and localRevision advanced, we need a follow-up.
        if (!isPush && (currentLocalRev > localRevision)) {
          revisionMap[key] = _RevisionEntry(
            localRevision: currentLocalRev,
            serverRevision: currentServerRev,
            isPush: false,
          );

          // Read the current value from the store.
          // Will loop one more time, to do the follow-up request.
          value = getValueFromState(state);
          localRevision = currentLocalRev;
        }
        //
        // If the state is stable for this key, we may apply the server response,
        // but only if it is not stale relative to newer pushes.
        else {
          // State is stable for this key. Now we may apply the server response,
          // but only if it is not stale relative to newer pushes.
          if (serverResponse != null) {
            // Only apply if the informed server revision still matches the latest
            // known server revision for this key (i.e., no newer push arrived).
            final bool shouldApply = informedServerRev! >= currentServerRev;

            if (shouldApply) {
              revisionMap[key] = _RevisionEntry(
                localRevision: currentLocalRev,
                serverRevision: informedServerRev!,
                isPush: false,
              );

              if (applyServerResponseToState != null) {
                final newState =
                    applyServerResponseToState(state, serverResponse);
                if (newState != null) emit(newState);
              }
            }
          }

          // Release lock and finish.
          keySet.remove(key);
          final newState = await onFinish?.call(null);
          if (newState != null) emit(newState);

          // Break the loop.
          break;
        }
      }
      //
      catch (error) {
        // Request failed: release lock, run onFinish(error),
        // then rethrow so the action still fails as before.
        keySet.remove(key);
        final newState = await onFinish?.call(error);
        if (newState != null) emit(newState);
        rethrow;
      }
    }
  }

  /// Applies a server push to the state with proper revision tracking.
  ///
  /// This should be used by code that receives values via server push
  /// (WebSockets, Server-Sent Events, Firebase, etc.) and needs to apply
  /// them to the state while properly coordinating with [optimisticSyncWithPush].
  ///
  /// **Required parameters:**
  ///
  /// - [pushMetadata] - The metadata that came with the push, including:
  ///   - `serverRevision`: The server's revision number
  ///   - `localRevision`: The local revision that triggered this push (if from this device)
  ///   - `deviceId`: The device ID that made the original change
  /// - [applyServerPushToState] - Applies the pushed data to the state.
  ///   Receives the current state, key, and server revision. Should save the
  ///   server revision in the state. Return null to ignore the push.
  /// - [getServerRevisionFromState] - Returns the server revision from state
  ///   for a given key. Return -1 if unknown.
  /// - [key] - Key that matches the corresponding [optimisticSyncWithPush] key.
  ///
  /// **Example:**
  ///
  /// ```dart
  /// void handlePush(PushData data) {
  ///   serverPush(
  ///     key: ('toggleLike', data.itemId),
  ///     pushMetadata: (
  ///       serverRevision: data.serverRev,
  ///       localRevision: data.localRev,
  ///       deviceId: data.deviceId,
  ///     ),
  ///     getServerRevisionFromState: (key) => state.revisions[key] ?? -1,
  ///     applyServerPushToState: (state, key, serverRev) =>
  ///         state.copyWith(
  ///           items: state.items.setLiked(data.itemId, data.liked),
  ///           revisions: state.revisions.add(key, serverRev),
  ///         ),
  ///   );
  /// }
  /// ```
  void serverPush({
    required PushMetadata pushMetadata,
    required S? Function(S state, Object? key, int serverRevision)
        applyServerPushToState,
    required int Function(Object? key) getServerRevisionFromState,
    required Object key,
  }) {
    final revisionMap = _getRevisionMap();

    final (
      :serverRevision,
      :localRevision,
      :deviceId,
    ) = pushMetadata;

    final current = revisionMap[key];
    final int serverRevisionFromMap = current?.serverRevision ?? -1;
    final int serverRevisionFromState = getServerRevisionFromState(key);

    // Determine the current known server revision for this key.
    // This is the max of what we have in the map versus what is in the state.
    final currentServerRev =
        max(serverRevisionFromMap, serverRevisionFromState);

    // Seed the map from persisted state, if needed.
    // This is important even when we ignore the push as stale.
    if ((serverRevisionFromMap == -1) && (serverRevisionFromState >= 0)) {
      revisionMap[key] = _RevisionEntry(
        localRevision: 0,
        serverRevision: serverRevisionFromState,
        isPush: true,
      );
    }

    // Ignore stale/out-of-order pushes.
    if (serverRevision > currentServerRev) {
      final entry = revisionMap[key];
      final int currentLocalRev = entry?.localRevision ?? 0;

      final bool isSelf = (deviceId == optimisticSyncWithPushDeviceId());

      // Self-echo of an older request: treat as ACK only.
      // Do NOT apply and do NOT mark isPush=true (otherwise it cancels follow-ups).
      if (isSelf && (localRevision < currentLocalRev)) {
        revisionMap[key] = _RevisionEntry(
          localRevision: currentLocalRev,
          serverRevision: serverRevision,
          isPush: false,
        );
      } else {
        // Safe to apply (external push, or self echo that matches latest intent).
        final newState = applyServerPushToState(state, key, serverRevision);

        // Always record newest known server revision, even if user ignores the push (newState == null).
        final int storedLocalRev =
            isSelf ? max(currentLocalRev, localRevision) : currentLocalRev;

        revisionMap[key] = _RevisionEntry(
          localRevision: storedLocalRev,
          serverRevision: serverRevision,
          isPush: true,
        );

        if (newState != null) emit(newState);
      }
    }
  }
}

/// Gets the revision entry for a key, creating a default if it doesn't exist.
_RevisionEntry _getEntry(
    Object? key, int Function(Object? key) getServerRevisionFromState) {
  final revisionMap = _getRevisionMap();
  return revisionMap[key] ??
      _RevisionEntry(
        localRevision: 0,
        serverRevision: getServerRevisionFromState(key),
        isPush: false,
      );
}
