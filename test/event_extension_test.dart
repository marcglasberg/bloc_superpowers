import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Reset Superpowers static state before each test (for any shared static state)
  setUp(() {
    Superpowers.clear();
  });

  // Diagnostic test to understand state changes
  group('diagnostic', () {
    testWidgets('BlocBuilder rebuilds on state change', (tester) async {
      final cubit = EffectCubit();
      List<String?> capturedValues = [];

      await tester.pumpWidget(
        BlocProvider<EffectCubit>.value(
          value: cubit,
          child: MaterialApp(
            home: BlocBuilder<EffectCubit, EffectState>(
              builder: (context, state) {
                final value = state.messageEffect.consume();
                capturedValues.add(value);
                return Text(value ?? 'null');
              },
            ),
          ),
        ),
      );

      expect(capturedValues, [null]);

      cubit.showMessage('A');
      await tester.pumpAndSettle();
      expect(capturedValues, [null, 'A']);

      cubit.showMessage('B');
      await tester.pumpAndSettle();
      expect(capturedValues, [null, 'A', 'B']);
    });

    testWidgets('state equality after consume', (tester) async {
      final cubit = EffectCubit();

      // Initial state
      final state1 = cubit.state;
      expect(state1.messageEffect.isSpent, true);

      // Dispatch action
      cubit.showMessage('Test');
      final state2 = cubit.state;
      expect(state2.messageEffect.isSpent, false);
      expect(state1 == state2, false); // Should be different

      // Consume the effect
      state2.messageEffect.consume();
      expect(state2.messageEffect.isSpent, true);

      // Dispatch another action
      cubit.showMessage('Another');
      final state3 = cubit.state;
      expect(state3.messageEffect.isSpent, false);
      expect(state2 == state3, false); // Should be different
    });
  });

  group('context.effect() extension', () {
    group('value-less effects', () {
      testWidgets('returns false for spent effect', (tester) async {
        final cubit = EffectCubit();

        dynamic capturedValue;
        await tester.pumpWidget(
          BlocProvider<EffectCubit>.value(
            value: cubit,
            child: MaterialApp(
              home: Builder(
                builder: (context) {
                  capturedValue = context.effect((EffectCubit c) => c.state.clearEffect);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        expect(capturedValue, false);
      });

      testWidgets('returns true for unspent effect', (tester) async {
        final cubit = EffectCubit();

        dynamic capturedValue;
        await tester.pumpWidget(
          BlocProvider<EffectCubit>.value(
            value: cubit,
            child: MaterialApp(
              home: Builder(
                builder: (context) {
                  capturedValue = context.effect((EffectCubit c) => c.state.clearEffect);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        // Initial state has spent effect
        expect(capturedValue, false);

        // Dispatch action that creates new effect
        cubit.clearText();
        await tester.pumpAndSettle();

        // Now should capture true
        expect(capturedValue, true);
      });

      testWidgets('effect is consumed after first read', (tester) async {
        final cubit = EffectCubit();

        List<dynamic> capturedValues = [];

        await tester.pumpWidget(
          BlocProvider<EffectCubit>.value(
            value: cubit,
            child: MaterialApp(
              home: Builder(
                builder: (context) {
                  final value = context.effect((EffectCubit c) => c.state.clearEffect);
                  capturedValues.add(value);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        // Initial build with spent effect
        expect(capturedValues, [false]);

        // Dispatch action - creates unspent effect
        cubit.clearText();
        await tester.pumpAndSettle();

        // Should have captured true
        expect(capturedValues.last, true);

        // Dispatch a new effect to trigger rebuild
        cubit.clearText();
        await tester.pumpAndSettle();

        // Should capture true again (new unspent effect)
        expect(capturedValues.last, true);
      });
    });

    group('typed effects', () {
      testWidgets('returns null for spent effect', (tester) async {
        final cubit = EffectCubit();

        String? capturedValue;
        await tester.pumpWidget(
          BlocProvider<EffectCubit>.value(
            value: cubit,
            child: MaterialApp(
              home: Builder(
                builder: (context) {
                  capturedValue = context.effect((EffectCubit c) => c.state.messageEffect);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        expect(capturedValue, null);
      });

      testWidgets('returns value for unspent effect', (tester) async {
        final cubit = EffectCubit();

        String? capturedValue;
        await tester.pumpWidget(
          BlocProvider<EffectCubit>.value(
            value: cubit,
            child: MaterialApp(
              home: Builder(
                builder: (context) {
                  capturedValue = context.effect((EffectCubit c) => c.state.messageEffect);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        expect(capturedValue, null);

        // Dispatch action with message
        cubit.showMessage('Hello World');
        await tester.pumpAndSettle();

        expect(capturedValue, 'Hello World');
      });

      testWidgets('effect is consumed after first read', (tester) async {
        final cubit = EffectCubit();

        String? capturedValue;
        await tester.pumpWidget(
          BlocProvider<EffectCubit>.value(
            value: cubit,
            child: MaterialApp(
              home: Builder(
                builder: (context) {
                  capturedValue = context.effect((EffectCubit c) => c.state.messageEffect);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        // Initial build with spent effect
        expect(capturedValue, null);

        // Dispatch action
        cubit.showMessage('Test Message');
        await tester.pumpAndSettle();

        expect(capturedValue, 'Test Message');

        // Dispatch new effect to trigger rebuild
        cubit.showMessage('Another Message');
        await tester.pumpAndSettle();

        // Should capture new message (new unspent effect)
        expect(capturedValue, 'Another Message');
      });

      testWidgets('different messages create different effects', (tester) async {
        final cubit = EffectCubit();

        String? capturedValue;
        await tester.pumpWidget(
          BlocProvider<EffectCubit>.value(
            value: cubit,
            child: MaterialApp(
              home: Builder(
                builder: (context) {
                  capturedValue = context.effect((EffectCubit c) => c.state.messageEffect);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        // Initial build
        expect(capturedValue, null);

        cubit.showMessage('First');
        await tester.pumpAndSettle();
        expect(capturedValue, 'First');

        cubit.showMessage('Second');
        await tester.pumpAndSettle();
        expect(capturedValue, 'Second');

        cubit.showMessage('Third');
        await tester.pumpAndSettle();
        expect(capturedValue, 'Third');
      });
    });

    group('multiple effects in state', () {
      testWidgets('each effect is consumed independently', (tester) async {
        final cubit = EffectCubit();

        dynamic clearTextValue;
        String? messageValue;

        await tester.pumpWidget(
          BlocProvider<EffectCubit>.value(
            value: cubit,
            child: MaterialApp(
              home: Builder(
                builder: (context) {
                  clearTextValue = context.effect((EffectCubit c) => c.state.clearEffect);
                  messageValue = context.effect((EffectCubit c) => c.state.messageEffect);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        // Initial build
        expect(clearTextValue, false);
        expect(messageValue, null);

        // Dispatch only clear text effect
        cubit.clearText();
        await tester.pumpAndSettle();

        expect(clearTextValue, true);
        expect(messageValue, null);

        // Dispatch only message effect
        cubit.showMessage('Hello');
        await tester.pumpAndSettle();

        // clearEffect is still spent from previous state (wasn't touched)
        expect(clearTextValue, false);
        expect(messageValue, 'Hello');
      });

      testWidgets('dispatching both effects at once', (tester) async {
        final cubit = EffectCubit();

        dynamic clearTextValue;
        String? messageValue;

        await tester.pumpWidget(
          BlocProvider<EffectCubit>.value(
            value: cubit,
            child: MaterialApp(
              home: Builder(
                builder: (context) {
                  clearTextValue = context.effect((EffectCubit c) => c.state.clearEffect);
                  messageValue = context.effect((EffectCubit c) => c.state.messageEffect);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        // Dispatch both effects
        cubit.bothEffects('Both!');
        await tester.pumpAndSettle();

        expect(clearTextValue, true);
        expect(messageValue, 'Both!');
      });
    });

    group('widget rebuild behavior', () {
      testWidgets('widget rebuilds when new effect is dispatched', (tester) async {
        final cubit = EffectCubit();
        String? capturedValue;

        await tester.pumpWidget(
          BlocProvider<EffectCubit>.value(
            value: cubit,
            child: MaterialApp(
              home: Builder(
                builder: (context) {
                  capturedValue = context.effect((EffectCubit c) => c.state.messageEffect);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        expect(capturedValue, null);

        cubit.showMessage('1');
        await tester.pumpAndSettle();
        expect(capturedValue, '1');

        cubit.showMessage('2');
        await tester.pumpAndSettle();
        expect(capturedValue, '2');

        cubit.showMessage('3');
        await tester.pumpAndSettle();
        expect(capturedValue, '3');
      });

      testWidgets('widget rebuilds even with same message value', (tester) async {
        final cubit = EffectCubit();
        String? capturedValue;
        int buildCount = 0;

        await tester.pumpWidget(
          BlocProvider<EffectCubit>.value(
            value: cubit,
            child: MaterialApp(
              home: Builder(
                builder: (context) {
                  capturedValue = context.effect((EffectCubit c) => c.state.messageEffect);
                  buildCount++;
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        expect(capturedValue, null);
        final initialBuildCount = buildCount;

        // Dispatch same message multiple times - each creates a new unspent effect
        cubit.showMessage('Same');
        await tester.pumpAndSettle();
        expect(capturedValue, 'Same');

        cubit.showMessage('Same');
        await tester.pumpAndSettle();
        expect(capturedValue, 'Same');

        cubit.showMessage('Same');
        await tester.pumpAndSettle();
        expect(capturedValue, 'Same');

        // Verify widget rebuilt multiple times (at least initial + 3 dispatches)
        expect(buildCount, greaterThanOrEqualTo(initialBuildCount + 3));
      });
    });

    group('select optimization', () {
      testWidgets(
          'context.effect should NOT rebuild when non-effect state changes',
          (tester) async {
        // This test verifies that context.effect() uses select (not watch).
        // With select: only rebuilds when the Effect changes.
        // With watch: rebuilds on ANY state change (inefficient).
        //
        // If using watch, this test will FAIL because changing the counter
        // (a non-effect property) would trigger a rebuild.

        final cubit = MixedCubit();
        int buildCount = 0;
        String? capturedMessage;

        await tester.pumpWidget(
          BlocProvider<MixedCubit>.value(
            value: cubit,
            child: MaterialApp(
              home: Builder(
                builder: (context) {
                  buildCount++;
                  capturedMessage =
                      context.effect((MixedCubit c) => c.state.messageEffect);
                  return Text('builds: $buildCount');
                },
              ),
            ),
          ),
        );

        // Initial build
        expect(buildCount, 1);
        expect(capturedMessage, null);

        // Change counter (non-effect property) - should NOT trigger rebuild
        cubit.incrementCounter();
        await tester.pumpAndSettle();

        // With select: buildCount should still be 1 (no rebuild)
        // With watch: buildCount would be 2 (unnecessary rebuild) - TEST FAILS
        expect(buildCount, 1,
            reason: 'Changing non-effect state should not rebuild widget');

        // Change counter again - should still NOT trigger rebuild
        cubit.incrementCounter();
        await tester.pumpAndSettle();

        expect(buildCount, 1,
            reason: 'Changing non-effect state should not rebuild widget');

        // Now dispatch an actual effect - THIS should trigger rebuild
        cubit.showMessage('Hello');
        await tester.pumpAndSettle();

        expect(buildCount, 2, reason: 'Effect dispatch should rebuild widget');
        expect(capturedMessage, 'Hello');
      });
    });

    group('edge cases', () {
      testWidgets('empty string message', (tester) async {
        final cubit = EffectCubit();

        String? capturedValue;
        await tester.pumpWidget(
          BlocProvider<EffectCubit>.value(
            value: cubit,
            child: MaterialApp(
              home: Builder(
                builder: (context) {
                  capturedValue = context.effect((EffectCubit c) => c.state.messageEffect);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        cubit.showMessage('');
        await tester.pumpAndSettle();

        expect(capturedValue, '');
      });

      testWidgets('effect with complex type', (tester) async {
        final cubit = ComplexEffectCubit();

        List<int>? capturedValue;
        await tester.pumpWidget(
          BlocProvider<ComplexEffectCubit>.value(
            value: cubit,
            child: MaterialApp(
              home: Builder(
                builder: (context) {
                  capturedValue = context.effect((ComplexEffectCubit c) => c.state.numbersEffect);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        expect(capturedValue, null);

        cubit.setNumbers([1, 2, 3]);
        await tester.pumpAndSettle();

        expect(capturedValue, [1, 2, 3]);
      });

      testWidgets('rapid effect dispatching', (tester) async {
        final cubit = EffectCubit();
        List<String> capturedValues = [];

        await tester.pumpWidget(
          BlocProvider<EffectCubit>.value(
            value: cubit,
            child: MaterialApp(
              home: Builder(
                builder: (context) {
                  final value = context.effect((EffectCubit c) => c.state.messageEffect);
                  if (value != null) capturedValues.add(value);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        // Dispatch multiple effects rapidly
        cubit.showMessage('A');
        cubit.showMessage('B');
        cubit.showMessage('C');
        await tester.pumpAndSettle();

        // Only the last effect should be captured (previous ones were overwritten)
        expect(capturedValues, ['C']);
      });
    });
  });
}

// Test state with effects
@immutable
class EffectState {
  final Effect clearEffect;
  final Effect<String> messageEffect;

  EffectState({
    Effect? clearEffect,
    Effect<String>? messageEffect,
  })  : clearEffect = clearEffect ?? Effect.spent(),
        messageEffect = messageEffect ?? Effect.spent();

  EffectState copy({
    Effect? clearEffect,
    Effect<String>? messageEffect,
  }) =>
      EffectState(
        clearEffect: clearEffect ?? this.clearEffect,
        messageEffect: messageEffect ?? this.messageEffect,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EffectState &&
          runtimeType == other.runtimeType &&
          clearEffect == other.clearEffect &&
          messageEffect == other.messageEffect;

  @override
  int get hashCode => clearEffect.hashCode ^ messageEffect.hashCode;
}

// Test Cubit (using regular Cubit, not Superpowers)
class EffectCubit extends Cubit<EffectState> {
  EffectCubit() : super(EffectState());

  void clearText() => emit(state.copy(clearEffect: Effect()));

  void showMessage(String message) =>
      emit(state.copy(messageEffect: Effect<String>(message)));

  void bothEffects(String message) => emit(state.copy(
        clearEffect: Effect(),
        messageEffect: Effect<String>(message),
      ));

  void noOp() {
    // Force a rebuild by emitting same state structure but new effect objects
    // that are already spent
    emit(state.copy());
  }
}

// Complex effect state for edge case testing
@immutable
class ComplexEffectState {
  final Effect<List<int>> numbersEffect;

  ComplexEffectState({
    Effect<List<int>>? numbersEffect,
  }) : numbersEffect = numbersEffect ?? Effect.spent();

  ComplexEffectState copy({Effect<List<int>>? numbersEffect}) =>
      ComplexEffectState(numbersEffect: numbersEffect ?? this.numbersEffect);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComplexEffectState &&
          runtimeType == other.runtimeType &&
          numbersEffect == other.numbersEffect;

  @override
  int get hashCode => numbersEffect.hashCode;
}

// Test Cubit for complex effects (using regular Cubit, not Superpowers)
class ComplexEffectCubit extends Cubit<ComplexEffectState> {
  ComplexEffectCubit() : super(ComplexEffectState());

  void setNumbers(List<int> numbers) =>
      emit(state.copy(numbersEffect: Effect<List<int>>(numbers)));
}

// State with both effect and non-effect properties (for select vs watch test)
@immutable
class MixedState {
  final int counter;
  final Effect<String> messageEffect;

  MixedState({
    this.counter = 0,
    Effect<String>? messageEffect,
  }) : messageEffect = messageEffect ?? Effect.spent();

  MixedState copy({int? counter, Effect<String>? messageEffect}) => MixedState(
        counter: counter ?? this.counter,
        messageEffect: messageEffect ?? this.messageEffect,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MixedState &&
          runtimeType == other.runtimeType &&
          counter == other.counter &&
          messageEffect == other.messageEffect;

  @override
  int get hashCode => counter.hashCode ^ messageEffect.hashCode;
}

// Cubit that can change counter without changing effect
class MixedCubit extends Cubit<MixedState> {
  MixedCubit() : super(MixedState());

  void incrementCounter() => emit(state.copy(counter: state.counter + 1));

  void showMessage(String message) =>
      emit(state.copy(messageEffect: Effect<String>(message)));
}
