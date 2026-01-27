import 'package:bloc/bloc.dart';
import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:bloc_superpowers/src/optimistic_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    Superpowers.clear();
  });

  group('optimisticSync basic functionality', () {
    test('single dispatch applies optimistic update and sends request',
        () async {
      final cubit = TestCubit();
      final requestLog = <String>[];

      await cubit.toggleLike(requestLog: requestLog);

      expect(cubit.state.liked, true);
      expect(requestLog, ['saveValue(true)', 'onFinish(null)']);
    });

    test('applies optimistic value immediately', () async {
      final cubit = TestCubit();
      bool? valueBeforeServerCall;

      await cubit.toggleLikeWithCallback(
        onBeforeServerCall: () {
          valueBeforeServerCall = cubit.state.liked;
        },
      );

      // Optimistic update was applied before server call
      expect(valueBeforeServerCall, true);
      expect(cubit.state.liked, true);
    });
  });

  group('optimisticSync request coalescing', () {
    test('rapid dispatches apply all optimistic updates but coalesce requests',
        () async {
      final cubit = TestCubit();
      final requestLog = <String>[];

      // Dispatch rapidly: false -> true -> false -> true
      cubit.toggleLikeSlow(
        requestLog: requestLog,
        delayMillis: 100,
      );
      await Future.delayed(const Duration(milliseconds: 10));
      expect(cubit.state.liked, true);

      cubit.toggleLikeSlow(
        requestLog: requestLog,
        delayMillis: 100,
      ); // true -> false, locked
      await Future.delayed(const Duration(milliseconds: 10));
      expect(cubit.state.liked, false);

      cubit.toggleLikeSlow(
        requestLog: requestLog,
        delayMillis: 100,
      ); // false -> true, locked
      await Future.delayed(const Duration(milliseconds: 10));
      expect(cubit.state.liked, true);

      // Wait for all requests to complete
      await Future.delayed(const Duration(milliseconds: 300));

      // Final state should be true (last toggle)
      expect(cubit.state.liked, true);

      // Only one request sent (coalesced), no follow-up needed
      expect(requestLog, ['saveValue(true)', 'onFinish(null)']);
    });

    test('follow-up request sent when state differs after completion',
        () async {
      final cubit = TestCubit();
      final requestLog = <String>[];

      // Dispatch: false -> true (sends request)
      cubit.toggleLikeSlow(
        requestLog: requestLog,
        delayMillis: 100,
      );
      await Future.delayed(const Duration(milliseconds: 10));
      expect(cubit.state.liked, true);

      // Dispatch while locked: true -> false
      cubit.toggleLikeSlow(
        requestLog: requestLog,
        delayMillis: 100,
      );
      await Future.delayed(const Duration(milliseconds: 10));
      expect(cubit.state.liked, false);

      // Wait for all to complete
      await Future.delayed(const Duration(milliseconds: 300));

      expect(cubit.state.liked, false);

      // First request sent true, then follow-up sent false
      expect(requestLog,
          ['saveValue(true)', 'saveValue(false)', 'onFinish(null)']);
    });

    test('no follow-up when state returns to sent value', () async {
      final cubit = TestCubit();
      final requestLog = <String>[];

      // Dispatch: false -> true (sends request)
      cubit.toggleLikeSlow(
        requestLog: requestLog,
        delayMillis: 100,
      );
      await Future.delayed(const Duration(milliseconds: 10));

      // Dispatch: true -> false
      cubit.toggleLikeSlow(
        requestLog: requestLog,
        delayMillis: 100,
      );
      await Future.delayed(const Duration(milliseconds: 10));

      // Dispatch: false -> true (back to sent value)
      cubit.toggleLikeSlow(
        requestLog: requestLog,
        delayMillis: 100,
      );
      await Future.delayed(const Duration(milliseconds: 10));

      await Future.delayed(const Duration(milliseconds: 300));

      expect(cubit.state.liked, true);
      // Only one request needed since final state matches sent value
      expect(requestLog, ['saveValue(true)', 'onFinish(null)']);
    });
  });

  group('optimisticSync error handling', () {
    test('error calls onFinish and keeps optimistic state', () async {
      final cubit = TestCubit();
      final requestLog = <String>[];

      try {
        await cubit.toggleLikeThatFails(requestLog: requestLog);
      } catch (_) {}

      // Optimistic update remains (no automatic rollback)
      expect(cubit.state.liked, true);
      expect(requestLog, ['saveValue(true)', 'onFinish(error)']);
    });

    test('error is rethrown after onFinish', () async {
      final cubit = TestCubit();

      await expectLater(
        cubit.toggleLikeThatFails(requestLog: []),
        throwsA(isA<UserException>()),
      );
    });

    test('onFinish can rollback state on error', () async {
      final cubit = TestCubit();
      final requestLog = <String>[];

      try {
        await cubit.toggleLikeThatFailsWithRollback(requestLog: requestLog);
      } catch (_) {}

      // onFinish rolled back the state
      expect(cubit.state.liked, false);
      expect(requestLog, ['saveValue(true)', 'onFinish(error)', 'rollback']);
    });
  });

  group('optimisticSync key-based locking', () {
    test('different keys can have concurrent requests', () async {
      final cubit = TestCubit();
      final requestLog = <String>[];

      // Dispatch for item A and B concurrently
      cubit.toggleLikeItem('A', requestLog: requestLog, delayMillis: 100);
      cubit.toggleLikeItem('B', requestLog: requestLog, delayMillis: 100);

      await Future.delayed(const Duration(milliseconds: 10));

      // Both optimistic updates applied
      expect(cubit.state.items['A'], true);
      expect(cubit.state.items['B'], true);

      await Future.delayed(const Duration(milliseconds: 200));

      // Both requests sent (not blocked by each other)
      expect(requestLog.contains('saveValue(A, true)'), true);
      expect(requestLog.contains('saveValue(B, true)'), true);
    });

    test('same key blocks concurrent requests', () async {
      final cubit = TestCubit();
      final requestLog = <String>[];

      // Dispatch twice for same item
      cubit.toggleLikeItem('A',
          requestLog: requestLog, delayMillis: 100); // false -> true
      await Future.delayed(const Duration(milliseconds: 10));
      cubit.toggleLikeItem('A',
          requestLog: requestLog, delayMillis: 100); // true -> false (locked)

      await Future.delayed(const Duration(milliseconds: 10));

      // Both optimistic updates applied
      expect(cubit.state.items['A'], false);

      // At this point, only one request should have started
      expect(requestLog, ['saveValue(A, true)']);

      await Future.delayed(const Duration(milliseconds: 300));

      // After completion, follow-up request sent
      expect(requestLog, [
        'saveValue(A, true)',
        'saveValue(A, false)',
        'onFinish(A, null)'
      ]);
    });

    test('lock is released after successful request', () async {
      final cubit = TestCubit();
      final requestLog = <String>[];

      // First dispatch
      await cubit.toggleLike(requestLog: requestLog);
      expect(cubit.state.liked, true);
      expect(requestLog, ['saveValue(true)', 'onFinish(null)']);

      // Second dispatch after completion
      await cubit.toggleLike(requestLog: requestLog);
      expect(cubit.state.liked, false);
      expect(requestLog, [
        'saveValue(true)',
        'onFinish(null)',
        'saveValue(false)',
        'onFinish(null)'
      ]);
    });

    test('lock is released after failed request', () async {
      final cubit = TestCubit();
      final requestLog = <String>[];

      // First dispatch (fails)
      try {
        await cubit.toggleLikeThatFails(requestLog: requestLog);
      } catch (_) {}
      expect(cubit.state.liked, true); // Optimistic state remains
      expect(requestLog, ['saveValue(true)', 'onFinish(error)']);

      // Second dispatch after failure (should not be blocked)
      await cubit.toggleLike(requestLog: requestLog);
      expect(cubit.state.liked, false);
      expect(requestLog, [
        'saveValue(true)',
        'onFinish(error)',
        'saveValue(false)',
        'onFinish(null)'
      ]);
    });
  });

  group('optimisticSync follow-up requests', () {
    test('multiple follow-up requests when state keeps changing', () async {
      final cubit = TestCubit();
      final requestLog = <String>[];
      var requestCount = 0;

      await cubit.toggleLikeWithStateChangeDuringRequest(
        requestLog: requestLog,
        maxChanges: 2,
        onRequestSent: () {
          requestCount++;
        },
      );

      // Should have sent multiple follow-up requests
      expect(requestCount, greaterThan(1));
      expect(requestLog.where((e) => e.startsWith('saveValue')).length,
          greaterThan(1));
    });

    test('maxFollowUpRequests throws when exceeded', () async {
      final cubit = TestCubit();

      await expectLater(
        cubit.toggleLikeWithInfiniteChanges(maxFollowUpRequests: 3),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Too many follow-up requests'),
        )),
      );
    });

    test('custom ifShouldSendAnotherRequest can prevent follow-ups', () async {
      final cubit = TestCubit();
      final requestLog = <String>[];

      // Dispatch first action
      cubit.toggleLikeWithCustomFollowUpLogic(
        requestLog: requestLog,
        delayMillis: 100,
        shouldSendFollowUp: false, // Never send follow-up
      );
      await Future.delayed(const Duration(milliseconds: 10));

      // Dispatch second (state changes while first in flight)
      cubit.toggleLikeWithCustomFollowUpLogic(
        requestLog: requestLog,
        delayMillis: 100,
        shouldSendFollowUp: false,
      );
      await Future.delayed(const Duration(milliseconds: 10));

      await Future.delayed(const Duration(milliseconds: 200));

      // No follow-up sent even though state changed
      expect(requestLog, ['saveValue(true)', 'onFinish(null)']);
    });
  });

  group('optimisticSync server response', () {
    test('server response is applied when non-null and state is stable',
        () async {
      final cubit = TestCubit();
      final requestLog = <String>[];

      await cubit.incrementWithServerResponse(
        increment: 10,
        requestLog: requestLog,
      );

      // Optimistic update was 10, but server returns 15 (normalized value)
      expect(cubit.state.count, 15);
      expect(
          requestLog, ['saveValue(10)', 'serverResponse(15)', 'onFinish(null)']);
    });

    test(
        'earlier server response does not overwrite newer local optimistic value',
        () async {
      final cubit = TestCubit();
      final requestLog = <String>[];

      // Dispatch first action: optimistic count = 10
      cubit.incrementWithServerResponseSlow(
        increment: 10,
        requestLog: requestLog,
        delayMillis: 100,
      );
      await Future.delayed(const Duration(milliseconds: 10));
      expect(cubit.state.count, 10, reason: 'First optimistic update');

      // Dispatch second action while first is in flight: optimistic count = 20
      cubit.incrementWithServerResponseSlow(
        increment: 10,
        requestLog: requestLog,
        delayMillis: 100,
      );
      await Future.delayed(const Duration(milliseconds: 10));
      expect(cubit.state.count, 20, reason: 'Second optimistic update');

      // Wait for all to complete
      await Future.delayed(const Duration(milliseconds: 300));

      // First request would have returned 15 (server normalized 10 to 15),
      // but that should NOT be applied because state changed while in flight.
      // A follow-up request was sent with 20, which server normalizes to 25.
      expect(cubit.state.count, 25, reason: 'Final state from follow-up');

      // Request log shows: first request, follow-up request, then only final serverResponse applied
      expect(requestLog,
          ['saveValue(10)', 'saveValue(20)', 'serverResponse(25)', 'onFinish(null)']);
    });

    test('server response is ignored when applyServerResponseToState is null',
        () async {
      final cubit = TestCubit();
      final requestLog = <String>[];

      await cubit.incrementWithoutApplyingServerResponse(
        increment: 10,
        requestLog: requestLog,
      );

      // Optimistic update was 10, server returned 15, but no applyServerResponseToState
      expect(cubit.state.count, 10, reason: 'Server response ignored');
      expect(requestLog, ['saveValue(10)', 'onFinish(null)']);
    });

    test(
        'server response is ignored when applyServerResponseToState returns null',
        () async {
      final cubit = TestCubit();
      final requestLog = <String>[];

      await cubit.incrementWithServerResponseReturningNull(
        increment: 10,
        requestLog: requestLog,
      );

      // Server returned a value, but applyServerResponseToState returned null
      expect(cubit.state.count, 10, reason: 'Server response ignored');
      expect(requestLog, ['saveValue(10)', 'onFinish(null)']);
    });

    test('with multiple follow-ups, only the final server response is applied',
        () async {
      final cubit = TestCubit();
      final requestLog = <String>[];

      await cubit.incrementWithServerResponseAndStateChanges(
        increment: 10,
        requestLog: requestLog,
        maxChanges: 2,
      );

      // Should have sent 3 requests (initial + 2 follow-ups)
      // Only the final server response should be applied
      expect(requestLog.where((e) => e.startsWith('saveValue')).length, 3);
      expect(requestLog.where((e) => e.startsWith('serverResponse')).length, 1);
      expect(requestLog.last, 'onFinish(null)');
    });
  });

  group('optimisticSync state cleanup', () {
    test('coalescing state is cleared on Superpowers.clear()', () async {
      final cubit = TestCubit();
      final requestLog = <String>[];

      // Start a request
      cubit.toggleLikeSlow(
        requestLog: requestLog,
        delayMillis: 50,
      );
      await Future.delayed(const Duration(milliseconds: 10));

      // Reset Superpowers state
      Superpowers.clear();

      // Wait for old action to complete
      await Future.delayed(const Duration(milliseconds: 100));

      // Create new cubit - should have fresh coalescing state
      final newCubit = TestCubit();
      requestLog.clear();

      // Should be able to dispatch without being blocked
      await newCubit.toggleLike(requestLog: requestLog);
      expect(newCubit.state.liked, true);
      expect(requestLog, ['saveValue(true)', 'onFinish(null)']);
    });
  });

  group('optimisticSync shared keys', () {
    test('different action types can share the same coalescing key', () async {
      final cubit = TestCubit();
      final requestLog = <String>[];

      // Dispatch first action type with shared key
      cubit.incrementWithSharedKey(
        increment: 1,
        requestLog: requestLog,
        delayMillis: 100,
      );
      await Future.delayed(const Duration(milliseconds: 10));
      expect(cubit.state.count, 1);

      // Dispatch second action type with same shared key (should be locked)
      cubit.decrementWithSharedKey(
        decrement: 1,
        requestLog: requestLog,
        delayMillis: 100,
      );
      await Future.delayed(const Duration(milliseconds: 10));
      expect(cubit.state.count, 0); // Optimistic update applied

      // At this point, only first request sent
      expect(requestLog, ['saveValue(sharedKey, 1)']);

      await Future.delayed(const Duration(milliseconds: 200));

      // Follow-up with current value
      expect(requestLog,
          ['saveValue(sharedKey, 1)', 'saveValue(sharedKey, 0)', 'onFinish(sharedKey, null)']);
    });
  });

  group('optimisticSync onFinish callback', () {
    test('onFinish receives optimisticValue on success', () async {
      final cubit = TestCubit();
      bool? receivedOptimisticValue;

      await cubit.toggleLikeWithOnFinishCheck(
        onFinish: (optimisticValue, error) {
          receivedOptimisticValue = optimisticValue;
        },
      );

      expect(receivedOptimisticValue, true);
    });

    test('onFinish receives optimisticValue and error on failure', () async {
      final cubit = TestCubit();
      bool? receivedOptimisticValue;
      Object? receivedError;

      try {
        await cubit.toggleLikeThatFailsWithOnFinishCheck(
          onFinish: (optimisticValue, error) {
            receivedOptimisticValue = optimisticValue;
            receivedError = error;
          },
        );
      } catch (_) {}

      expect(receivedOptimisticValue, true);
      expect(receivedError, isA<UserException>());
    });

    test('onFinish can modify state', () async {
      final cubit = TestCubit();

      await cubit.toggleLikeWithStateModifyingOnFinish();

      // onFinish set a custom value
      expect(cubit.state.liked, false); // onFinish set it back to false
      expect(cubit.state.count, 999); // onFinish also set count
    });
  });

  group('optimisticSync record keys', () {
    test('supports record keys for coalescing', () async {
      final cubit = TestCubit();
      final requestLog = <String>[];

      // First dispatch with record key
      cubit.toggleLikeWithRecordKey(
        'item123',
        requestLog: requestLog,
        delayMillis: 100,
      );
      await Future.delayed(const Duration(milliseconds: 10));
      expect(cubit.state.liked, true);

      // Second dispatch with same record key (should be blocked)
      cubit.toggleLikeWithRecordKey(
        'item123',
        requestLog: requestLog,
        delayMillis: 10,
      );
      await Future.delayed(const Duration(milliseconds: 10));
      expect(cubit.state.liked, false); // Optimistic update applied

      await Future.delayed(const Duration(milliseconds: 200));

      // Follow-up request sent
      expect(requestLog, [
        'saveValue(item123, true)',
        'saveValue(item123, false)',
        'onFinish(item123, null)'
      ]);
    });

    test('different record keys can run in parallel', () async {
      final cubit = TestCubit();
      final requestLog = <String>[];

      // Dispatch with different record keys using items (not liked)
      cubit.toggleLikeItem('A', requestLog: requestLog, delayMillis: 100);
      cubit.toggleLikeItem('B', requestLog: requestLog, delayMillis: 100);

      await Future.delayed(const Duration(milliseconds: 10));

      // Both optimistic updates applied
      expect(cubit.state.items['A'], true);
      expect(cubit.state.items['B'], true);

      await Future.delayed(const Duration(milliseconds: 200));

      // Both requests sent in parallel (not blocked by each other)
      expect(requestLog.contains('saveValue(A, true)'), true);
      expect(requestLog.contains('saveValue(B, true)'), true);
    });
  });
}

