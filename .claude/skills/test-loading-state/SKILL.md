---
name: test-loading-state
description: Test isWaiting() behavior using Completers to verify loading states work correctly
---

# Test Loading State (isWaiting)

This skill tests `isWaiting()` behavior in Cubit methods.

## What This Skill Does

Tests that:
- `isWaiting()` returns true while operation is in progress
- `isWaiting()` returns false after operation completes
- Loading state works with composite keys

## Instructions

### Step 1: Set Up Test with Completer

Use `Completer` to control when async operations complete:

```dart
import 'dart:async';
import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  late UserCubit cubit;
  late MockApi mockApi;

  setUp(() {
    Superpowers.clear();
    mockApi = MockApi();
    cubit = UserCubit(api: mockApi);
  });

  tearDown(() => cubit.close());

  test('isWaiting is true during operation', () async {
    // Create a completer to control when the future completes
    final completer = Completer<User>();

    // Mock returns a future we control
    when(() => mockApi.getUser()).thenAnswer((_) => completer.future);

    // Start the operation
    cubit.loadUser();

    // Allow async to process
    await Future.delayed(Duration.zero);

    // Verify loading state is true
    expect(Superpowers.isWaiting(UserCubit), isTrue);

    // Complete the operation
    completer.complete(User(name: 'John'));

    // Allow async to process
    await Future.delayed(Duration.zero);

    // Verify loading state is false
    expect(Superpowers.isWaiting(UserCubit), isFalse);
  });
}
```

### Step 2: Test Pattern

```dart
test('loading state pattern', () async {
  final completer = Completer<Data>();
  when(() => mockApi.getData()).thenAnswer((_) => completer.future);

  // 1. Start operation
  cubit.loadData();
  await Future.delayed(Duration.zero);

  // 2. Assert loading is true
  expect(Superpowers.isWaiting(key), isTrue);

  // 3. Complete operation
  completer.complete(data);
  await Future.delayed(Duration.zero);

  // 4. Assert loading is false
  expect(Superpowers.isWaiting(key), isFalse);
});
```

## Testing Different Key Types

### Type Key

```dart
// Cubit uses: key: this (becomes UserCubit)
test('loading with type key', () async {
  final completer = Completer<User>();
  when(() => mockApi.getUser()).thenAnswer((_) => completer.future);

  cubit.loadUser();
  await Future.delayed(Duration.zero);

  expect(Superpowers.isWaiting(UserCubit), isTrue);

  completer.complete(User(name: 'John'));
  await Future.delayed(Duration.zero);

  expect(Superpowers.isWaiting(UserCubit), isFalse);
});
```

### Enum Key

```dart
// Cubit uses: key: UserAction.load
test('loading with enum key', () async {
  final completer = Completer<User>();
  when(() => mockApi.getUser()).thenAnswer((_) => completer.future);

  cubit.loadUser();
  await Future.delayed(Duration.zero);

  expect(Superpowers.isWaiting(UserAction.load), isTrue);

  completer.complete(User(name: 'John'));
  await Future.delayed(Duration.zero);

  expect(Superpowers.isWaiting(UserAction.load), isFalse);
});
```

### Composite Key (Record)

```dart
// Cubit uses: key: (DeleteItem, itemId)
test('loading with composite key', () async {
  final completer = Completer<void>();
  when(() => mockApi.deleteItem('123')).thenAnswer((_) => completer.future);

  cubit.deleteItem('123');
  await Future.delayed(Duration.zero);

  // Only this specific item is loading
  expect(Superpowers.isWaiting((DeleteItem, '123')), isTrue);
  expect(Superpowers.isWaiting((DeleteItem, '456')), isFalse);

  completer.complete();
  await Future.delayed(Duration.zero);

  expect(Superpowers.isWaiting((DeleteItem, '123')), isFalse);
});
```

## Testing Multiple Operations

```dart
test('multiple operations have independent loading states', () async {
  final loadCompleter = Completer<User>();
  final saveCompleter = Completer<void>();

  when(() => mockApi.getUser()).thenAnswer((_) => loadCompleter.future);
  when(() => mockApi.saveUser(any())).thenAnswer((_) => saveCompleter.future);

  // Start both operations
  cubit.loadUser();
  cubit.saveUser(User(name: 'John'));
  await Future.delayed(Duration.zero);

  // Both are loading
  expect(Superpowers.isWaiting(UserAction.load), isTrue);
  expect(Superpowers.isWaiting(UserAction.save), isTrue);

  // Complete load
  loadCompleter.complete(User(name: 'John'));
  await Future.delayed(Duration.zero);

  // Load done, save still loading
  expect(Superpowers.isWaiting(UserAction.load), isFalse);
  expect(Superpowers.isWaiting(UserAction.save), isTrue);

  // Complete save
  saveCompleter.complete();
  await Future.delayed(Duration.zero);

  // Both done
  expect(Superpowers.isWaiting(UserAction.load), isFalse);
  expect(Superpowers.isWaiting(UserAction.save), isFalse);
});
```

## Testing Loading Clears on Error

```dart
test('loading state clears on error', () async {
  when(() => mockApi.getUser()).thenThrow(Exception('Error'));

  cubit.loadUser();
  await Future.delayed(Duration.zero);

  // Loading should be false (operation completed, with error)
  expect(Superpowers.isWaiting(UserCubit), isFalse);
  // Error state should be true
  expect(Superpowers.isFailed(UserCubit), isTrue);
});
```

## Complete Test File

```dart
import 'dart:async';
import 'package:bloc_superpowers/bloc_superpowers.dart';
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

  tearDown(() => cubit.close());

  group('loading state', () {
    test('isWaiting is true while loading products', () async {
      final completer = Completer<List<Product>>();
      when(() => mockApi.getProducts()).thenAnswer((_) => completer.future);

      cubit.loadProducts();
      await Future.delayed(Duration.zero);

      expect(Superpowers.isWaiting(ProductCubit), isTrue);

      completer.complete([Product(id: '1', name: 'Widget')]);
      await Future.delayed(Duration.zero);

      expect(Superpowers.isWaiting(ProductCubit), isFalse);
    });

    test('per-item loading for delete', () async {
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

    test('loading clears on error', () async {
      when(() => mockApi.getProducts()).thenThrow(Exception('Error'));

      cubit.loadProducts();
      await Future.delayed(Duration.zero);

      expect(Superpowers.isWaiting(ProductCubit), isFalse);
      expect(Superpowers.isFailed(ProductCubit), isTrue);
    });
  });
}
```

## Key Points

1. **Use `Completer`** to control async timing
2. **Use `Future.delayed(Duration.zero)`** to let async process
3. **Use `Superpowers.isWaiting(key)`** static method in tests
4. **Match the key exactly** as used in the Cubit's `mix()` call
5. **Reset with `Superpowers.clear()`** in setUp
