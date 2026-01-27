import 'package:bloc/bloc.dart';
import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:bloc_superpowers/src/optimistic_command.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    Superpowers.clear();
  });

  group('optimisticCommand basic functionality', () {
    test('applies optimistic value immediately and keeps it on success',
        () async {
      final cubit = TestCubit();
      final stateLog = <List<String>>[];

      await cubit.saveItem(
        'new_item',
        stateLog: stateLog,
      );

      // State should have the optimistic value
      expect(cubit.state.items, ['initial', 'new_item']);

      // Only one state change (the optimistic update)
      expect(stateLog.length, 1);
      expect(stateLog[0], ['initial', 'new_item']);
    });

    test('rolls back on failure when state unchanged', () async {
      final cubit = TestCubit();
      final stateLog = <List<String>>[];

      try {
        await cubit.saveItemThatFails(
          'new_item',
          stateLog: stateLog,
        );
      } catch (_) {}

      // State should be rolled back to initial
      expect(cubit.state.items, ['initial']);

      // Two state changes: optimistic, then rollback
      expect(stateLog.length, 2);
      expect(stateLog[0], ['initial', 'new_item']); // Optimistic
      expect(stateLog[1], ['initial']); // Rolled back
    });

    test('does NOT rollback if state was changed by another operation',
        () async {
      final cubit = TestCubit();
      final stateLog = <List<String>>[];
      var rollbackOccurred = false;

      try {
        await cubit.saveItemThatFailsAfterStateChange(
          'new_item',
          stateLog: stateLog,
          onStateChange: () {
            // Simulate another operation changing state during server call
            cubit.changeStateExternally(['changed_by_other']);
          },
          onRollback: () {
            rollbackOccurred = true;
          },
        );
      } catch (_) {}

      // Rollback should NOT have occurred because state changed
      expect(rollbackOccurred, isFalse);

      // State should be 'changed_by_other' (not rolled back)
      expect(cubit.state.items, ['changed_by_other']);
    });

    test('applies server response when sendCommandToServer returns a value',
        () async {
      final cubit = TestCubit();

      await cubit.saveItemWithServerResponse('new_item');

      // State should have the server-confirmed value
      expect(cubit.state.items, ['initial', 'new_item', 'server_confirmed']);
    });

    test(
        'does NOT apply server response when applyServerResponseToState returns null',
        () async {
      final cubit = TestCubit();

      await cubit.saveItemWithServerResponseIgnored('new_item');

      // State should keep the optimistic value
      expect(cubit.state.items, ['initial', 'new_item']);
    });
  });

  group('optimisticCommand with reloadFromServer', () {
    test('calls reloadFromServer on failure (default shouldReload)', () async {
      final cubit = TestCubit();
      var reloadCalled = false;

      try {
        await cubit.saveItemThatFailsWithReload(
          'new_item',
          onReload: () => reloadCalled = true,
        );
      } catch (_) {}

      expect(reloadCalled, isTrue);
      // State should be reloaded
      expect(cubit.state.items, ['reloaded']);
    });

    test('does NOT call reloadFromServer on success (default shouldReload)',
        () async {
      final cubit = TestCubit();
      var reloadCalled = false;

      await cubit.saveItemWithReloadOnSuccess(
        'new_item',
        onReload: () => reloadCalled = true,
      );

      expect(reloadCalled, isFalse);
      // State keeps optimistic value
      expect(cubit.state.items, ['initial', 'new_item']);
    });

    test('skips reload when reloadFromServer is not provided', () async {
      final cubit = TestCubit();
      final stateLog = <List<String>>[];

      await cubit.saveItem(
        'new_item',
        stateLog: stateLog,
      );

      // Only one state change (no reload)
      expect(stateLog.length, 1);
      expect(cubit.state.items, ['initial', 'new_item']);
    });

    test('skips reload on failure when reloadFromServer not provided',
        () async {
      final cubit = TestCubit();
      final stateLog = <List<String>>[];

      try {
        await cubit.saveItemThatFails(
          'new_item',
          stateLog: stateLog,
        );
      } catch (_) {}

      // Two state changes: optimistic, rollback (no reload)
      expect(stateLog.length, 2);
      expect(cubit.state.items, ['initial']);
    });
  });

  group('optimisticCommand shouldRollback override', () {
    test('shouldRollback returning false prevents rollback', () async {
      final cubit = TestCubit();

      try {
        await cubit.saveItemThatFailsWithoutRollback('new_item');
      } catch (_) {}

      // State should keep the optimistic value (no rollback)
      expect(cubit.state.items, ['initial', 'new_item']);
    });

    test('shouldRollback always true: rollback even when state changed',
        () async {
      final cubit = TestCubit();

      try {
        await cubit.saveItemThatFailsWithAlwaysRollback(
          'new_item',
          onStateChange: () {
            cubit.changeStateExternally(['changed_by_other']);
          },
        );
      } catch (_) {}

      // State should be rolled back even though another operation changed it
      expect(cubit.state.items, ['initial']);
    });
  });

  group('optimisticCommand custom rollbackState', () {
    test('custom rollbackState marks item as failed instead of removing',
        () async {
      final cubit = TestCubit();

      try {
        await cubit.saveItemWithCustomRollback('new_item');
      } catch (_) {}

      // State should have the item marked as failed
      expect(cubit.state.items, ['initial', 'new_item (FAILED)']);
    });

    test('rollbackState returning null skips rollback', () async {
      final cubit = TestCubit();

      try {
        await cubit.saveItemWithRollbackReturningNull('new_item');
      } catch (_) {}

      // State should keep the optimistic value
      expect(cubit.state.items, ['initial', 'new_item']);
    });
  });

  group('optimisticCommand shouldReload override', () {
    test('shouldReload returning false skips reload', () async {
      final cubit = TestCubit();
      var reloadCalled = false;

      try {
        await cubit.saveItemWithShouldReloadFalse(
          'new_item',
          onReload: () => reloadCalled = true,
        );
      } catch (_) {}

      expect(reloadCalled, isFalse);
      // State should be rolled back (no reload)
      expect(cubit.state.items, ['initial']);
    });

    test('shouldReload returning true triggers reload', () async {
      final cubit = TestCubit();
      var reloadCalled = false;

      await cubit.saveItemWithShouldReloadTrue(
        'new_item',
        onReload: () => reloadCalled = true,
      );

      expect(reloadCalled, isTrue);
      expect(cubit.state.items, ['reloaded']);
    });
  });

  group('optimisticCommand shouldApplyReload override', () {
    test('shouldApplyReload returning false skips applying reload result',
        () async {
      final cubit = TestCubit();

      try {
        await cubit.saveItemWithShouldApplyReloadFalse('new_item');
      } catch (_) {}

      // State should be rolled back, not reloaded
      expect(cubit.state.items, ['initial']);
    });

    test('shouldApplyReload returning true applies reload result', () async {
      final cubit = TestCubit();

      try {
        await cubit.saveItemWithShouldApplyReloadTrue('new_item');
      } catch (_) {}

      expect(cubit.state.items, ['reloaded']);
    });
  });

  group('optimisticCommand custom applyReloadResultToState', () {
    test('custom applyReloadResultToState transforms reload result', () async {
      final cubit = TestCubit();

      try {
        await cubit.saveItemWithCustomApplyReload('new_item');
      } catch (_) {}

      expect(cubit.state.items, ['reloaded', 'TRANSFORMED']);
    });

    test('applyReloadResultToState returning null skips applying reload',
        () async {
      final cubit = TestCubit();
      var reloadCalled = false;

      try {
        await cubit.saveItemWithApplyReloadReturningNull(
          'new_item',
          onReload: () => reloadCalled = true,
        );
      } catch (_) {}

      // Reload was called but result was not applied
      expect(reloadCalled, isTrue);
      // State should be rolled back, not reloaded
      expect(cubit.state.items, ['initial']);
    });
  });

  group('optimisticCommand non-reentrant behavior', () {
    test('uses key as nonReentrantKey when not provided', () async {
      final cubit = TestCubit();

      // Start first action without explicit nonReentrantKey
      final future1 =
          cubit.saveItemSlowWithoutNonReentrantKey('item1', delayMillis: 100);

      // Wait a bit and start second action with same key
      await Future.delayed(const Duration(milliseconds: 10));
      final future2 =
          cubit.saveItemSlowWithoutNonReentrantKey('item2', delayMillis: 10);

      await Future.wait([future1, future2]);

      // Only first action should have run (key was used as nonReentrantKey)
      expect(cubit.state.items, ['initial', 'item1']);
    });

    test('blocks concurrent dispatches with same key', () async {
      final cubit = TestCubit();

      // Start first action that takes 100ms
      final future1 = cubit.saveItemSlow('item1', delayMillis: 100);

      // Wait a bit and start second action with same key
      await Future.delayed(const Duration(milliseconds: 10));
      final future2 = cubit.saveItemSlow('item2', delayMillis: 10);

      await Future.wait([future1, future2]);

      // Only first action should have run
      expect(cubit.state.items, ['initial', 'item1']);
    });

    test('allows dispatch after action completes', () async {
      final cubit = TestCubit();

      await cubit.saveItemSlow('item1', delayMillis: 10);
      expect(cubit.state.items, ['initial', 'item1']);

      // After completion, we can dispatch again
      await cubit.saveItemSlow('item2', delayMillis: 10);
      expect(cubit.state.items, ['initial', 'item1', 'item2']);
    });

    test('releases key even when action fails', () async {
      final cubit = TestCubit();

      // Dispatch action that will fail
      try {
        await cubit.saveItemSlowThatFails(delayMillis: 10);
      } catch (_) {}

      expect(cubit.state.items, ['initial']); // Rolled back

      // After failure, we can dispatch again
      await cubit.saveItemSlow('item1', delayMillis: 10);
      expect(cubit.state.items, ['initial', 'item1']);
    });

    test('different nonReentrantKeys can run in parallel', () async {
      final cubit = TestCubit();

      // Start two actions with different keys
      final future1 = cubit.saveItemWithKey('A', 'valueA', delayMillis: 100);
      final future2 = cubit.saveItemWithKey('B', 'valueB', delayMillis: 100);

      await Future.wait([future1, future2]);

      // Both should have run
      expect(cubit.state.items.length, 3); // initial + valueA + valueB
      expect(cubit.state.items.contains('valueA'), isTrue);
      expect(cubit.state.items.contains('valueB'), isTrue);
    });

    test('same nonReentrantKey blocks concurrent executions', () async {
      final cubit = TestCubit();

      // Start first action
      final future1 = cubit.saveItemWithKey('A', 'valueA1', delayMillis: 100);

      // Wait a bit and start second action with same key
      await Future.delayed(const Duration(milliseconds: 10));
      final future2 = cubit.saveItemWithKey('A', 'valueA2', delayMillis: 10);

      await Future.wait([future1, future2]);

      // Only first should have run
      expect(cubit.state.items, ['initial', 'valueA1']);
    });
  });

  group('optimisticCommand error handling', () {
    test('reload error is thrown when command succeeds but reload fails',
        () async {
      final cubit = TestCubit();

      await expectLater(
        cubit.saveItemWithReloadThatThrows('new_item'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Reload failed'),
        )),
      );

      // Optimistic value should remain (reload didn't overwrite)
      expect(cubit.state.items, ['initial', 'new_item']);
    });

    test('original command error is thrown when both command and reload fail',
        () async {
      final cubit = TestCubit();

      await expectLater(
        cubit.saveItemWithBothCommandAndReloadThatThrow('new_item'),
        throwsA(isA<UserException>().having(
          (e) => e.message,
          'message',
          contains('Command failed'),
        )),
      );

      // Should be rolled back
      expect(cubit.state.items, ['initial']);
    });
  });

  group('optimisticCommand inline state tracking', () {
    test('tracks waiting state during execution', () async {
      final cubit = TestCubit();

      expect(Superpowers.isWaiting('saveItem'), isFalse);

      final future = cubit.saveItemSlow('item', delayMillis: 50);

      // Should be waiting during execution
      await Future.delayed(const Duration(milliseconds: 10));
      expect(Superpowers.isWaiting('saveItem'), isTrue);

      await future;

      expect(Superpowers.isWaiting('saveItem'), isFalse);
    });

    test('tracks failed state after error', () async {
      final cubit = TestCubit();

      expect(Superpowers.isFailed('saveItem'), isFalse);

      try {
        await cubit.saveItemThatFailsWithUserException('item');
      } catch (_) {}

      expect(Superpowers.isFailed('saveItem'), isTrue);
      expect(Superpowers.getException('saveItem'), isA<UserException>());
    });

    test('supports record keys for inline tracking', () async {
      final cubit = TestCubit();
      final recordKey = ('saveItem', 'item123');

      expect(Superpowers.isWaiting(recordKey), isFalse);

      final future = cubit.saveItemWithRecordKey('item123', delayMillis: 50);

      // Should be waiting during execution
      await Future.delayed(const Duration(milliseconds: 10));
      expect(Superpowers.isWaiting(recordKey), isTrue);

      await future;

      expect(Superpowers.isWaiting(recordKey), isFalse);
    });

    test('supports record keys for failed state tracking', () async {
      final cubit = TestCubit();
      final recordKey = ('saveItem', 'item123');

      expect(Superpowers.isFailed(recordKey), isFalse);

      try {
        await cubit.saveItemWithRecordKeyThatFails('item123');
      } catch (_) {}

      expect(Superpowers.isFailed(recordKey), isTrue);
      expect(Superpowers.getException(recordKey), isA<UserException>());
    });
  });
}