// -----------------------------------------------------------------------------
// Test State
// -----------------------------------------------------------------------------

class TestState {
  final bool liked;
  final Map<String, bool> items;
  final int count;

  TestState({
    required this.liked,
    this.items = const {},
    this.count = 0,
  });

  TestState copyWith({
    bool? liked,
    Map<String, bool>? items,
    int? count,
  }) =>
      TestState(
        liked: liked ?? this.liked,
        items: items ?? this.items,
        count: count ?? this.count,
      );
}

// -----------------------------------------------------------------------------
// Test Cubit
// -----------------------------------------------------------------------------

class TestCubit extends Cubit<TestState> {
  TestCubit()
      : super(TestState(
          liked: false,
          items: {'A': false, 'B': false},
          count: 0,
        ));

  /// Basic toggle like
  Future<void> toggleLike({List<String>? requestLog}) async {
    await optimisticSync<bool>(
      key: 'toggleLike',
      valueToApply: () => !state.liked,
      applyOptimisticValueToState: (state, isLiked) =>
          state.copyWith(liked: isLiked),
      getValueFromState: (state) => state.liked,
      sendValueToServer: (value) async {
        requestLog?.add('saveValue($value)');
        await Future.delayed(const Duration(milliseconds: 10));
        return null;
      },
      onFinish: (optimisticValue, error) async {
        requestLog?.add('onFinish(${error == null ? 'null' : 'error'})');
        return null;
      },
    );
  }

