---
name: test-error-state
description: Test isFailed() and UserException handling to verify error states work correctly
---

# Test Error State (isFailed)

This skill tests `isFailed()` and `UserException` handling in Cubit methods.

## What This Skill Does

Tests that:
- `isFailed()` returns true after operation fails
- `getException()` returns the thrown exception
- Error state clears when operation succeeds

## Instructions

### Step 1: Test Error State

```dart
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

  test('isFailed is true after error', () async {
    when(() => mockApi.getUser()).thenThrow(Exception('Network error'));

    cubit.loadUser();
    await Future.delayed(Duration.zero);

    expect(Superpowers.isFailed(UserCubit), isTrue);
  });
}
```

### Step 2: Test Exception Retrieval

```dart
test('getException returns the thrown exception', () async {
  when(() => mockApi.getUser()).thenThrow(
    UserException('User not found'),
  );

  cubit.loadUser();
  await Future.delayed(Duration.zero);

  expect(Superpowers.isFailed(UserCubit), isTrue);

  final exception = Superpowers.getException(UserCubit);
  expect(exception, isA<UserException>());
  expect(exception?.message, 'User not found');
});
```

### Step 3: Test Error Clears on Success

```dart
test('error clears when operation succeeds', () async {
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
  expect(Superpowers.getException(UserCubit), isNull);
});
```

## Testing Different Error Types

### UserException

```dart
test('UserException is preserved', () async {
  when(() => mockApi.getUser()).thenThrow(
    UserException('Please check your connection'),
  );

  cubit.loadUser();
  await Future.delayed(Duration.zero);

  final exception = Superpowers.getException(UserCubit);
  expect(exception?.message, 'Please check your connection');
});
```

### Exception Converted by catchError

```dart
test('exception is converted by catchError', () async {
  // Cubit has catchError that converts exceptions
  when(() => mockApi.getUser()).thenThrow(SocketException('No internet'));

  cubit.loadUser();
  await Future.delayed(Duration.zero);

  final exception = Superpowers.getException(UserCubit);
  // catchError converted it to UserException
  expect(exception?.message, contains('connection'));
});
```

### With Composite Keys

```dart
test('error state with composite key', () async {
  when(() => mockApi.deleteItem('123')).thenThrow(
    UserException('Cannot delete item'),
  );

  cubit.deleteItem('123');
  await Future.delayed(Duration.zero);

  // Error is tracked per item
  expect(Superpowers.isFailed((DeleteItem, '123')), isTrue);
  expect(Superpowers.isFailed((DeleteItem, '456')), isFalse);

  final exception = Superpowers.getException((DeleteItem, '123'));
  expect(exception?.message, 'Cannot delete item');
});
```

## Testing Error Recovery

```dart
test('manual clearException works', () async {
  when(() => mockApi.getUser()).thenThrow(Exception('Error'));

  cubit.loadUser();
  await Future.delayed(Duration.zero);

  expect(Superpowers.isFailed(UserCubit), isTrue);

  // Manually clear the exception
  Superpowers.clearException(UserCubit);

  expect(Superpowers.isFailed(UserCubit), isFalse);
  expect(Superpowers.getException(UserCubit), isNull);
});
```

## Testing with Retry

```dart
test('error only set after all retries exhausted', () async {
  var callCount = 0;
  when(() => mockApi.getUser()).thenAnswer((_) {
    callCount++;
    throw Exception('Retry $callCount');
  });

  cubit.loadUserWithRetry();  // mix with retry: retry(maxRetries: 2)
  await Future.delayed(const Duration(seconds: 5));  // Wait for retries

  expect(Superpowers.isFailed(UserCubit), isTrue);
  expect(callCount, 3);  // Initial + 2 retries
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

  group('error state', () {
    test('isFailed is true after error', () async {
      when(() => mockApi.getProducts()).thenThrow(Exception('Error'));

      cubit.loadProducts();
      await Future.delayed(Duration.zero);

      expect(Superpowers.isFailed(ProductCubit), isTrue);
      expect(Superpowers.isWaiting(ProductCubit), isFalse);
    });

    test('getException returns UserException', () async {
      when(() => mockApi.getProducts()).thenThrow(
        UserException('Products not available'),
      );

      cubit.loadProducts();
      await Future.delayed(Duration.zero);

      final exception = Superpowers.getException(ProductCubit);
      expect(exception, isA<UserException>());
      expect(exception?.message, 'Products not available');
    });

    test('error clears on successful retry', () async {
      // First fails
      when(() => mockApi.getProducts()).thenThrow(Exception('Error'));
      cubit.loadProducts();
      await Future.delayed(Duration.zero);
      expect(Superpowers.isFailed(ProductCubit), isTrue);

      // Then succeeds
      when(() => mockApi.getProducts()).thenAnswer(
        (_) async => [Product(id: '1', name: 'Widget')],
      );
      cubit.loadProducts();
      await Future.delayed(Duration.zero);

      expect(Superpowers.isFailed(ProductCubit), isFalse);
      expect(cubit.state.products.length, 1);
    });

    test('per-item error state', () async {
      when(() => mockApi.deleteProduct('1')).thenThrow(
        UserException('Cannot delete'),
      );

      cubit.deleteProduct('1');
      await Future.delayed(Duration.zero);

      expect(Superpowers.isFailed((DeleteProduct, '1')), isTrue);
      expect(Superpowers.isFailed((DeleteProduct, '2')), isFalse);

      final exception = Superpowers.getException((DeleteProduct, '1'));
      expect(exception?.message, 'Cannot delete');
    });

    test('clearException manually clears error', () async {
      when(() => mockApi.getProducts()).thenThrow(Exception('Error'));

      cubit.loadProducts();
      await Future.delayed(Duration.zero);
      expect(Superpowers.isFailed(ProductCubit), isTrue);

      Superpowers.clearException(ProductCubit);

      expect(Superpowers.isFailed(ProductCubit), isFalse);
      expect(Superpowers.getException(ProductCubit), isNull);
    });
  });
}
```

## Key Points

1. **Use `Superpowers.isFailed(key)`** to check error state
2. **Use `Superpowers.getException(key)`** to get the exception
3. **Use `Superpowers.clearException(key)`** to manually clear
4. **Error clears automatically** when operation succeeds
5. **Match the key exactly** as used in the Cubit's `mix()` call
6. **Reset with `Superpowers.clear()`** in setUp