// -----------------------------------------------------------------------------
// Test State
// -----------------------------------------------------------------------------

class TestState {
  final List<String> items;

  TestState({required this.items});

  TestState copyWith({List<String>? items}) =>
      TestState(items: items ?? this.items);
}

// -----------------------------------------------------------------------------
// Test Cubit
// -----------------------------------------------------------------------------

class TestCubit extends Cubit<TestState> {
  TestCubit() : super(TestState(items: ['initial']));

  void changeStateExternally(List<String> items) {
    emit(state.copyWith(items: items));
  }

  /// Basic save that succeeds
  Future<void> saveItem(
    String newItem, {
    List<List<String>>? stateLog,
  }) async {
    await optimisticCommand(
      key: 'saveItem',
      nonReentrantKey: 'saveItem',
      optimisticValue: () => [...state.items, newItem],
      getValueFromState: (state) => state.items,
      applyValueToState: (state, value) {
        final items = value as List<String>;
        stateLog?.add(items);
        return state.copyWith(items: items);
      },
      sendCommandToServer: (optimisticValue) async {
        await Future.delayed(const Duration(milliseconds: 10));
        return null;
      },
    );
  }

  /// Save that fails
  Future<void> saveItemThatFails(
    String newItem, {
    List<List<String>>? stateLog,
  }) async {
    await optimisticCommand(
      key: 'saveItem',
      nonReentrantKey: 'saveItem',
      optimisticValue: () => [...state.items, newItem],
      getValueFromState: (state) => state.items,
      applyValueToState: (state, value) {
        final items = value as List<String>;
        stateLog?.add(items);
        return state.copyWith(items: items);
      },
      sendCommandToServer: (optimisticValue) async {
        await Future.delayed(const Duration(milliseconds: 10));
        throw const UserException('Save failed');
      },
    );
  }