  /// Toggle like with callback before server call
  Future<void> toggleLikeWithCallback({
    void Function()? onBeforeServerCall,
  }) async {
    await optimisticSync<bool>(
      key: 'toggleLike',
      valueToApply: () => !state.liked,
      applyOptimisticValueToState: (state, isLiked) =>
          state.copyWith(liked: isLiked),
      getValueFromState: (state) => state.liked,
      sendValueToServer: (value) async {
        onBeforeServerCall?.call();
        await Future.delayed(const Duration(milliseconds: 10));
        return null;
      },
    );
  }

  /// Slow toggle like for testing coalescing
  Future<void> toggleLikeSlow({
    List<String>? requestLog,
    required int delayMillis,
  }) async {
    await optimisticSync<bool>(
      key: 'toggleLike',
      valueToApply: () => !state.liked,
      applyOptimisticValueToState: (state, isLiked) =>
          state.copyWith(liked: isLiked),
      getValueFromState: (state) => state.liked,
      sendValueToServer: (value) async {
        requestLog?.add('saveValue($value)');
        await Future.delayed(Duration(milliseconds: delayMillis));
        return null;
      },
      onFinish: (optimisticValue, error) async {
        requestLog?.add('onFinish(${error == null ? 'null' : 'error'})');
        return null;
      },
    );
  }

