---
name: setup-observer
description: Configure Superpowers.observer for performance tracking, analytics, and debugging of all mix() calls
---

# Setup Global Observer

This skill configures `Superpowers.observer` for performance tracking, analytics, and debugging of all `mix()` calls.

## What This Skill Does

Sets up a global observer that:
- Tracks when operations start and complete
- Measures operation duration
- Captures errors and success states
- Sends data to analytics/monitoring services

## Instructions

### Step 1: Configure in main()

Set `Superpowers.observer` before `runApp()`:

```dart
import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:flutter/material.dart';

void main() {
  Superpowers.observer = (
    bool isStart,
    Object key,
    Object? metrics,
    Object? error,
    StackTrace? stackTrace,
    Duration? duration,
  ) {
    // Handle observation
  };

  runApp(
    Superpowers(
      child: MaterialApp(...),
    ),
  );
}
```

### Step 2: Understand Parameters

| Parameter | When | Description |
|-----------|------|-------------|
| `isStart` | Always | `true` at start, `false` at end |
| `key` | Always | The key from `mix()` call |
| `metrics` | Always | Custom data from `metrics` callback |
| `error` | End only | Exception if operation failed |
| `stackTrace` | End only | Stack trace if operation failed |
| `duration` | End only | How long the operation took |

## Common Patterns

### Basic Logging

```dart
Superpowers.observer = (isStart, key, metrics, error, stackTrace, duration) {
  if (isStart) {
    print('▶ Starting: $key');
  } else {
    if (error != null) {
      print('✗ Failed: $key after ${duration?.inMilliseconds}ms - $error');
    } else {
      print('✓ Completed: $key in ${duration?.inMilliseconds}ms');
    }
  }
};
```

### Performance Monitoring

```dart
Superpowers.observer = (isStart, key, metrics, error, stackTrace, duration) {
  if (!isStart && duration != null) {
    // Log slow operations
    if (duration.inMilliseconds > 1000) {
      print('⚠ Slow operation: $key took ${duration.inMilliseconds}ms');
    }

    // Send to analytics
    analytics.logTiming(
      category: 'cubit_operation',
      name: key.toString(),
      duration: duration,
      success: error == null,
    );
  }
};
```

### Analytics Integration

```dart
Superpowers.observer = (isStart, key, metrics, error, stackTrace, duration) {
  if (!isStart) {
    // Firebase Analytics
    FirebaseAnalytics.instance.logEvent(
      name: 'cubit_operation',
      parameters: {
        'key': key.toString(),
        'duration_ms': duration?.inMilliseconds,
        'success': error == null,
        'error_type': error?.runtimeType.toString(),
      },
    );

    // Or Amplitude
    Amplitude.instance.logEvent(
      'cubit_operation_completed',
      eventProperties: {
        'key': key.toString(),
        'duration_ms': duration?.inMilliseconds,
        'success': error == null,
      },
    );
  }
};
```

### Error Monitoring

```dart
Superpowers.observer = (isStart, key, metrics, error, stackTrace, duration) {
  if (!isStart && error != null) {
    // Send to Sentry
    Sentry.captureException(
      error,
      stackTrace: stackTrace,
      hint: Hint.withMap({
        'key': key.toString(),
        'duration_ms': duration?.inMilliseconds.toString(),
      }),
    );

    // Or Crashlytics
    FirebaseCrashlytics.instance.recordError(
      error,
      stackTrace,
      reason: 'mix operation failed: $key',
    );
  }
};
```

## Using Metrics

Pass custom data to the observer with the `metrics` parameter:

### Pass Current State

```dart
void loadUser() => mix(
  key: this,
  metrics: () => state,  // Pass current state
  () async {
    final user = await api.getUser();
    emit(user);
  },
);

// In observer
Superpowers.observer = (isStart, key, metrics, error, stackTrace, duration) {
  if (metrics != null) {
    print('State at ${isStart ? "start" : "end"}: $metrics');
  }
};
```

### Pass Cubit Instance

```dart
void loadData() => mix(
  key: this,
  metrics: () => this,  // Pass entire Cubit
  () async {
    final data = await api.getData();
    emit(data);
  },
);

// In observer - access Cubit state
Superpowers.observer = (isStart, key, metrics, error, stackTrace, duration) {
  if (metrics is MyCubit) {
    print('Cubit state: ${metrics.state}');
  }
};
```

### Pass Custom Metrics

```dart
void processOrder(Order order) => mix(
  key: this,
  metrics: () => {
    'orderId': order.id,
    'itemCount': order.items.length,
    'total': order.total,
  },
  () async {
    await api.processOrder(order);
  },
);

// In observer
Superpowers.observer = (isStart, key, metrics, error, stackTrace, duration) {
  if (metrics is Map) {
    analytics.logEvent('order_processing', parameters: metrics);
  }
};
```

## Behavior Notes

- **Called twice:** Once at start (`isStart: true`), once at end (`isStart: false`)
- **Retry transparency:** With `retry`, observer only sees the overall start/end, not individual attempts
- **Error safety:** If the metrics callback or observer throws, the error is captured safely
- **Metrics called twice:** The `metrics` callback runs at both start and end, so you can see state changes

## Complete Example

```dart
void main() {
  _setupObserver();

  runApp(
    Superpowers(
      child: MyApp(),
    ),
  );
}

void _setupObserver() {
  Superpowers.observer = (
    bool isStart,
    Object key,
    Object? metrics,
    Object? error,
    StackTrace? stackTrace,
    Duration? duration,
  ) {
    final keyStr = _formatKey(key);

    if (isStart) {
      // Log operation start
      debugPrint('▶ [$keyStr] Starting');
    } else {
      // Log operation completion
      final durationMs = duration?.inMilliseconds ?? 0;

      if (error != null) {
        debugPrint('✗ [$keyStr] Failed after ${durationMs}ms: $error');

        // Report to crash analytics
        _reportError(key, error, stackTrace, duration);
      } else {
        debugPrint('✓ [$keyStr] Completed in ${durationMs}ms');

        // Report slow operations
        if (durationMs > 2000) {
          _reportSlowOperation(key, duration!);
        }
      }

      // Send analytics
      _sendAnalytics(key, duration, error == null);
    }
  };
}

String _formatKey(Object key) {
  if (key is Type) return key.toString();
  if (key is Record) return key.toString();
  return key.runtimeType.toString();
}

void _reportError(Object key, Object error, StackTrace? stack, Duration? duration) {
  FirebaseCrashlytics.instance.recordError(
    error,
    stack,
    reason: 'Operation failed: $key',
    information: ['Duration: ${duration?.inMilliseconds}ms'],
  );
}

void _reportSlowOperation(Object key, Duration duration) {
  FirebaseAnalytics.instance.logEvent(
    name: 'slow_operation',
    parameters: {
      'key': key.toString(),
      'duration_ms': duration.inMilliseconds,
    },
  );
}

void _sendAnalytics(Object key, Duration? duration, bool success) {
  FirebaseAnalytics.instance.logEvent(
    name: 'cubit_operation',
    parameters: {
      'key': key.toString(),
      'duration_ms': duration?.inMilliseconds,
      'success': success,
    },
  );
}
```

## Testing

Reset the observer between tests:

```dart
setUp(() {
  Superpowers.clear();  // Removes observer and resets state
});
```

## User Preferences

Ask the user:
1. **What should be logged?** (start, completion, errors, slow operations)
2. **Where to send analytics?** (Firebase, Amplitude, custom backend)
3. **Need custom metrics?** (state, order details, etc.)