  /// Save that fails after state is changed by another operation
  Future<void> saveItemThatFailsAfterStateChange(
    String newItem, {
    List<List<String>>? stateLog,
    void Function()? onStateChange,
    void Function()? onRollback,
  }) async {
    await optimisticCommand(
      key: 'saveItem',
      nonReentrantKey: 'saveItem',
      optimisticValue: () => [...state.items, newItem],
      getValueFromState: (state) => state.items,
      applyValueToState: (state, value) {
        final items = value as List<String>;
        stateLog?.add(items);
        return state.copyWith(items: items);
      },
      sendCommandToServer: (optimisticValue) async {
        await Future.delayed(const Duration(milliseconds: 10));
        onStateChange?.call();
        await Future.delayed(const Duration(milliseconds: 10));
        throw const UserException('Save failed');
      },
      rollbackState: ({
        required state,
        required initialValue,
        required optimisticValue,
        required error,
      }) {
        onRollback?.call();
        return state.copyWith(items: initialValue as List<String>);
      },
    );
  }

  /// Save with server response
  Future<void> saveItemWithServerResponse(String newItem) async {
    await optimisticCommand(
      key: 'saveItem',
      nonReentrantKey: 'saveItem',
      optimisticValue: () => [...state.items, newItem],
      getValueFromState: (state) => state.items,
      applyValueToState: (state, value) {
        return state.copyWith(items: value as List<String>);
      },
      sendCommandToServer: (optimisticValue) async {
        await Future.delayed(const Duration(milliseconds: 10));
        return [...(optimisticValue as List<String>), 'server_confirmed'];
      },
      applyServerResponseToState: (state, serverResponse) {
        return state.copyWith(items: serverResponse as List<String>);
      },
    );
  }