  /// Toggle like that fails
  Future<void> toggleLikeThatFails({List<String>? requestLog}) async {
    await optimisticSync<bool>(
      key: 'toggleLike',
      valueToApply: () => !state.liked,
      applyOptimisticValueToState: (state, isLiked) =>
          state.copyWith(liked: isLiked),
      getValueFromState: (state) => state.liked,
      sendValueToServer: (value) async {
        requestLog?.add('saveValue($value)');
        throw const UserException('Send failed');
      },
      onFinish: (optimisticValue, error) async {
        requestLog?.add('onFinish(${error == null ? 'null' : 'error'})');
        return null;
      },
    );
  }

  /// Toggle like that fails with rollback in onFinish
  Future<void> toggleLikeThatFailsWithRollback({
    List<String>? requestLog,
  }) async {
    await optimisticSync<bool>(
      key: 'toggleLike',
      valueToApply: () => !state.liked,
      applyOptimisticValueToState: (state, isLiked) =>
          state.copyWith(liked: isLiked),
      getValueFromState: (state) => state.liked,
      sendValueToServer: (value) async {
        requestLog?.add('saveValue($value)');
        throw const UserException('Send failed');
      },
      onFinish: (optimisticValue, error) async {
        requestLog?.add('onFinish(${error == null ? 'null' : 'error'})');
        if (error != null) {
          requestLog?.add('rollback');
          // Rollback: set back to opposite of optimistic value
          return state.copyWith(liked: !optimisticValue);
        }
        return null;
      },
    );
  }

