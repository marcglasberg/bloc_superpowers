---
name: setup-global-catch-error
description: Configure Superpowers.globalCatchError for centralized error handling, logging, and error conversion
---

# Setup Global Error Handler

This skill configures `Superpowers.globalCatchError` for centralized error handling across all `mix()` calls.

## What This Skill Does

Sets up a global error handler that:
- Catches all unhandled errors from `mix()` calls
- Logs errors to analytics/crash reporting
- Converts technical errors to user-friendly messages
- Provides consistent error handling across the app

## Instructions

### Step 1: Configure in main()

Set `Superpowers.globalCatchError` before `runApp()`:

```dart
import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:flutter/material.dart';

void main() {
  Superpowers.globalCatchError = (error, stackTrace, key) {
    // Handle the error
  };

  runApp(
    Superpowers(
      child: MaterialApp(...),
    ),
  );
}
```

### Step 2: Choose Response Strategy

The handler can respond in three ways:

**1. Suppress (return normally):** Error is silenced, no dialog shown
```dart
Superpowers.globalCatchError = (error, stackTrace, key) {
  logError(error, stackTrace);
  // Return without throwing = error suppressed
};
```

**2. Show Dialog (throw UserException):** Displays error dialog to user
```dart
Superpowers.globalCatchError = (error, stackTrace, key) {
  logError(error, stackTrace);
  throw UserException('Something went wrong');
};
```

**3. Crash (throw other exception):** App crashes (useful in debug mode)
```dart
Superpowers.globalCatchError = (error, stackTrace, key) {
  if (kDebugMode) throw error;  // Crash in debug
  throw UserException('Something went wrong');  // Dialog in release
};
```

## Handler Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `error` | `Object` | The exception that was thrown |
| `stackTrace` | `StackTrace` | Where the error originated |
| `key` | `Object` | The key from the `mix()` call |

## Common Patterns

### Log All Errors

```dart
Superpowers.globalCatchError = (error, stackTrace, key) {
  // Log to your analytics service
  analyticsService.logError(
    error: error,
    stackTrace: stackTrace,
    context: {'key': key.toString()},
  );

  // Show generic message
  if (error is UserException) throw error;
  throw UserException('Something went wrong. Please try again.');
};
```

### Convert API Errors

```dart
Superpowers.globalCatchError = (error, stackTrace, key) {
  logError(error, stackTrace);

  // Firebase Auth errors
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'user-not-found':
        throw UserException('No account found with this email.');
      case 'wrong-password':
        throw UserException('Incorrect password.');
      case 'user-disabled':
        throw UserException('This account has been disabled.');
      case 'too-many-requests':
        throw UserException('Too many attempts. Try again later.');
      default:
        throw UserException('Authentication failed.');
    }
  }

  // Dio/HTTP errors
  if (error is DioException) {
    switch (error.response?.statusCode) {
      case 401:
        throw UserException('Session expired. Please log in again.');
      case 403:
        throw UserException('You don\'t have permission for this action.');
      case 404:
        throw UserException('The requested item was not found.');
      case 500:
        throw UserException('Server error. Please try again later.');
      default:
        throw UserException('Network error. Check your connection.');
    }
  }

  // Network errors
  if (error is SocketException || error is TimeoutException) {
    throw UserException('Could not connect to the server.');
  }

  // Pass through UserExceptions
  if (error is UserException) throw error;

  // Generic fallback
  throw UserException('Something went wrong. Please try again.');
};
```

### Debug vs Release Mode

```dart
Superpowers.globalCatchError = (error, stackTrace, key) {
  // Always log
  logger.error('Error in $key', error, stackTrace);

  // In debug mode, crash to see the error
  if (kDebugMode) {
    throw error;
  }

  // In release, show friendly message
  if (error is UserException) throw error;
  throw UserException('Something went wrong. Please try again.');
};
```

### With Crash Reporting (Crashlytics/Sentry)

```dart
Superpowers.globalCatchError = (error, stackTrace, key) {
  // Report to Crashlytics
  FirebaseCrashlytics.instance.recordError(
    error,
    stackTrace,
    reason: 'Error in mix call: $key',
  );

  // Or report to Sentry
  Sentry.captureException(
    error,
    stackTrace: stackTrace,
    hint: Hint.withMap({'key': key.toString()}),
  );

  // Convert to user-friendly message
  if (error is UserException) throw error;
  throw UserException('An error occurred. Our team has been notified.');
};
```

## Error Flow

Errors flow through handlers in order:

```
Error in mix()
       ↓
1. Local catchError (in mix call)
       ↓ (if rethrows)
2. Config catchError (in MixConfig)
       ↓ (if rethrows)
3. globalCatchError
       ↓
   ┌───┴───┐
   │       │
returns  throws
   │       │
   ↓       ↓
suppressed → isFailed() = true
             UserExceptionDialog shows
```

If any handler suppresses (returns without throwing), subsequent handlers don't run.

## Complete Example

```dart
import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() {
  _setupGlobalErrorHandler();

  runApp(
    Superpowers(
      child: MyApp(),
    ),
  );
}

void _setupGlobalErrorHandler() {
  Superpowers.globalCatchError = (error, stackTrace, key) {
    // 1. Log all errors
    _logError(error, stackTrace, key);

    // 2. In debug mode, rethrow to see full error
    if (kDebugMode && error is! UserException) {
      print('Error in $key: $error\n$stackTrace');
    }

    // 3. Convert known errors to user-friendly messages
    final userMessage = _convertToUserMessage(error);
    throw UserException(userMessage).addCause(error);
  };
}

void _logError(Object error, StackTrace stackTrace, Object key) {
  // Log to your service
  analyticsService.logError(
    error: error,
    stackTrace: stackTrace,
    context: {'mix_key': key.toString()},
  );
}

String _convertToUserMessage(Object error) {
  // Pass through existing user messages
  if (error is UserException) return error.message;

  // Firebase Auth
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'user-not-found' => 'No account found with this email.',
      'wrong-password' => 'Incorrect password.',
      'email-already-in-use' => 'An account already exists with this email.',
      _ => 'Authentication failed. Please try again.',
    };
  }

  // Network errors
  if (error is SocketException) {
    return 'No internet connection.';
  }
  if (error is TimeoutException) {
    return 'Request timed out. Please try again.';
  }

  // HTTP errors
  if (error is DioException) {
    return switch (error.response?.statusCode) {
      401 => 'Please log in to continue.',
      403 => 'You don\'t have permission for this action.',
      404 => 'The requested item was not found.',
      >= 500 => 'Server error. Please try again later.',
      _ => 'Network error. Please check your connection.',
    };
  }

  // Generic fallback
  return 'Something went wrong. Please try again.';
}
```

## Testing

Reset the global handler between tests:

```dart
setUp(() {
  Superpowers.clear();  // Removes globalCatchError and resets state
});
```

## User Preferences

Ask the user:
1. **What error types need conversion?** (Firebase, Dio, custom API errors)
2. **Should errors be logged?** (to analytics, Crashlytics, Sentry)
3. **Debug mode behavior?** (crash to see error, or show dialog)