  /// Save with server response that is ignored
  Future<void> saveItemWithServerResponseIgnored(String newItem) async {
    await optimisticCommand(
      key: 'saveItem',
      nonReentrantKey: 'saveItem',
      optimisticValue: () => [...state.items, newItem],
      getValueFromState: (state) => state.items,
      applyValueToState: (state, value) {
        return state.copyWith(items: value as List<String>);
      },
      sendCommandToServer: (optimisticValue) async {
        await Future.delayed(const Duration(milliseconds: 10));
        return ['server_response'];
      },
      applyServerResponseToState: (state, serverResponse) {
        return null; // Ignore server response
      },
    );
  }

  /// Save that fails with reload
  Future<void> saveItemThatFailsWithReload(
    String newItem, {
    void Function()? onReload,
  }) async {
    await optimisticCommand(
      key: 'saveItem',
      nonReentrantKey: 'saveItem',
      optimisticValue: () => [...state.items, newItem],
      getValueFromState: (state) => state.items,
      applyValueToState: (state, value) {
        return state.copyWith(items: value as List<String>);
      },
      sendCommandToServer: (optimisticValue) async {
        await Future.delayed(const Duration(milliseconds: 10));
        throw const UserException('Save failed');
      },
      reloadFromServer: () async {
        onReload?.call();
        return ['reloaded'];
      },
    );
  }