  /// Toggle like for a specific item
  Future<void> toggleLikeItem(
    String itemId, {
    List<String>? requestLog,
    required int delayMillis,
  }) async {
    await optimisticSync<bool>(
      key: ('toggleLike', itemId),
      valueToApply: () => !(state.items[itemId] ?? false),
      applyOptimisticValueToState: (state, isLiked) {
        final newItems = Map<String, bool>.from(state.items);
        newItems[itemId] = isLiked;
        return state.copyWith(items: newItems);
      },
      getValueFromState: (state) => state.items[itemId] ?? false,
      sendValueToServer: (value) async {
        requestLog?.add('saveValue($itemId, $value)');
        await Future.delayed(Duration(milliseconds: delayMillis));
        return null;
      },
      onFinish: (optimisticValue, error) async {
        requestLog?.add('onFinish($itemId, ${error == null ? 'null' : 'error'})');
        return null;
      },
    );
  }

  /// Toggle like with state change during request (for testing follow-ups)
  Future<void> toggleLikeWithStateChangeDuringRequest({
    List<String>? requestLog,
    required int maxChanges,
    void Function()? onRequestSent,
  }) async {
    var changeCount = 0;

    await optimisticSync<bool>(
      key: 'toggleLike',
      valueToApply: () => !state.liked,
      applyOptimisticValueToState: (state, isLiked) =>
          state.copyWith(liked: isLiked),
      getValueFromState: (state) => state.liked,
      sendValueToServer: (value) async {
        requestLog?.add('saveValue($value)');
        onRequestSent?.call();
        await Future.delayed(const Duration(milliseconds: 50));
        // Change state during request if under max changes
        if (changeCount < maxChanges) {
          changeCount++;
          emit(state.copyWith(liked: !state.liked));
        }
        return null;
      },
      onFinish: (optimisticValue, error) async {
        requestLog?.add('onFinish(${error == null ? 'null' : 'error'})');
        return null;
      },
    );
  }

