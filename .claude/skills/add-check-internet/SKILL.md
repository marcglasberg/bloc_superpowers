---
name: add-check-internet
description: Add internet connectivity checking before executing a Cubit method with optional retry
---

# Add Internet Connectivity Check

This skill adds internet connectivity checking before executing a Cubit method.

## What This Skill Does

Adds the `checkInternet` parameter to a `mix()` call to:
- Check device internet connectivity before running the method
- Abort execution if no internet is available
- Optionally show an error dialog or fail silently
- Combine with retry for persistent loading

## Instructions

### Step 1: Identify the Method

Ask the user which Cubit method needs internet checking, or identify methods that:
- Make network/API calls
- Require internet connectivity to function
- Should not attempt execution without connectivity

### Step 2: Add Basic Internet Check

Add `checkInternet: checkInternet` to the `mix()` call:

```dart
import 'package:bloc_superpowers/bloc_superpowers.dart';

class UserCubit extends Cubit<User> {
  UserCubit() : super(User());

  void loadData() => mix(
    key: this,
    checkInternet: checkInternet,  // Add this line
    () async {
      final user = await api.loadUser();
      emit(user);
    },
  );
}
```

### Step 3: Understand Default Behavior

When internet is unavailable with default settings:
1. Method does **not** execute
2. Cubit enters failed state (`context.isFailed()` returns true)
3. `ConnectionException` is thrown with message "No internet connection"
4. `UserExceptionDialog` shows the error (if configured)

**Note:** This only checks device connectivity, not whether your specific server is reachable.

## Configuration Options

### Default Parameters

```dart
checkInternet(
  abortSilently: false,    // If true, don't throw exception
  ifOpenDialog: true,      // If true, show error dialog
  maxRetryDelay: 1.sec,    // Recheck interval when combined with retry
)
```

### Silent Abort (No Error)

For background operations that should quietly skip when offline:

```dart
void syncInBackground() => mix(
  key: this,
  checkInternet: checkInternet(abortSilently: true),
  () async {
    await api.syncData();
  },
);
```

The method returns immediately without executing or throwing. No error dialog appears.

### Manual Error Handling (No Dialog)

To handle the error in your widget instead of showing a dialog:

```dart
void loadData() => mix(
  key: this,
  checkInternet: checkInternet(ifOpenDialog: false),
  () async {
    final data = await api.getData();
    emit(data);
  },
);
```

Then in the widget:

```dart
Widget build(BuildContext context) {
  if (context.isFailed(UserCubit)) {
    return Column(
      children: [
        const Text('No internet connection'),
        ElevatedButton(
          onPressed: () => context.read<UserCubit>().loadData(),
          child: const Text('Retry'),
        ),
      ],
    );
  }
  // ... rest of widget
}
```

### Retry Until Internet Returns

For critical data that must load eventually:

```dart
void loadInitialData() => mix(
  key: this,
  checkInternet: checkInternet,
  retry: retry.unlimited,
  () async {
    final data = await api.getInitialData();
    emit(data);
  },
);
```

Internet connectivity is rechecked before each retry attempt.

### Custom Retry Delay

Control how often to recheck connectivity:

```dart
void loadData() => mix(
  key: this,
  checkInternet: checkInternet(maxRetryDelay: 500.millis),
  retry: retry.unlimited(maxDelay: 5.sec),
  () async {
    final data = await api.getData();
    emit(data);
  },
);
```

## Common Patterns

### Standard API Call with Internet Check

```dart
void fetchProducts() => mix(
  key: this,
  checkInternet: checkInternet,
  () async {
    final products = await api.getProducts();
    emit(state.copyWith(products: products));
  },
);
```

### Background Sync (Silent)

```dart
void syncData() => mix(
  key: this,
  checkInternet: checkInternet(abortSilently: true),
  () async {
    await api.sync();
  },
);
```

### Critical Startup Data (Persistent)

```dart
void loadAppConfig() => mix(
  key: this,
  checkInternet: checkInternet(maxRetryDelay: 1.sec),
  retry: retry.unlimited,
  () async {
    final config = await api.getConfig();
    emit(config);
  },
);
```

### Internet Check + Retry + Error Handling

```dart
void loadData() => mix(
  key: this,
  checkInternet: checkInternet,
  retry: retry(maxRetries: 3),
  catchError: (error, stackTrace) {
    if (error is ConnectionException) {
      throw UserException('Please check your internet connection');
    }
    throw UserException('Failed to load data. Please try again.');
  },
  () async {
    final data = await api.getData();
    emit(data);
  },
);
```

## Behavior Summary

| Configuration | On No Internet |
|--------------|----------------|
| `checkInternet` (default) | Throws `ConnectionException`, shows dialog |
| `checkInternet(abortSilently: true)` | Returns silently, no error |
| `checkInternet(ifOpenDialog: false)` | Throws `ConnectionException`, no dialog |
| `checkInternet` + `retry.unlimited` | Keeps retrying until internet returns |

## User Preferences

Ask the user:
1. **Should it fail silently?** (for background operations)
2. **Show error dialog or handle manually?**
3. **Retry until internet returns?** (for critical data)