  /// Save with reload on success (shouldReload always true)
  Future<void> saveItemWithReloadOnSuccess(
    String newItem, {
    void Function()? onReload,
  }) async {
    await optimisticCommand(
      key: 'saveItem',
      nonReentrantKey: 'saveItem',
      optimisticValue: () => [...state.items, newItem],
      getValueFromState: (state) => state.items,
      applyValueToState: (state, value) {
        return state.copyWith(items: value as List<String>);
      },
      sendCommandToServer: (optimisticValue) async {
        await Future.delayed(const Duration(milliseconds: 10));
        return null;
      },
      reloadFromServer: () async {
        onReload?.call();
        return ['reloaded'];
      },
      // Default shouldReload returns error != null, so reload won't be called on success
    );
  }

  /// Save that fails but shouldRollback returns false
  Future<void> saveItemThatFailsWithoutRollback(String newItem) async {
    await optimisticCommand(
      key: 'saveItem',
      nonReentrantKey: 'saveItem',
      optimisticValue: () => [...state.items, newItem],
      getValueFromState: (state) => state.items,
      applyValueToState: (state, value) {
        return state.copyWith(items: value as List<String>);
      },
      sendCommandToServer: (optimisticValue) async {
        throw const UserException('Save failed');
      },
      shouldRollback: ({
        required currentValue,
        required initialValue,
        required optimisticValue,
        required error,
      }) =>
          false,
    );
  }