  /// Toggle like with infinite state changes (to test maxFollowUpRequests)
  Future<void> toggleLikeWithInfiniteChanges({
    required int maxFollowUpRequests,
  }) async {
    await optimisticSync<bool>(
      key: 'toggleLike',
      valueToApply: () => !state.liked,
      applyOptimisticValueToState: (state, isLiked) =>
          state.copyWith(liked: isLiked),
      getValueFromState: (state) => state.liked,
      sendValueToServer: (value) async {
        await Future.delayed(const Duration(milliseconds: 10));
        // Always change state to force infinite follow-ups
        emit(state.copyWith(liked: !state.liked));
        return null;
      },
      maxFollowUpRequests: maxFollowUpRequests,
    );
  }

  /// Toggle like with custom follow-up logic
  Future<void> toggleLikeWithCustomFollowUpLogic({
    List<String>? requestLog,
    required int delayMillis,
    required bool shouldSendFollowUp,
  }) async {
    await optimisticSync<bool>(
      key: 'toggleLike',
      valueToApply: () => !state.liked,
      applyOptimisticValueToState: (state, isLiked) =>
          state.copyWith(liked: isLiked),
      getValueFromState: (state) => state.liked,
      sendValueToServer: (value) async {
        requestLog?.add('saveValue($value)');
        await Future.delayed(Duration(milliseconds: delayMillis));
        return null;
      },
      ifShouldSendAnotherRequest: ({
        required stateValue,
        required sentValue,
        required requestCount,
      }) =>
          shouldSendFollowUp,
      onFinish: (optimisticValue, error) async {
        requestLog?.add('onFinish(${error == null ? 'null' : 'error'})');
        return null;
      },
    );
  }

