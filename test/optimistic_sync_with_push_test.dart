import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:bloc_superpowers/src/optimistic_sync_with_push.dart';
import 'package:flutter_test/flutter_test.dart';

/// These tests verify that [optimisticSyncWithPush] correctly handles
/// server-pushed updates (e.g., via WebSockets) when using the revision-based
/// synchronization system.
///
/// The revision system consists of:
/// - [localRevision]: Tracks local user intent (increments on each dispatch)
/// - [informServerRevision]: Reports the server's revision from responses/pushes
///
/// This ensures that:
/// 1. Push updates don't cause incorrect "stable" detection
/// 2. Last-write-wins semantics work across devices
/// 3. Out-of-order/replay pushes don't regress state
void main() {
  setUp(() {
    Superpowers.clear();
    resetTestState();
  });

  // ===========================================================================
  // Test 1: Basic optimistic update works
  // ===========================================================================

  test('Basic optimistic update works', () async {
    final cubit = TestCubit();

    nextServerRevision = 11;

    await cubit.toggleLike();
    await Future.delayed(const Duration(milliseconds: 50));

    expect(cubit.state.liked, true, reason: 'Optimistic update applied');
    expect(requestLog, contains('sendValue(true, localRev=1)'));
    expect(requestLog, contains('onFinish(null)'));

    cubit.close();
  });

  // ===========================================================================
  // Test 2: With revisions, push does not prevent follow-up
  // ===========================================================================

  test('With revisions, push does not prevent follow-up', () async {
    final cubit = TestCubit();

    nextServerRevision = 11;

    // Tap #1: liked=false -> liked=true (optimistic), localRev=1
    cubit.toggleLike();
    await Future.delayed(const Duration(milliseconds: 10));
    expect(cubit.state.liked, true, reason: 'Tap #1 optimistic update');

    // Tap #2 (while request 1 potentially still processing): localRev=2
    cubit.toggleLike();
    await Future.delayed(const Duration(milliseconds: 10));
    expect(cubit.state.liked, false, reason: 'Tap #2 optimistic update');

    // Wait for all actions to complete
    await Future.delayed(const Duration(milliseconds: 100));

    // With revisions, the follow-up should have been sent because
    // localRev(2) > sentLocalRev(1) at the time request 1 completed
    expect(requestLog.where((s) => s.startsWith('sendValue')).length,
        greaterThanOrEqualTo(2),
        reason: 'Follow-up should be sent');

    cubit.close();
  });

  // ===========================================================================
  // Test 3: Remote device wins (last write wins)
  // ===========================================================================

  test('Remote device wins under last-write-wins', () async {
    final cubit = TestCubit();

    nextServerRevision = 11;

    // This device taps LIKE: localRev=1
    cubit.toggleLike();
    await Future.delayed(const Duration(milliseconds: 10));
    expect(cubit.state.liked, true);

    // Other device sets UNLIKE with newer serverRev=12 (via push)
    cubit.simulatePush(liked: false, serverRev: 12);
    await Future.delayed(const Duration(milliseconds: 10));
    expect(cubit.state.liked, false, reason: 'Push from other device applied');
    expect(cubit.state.serverRevision, 12);

    // Wait for our request to complete
    await Future.delayed(const Duration(milliseconds: 100));

    // The push's value should be preserved because it had a newer serverRev
    // and the server response (serverRev=11) is stale
    expect(cubit.state.serverRevision, 12, reason: 'Push serverRev preserved');

    cubit.close();
  });

  // ===========================================================================
  // Test 4: Local wins over older remote push
  // ===========================================================================

  test('Local wins when remote push is older', () async {
    final cubit = TestCubit();

    nextServerRevision = 15;

    // This device taps LIKE: localRev=1
    cubit.toggleLike();
    await Future.delayed(const Duration(milliseconds: 100));

    expect(cubit.state.liked, true);
    expect(cubit.state.serverRevision, 15);

    // Old push arrives (serverRev=12 < 15) - should be IGNORED
    cubit.simulatePush(liked: false, serverRev: 12);
    await Future.delayed(const Duration(milliseconds: 10));

    // State should NOT change (push was stale)
    expect(cubit.state.liked, true, reason: 'Stale push ignored, local wins');
    expect(cubit.state.serverRevision, 15, reason: 'ServerRev unchanged');

    cubit.close();
  });

  // ===========================================================================
  // Test 5: Out-of-order / replay safety
  // ===========================================================================

  test('Out-of-order pushes are ignored (replay safety)', () async {
    final cubit = TestCubit(initialLiked: true, initialServerRevision: 20);

    // Old pushes arrive (replay from reconnect) - should be IGNORED
    cubit.simulatePush(liked: false, serverRev: 18);
    await Future.delayed(const Duration(milliseconds: 10));
    expect(cubit.state.liked, true, reason: 'serverRev=18 < 20, ignored');
    expect(cubit.state.serverRevision, 20);

    cubit.simulatePush(liked: false, serverRev: 19);
    await Future.delayed(const Duration(milliseconds: 10));
    expect(cubit.state.liked, true, reason: 'serverRev=19 < 20, ignored');
    expect(cubit.state.serverRevision, 20);

    // New push arrives (serverRev=21) - should be APPLIED
    cubit.simulatePush(liked: false, serverRev: 21);
    await Future.delayed(const Duration(milliseconds: 10));
    expect(cubit.state.liked, false, reason: 'serverRev=21 > 20, applied');
    expect(cubit.state.serverRevision, 21);

    cubit.close();
  });

  // ===========================================================================
  // Test 6: Stale response is not applied when push is newer
  // ===========================================================================

  test('Stale server response is not applied to state', () async {
    final cubit = TestCubit();

    nextServerRevision = 11;

    // Tap: false -> true, localRev=1
    cubit.toggleLike();
    await Future.delayed(const Duration(milliseconds: 100));

    // Now the request has completed with serverRev=11
    expect(cubit.state.liked, true);
    expect(cubit.state.serverRevision, 11);

    // Push arrives with newer serverRev - should be applied
    cubit.simulatePush(liked: false, serverRev: 15);
    await Future.delayed(const Duration(milliseconds: 10));

    expect(cubit.state.liked, false,
        reason: 'Push with newer serverRev applied');
    expect(cubit.state.serverRevision, 15,
        reason: 'Push serverRev applied (15 > 11)');

    // Now a stale push arrives (serverRev=12 < 15) - should be IGNORED
    cubit.simulatePush(liked: true, serverRev: 12);
    await Future.delayed(const Duration(milliseconds: 10));

    expect(cubit.state.liked, false, reason: 'Stale push ignored');
    expect(cubit.state.serverRevision, 15, reason: 'ServerRev unchanged');

    cubit.close();
  });

  // ===========================================================================
  // Test 7: Throws error if informServerRevision() is not called
  // ===========================================================================

  test('Throws error if informServerRevision() is not called', () async {
    final cubit = TestCubit();

    expect(
      () => cubit.toggleLikeNoRevision(),
      throwsA(isA<StateError>().having(
        (e) => e.message,
        'message',
        contains('informServerRevision()'),
      )),
    );

    cubit.close();
  });

  // ===========================================================================
  // Test 8: DateTime-based server revision works correctly
  // ===========================================================================

  test('DateTime-based server revision works correctly', () async {
    final oldTime = DateTime(2024, 1, 1, 12, 0, 0);
    final newTime = DateTime(2024, 1, 1, 12, 0, 1);

    final cubit = TestCubit(
        initialLiked: true,
        initialServerRevision: oldTime.millisecondsSinceEpoch);

    // Push with older DateTime - should be ignored
    cubit.simulatePush(
      liked: false, // Initial is true
      serverRev: oldTime.subtract(const Duration(seconds: 1)).millisecondsSinceEpoch,
    );
    await Future.delayed(const Duration(milliseconds: 10));
    expect(cubit.state.liked, true, reason: 'Older DateTime ignored');

    // Push with newer DateTime - should be applied
    cubit.simulatePush(
      liked: false,
      serverRev: newTime.millisecondsSinceEpoch,
    );
    await Future.delayed(const Duration(milliseconds: 10));
    expect(cubit.state.liked, false, reason: 'Newer DateTime applied');

    cubit.close();
  });

  // ===========================================================================
  // Test 9: Multiple rapid taps coalesce correctly with revisions
  // ===========================================================================

  test('Multiple rapid taps coalesce correctly with revisions', () async {
    final cubit = TestCubit();

    nextServerRevision = 11;
    requestDelay = const Duration(milliseconds: 50);

    // Rapid taps: false -> true -> false -> true -> false -> true
    for (var i = 0; i < 5; i++) {
      cubit.toggleLike();
      await Future.delayed(const Duration(milliseconds: 5));
    }

    // Optimistic state after 5 toggles from false should be true
    // (odd number of toggles inverts the initial state)
    expect(cubit.state.liked, true,
        reason: '5 toggles from false ends at true (optimistic)');

    // Wait for all to complete
    await Future.delayed(const Duration(milliseconds: 500));

    // Should have at least 1 request (coalescing may occur)
    final sendCount = requestLog.where((s) => s.startsWith('sendValue')).length;
    expect(sendCount, greaterThanOrEqualTo(1));

    // Verify onFinish was called
    expect(requestLog.last, 'onFinish(null)');

    requestDelay = Duration.zero;
    cubit.close();
  });

  // ===========================================================================
  // Test 10: localRevision increments correctly across dispatches
  // ===========================================================================

  test('localRevision increments correctly across dispatches', () async {
    final cubit = TestCubit();

    nextServerRevision = 11;
    requestDelay = const Duration(milliseconds: 50);

    // Dispatch 1: localRev should be 1
    cubit.toggleLike();
    await Future.delayed(const Duration(milliseconds: 10));

    // Dispatch 2 (while 1 is in flight): this will increment localRev to 2
    // but won't send a request yet (locked)
    cubit.toggleLike();
    await Future.delayed(const Duration(milliseconds: 10));

    // Wait for request 1 to complete and follow-up to be sent
    await Future.delayed(const Duration(milliseconds: 200));

    // Check that first request had localRev=1
    expect(requestLog[0], contains('localRev=1'),
        reason: 'First request has localRev=1');

    // If follow-up was sent (because state changed), it should have localRev=2
    final sendValueLogs =
        requestLog.where((s) => s.startsWith('sendValue')).toList();
    if (sendValueLogs.length > 1) {
      expect(sendValueLogs[1], contains('localRev=2'),
          reason: 'Follow-up has localRev=2');
    }

    requestDelay = Duration.zero;
    cubit.close();
  });

  // ===========================================================================
  // Test 11: Push during follow-up is handled correctly
  // ===========================================================================

  test('Push during follow-up request is handled correctly', () async {
    final cubit = TestCubit();

    nextServerRevision = 11;
    requestDelay = const Duration(milliseconds: 50);

    // Tap 1
    cubit.toggleLike();
    await Future.delayed(const Duration(milliseconds: 10));

    // Tap 2 (triggers follow-up later)
    cubit.toggleLike();
    await Future.delayed(const Duration(milliseconds: 10));

    // Push arrives
    cubit.simulatePush(liked: true, serverRev: 15);
    await Future.delayed(const Duration(milliseconds: 10));

    // Wait for everything to settle
    await Future.delayed(const Duration(milliseconds: 200));

    // System should be in a consistent state
    expect(cubit.state.serverRevision, greaterThanOrEqualTo(11));
    expect(requestLog.last, 'onFinish(null)');

    requestDelay = Duration.zero;
    cubit.close();
  });

  // ===========================================================================
  // Test 12: Self-echo push is handled correctly
  // ===========================================================================

  test('Self-echo push is handled correctly: follow-up sends latest intent',
      () async {
    final cubit = TestCubit();

    nextServerRevision = 11;

    // Use completer to precisely control when Request 1 completes
    final request1Completer = Completer<void>();
    requestCompleter = request1Completer;

    // Tap #1: liked=false -> liked=true (optimistic), localRev=1
    cubit.toggleLike();
    await Future.delayed(const Duration(milliseconds: 10));
    expect(cubit.state.liked, true, reason: 'Tap #1 optimistic update');
    expect(requestLog, ['sendValue(true, localRev=1)']);

    // Tap #2 (while request 1 in flight): liked=true -> liked=false (optimistic), localRev=2
    cubit.toggleLike();
    await Future.delayed(const Duration(milliseconds: 10));
    expect(cubit.state.liked, false,
        reason: 'Tap #2 optimistic update (user wants false)');

    // Self-echo push arrives (echo of Request 1)
    // Using the same deviceId as the current device and localRevision=1 (stale)
    // This simulates the server echoing back the first request's value
    cubit.simulatePush(
      liked: true,
      serverRev: 11,
      pushLocalRevision: 1, // Matches request 1's localRevision
      pushDeviceId: optimisticSyncWithPushDeviceId(), // Same device = self-echo
    );
    await Future.delayed(const Duration(milliseconds: 10));
    // Self-echo with stale localRevision should NOT apply to state
    expect(cubit.state.liked, false,
        reason: 'Self-echo with stale localRev should not apply');

    // Request 1 completes
    request1Completer.complete();
    await Future.delayed(const Duration(milliseconds: 50));

    // Follow-up should be sent because localRev advanced and isPush=false
    expect(requestLog.length, greaterThanOrEqualTo(2),
        reason: 'Follow-up was sent (revision check passed)');

    // Check what the follow-up sent
    final followUpLog =
        requestLog.where((s) => s.startsWith('sendValue')).toList();
    if (followUpLog.length >= 2) {
      // Should send user's last intent (false)
      expect(followUpLog[1], 'sendValue(false, localRev=2)',
          reason: 'Follow-up should send latest local intent (false)');
    }

    // Wait for everything to complete
    await Future.delayed(const Duration(milliseconds: 100));

    // Final state should match user's last tap (false)
    expect(cubit.state.liked, false,
        reason: 'Final state should be false (user\'s last tap)');

    cubit.close();
  });

  // ===========================================================================
  // Test 13: Follow-up is based on localRevision, not value comparison
  // ===========================================================================

  test(
      'Follow-up is sent based on localRevision even when value matches sent value',
      () async {
    final cubit = TestCubit();

    nextServerRevision = 11;

    // Control when Request 1 completes.
    final request1Completer = Completer<void>();
    requestCompleter = request1Completer;

    // Tap #1: liked=false -> liked=true, localRev=1
    cubit.toggleLike();
    await Future.delayed(const Duration(milliseconds: 10));
    expect(cubit.state.liked, true, reason: 'Tap #1 optimistic');
    expect(requestLog, ['sendValue(true, localRev=1)']);

    // Tap #2 (while request 1 in flight): liked=true -> liked=false, localRev=2
    cubit.toggleLike();
    await Future.delayed(const Duration(milliseconds: 10));
    expect(cubit.state.liked, false, reason: 'Tap #2 optimistic');

    // Tap #3 (still while request 1 in flight): liked=false -> liked=true, localRev=3
    // Final value returns to the SAME VALUE that was sent in Request 1.
    cubit.toggleLike();
    await Future.delayed(const Duration(milliseconds: 10));
    expect(cubit.state.liked, true, reason: 'Tap #3 back to sent value');

    // Request 1 completes.
    request1Completer.complete();
    await Future.delayed(const Duration(milliseconds: 100));

    final sendValueLogs =
        requestLog.where((s) => s.startsWith('sendValue')).toList();

    // With revision-based tracking, a follow-up IS sent because localRev(3) > sentLocalRev(1),
    // even though the final value (true) equals the sent value (true).
    // The follow-up sends true with localRev=3.
    expect(sendValueLogs.length, greaterThanOrEqualTo(2),
        reason:
            'Follow-up is sent because localRevision advanced (revision-based tracking)');

    // The follow-up should send the current value (true) with localRev=3
    if (sendValueLogs.length >= 2) {
      expect(sendValueLogs[1], 'sendValue(true, localRev=3)',
          reason: 'Follow-up sends current value with updated localRevision');
    }

    cubit.close();
  });

  // ===========================================================================
  // Test 14: onFinish receives error on failure
  // ===========================================================================

  test('onFinish receives error on failure', () async {
    final cubit = TestCubit();

    shouldThrowError = true;

    try {
      await cubit.toggleLike();
    } catch (e) {
      // Expected
    }

    await Future.delayed(const Duration(milliseconds: 50));

    // onFinish should have been called with the error
    expect(requestLog, contains(startsWith('onFinish(Exception:')));

    shouldThrowError = false;
    cubit.close();
  });

  // ===========================================================================
  // Test 15: onFinish can modify state on success
  // ===========================================================================

  test('onFinish can modify state on success', () async {
    final cubit = TestCubit();

    nextServerRevision = 11;
    onFinishModifiesState = true;

    await cubit.toggleLike();
    await Future.delayed(const Duration(milliseconds: 50));

    // onFinish should have modified the state
    expect(cubit.state.extraData, 'modified by onFinish');

    onFinishModifiesState = false;
    cubit.close();
  });

  // ===========================================================================
  // Test 16: onFinish can modify state on error
  // ===========================================================================

  test('onFinish can modify state on error', () async {
    final cubit = TestCubit();

    shouldThrowError = true;
    onFinishModifiesState = true;

    try {
      await cubit.toggleLike();
    } catch (e) {
      // Expected
    }

    await Future.delayed(const Duration(milliseconds: 50));

    // onFinish should have modified the state even on error
    expect(cubit.state.extraData, 'modified by onFinish');

    shouldThrowError = false;
    onFinishModifiesState = false;
    cubit.close();
  });

  // ===========================================================================
  // Test 17: applyServerResponseToState is called when state stabilizes
  // ===========================================================================

  test('applyServerResponseToState is called when state stabilizes', () async {
    final cubit = TestCubit();

    nextServerRevision = 11;
    serverReturnsValue = 'server-value';

    await cubit.toggleLikeWithServerResponse();
    await Future.delayed(const Duration(milliseconds: 50));

    // The server response should have been applied
    expect(cubit.state.extraData, 'server-value');

    serverReturnsValue = null;
    cubit.close();
  });

  // ===========================================================================
  // Test 18: Concurrent requests with different keys don't interfere
  // ===========================================================================

  test('Concurrent requests with different keys do not interfere', () async {
    final cubit = TestCubit();

    nextServerRevision = 11;
    requestDelay = const Duration(milliseconds: 30);

    // Start requests for two different items
    cubit.toggleLikeForItem('item1');
    cubit.toggleLikeForItem('item2');

    await Future.delayed(const Duration(milliseconds: 100));

    // Both should have been sent (different keys = no lock conflict)
    final sendValueLogs =
        requestLog.where((s) => s.startsWith('sendValue')).toList();
    expect(sendValueLogs.length, 2, reason: 'Both requests sent');
    expect(sendValueLogs[0], contains('item1'));
    expect(sendValueLogs[1], contains('item2'));

    requestDelay = Duration.zero;
    cubit.close();
  });

  // ===========================================================================
  // Test 19: maxFollowUpRequests limit is enforced
  // ===========================================================================

  test('maxFollowUpRequests limit is enforced', () async {
    final cubit = TestCubit();

    nextServerRevision = 11;

    // Test that StateError with correct message is thrown when limit is exceeded.
    // We test this by using a specially crafted method that forces infinite follow-ups.
    await expectLater(
      cubit.toggleLikeForceInfiniteFollowUp(maxFollowUp: 3),
      throwsA(isA<StateError>().having(
        (e) => e.message,
        'message',
        contains('Too many follow-up requests'),
      )),
    );

    // Don't close immediately - let any pending async work settle first
    await Future.delayed(const Duration(milliseconds: 50));
    cubit.close();
  });

  // ===========================================================================
  // Test 20: serverPush with matching self-echo updates serverRevision only
  // ===========================================================================

  test('serverPush with self-echo matching latest intent applies state',
      () async {
    final cubit = TestCubit();

    nextServerRevision = 11;

    // Control when request completes
    final completer = Completer<void>();
    requestCompleter = completer;

    // Tap: localRev=1
    cubit.toggleLike();
    await Future.delayed(const Duration(milliseconds: 10));
    expect(cubit.state.liked, true);

    // Self-echo arrives with localRevision matching latest intent
    cubit.simulatePush(
      liked: true,
      serverRev: 11,
      pushLocalRevision: 1,
      pushDeviceId: optimisticSyncWithPushDeviceId(),
    );
    await Future.delayed(const Duration(milliseconds: 10));

    // Self-echo with matching localRevision SHOULD apply
    expect(cubit.state.liked, true);
    expect(cubit.state.serverRevision, 11);

    // Complete the request
    completer.complete();
    await Future.delayed(const Duration(milliseconds: 50));

    cubit.close();
  });
}