  /// Save that fails with always rollback (even when state changed)
  Future<void> saveItemThatFailsWithAlwaysRollback(
    String newItem, {
    void Function()? onStateChange,
  }) async {
    await optimisticCommand(
      key: 'saveItem',
      nonReentrantKey: 'saveItem',
      optimisticValue: () => [...state.items, newItem],
      getValueFromState: (state) => state.items,
      applyValueToState: (state, value) {
        return state.copyWith(items: value as List<String>);
      },
      sendCommandToServer: (optimisticValue) async {
        await Future.delayed(const Duration(milliseconds: 10));
        onStateChange?.call();
        await Future.delayed(const Duration(milliseconds: 10));
        throw const UserException('Save failed');
      },
      shouldRollback: ({
        required currentValue,
        required initialValue,
        required optimisticValue,
        required error,
      }) =>
          true, // Always rollback
    );
  }

  /// Save with custom rollback that marks item as failed
  Future<void> saveItemWithCustomRollback(String newItem) async {
    await optimisticCommand(
      key: 'saveItem',
      nonReentrantKey: 'saveItem',
      optimisticValue: () => [...state.items, newItem],
      getValueFromState: (state) => state.items,
      applyValueToState: (state, value) {
        return state.copyWith(items: value as List<String>);
      },
      sendCommandToServer: (optimisticValue) async {
        throw const UserException('Save failed');
      },
      rollbackState: ({
        required state,
        required initialValue,
        required optimisticValue,
        required error,
      }) {
        // Instead of removing, mark as failed
        final initial = initialValue as List<String>;
        return state.copyWith(items: [...initial, '$newItem (FAILED)']);
      },
    );
  }

  /// Save with rollbackState returning null
  Future<void> saveItemWithRollbackReturningNull(String newItem) async {
    await optimisticCommand(
      key: 'saveItem',
      nonReentrantKey: 'saveItem',
      optimisticValue: () => [...state.items, newItem],
      getValueFromState: (state) => state.items,
      applyValueToState: (state, value) {
        return state.copyWith(items: value as List<String>);
      },
      sendCommandToServer: (optimisticValue) async {
        throw const UserException('Save failed');
      },
      rollbackState: ({
        required state,
        required initialValue,
        required optimisticValue,
        required error,
      }) =>
          null, // Skip rollback
    );
  }

  /// Save with shouldReload returning false
  Future<void> saveItemWithShouldReloadFalse(
    String newItem, {
    void Function()? onReload,
  }) async {
    await optimisticCommand(
      key: 'saveItem',
      nonReentrantKey: 'saveItem',
      optimisticValue: () => [...state.items, newItem],
      getValueFromState: (state) => state.items,
      applyValueToState: (state, value) {
        return state.copyWith(items: value as List<String>);
      },
      sendCommandToServer: (optimisticValue) async {
        throw const UserException('Save failed');
      },
      reloadFromServer: () async {
        onReload?.call();
        return ['reloaded'];
      },
      shouldReload: ({
        required currentValue,
        required lastAppliedValue,
        required optimisticValue,
        required rollbackValue,
        required error,
      }) =>
          false, // Never reload
    );
  }

  /// Save with shouldReload returning true (always reload)
  Future<void> saveItemWithShouldReloadTrue(
    String newItem, {
    void Function()? onReload,
  }) async {
    await optimisticCommand(
      key: 'saveItem',
      nonReentrantKey: 'saveItem',
      optimisticValue: () => [...state.items, newItem],
      getValueFromState: (state) => state.items,
      applyValueToState: (state, value) {
        return state.copyWith(items: value as List<String>);
      },
      sendCommandToServer: (optimisticValue) async {
        return null;
      },
      reloadFromServer: () async {
        onReload?.call();
        return ['reloaded'];
      },
      shouldReload: ({
        required currentValue,
        required lastAppliedValue,
        required optimisticValue,
        required rollbackValue,
        required error,
      }) =>
          true, // Always reload
    );
  }

