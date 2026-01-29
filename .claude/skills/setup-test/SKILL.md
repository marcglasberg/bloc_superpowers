---
name: setup-test
description: Set up proper test configuration for Cubits using bloc_superpowers with Superpowers.clear() and Completers
---

# Set Up Tests for bloc_superpowers

This skill sets up proper test configuration for Cubits using bloc_superpowers.

## What This Skill Does

Configures tests to:
- Reset Superpowers state between tests
- Properly test loading and error states
- Use Completers for async test control

## Instructions

### Step 1: Add setUp with Superpowers.clear()

**Always** call `Superpowers.clear()` in setUp to reset state between tests:

```dart
import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    Superpowers.clear();  // IMPORTANT: Reset state between tests
  });

  // ... tests
}
```

### Step 2: Test Structure

```dart
import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApi extends Mock implements Api {}

void main() {
  late UserCubit cubit;
  late MockApi mockApi;

  setUp(() {
    Superpowers.clear();  // Reset Superpowers state
    mockApi = MockApi();
    cubit = UserCubit(api: mockApi);
  });

  tearDown(() {
    cubit.close();
  });

  group('UserCubit', () {
    test('initial state is correct', () {
      expect(cubit.state, const UserState());
    });

    // ... more tests
  });
}
```

### Step 3: Test with Completers for Async Control

Use `Completer` to control when async operations complete:

```dart
test('loadUser sets loading state while fetching', () async {
  final completer = Completer<User>();

  // Mock returns a future that we control
  when(() => mockApi.getUser()).thenAnswer((_) => completer.future);

  // Start the operation
  cubit.loadUser();

  // Wait for next event loop
  await Future.delayed(Duration.zero);

  // Check loading state
  expect(Superpowers.isWaiting(UserCubit), isTrue);

  // Complete the operation
  completer.complete(User(name: 'John'));

  // Wait for completion
  await Future.delayed(Duration.zero);

  // Check final state
  expect(Superpowers.isWaiting(UserCubit), isFalse);
  expect(cubit.state.user?.name, 'John');
});
```

## Testing Loading State

### Using Static Method

```dart
test('isWaiting is true during load', () async {
  final completer = Completer<User>();
  when(() => mockApi.getUser()).thenAnswer((_) => completer.future);

  cubit.loadUser();
  await Future.delayed(Duration.zero);

  // Use static method
  expect(Superpowers.isWaiting(UserCubit), isTrue);

  completer.complete(User(name: 'John'));
  await Future.delayed(Duration.zero);

  expect(Superpowers.isWaiting(UserCubit), isFalse);
});
```

### With Composite Keys

```dart
test('per-item loading state', () async {
  final completer = Completer<void>();
  when(() => mockApi.deleteItem('123')).thenAnswer((_) => completer.future);

  cubit.deleteItem('123');
  await Future.delayed(Duration.zero);

  // Check specific item key
  expect(Superpowers.isWaiting((DeleteItem, '123')), isTrue);
  expect(Superpowers.isWaiting((DeleteItem, '456')), isFalse);

  completer.complete();
  await Future.delayed(Duration.zero);

  expect(Superpowers.isWaiting((DeleteItem, '123')), isFalse);
});
```

## Testing Error State

```dart
test('isFailed is true after error', () async {
  when(() => mockApi.getUser()).thenThrow(Exception('Network error'));

  cubit.loadUser();
  await Future.delayed(Duration.zero);

  expect(Superpowers.isFailed(UserCubit), isTrue);
  expect(Superpowers.getException(UserCubit), isA<UserException>());
});

test('error clears on retry', () async {
  // First call fails
  when(() => mockApi.getUser()).thenThrow(Exception('Network error'));
  cubit.loadUser();
  await Future.delayed(Duration.zero);
  expect(Superpowers.isFailed(UserCubit), isTrue);

  // Second call succeeds
  when(() => mockApi.getUser()).thenAnswer((_) async => User(name: 'John'));
  cubit.loadUser();
  await Future.delayed(Duration.zero);

  expect(Superpowers.isFailed(UserCubit), isFalse);
  expect(cubit.state.user?.name, 'John');
});
```

## Testing with bloc_test

```dart
blocTest<UserCubit, UserState>(
  'emits user when loadUser succeeds',
  setUp: () {
    Superpowers.clear();  // Reset in setUp
    when(() => mockApi.getUser()).thenAnswer(
      (_) async => User(name: 'John'),
    );
  },
  build: () => UserCubit(api: mockApi),
  act: (cubit) => cubit.loadUser(),
  expect: () => [
    UserState(user: User(name: 'John')),
  ],
);
```

## Testing Effects

```dart
test('effect is emitted on success', () async {
  when(() => mockApi.saveUser(any())).thenAnswer((_) async {});

  cubit.saveUser(User(name: 'John'));
  await Future.delayed(Duration.zero);

  // Check effect was emitted
  expect(cubit.state.successMessageEffect.isNotSpent, isTrue);

  // Consume the effect
  final message = cubit.state.successMessageEffect.consume();
  expect(message, 'User saved!');

  // Effect is now spent
  expect(cubit.state.successMessageEffect.isSpent, isTrue);
});
```

## Complete Test Example

```dart
import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApi extends Mock implements Api {}

void main() {
  late ProductCubit cubit;
  late MockApi mockApi;

  setUp(() {
    Superpowers.clear();
    mockApi = MockApi();
    cubit = ProductCubit(api: mockApi);
  });

  tearDown(() {
    cubit.close();
  });

  group('loadProducts', () {
    test('sets loading state while fetching', () async {
      final completer = Completer<List<Product>>();
      when(() => mockApi.getProducts()).thenAnswer((_) => completer.future);

      cubit.loadProducts();
      await Future.delayed(Duration.zero);

      expect(Superpowers.isWaiting(ProductCubit), isTrue);

      completer.complete([Product(id: '1', name: 'Widget')]);
      await Future.delayed(Duration.zero);

      expect(Superpowers.isWaiting(ProductCubit), isFalse);
      expect(cubit.state.products.length, 1);
    });

    test('sets error state on failure', () async {
      when(() => mockApi.getProducts()).thenThrow(Exception('Error'));

      cubit.loadProducts();
      await Future.delayed(Duration.zero);

      expect(Superpowers.isFailed(ProductCubit), isTrue);
    });
  });

  group('deleteProduct', () {
    test('tracks loading per product', () async {
      final completer = Completer<void>();
      when(() => mockApi.deleteProduct('1')).thenAnswer((_) => completer.future);

      cubit.deleteProduct('1');
      await Future.delayed(Duration.zero);

      expect(Superpowers.isWaiting((DeleteProduct, '1')), isTrue);
      expect(Superpowers.isWaiting((DeleteProduct, '2')), isFalse);

      completer.complete();
      await Future.delayed(Duration.zero);

      expect(Superpowers.isWaiting((DeleteProduct, '1')), isFalse);
    });
  });
}
```

## Key Points

1. **Always call `Superpowers.clear()` in setUp** - Prevents state leaking between tests
2. **Use `Completer` for async control** - Allows testing intermediate states
3. **Use `Future.delayed(Duration.zero)`** - Allows async operations to process
4. **Test both `isWaiting` and `isFailed`** - Cover loading and error states
5. **Test with composite keys** - For per-item operations

## User Preferences

Ask the user:
1. **What Cubit is being tested?**
2. **What operations need testing?** (load, save, delete)
3. **Need to test loading states?** (use Completer pattern)
4. **Need to test error states?** (mock throws)