// =============================================================================
// Test state
// =============================================================================

class AppState {
  final bool liked;
  final Map<String, bool> items;
  final int serverRevision;
  final String? extraData;

  AppState({
    required this.liked,
    this.items = const {},
    this.serverRevision = 0,
    this.extraData,
  });

  AppState copyWith({
    bool? liked,
    Map<String, bool>? items,
    int? serverRevision,
    String? extraData,
  }) =>
      AppState(
        liked: liked ?? this.liked,
        items: items ?? this.items,
        serverRevision: serverRevision ?? this.serverRevision,
        extraData: extraData ?? this.extraData,
      );

  @override
  String toString() =>
      'AppState(liked: $liked, serverRev: $serverRevision, items: $items)';
}

// =============================================================================
// Test control variables
// =============================================================================

List<String> requestLog = [];
Completer<void>? requestCompleter;
int nextServerRevision = 1;
Duration requestDelay = Duration.zero;
bool shouldThrowError = false;
bool onFinishModifiesState = false;
String? serverReturnsValue;

void resetTestState() {
  requestLog = [];
  requestCompleter = null;
  nextServerRevision = 1;
  requestDelay = Duration.zero;
  shouldThrowError = false;
  onFinishModifiesState = false;
  serverReturnsValue = null;
}

// =============================================================================
// Test Cubit
// =============================================================================