  /// Increment with server response
  Future<void> incrementWithServerResponse({
    required int increment,
    List<String>? requestLog,
  }) async {
    await optimisticSync<int>(
      key: 'increment',
      valueToApply: () => state.count + increment,
      applyOptimisticValueToState: (state, count) =>
          state.copyWith(count: count),
      getValueFromState: (state) => state.count,
      sendValueToServer: (value) async {
        requestLog?.add('saveValue($value)');
        await Future.delayed(const Duration(milliseconds: 10));
        // Server "normalizes" the value by adding 5
        return value + 5;
      },
      applyServerResponseToState: (state, serverResponse) {
        requestLog?.add('serverResponse($serverResponse)');
        return state.copyWith(count: serverResponse as int);
      },
      onFinish: (optimisticValue, error) async {
        requestLog?.add('onFinish(${error == null ? 'null' : 'error'})');
        return null;
      },
    );
  }

  /// Increment with server response (slow version for testing coalescing)
  Future<void> incrementWithServerResponseSlow({
    required int increment,
    List<String>? requestLog,
    required int delayMillis,
  }) async {
    await optimisticSync<int>(
      key: 'increment',
      valueToApply: () => state.count + increment,
      applyOptimisticValueToState: (state, count) =>
          state.copyWith(count: count),
      getValueFromState: (state) => state.count,
      sendValueToServer: (value) async {
        requestLog?.add('saveValue($value)');
        await Future.delayed(Duration(milliseconds: delayMillis));
        // Server "normalizes" the value by adding 5
        return value + 5;
      },
      applyServerResponseToState: (state, serverResponse) {
        requestLog?.add('serverResponse($serverResponse)');
        return state.copyWith(count: serverResponse as int);
      },
      onFinish: (optimisticValue, error) async {
        requestLog?.add('onFinish(${error == null ? 'null' : 'error'})');
        return null;
      },
    );
  }

  /// Increment without applying server response (no applyServerResponseToState)
  Future<void> incrementWithoutApplyingServerResponse({
    required int increment,
    List<String>? requestLog,
  }) async {
    await optimisticSync<int>(
      key: 'increment',
      valueToApply: () => state.count + increment,
      applyOptimisticValueToState: (state, count) =>
          state.copyWith(count: count),
      getValueFromState: (state) => state.count,
      sendValueToServer: (value) async {
        requestLog?.add('saveValue($value)');
        await Future.delayed(const Duration(milliseconds: 10));
        // Server returns a value, but we don't provide applyServerResponseToState
        return value + 5;
      },
      // applyServerResponseToState is null
      onFinish: (optimisticValue, error) async {
        requestLog?.add('onFinish(${error == null ? 'null' : 'error'})');
        return null;
      },
    );
  }

  /// Increment with server response that returns null
  Future<void> incrementWithServerResponseReturningNull({
    required int increment,
    List<String>? requestLog,
  }) async {
    await optimisticSync<int>(
      key: 'increment',
      valueToApply: () => state.count + increment,
      applyOptimisticValueToState: (state, count) =>
          state.copyWith(count: count),
      getValueFromState: (state) => state.count,
      sendValueToServer: (value) async {
        requestLog?.add('saveValue($value)');
        await Future.delayed(const Duration(milliseconds: 10));
        return value + 5;
      },
      applyServerResponseToState: (state, serverResponse) {
        // Intentionally return null to ignore server response
        return null;
      },
      onFinish: (optimisticValue, error) async {
        requestLog?.add('onFinish(${error == null ? 'null' : 'error'})');
        return null;
      },
    );
  }

  /// Increment with server response and state changes during request
  Future<void> incrementWithServerResponseAndStateChanges({
    required int increment,
    List<String>? requestLog,
    required int maxChanges,
  }) async {
    var changeCount = 0;

    await optimisticSync<int>(
      key: 'increment',
      valueToApply: () => state.count + increment,
      applyOptimisticValueToState: (state, count) =>
          state.copyWith(count: count),
      getValueFromState: (state) => state.count,
      sendValueToServer: (value) async {
        requestLog?.add('saveValue($value)');
        await Future.delayed(const Duration(milliseconds: 50));
        // Change state during request if under max changes
        if (changeCount < maxChanges) {
          changeCount++;
          emit(state.copyWith(count: state.count + increment));
        }
        return value + 5;
      },
      applyServerResponseToState: (state, serverResponse) {
        requestLog?.add('serverResponse($serverResponse)');
        return state.copyWith(count: serverResponse as int);
      },
      onFinish: (optimisticValue, error) async {
        requestLog?.add('onFinish(${error == null ? 'null' : 'error'})');
        return null;
      },
    );
  }

