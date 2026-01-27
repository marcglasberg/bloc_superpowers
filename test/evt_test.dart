import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Effect', () {
    group('construction', () {
      test('Effect() creates an unspent effect', () {
        final effect = Effect();
        expect(effect.isSpent, false);
        expect(effect.isNotSpent, true);
      });

      test('Effect(value) creates an unspent effect with value', () {
        final effect = Effect<String>('hello');
        expect(effect.isSpent, false);
        expect(effect.isNotSpent, true);
      });

      test('Effect.spent() creates a spent effect', () {
        final effect = Effect.spent();
        expect(effect.isSpent, true);
        expect(effect.isNotSpent, false);
      });

      test('Effect<T>.spent() creates a spent typed effect', () {
        final effect = Effect<String>.spent();
        expect(effect.isSpent, true);
        expect(effect.isNotSpent, false);
      });

      test('Effect<dynamic>(value) creates effect with explicit dynamic type', () {
        final effect = Effect<dynamic>('hello');
        expect(effect.isSpent, false);
        expect(effect.state, 'hello');
        expect(effect.consume(), 'hello');
      });

      test('Effect<dynamic>.spent() creates spent dynamic effect', () {
        final effect = Effect<dynamic>.spent();
        expect(effect.isSpent, true);
        // When T == dynamic and _value == null, state returns boolean (false for spent)
        expect(effect.state, false);
      });

      test('Effect<Object>(value) works correctly', () {
        final effect = Effect<Object>('test');
        expect(effect.state, 'test');
        expect(effect.consume(), 'test');
      });

      test('Effect<bool>() without value defaults to true', () {
        // This test would have FAILED before the fix.
        // Previously, Effect<bool>() would have _value = null and consume() returned null.
        final effect = Effect<bool>();
        expect(effect.isSpent, false);
        expect(effect.state, true);
        expect(effect.consume(), true);
      });

      test('Effect<bool>(true) works correctly', () {
        final effect = Effect<bool>(true);
        expect(effect.state, true);
        expect(effect.consume(), true);
      });

      test('Effect<bool>(false) works correctly', () {
        final effect = Effect<bool>(false);
        expect(effect.state, false);
        expect(effect.consume(), false);
      });

      test('Effect<bool>.spent() returns null on consume', () {
        final effect = Effect<bool>.spent();
        expect(effect.isSpent, true);
        expect(effect.state, null);
        expect(effect.consume(), null);
      });

      test('Effect<bool>() second consume returns null', () {
        // After consuming, it should return null (not false)
        final effect = Effect<bool>();
        expect(effect.consume(), true);
        expect(effect.consume(), null);
      });
    });

    group('consume() - value-less effects', () {
      test('consume() returns true for unspent effect', () {
        final effect = Effect();
        expect(effect.consume(), true);
      });

      test('consume() returns false for spent effect', () {
        final effect = Effect.spent();
        expect(effect.consume(), false);
      });

      test('consume() marks effect as spent', () {
        final effect = Effect();
        expect(effect.isSpent, false);
        effect.consume();
        expect(effect.isSpent, true);
      });

      test('consume() returns false on second call', () {
        final effect = Effect();
        expect(effect.consume(), true);
        expect(effect.consume(), false);
        expect(effect.consume(), false);
      });
    });

    group('consume() - typed effects', () {
      test('consume() returns value for unspent effect', () {
        final effect = Effect<String>('hello');
        expect(effect.consume(), 'hello');
      });

      test('consume() returns null for spent effect', () {
        final effect = Effect<String>.spent();
        expect(effect.consume(), null);
      });

      test('consume() marks effect as spent', () {
        final effect = Effect<String>('hello');
        expect(effect.isSpent, false);
        effect.consume();
        expect(effect.isSpent, true);
      });

      test('consume() returns null on second call', () {
        final effect = Effect<String>('hello');
        expect(effect.consume(), 'hello');
        expect(effect.consume(), null);
        expect(effect.consume(), null);
      });

      test('consume() works with null value', () {
        final effect = Effect<String?>(null);
        expect(effect.isSpent, false);
        // For typed effects with null value, consume returns null but marks as spent
        expect(effect.consume(), null);
        expect(effect.isSpent, true);
      });

      test('consume() works with various types', () {
        expect(Effect<int>(42).consume(), 42);
        expect(Effect<double>(3.14).consume(), 3.14);
        expect(Effect<bool>(true).consume(), true);
        expect(Effect<List<int>>([1, 2, 3]).consume(), [1, 2, 3]);
        expect(Effect<Map<String, int>>({'a': 1}).consume(), {'a': 1});
      });

      test('consume() with zero value', () {
        final effect = Effect<int>(0);
        expect(effect.consume(), 0);
        expect(effect.consume(), null);
      });

      test('consume() with empty string', () {
        final effect = Effect<String>('');
        expect(effect.consume(), '');
        expect(effect.consume(), null);
      });

      test('consume() with false boolean', () {
        final effect = Effect<bool>(false);
        expect(effect.consume(), false);
        expect(effect.consume(), null);
      });

      test('consume() with empty list', () {
        final effect = Effect<List<int>>([]);
        expect(effect.consume(), <int>[]);
        expect(effect.consume(), null);
      });
    });

    group('state getter', () {
      test('state returns true for unspent value-less effect', () {
        final effect = Effect();
        expect(effect.state, true);
      });

      test('state returns false for spent value-less effect', () {
        final effect = Effect.spent();
        expect(effect.state, false);
      });

      test('state returns value for unspent typed effect', () {
        final effect = Effect<String>('hello');
        expect(effect.state, 'hello');
      });

      test('state returns null for spent typed effect', () {
        final effect = Effect<String>.spent();
        expect(effect.state, null);
      });

      test('state does NOT consume the effect', () {
        final effect = Effect<String>('hello');
        expect(effect.state, 'hello');
        expect(effect.state, 'hello');
        expect(effect.isSpent, false);
        expect(effect.state, 'hello');
      });

      test('state can be called multiple times without affecting consume', () {
        final effect = Effect<int>(42);
        expect(effect.state, 42);
        expect(effect.state, 42);
        expect(effect.consume(), 42);
        expect(effect.state, null);
      });

      test('state for typed effect with null value (unspent)', () {
        final effect = Effect<String?>(null);
        expect(effect.isSpent, false);
        expect(effect.state, null); // null value but not spent
      });

      test('state for Effect<dynamic> with value', () {
        final effect = Effect<dynamic>('hello');
        expect(effect.state, 'hello');
      });

      test('state for Effect<dynamic> with null value', () {
        // When T is dynamic and value is null, behaves like value-less
        final effect = Effect<dynamic>(null);
        expect(effect.state, true); // unspent value-less behavior
      });

      test('state after consume for value-less effect', () {
        final effect = Effect();
        expect(effect.state, true);
        effect.consume();
        expect(effect.state, false);
      });

      test('state for zero and falsy values', () {
        expect(Effect<int>(0).state, 0);
        expect(Effect<String>('').state, '');
        expect(Effect<bool>(false).state, false);
        expect(Effect<double>(0.0).state, 0.0);
      });
    });

    group('equality', () {
      test('spent effects are equal', () {
        final effect1 = Effect.spent();
        final effect2 = Effect.spent();
        expect(effect1 == effect2, true);
      });

      test('spent typed effects are equal', () {
        final effect1 = Effect<String>.spent();
        final effect2 = Effect<String>.spent();
        expect(effect1 == effect2, true);
      });

      test('unspent effects are NOT equal (even with same value)', () {
        final effect1 = Effect<String>('hello');
        final effect2 = Effect<String>('hello');
        expect(effect1 == effect2, false);
      });

      test('unspent effect is NOT equal to spent effect', () {
        final effect1 = Effect<String>('hello');
        final effect2 = Effect<String>.spent();
        expect(effect1 == effect2, false);
      });

      test('spent effect is NOT equal to unspent effect', () {
        final effect1 = Effect<String>.spent();
        final effect2 = Effect<String>('hello');
        expect(effect1 == effect2, false);
      });

      test('effect becomes equal to spent after consume', () {
        final effect1 = Effect<String>('hello');
        final effect2 = Effect<String>.spent();

        expect(effect1 == effect2, false);
        effect1.consume();
        expect(effect1 == effect2, true);
      });

      test('two consumed effects become equal', () {
        final effect1 = Effect<String>('hello');
        final effect2 = Effect<String>('world');

        expect(effect1 == effect2, false);
        effect1.consume();
        expect(effect1 == effect2, false);
        effect2.consume();
        expect(effect1 == effect2, true);
      });

      test('identical effects are equal', () {
        final effect = Effect<String>('hello');
        expect(effect == effect, true);
      });

      test('different runtime types are not equal', () {
        final effect1 = Effect<String>.spent();
        final effect2 = Effect<int>.spent();
        expect(effect1 == effect2, false);
      });

      test('Effect is not equal to non-Effect', () {
        final effect = Effect.spent();
        expect(effect == 'not an effect', false);
        expect(effect == 42, false);
        expect(effect == null, false);
      });

      test('value-less unspent effects are NOT equal', () {
        final effect1 = Effect();
        final effect2 = Effect();
        expect(effect1 == effect2, false);
      });

      test(
          'value-less spent and typed spent are NOT equal (different runtimeType)',
          () {
        final effect1 = Effect.spent();
        final effect2 = Effect<String>.spent();
        expect(effect1 == effect2, false);
      });

      test('Effect<dynamic>.spent() vs Effect.spent()', () {
        final effect1 = Effect<dynamic>.spent();
        final effect2 = Effect.spent();
        // Both should have same runtimeType since Effect() defaults to Effect<dynamic>
        expect(effect1 == effect2, true);
      });

      test('unspent identical to self', () {
        final effect = Effect();
        expect(identical(effect, effect), true);
        expect(effect == effect, true);
      });

      test('equality is symmetric for spent effects', () {
        final effect1 = Effect<String>.spent();
        final effect2 = Effect<String>.spent();
        expect(effect1 == effect2, true);
        expect(effect2 == effect1, true);
      });

      test('equality after one is consumed', () {
        final effect1 = Effect<String>('a');
        final effect2 = Effect<String>('b');
        effect1.consume();
        // effect1 spent, effect2 unspent - not equal
        expect(effect1 == effect2, false);
        expect(effect2 == effect1, false);
      });
    });

    group('hashCode', () {
      test('all effects have same hashCode (for mutable consistency)', () {
        expect(Effect().hashCode, 0);
        expect(Effect.spent().hashCode, 0);
        expect(Effect<String>('hello').hashCode, 0);
        expect(Effect<String>.spent().hashCode, 0);
      });

      test('hashCode remains constant after consume', () {
        final effect = Effect<String>('hello');
        final hashBefore = effect.hashCode;
        effect.consume();
        expect(effect.hashCode, hashBefore);
      });

      test('hashCode is same for all effect types', () {
        expect(Effect<int>(42).hashCode, Effect<String>('x').hashCode);
        expect(Effect().hashCode, Effect<bool>(true).hashCode);
      });

      test('effects can be used in Set (though not recommended)', () {
        // All effects have same hashCode, so Set behavior is based on equality
        final set = <Effect<String>>{};
        final effect1 = Effect<String>.spent();
        final effect2 = Effect<String>.spent();
        set.add(effect1);
        set.add(effect2);
        // Both spent, so equal, so only one in set
        expect(set.length, 1);

        final effect3 = Effect<String>('hello');
        set.add(effect3);
        // Unspent, not equal to spent, so added
        expect(set.length, 2);
      });
    });

    group('toString', () {
      test('unspent value-less effect', () {
        final effect = Effect();
        expect(effect.toString(), 'Effect(true)');
      });

      test('spent value-less effect', () {
        final effect = Effect.spent();
        expect(effect.toString(), 'Effect(false, spent)');
      });

      test('unspent typed effect', () {
        final effect = Effect<String>('hello');
        expect(effect.toString(), 'Effect(hello)');
      });

      test('spent typed effect', () {
        final effect = Effect<String>.spent();
        expect(effect.toString(), 'Effect(null, spent)');
      });

      test('consumed typed effect', () {
        final effect = Effect<String>('hello');
        effect.consume();
        expect(effect.toString(), 'Effect(null, spent)');
      });

      test('toString with numeric value', () {
        expect(Effect<int>(42).toString(), 'Effect(42)');
        expect(Effect<double>(3.14).toString(), 'Effect(3.14)');
      });

      test('toString with boolean value', () {
        expect(Effect<bool>(true).toString(), 'Effect(true)');
        expect(Effect<bool>(false).toString(), 'Effect(false)');
      });

      test('toString with list value', () {
        expect(Effect<List<int>>([1, 2]).toString(), 'Effect([1, 2])');
      });

      test('toString with null typed value', () {
        final effect = Effect<String?>(null);
        expect(effect.toString(), 'Effect(null)');
        effect.consume();
        expect(effect.toString(), 'Effect(null, spent)');
      });

      test('toString consumed value-less effect', () {
        final effect = Effect();
        effect.consume();
        expect(effect.toString(), 'Effect(false, spent)');
      });
    });

    group('isNotSpent', () {
      test('isNotSpent is inverse of isSpent for unspent', () {
        final effect = Effect<String>('hello');
        expect(effect.isSpent, false);
        expect(effect.isNotSpent, true);
        expect(effect.isSpent, !effect.isNotSpent);
      });

      test('isNotSpent is inverse of isSpent for spent', () {
        final effect = Effect<String>.spent();
        expect(effect.isSpent, true);
        expect(effect.isNotSpent, false);
        expect(effect.isSpent, !effect.isNotSpent);
      });

      test('isNotSpent changes after consume', () {
        final effect = Effect<String>('hello');
        expect(effect.isNotSpent, true);
        effect.consume();
        expect(effect.isNotSpent, false);
      });
    });
  });

  group('Static helpers', () {
    group('Effect.consumeFrom', () {
      test('consumes from first effect if not spent', () {
        final effect1 = Effect<String>('first');
        final effect2 = Effect<String>('second');

        expect(Effect.consumeFrom(effect1, effect2), 'first');
        expect(effect1.isSpent, true);
        expect(effect2.isSpent, false);
      });

      test('consumes from second effect if first is spent', () {
        final effect1 = Effect<String>.spent();
        final effect2 = Effect<String>('second');

        expect(Effect.consumeFrom(effect1, effect2), 'second');
        expect(effect2.isSpent, true);
      });

      test('returns null if both spent', () {
        final effect1 = Effect<String>.spent();
        final effect2 = Effect<String>.spent();

        expect(Effect.consumeFrom(effect1, effect2), null);
      });

      test('example from documentation', () {
        final localMessageEffect = Effect<String>.spent();
        final remoteMessageEffect = Effect<String>('Remote message');

        final message = Effect.consumeFrom(localMessageEffect, remoteMessageEffect);
        expect(message, 'Remote message');
      });

      test('consumeFrom with both having values consumes only first', () {
        final effect1 = Effect<String>('first');
        final effect2 = Effect<String>('second');

        expect(Effect.consumeFrom(effect1, effect2), 'first');
        expect(effect1.isSpent, true);
        expect(effect2.isSpent, false);

        // Second call consumes from second
        expect(Effect.consumeFrom(effect1, effect2), 'second');
        expect(effect2.isSpent, true);
      });

      test('consumeFrom with first having null value', () {
        final effect1 = Effect<String?>(null);
        final effect2 = Effect<String>('second');

        // First returns null, ??= tries second which returns 'second'
        expect(Effect.consumeFrom(effect1, effect2), 'second');
        expect(effect1.isSpent, true);
        expect(effect2.isSpent, true);
      });

      test('consumeFrom with value-less effects', () {
        final effect1 = Effect();
        final effect2 = Effect();

        // First call: effect1 returns true
        expect(Effect.consumeFrom(effect1, effect2), true);
        // Second call: effect1 returns false (not null!), so ??= doesn't try effect2
        expect(Effect.consumeFrom(effect1, effect2), false);
        // effect2 was never consumed because false != null
        expect(effect2.isSpent, false);
      });
    });
  });

  group('Usage patterns', () {
    test('typical widget pattern - value-less effect', () {
      // Simulate state with effect
      var clearEffect = Effect.spent();

      // Widget build - no action (spent)
      expect(clearEffect.consume(), false);

      // Action dispatches new effect
      clearEffect = Effect();

      // Widget rebuild - should clear text
      expect(clearEffect.consume(), true);

      // Subsequent rebuilds - no action
      expect(clearEffect.consume(), false);
    });

    test('typical widget pattern - Effect<bool> effect (fixed behavior)', () {
      // This test demonstrates the fix for Effect<bool>().
      // Previously, using Effect<bool>() would fail because consume() returned null.
      // Now it correctly returns true.

      // Simulate state with typed bool effect
      var clearEffect = Effect<bool>.spent();

      // Widget build - no action (spent)
      expect(clearEffect.consume(), null);

      // Action dispatches new effect using Effect<bool>() - this used to fail!
      clearEffect = Effect<bool>();

      // Widget rebuild - should detect effect and clear text
      // Before fix: consume() returned null, so (clearText == true) was false
      // After fix: consume() returns true, so (clearText == true) is true
      final clearText = clearEffect.consume();
      expect(clearText, true);
      expect(clearText == true, true); // This is the actual widget check

      // Subsequent rebuilds - no action
      expect(clearEffect.consume(), null);
    });

    test('typical widget pattern - typed effect', () {
      // Simulate state with effect
      var messageEffect = Effect<String>.spent();

      // Widget build - no message
      expect(messageEffect.consume(), null);

      // Action dispatches new effect
      messageEffect = Effect<String>('Hello World');

      // Widget rebuild - should show message
      expect(messageEffect.consume(), 'Hello World');

      // Subsequent rebuilds - no message
      expect(messageEffect.consume(), null);
    });

    test('state equality for Bloc rebuild detection', () {
      // Initial state with spent effect
      final state1Effect = Effect<String>.spent();

      // Same state (no new effect) - should be equal (no rebuild)
      final state2Effect = Effect<String>.spent();
      expect(state1Effect == state2Effect, true);

      // New effect dispatched - should NOT be equal (triggers rebuild)
      final state3Effect = Effect<String>('new message');
      expect(state1Effect == state3Effect, false);

      // After consume, back to "empty" state - should be equal
      state3Effect.consume();
      expect(state1Effect == state3Effect, true);
    });

    test('effect in immutable state class pattern', () {
      // Simulating an immutable state class
      final state1 = _TestState(counter: 0, messageEffect: Effect.spent());

      // State with new effect
      final state2 = state1.copyWith(messageEffect: Effect<String>('Hello'));

      // Counter same, but effect different - states should differ
      expect(state1.counter, state2.counter);
      expect(state1.messageEffect == state2.messageEffect, false);

      // Consume the effect
      final message = state2.messageEffect.consume();
      expect(message, 'Hello');

      // Now effects are both spent - should be equal
      expect(state1.messageEffect == state2.messageEffect, true);
    });
  });
}

/// Test state class for usage pattern tests
class _TestState {
  final int counter;
  final Effect<String> messageEffect;

  _TestState({
    required this.counter,
    Effect<String>? messageEffect,
  }) : messageEffect = messageEffect ?? Effect.spent();

  _TestState copyWith({
    int? counter,
    Effect<String>? messageEffect,
  }) {
    return _TestState(
      counter: counter ?? this.counter,
      messageEffect: messageEffect ?? this.messageEffect,
    );
  }
}