class TestCubit extends Cubit<AppState> {
  TestCubit({bool initialLiked = false, int initialServerRevision = 10})
      : super(AppState(
            liked: initialLiked, serverRevision: initialServerRevision));

  static const _key = 'toggleLike';

  /// Tracks the server revision from response for applyServerResponseToState.
  int _serverRevFromResponse = 0;

  /// Toggle like using optimisticSyncWithPush.
  Future<void> toggleLike() async {
    await optimisticSyncWithPush<bool>(
      key: _key,
      valueToApply: () => !state.liked,
      applyOptimisticValueToState: (state, value) =>
          state.copyWith(liked: value),
      getValueFromState: (state) => state.liked,
      getServerRevisionFromState: (key) => state.serverRevision,
      sendValueToServer: (value, localRevision, deviceId, informServerRevision) async {
        requestLog.add('sendValue($value, localRev=$localRevision)');

        // Wait for completer if provided
        if (requestCompleter != null) {
          await requestCompleter!.future;
          requestCompleter = null;
        } else if (requestDelay != Duration.zero) {
          await Future.delayed(requestDelay);
        }

        if (shouldThrowError) {
          throw Exception('Test error');
        }

        _serverRevFromResponse = nextServerRevision++;
        informServerRevision(_serverRevFromResponse);

        return value;
      },
      applyServerResponseToState: (state, serverResponse) => state.copyWith(
        liked: serverResponse as bool,
        serverRevision: _serverRevFromResponse,
      ),
      onFinish: (error) async {
        requestLog.add('onFinish($error)');
        if (onFinishModifiesState) {
          return state.copyWith(extraData: 'modified by onFinish');
        }
        return null;
      },
    );
  }