  /// Save with shouldApplyReload returning false
  Future<void> saveItemWithShouldApplyReloadFalse(String newItem) async {
    await optimisticCommand(
      key: 'saveItem',
      nonReentrantKey: 'saveItem',
      optimisticValue: () => [...state.items, newItem],
      getValueFromState: (state) => state.items,
      applyValueToState: (state, value) {
        return state.copyWith(items: value as List<String>);
      },
      sendCommandToServer: (optimisticValue) async {
        throw const UserException('Save failed');
      },
      reloadFromServer: () async {
        return ['reloaded'];
      },
      shouldApplyReload: ({
        required currentValue,
        required lastAppliedValue,
        required optimisticValue,
        required rollbackValue,
        required reloadResult,
        required error,
      }) =>
          false, // Don't apply reload
    );
  }

  /// Save with shouldApplyReload returning true
  Future<void> saveItemWithShouldApplyReloadTrue(String newItem) async {
    await optimisticCommand(
      key: 'saveItem',
      nonReentrantKey: 'saveItem',
      optimisticValue: () => [...state.items, newItem],
      getValueFromState: (state) => state.items,
      applyValueToState: (state, value) {
        return state.copyWith(items: value as List<String>);
      },
      sendCommandToServer: (optimisticValue) async {
        throw const UserException('Save failed');
      },
      reloadFromServer: () async {
        return ['reloaded'];
      },
      shouldApplyReload: ({
        required currentValue,
        required lastAppliedValue,
        required optimisticValue,
        required rollbackValue,
        required reloadResult,
        required error,
      }) =>
          true, // Apply reload
    );
  }

  /// Save with custom applyReloadResultToState
  Future<void> saveItemWithCustomApplyReload(String newItem) async {
    await optimisticCommand(
      key: 'saveItem',
      nonReentrantKey: 'saveItem',
      optimisticValue: () => [...state.items, newItem],
      getValueFromState: (state) => state.items,
      applyValueToState: (state, value) {
        return state.copyWith(items: value as List<String>);
      },
      sendCommandToServer: (optimisticValue) async {
        throw const UserException('Save failed');
      },
      reloadFromServer: () async {
        return ['reloaded'];
      },
      applyReloadResultToState: (state, reloadResult) {
        final items = reloadResult as List<String>;
        return state.copyWith(items: [...items, 'TRANSFORMED']);
      },
    );
  }

  /// Save with applyReloadResultToState returning null
  Future<void> saveItemWithApplyReloadReturningNull(
    String newItem, {
    void Function()? onReload,
  }) async {
    await optimisticCommand(
      key: 'saveItem',
      nonReentrantKey: 'saveItem',
      optimisticValue: () => [...state.items, newItem],
      getValueFromState: (state) => state.items,
      applyValueToState: (state, value) {
        return state.copyWith(items: value as List<String>);
      },
      sendCommandToServer: (optimisticValue) async {
        throw const UserException('Save failed');
      },
      reloadFromServer: () async {
        onReload?.call();
        return ['reloaded'];
      },
      applyReloadResultToState: (state, reloadResult) {
        return null; // Skip applying reload
      },
    );
  }

  /// Slow save for testing non-reentrant behavior
  Future<void> saveItemSlow(
    String newItem, {
    required int delayMillis,
  }) async {
    await optimisticCommand(
      key: 'saveItem',
      nonReentrantKey: 'saveItem',
      optimisticValue: () => [...state.items, newItem],
      getValueFromState: (state) => state.items,
      applyValueToState: (state, value) {
        return state.copyWith(items: value as List<String>);
      },
      sendCommandToServer: (optimisticValue) async {
        await Future.delayed(Duration(milliseconds: delayMillis));
        return null;
      },
    );
  }

  /// Slow save without explicit nonReentrantKey (tests default behavior)
  Future<void> saveItemSlowWithoutNonReentrantKey(
    String newItem, {
    required int delayMillis,
  }) async {
    await optimisticCommand(
      key: 'saveItem',
      // nonReentrantKey not provided - should default to key
      optimisticValue: () => [...state.items, newItem],
      getValueFromState: (state) => state.items,
      applyValueToState: (state, value) {
        return state.copyWith(items: value as List<String>);
      },
      sendCommandToServer: (optimisticValue) async {
        await Future.delayed(Duration(milliseconds: delayMillis));
        return null;
      },
    );
  }