  /// Increment with shared key
  Future<void> incrementWithSharedKey({
    required int increment,
    List<String>? requestLog,
    required int delayMillis,
  }) async {
    await optimisticSync<int>(
      key: 'sharedKey', // Shared key
      valueToApply: () => state.count + increment,
      applyOptimisticValueToState: (state, count) =>
          state.copyWith(count: count),
      getValueFromState: (state) => state.count,
      sendValueToServer: (value) async {
        requestLog?.add('saveValue(sharedKey, $value)');
        await Future.delayed(Duration(milliseconds: delayMillis));
        return null;
      },
      onFinish: (optimisticValue, error) async {
        requestLog?.add('onFinish(sharedKey, ${error == null ? 'null' : 'error'})');
        return null;
      },
    );
  }

  /// Decrement with shared key
  Future<void> decrementWithSharedKey({
    required int decrement,
    List<String>? requestLog,
    required int delayMillis,
  }) async {
    await optimisticSync<int>(
      key: 'sharedKey', // Same shared key
      valueToApply: () => state.count - decrement,
      applyOptimisticValueToState: (state, count) =>
          state.copyWith(count: count),
      getValueFromState: (state) => state.count,
      sendValueToServer: (value) async {
        requestLog?.add('saveValue(sharedKey, $value)');
        await Future.delayed(Duration(milliseconds: delayMillis));
        return null;
      },
      onFinish: (optimisticValue, error) async {
        requestLog?.add('onFinish(sharedKey, ${error == null ? 'null' : 'error'})');
        return null;
      },
    );
  }

  /// Toggle like with onFinish check
  Future<void> toggleLikeWithOnFinishCheck({
    required void Function(bool optimisticValue, Object? error) onFinish,
  }) async {
    await optimisticSync<bool>(
      key: 'toggleLike',
      valueToApply: () => !state.liked,
      applyOptimisticValueToState: (state, isLiked) =>
          state.copyWith(liked: isLiked),
      getValueFromState: (state) => state.liked,
      sendValueToServer: (value) async {
        await Future.delayed(const Duration(milliseconds: 10));
        return null;
      },
      onFinish: (optimisticValue, error) async {
        onFinish(optimisticValue, error);
        return null;
      },
    );
  }

  /// Toggle like that fails with onFinish check
  Future<void> toggleLikeThatFailsWithOnFinishCheck({
    required void Function(bool optimisticValue, Object? error) onFinish,
  }) async {
    await optimisticSync<bool>(
      key: 'toggleLike',
      valueToApply: () => !state.liked,
      applyOptimisticValueToState: (state, isLiked) =>
          state.copyWith(liked: isLiked),
      getValueFromState: (state) => state.liked,
      sendValueToServer: (value) async {
        throw const UserException('Send failed');
      },
      onFinish: (optimisticValue, error) async {
        onFinish(optimisticValue, error);
        return null;
      },
    );
  }

  /// Toggle like with state modifying onFinish
  Future<void> toggleLikeWithStateModifyingOnFinish() async {
    await optimisticSync<bool>(
      key: 'toggleLike',
      valueToApply: () => !state.liked,
      applyOptimisticValueToState: (state, isLiked) =>
          state.copyWith(liked: isLiked),
      getValueFromState: (state) => state.liked,
      sendValueToServer: (value) async {
        await Future.delayed(const Duration(milliseconds: 10));
        return null;
      },
      onFinish: (optimisticValue, error) async {
        // Modify state in onFinish
        return state.copyWith(liked: false, count: 999);
      },
    );
  }

  /// Toggle like with record key
  Future<void> toggleLikeWithRecordKey(
    String itemId, {
    List<String>? requestLog,
    required int delayMillis,
  }) async {
    await optimisticSync<bool>(
      key: ('toggleLike', itemId), // Record key
      valueToApply: () => !state.liked,
      applyOptimisticValueToState: (state, isLiked) =>
          state.copyWith(liked: isLiked),
      getValueFromState: (state) => state.liked,
      sendValueToServer: (value) async {
        requestLog?.add('saveValue($itemId, $value)');
        await Future.delayed(Duration(milliseconds: delayMillis));
        return null;
      },
      onFinish: (optimisticValue, error) async {
        requestLog?.add('onFinish($itemId, ${error == null ? 'null' : 'error'})');
        return null;
      },
    );
  }
}