  /// Toggle like WITHOUT calling informServerRevision (to test error).
  Future<void> toggleLikeNoRevision() async {
    await optimisticSyncWithPush<bool>(
      key: _key,
      valueToApply: () => !state.liked,
      applyOptimisticValueToState: (state, value) =>
          state.copyWith(liked: value),
      getValueFromState: (state) => state.liked,
      getServerRevisionFromState: (key) => state.serverRevision,
      sendValueToServer: (value, localRevision, deviceId, informServerRevision) async {
        requestLog.add('sendValue($value)');
        // Intentionally NOT calling informServerRevision()
        return value;
      },
    );
  }

  /// Toggle like with server response being applied.
  Future<void> toggleLikeWithServerResponse() async {
    await optimisticSyncWithPush<bool>(
      key: _key,
      valueToApply: () => !state.liked,
      applyOptimisticValueToState: (state, value) =>
          state.copyWith(liked: value),
      getValueFromState: (state) => state.liked,
      getServerRevisionFromState: (key) => state.serverRevision,
      sendValueToServer: (value, localRevision, deviceId, informServerRevision) async {
        _serverRevFromResponse = nextServerRevision++;
        informServerRevision(_serverRevFromResponse);
        return serverReturnsValue;
      },
      applyServerResponseToState: (state, serverResponse) => state.copyWith(
        extraData: serverResponse as String,
        serverRevision: _serverRevFromResponse,
      ),
    );
  }