  /// Slow save that fails
  Future<void> saveItemSlowThatFails({required int delayMillis}) async {
    await optimisticCommand(
      key: 'saveItem',
      nonReentrantKey: 'saveItem',
      optimisticValue: () => [...state.items, 'temp'],
      getValueFromState: (state) => state.items,
      applyValueToState: (state, value) {
        return state.copyWith(items: value as List<String>);
      },
      sendCommandToServer: (optimisticValue) async {
        await Future.delayed(Duration(milliseconds: delayMillis));
        throw const UserException('Save failed');
      },
    );
  }

  /// Save with parameterized key
  Future<void> saveItemWithKey(
    String keyParam,
    String value, {
    required int delayMillis,
  }) async {
    await optimisticCommand(
      key: 'saveItem_$keyParam',
      nonReentrantKey: ('saveItem', keyParam),
      optimisticValue: () => [...state.items, value],
      getValueFromState: (state) => state.items,
      applyValueToState: (state, value) {
        return state.copyWith(items: value as List<String>);
      },
      sendCommandToServer: (optimisticValue) async {
        await Future.delayed(Duration(milliseconds: delayMillis));
        return null;
      },
    );
  }

  /// Save where reload throws
  Future<void> saveItemWithReloadThatThrows(String newItem) async {
    await optimisticCommand(
      key: 'saveItem',
      nonReentrantKey: 'saveItem',
      optimisticValue: () => [...state.items, newItem],
      getValueFromState: (state) => state.items,
      applyValueToState: (state, value) {
        return state.copyWith(items: value as List<String>);
      },
      sendCommandToServer: (optimisticValue) async {
        return null;
      },
      reloadFromServer: () async {
        throw Exception('Reload failed');
      },
      shouldReload: ({
        required currentValue,
        required lastAppliedValue,
        required optimisticValue,
        required rollbackValue,
        required error,
      }) =>
          true,
    );
  }

  /// Save where both command and reload throw
  Future<void> saveItemWithBothCommandAndReloadThatThrow(String newItem) async {
    await optimisticCommand(
      key: 'saveItem',
      nonReentrantKey: 'saveItem',
      optimisticValue: () => [...state.items, newItem],
      getValueFromState: (state) => state.items,
      applyValueToState: (state, value) {
        return state.copyWith(items: value as List<String>);
      },
      sendCommandToServer: (optimisticValue) async {
        throw const UserException('Command failed');
      },
      reloadFromServer: () async {
        throw Exception('Reload failed');
      },
    );
  }

  /// Save that fails with UserException (for inline tracking test)
  Future<void> saveItemThatFailsWithUserException(String newItem) async {
    await optimisticCommand(
      key: 'saveItem',
      nonReentrantKey: 'saveItem',
      optimisticValue: () => [...state.items, newItem],
      getValueFromState: (state) => state.items,
      applyValueToState: (state, value) {
        return state.copyWith(items: value as List<String>);
      },
      sendCommandToServer: (optimisticValue) async {
        throw const UserException('Save failed');
      },
    );
  }

  /// Save with record key (for testing Object key support)
  Future<void> saveItemWithRecordKey(
    String itemId, {
    required int delayMillis,
  }) async {
    await optimisticCommand(
      key: ('saveItem', itemId),
      // Record key
      optimisticValue: () => [...state.items, itemId],
      getValueFromState: (state) => state.items,
      applyValueToState: (state, value) {
        return state.copyWith(items: value as List<String>);
      },
      sendCommandToServer: (optimisticValue) async {
        await Future.delayed(Duration(milliseconds: delayMillis));
        return null;
      },
    );
  }

  /// Save with record key that fails (for testing Object key support)
  Future<void> saveItemWithRecordKeyThatFails(String itemId) async {
    await optimisticCommand(
      key: ('saveItem', itemId),
      // Record key
      optimisticValue: () => [...state.items, itemId],
      getValueFromState: (state) => state.items,
      applyValueToState: (state, value) {
        return state.copyWith(items: value as List<String>);
      },
      sendCommandToServer: (optimisticValue) async {
        throw const UserException('Save failed');
      },
    );
  }
}
