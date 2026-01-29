---
name: add-retry
description: Add automatic retry logic with exponential backoff to a Cubit method for transient failures
---

# Add Retry with Exponential Backoff

This skill adds automatic retry logic with exponential backoff to a Cubit method.

## What This Skill Does

Adds the `retry` parameter to a `mix()` call so that failed methods automatically retry with configurable:
- Number of retry attempts
- Initial delay before first retry
- Delay multiplier (exponential backoff)
- Maximum delay cap

## Instructions

### Step 1: Identify the Method to Add Retry

Ask the user which Cubit method should have retry logic, or identify methods that:
- Make network/API calls
- May fail due to transient errors
- Would benefit from automatic retry

### Step 2: Add Basic Retry

Add `retry: retry` to the `mix()` call:

```dart
import 'package:bloc_superpowers/bloc_superpowers.dart';

class UserCubit extends Cubit<User> {
  UserCubit() : super(User());

  void loadData() => mix(
    key: this,
    retry: retry,  // Add this line
    () async {
      final user = await api.loadUser();
      if (user == null) throw UserException('Failed to load user');
      emit(user);
    },
  );
}
```

### Step 3: Customize Retry Parameters (Optional)

The default retry configuration:
- **maxRetries: 3** — Three retry attempts after initial failure (4 total attempts)
- **initialDelay: 350ms** — Delay before first retry
- **multiplier: 2** — Each delay doubles (350ms → 700ms → 1400ms)
- **maxDelay: 5 seconds** — Maximum delay between retries

Customize as needed:

```dart
void loadData() => mix(
  key: this,
  retry: retry(
    maxRetries: 5,           // 5 retries (6 total attempts)
    initialDelay: 1.sec,     // Start with 1 second delay
    multiplier: 2.0,         // Double each time: 1s → 2s → 4s → 8s → 10s
    maxDelay: 10.sec,        // Cap at 10 seconds
  ),
  () async {
    final user = await api.loadUser();
    emit(user);
  },
);
```

## Configuration Options

### Limited Retries (Default)

```dart
retry                           // 3 retries with defaults
retry(maxRetries: 5)            // 5 retries
retry(maxRetries: 10)           // 10 retries
```

### Unlimited Retries

Use for critical operations that must eventually succeed:

```dart
retry.unlimited                 // Retry forever with default timing
retry(maxRetries: -1)           // Same as above

// Unlimited with custom timing
retry(initialDelay: 500.millis).unlimited
retry(initialDelay: 1.sec, maxDelay: 30.sec).unlimited
```

### Custom Timing

```dart
// Faster initial retry
retry(initialDelay: 100.millis)

// Slower backoff
retry(multiplier: 1.5)

// Higher cap
retry(maxDelay: 30.sec)

// Full customization
retry(
  maxRetries: 5,
  initialDelay: 500.millis,
  multiplier: 1.5,
  maxDelay: 15.sec,
)
```

## Timing Behavior

The retry delay starts **after** the method execution completes (not from when it started).

Example with default settings and a method that takes 1 second to fail:
- **Attempt 1**: Starts at 0s, fails at 1s
- **Attempt 2**: Starts at 1.35s (1s + 350ms delay), fails at 2.35s
- **Attempt 3**: Starts at 3.05s (2.35s + 700ms delay), fails at 4.05s
- **Attempt 4**: Starts at 5.45s (4.05s + 1400ms delay), fails at 6.45s
- **Final error thrown** at 6.45s

## Error Handling

- Only the **final error** is thrown after all retries are exhausted
- Previous errors are discarded
- The error will trigger `context.isFailed()` and show in `UserExceptionDialog`

## Common Patterns

### Retry with Internet Check

Combine retry with internet connectivity check:

```dart
void loadData() => mix(
  key: this,
  checkInternet: checkInternet,
  retry: retry,
  () async {
    final data = await api.getData();
    emit(data);
  },
);
```

### Retry Until Internet Returns

For critical startup data, retry forever until internet is available:

```dart
void loadInitialData() => mix(
  key: this,
  checkInternet: checkInternet(maxRetryDelay: 1.sec),
  retry: retry.unlimited,
  () async {
    final data = await api.getInitialData();
    emit(data);
  },
);
```

### Accessing Retry Context

Use `mix.ctx` to access retry information inside the method:

```dart
void loadData() => mix.ctx(
  key: this,
  retry: retry,
  (ctx) async {
    final retryCtx = ctx.retry!;
    final attempt = retryCtx.attempt;  // Zero-based (0, 1, 2, ...)
    final maxRetries = retryCtx.config.maxRetries;

    print('Attempt ${attempt + 1} of ${maxRetries + 1}');

    final data = await api.getData();
    emit(data);
  },
);
```

## When to Use Retry

**Good candidates for retry:**
- API calls that may fail due to network issues
- Database operations that may timeout
- File operations that may be temporarily locked
- Any operation with transient failures

**Not recommended for retry:**
- Validation errors (user input problems won't fix themselves)
- Authentication failures (wrong credentials won't become right)
- Business logic errors (invalid state won't change)

## User Preferences

Ask the user:
1. **How many retries?** Default is 3, but critical operations may need more
2. **Unlimited retries?** For must-succeed operations like initial app data
3. **Custom timing?** Faster retries for quick operations, slower for expensive ones