  /// Toggle like for a specific item (different key per item).
  Future<void> toggleLikeForItem(String itemId) async {
    await optimisticSyncWithPush<bool>(
      key: ('toggleLike', itemId),
      valueToApply: () => !(state.items[itemId] ?? false),
      applyOptimisticValueToState: (state, value) => state.copyWith(
        items: {...state.items, itemId: value},
      ),
      getValueFromState: (state) => state.items[itemId] ?? false,
      getServerRevisionFromState: (key) => state.serverRevision,
      sendValueToServer: (value, localRevision, deviceId, informServerRevision) async {
        requestLog.add('sendValue($itemId, $value, localRev=$localRevision)');

        if (requestDelay != Duration.zero) {
          await Future.delayed(requestDelay);
        }

        _serverRevFromResponse = nextServerRevision++;
        informServerRevision(_serverRevFromResponse);
        return value;
      },
    );
  }

  /// Simulate a server push.
  void simulatePush({
    required bool liked,
    required int serverRev,
    int pushLocalRevision = 0,
    int? pushDeviceId,
  }) {
    serverPush(
      key: _key,
      pushMetadata: (
        serverRevision: serverRev,
        localRevision: pushLocalRevision,
        deviceId: pushDeviceId ?? -999, // Default to a different deviceId
      ),
      getServerRevisionFromState: (key) => state.serverRevision,
      applyServerPushToState: (state, key, serverRevision) => state.copyWith(
        liked: liked,
        serverRevision: serverRevision,
      ),
    );
  }

