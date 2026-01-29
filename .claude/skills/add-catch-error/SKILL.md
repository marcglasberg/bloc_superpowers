---
name: add-catch-error
description: Add custom error handling with catchError to a mix() call for logging, error conversion, or suppression
---

# Add Error Handling with catchError

This skill adds custom error handling to a `mix()` call to suppress, rethrow, or wrap errors.

## What This Skill Does

Adds the `catchError` parameter to a `mix()` call to:
- Intercept errors before they propagate
- Log errors for debugging
- Convert technical errors to user-friendly messages
- Suppress specific errors silently

## Instructions

### Step 1: Identify the Method

Ask the user which Cubit method needs custom error handling, or identify methods that:
- May throw technical exceptions that need friendlier messages
- Need error logging
- Should silently suppress certain errors
- Have complex error handling requirements

### Step 2: Add catchError

Add `catchError` to the `mix()` call:

```dart
import 'package:bloc_superpowers/bloc_superpowers.dart';

class UserCubit extends Cubit<User> {
  UserCubit() : super(User());

  void loadData() => mix(
    key: this,
    catchError: (error, stackTrace) {
      // Handle the error
    },
    () async {
      final user = await api.loadUser();
      emit(user);
    },
  );
}
```

## Error Handling Patterns

### Log and Suppress (Silent Failure)

Error is logged but not shown to user:

```dart
void syncInBackground() => mix(
  key: this,
  catchError: (error, stackTrace) {
    logError(error, stackTrace);
    // Return normally = error suppressed
  },
  () async {
    await api.syncData();
  },
);
```

### Log and Rethrow

Error is logged and then propagated:

```dart
void loadData() => mix(
  key: this,
  catchError: (error, stackTrace) {
    logError(error, stackTrace);
    throw error;  // Rethrow preserves original stack trace
  },
  () async {
    final data = await api.getData();
    emit(data);
  },
);
```

### Wrap in UserException

Convert technical errors to user-friendly messages:

```dart
void loadData() => mix(
  key: this,
  catchError: (error, stackTrace) {
    throw UserException('Failed to load data. Please try again.')
        .addCause(error);  // Attach original error for debugging
  },
  () async {
    final data = await api.getData();
    emit(data);
  },
);
```

### Handle Specific Error Types

```dart
void loadData() => mix(
  key: this,
  catchError: (error, stackTrace) {
    if (error is NetworkException) {
      throw UserException('No internet connection');
    } else if (error is TimeoutException) {
      throw UserException('Request timed out. Please try again.');
    } else if (error is NotFoundException) {
      throw UserException('The requested item was not found.');
    } else if (error is UnauthorizedException) {
      throw UserException('Please log in to continue.');
    } else {
      // Log unexpected errors and show generic message
      logError(error, stackTrace);
      throw UserException('Something went wrong. Please try again.');
    }
  },
  () async {
    final data = await api.getData();
    emit(data);
  },
);
```

### Suppress Specific Errors

Only handle certain errors, let others propagate:

```dart
void loadData() => mix(
  key: this,
  catchError: (error, stackTrace) {
    if (error is CancelledException) {
      // Silently ignore cancellations
      return;
    }
    throw error;  // Rethrow everything else
  },
  () async {
    final data = await api.getData();
    emit(data);
  },
);
```

## Common Patterns

### API Error Translation

```dart
void fetchProducts() => mix(
  key: this,
  catchError: (error, stackTrace) {
    if (error is DioException) {
      switch (error.response?.statusCode) {
        case 401:
          throw UserException('Session expired. Please log in again.');
        case 403:
          throw UserException('You don\'t have permission to access this.');
        case 404:
          throw UserException('Products not found.');
        case 500:
          throw UserException('Server error. Please try again later.');
        default:
          throw UserException('Network error. Please check your connection.');
      }
    }
    throw UserException('Failed to load products.').addCause(error);
  },
  () async {
    final products = await api.getProducts();
    emit(state.copyWith(products: products));
  },
);
```

### Firebase Error Translation

```dart
void signIn(String email, String password) => mix(
  key: this,
  catchError: (error, stackTrace) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          throw UserException('No account found with this email.');
        case 'wrong-password':
          throw UserException('Incorrect password.');
        case 'user-disabled':
          throw UserException('This account has been disabled.');
        case 'too-many-requests':
          throw UserException('Too many attempts. Please try again later.');
        default:
          throw UserException('Sign in failed. Please try again.');
      }
    }
    throw error;
  },
  () async {
    await auth.signInWithEmailAndPassword(email, password);
    emit(state.copyWith(isAuthenticated: true));
  },
);
```

### With Logging Service

```dart
void loadData() => mix(
  key: this,
  catchError: (error, stackTrace) {
    // Log to analytics/crash reporting
    analyticsService.logError(
      error: error,
      stackTrace: stackTrace,
      context: {'action': 'loadData', 'cubit': 'UserCubit'},
    );

    // Show user-friendly message
    if (error is UserException) throw error;
    throw UserException('An error occurred').addCause(error);
  },
  () async {
    final data = await api.getData();
    emit(data);
  },
);
```

## catchError vs globalCatchError

| Feature | Scope | Use Case |
|---------|-------|----------|
| `catchError` | Single `mix()` call | Method-specific error handling |
| `globalCatchError` | All `mix()` calls | App-wide error logging/translation |

- `catchError` runs first
- If `catchError` rethrows, `globalCatchError` then processes the error
- Use `catchError` for method-specific logic
- Use `globalCatchError` for consistent app-wide behavior

## Error Flow

```
Error occurs in mix()
         ↓
    catchError runs (if defined)
         ↓
    ┌────┴────┐
    │         │
 returns   throws
    │         │
    ↓         ↓
 suppressed  globalCatchError runs
             (if defined)
                  ↓
             ┌────┴────┐
             │         │
          returns   throws
             │         │
             ↓         ↓
         suppressed  isFailed() = true
                     UserExceptionDialog shows
```

## Complete Example

```dart
class OrderCubit extends Cubit<OrderState> {
  OrderCubit() : super(const OrderState());

  void placeOrder(Order order) => mix(
    key: this,
    retry: retry(maxRetries: 2),
    catchError: (error, stackTrace) {
      // Log all errors
      logger.error('Order placement failed', error, stackTrace);

      // Translate to user-friendly messages
      if (error is InsufficientStockException) {
        throw UserException(
          'Some items are out of stock. Please review your cart.',
        );
      } else if (error is PaymentDeclinedException) {
        throw UserException(
          'Payment was declined. Please check your payment method.',
        );
      } else if (error is NetworkException) {
        throw UserException(
          'Connection lost. Please check your internet and try again.',
        );
      } else {
        throw UserException(
          'Could not place order. Please try again.',
        ).addCause(error);
      }
    },
    () async {
      final result = await api.placeOrder(order);
      emit(state.copyWith(
        currentOrder: null,
        completedOrders: [...state.completedOrders, result],
      ));
    },
  );
}
```

## User Preferences

Ask the user:
1. **What errors need special handling?** (network, auth, validation)
2. **Should errors be logged?** (for debugging/analytics)
3. **What user-friendly messages should be shown?**
4. **Should any errors be suppressed?** (background sync, optional features)