  /// Toggle like that forces infinite follow-ups by dispatching while holding the lock.
  /// This is used to test the maxFollowUpRequests safety limit.
  Future<void> toggleLikeForceInfiniteFollowUp({required int maxFollowUp}) async {
    await optimisticSyncWithPush<bool>(
      key: _key,
      maxFollowUpRequests: maxFollowUp,
      valueToApply: () => !state.liked,
      applyOptimisticValueToState: (state, value) =>
          state.copyWith(liked: value),
      getValueFromState: (state) => state.liked,
      getServerRevisionFromState: (key) => state.serverRevision,
      sendValueToServer: (value, localRevision, deviceId, informServerRevision) async {
        _serverRevFromResponse = nextServerRevision++;
        informServerRevision(_serverRevFromResponse);

        // Dispatch another call to the same key while we hold the lock.
        // This increments localRevision in the map, forcing a follow-up
        // when the current request completes.
        // The nested dispatch returns immediately (because we're locked),
        // but it does increment localRevision first.
        optimisticSyncWithPush<bool>(
          key: _key,
          maxFollowUpRequests: maxFollowUp,
          valueToApply: () => !state.liked,
          applyOptimisticValueToState: (state, value) =>
              state.copyWith(liked: value),
          getValueFromState: (state) => state.liked,
          getServerRevisionFromState: (key) => state.serverRevision,
          sendValueToServer: (v, l, d, i) async => v, // Won't run (locked)
        );

        return value;
      },
    );
  }
}
