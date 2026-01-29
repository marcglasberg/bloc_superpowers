---
name: configure-global-defaults
description: Set global default values for RetryConfig, ThrottleConfig, DebounceConfig, and other bloc_superpowers configurations
---

# Configure Global Defaults

This skill sets global default values for bloc_superpowers configuration classes.

## What This Skill Does

Configures static `defaults` properties on configuration classes so that:
- All `mix()` calls use your preferred defaults
- You don't need to specify common settings repeatedly
- The entire app has consistent behavior

## Instructions

### Step 1: Identify Desired Defaults

Ask the user what default values they want for:
- **RetryConfig**: maxRetries, initialDelay, multiplier, maxDelay
- **ThrottleConfig**: duration
- **DebounceConfig**: duration
- **FreshConfig**: freshFor duration
- Other configs as needed

### Step 2: Configure Defaults at App Startup

Set defaults in `main()` before `runApp()`:

```dart
import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:flutter/material.dart';

void main() {
  // Configure global defaults
  RetryConfig.defaults = retry(
    maxRetries: 5,
    initialDelay: 200.millis,
    multiplier: 2.0,
    maxDelay: 10.sec,
  );

  runApp(
    Superpowers(
      child: MyApp(),
    ),
  );
}
```

### Step 3: Use Defaults Automatically

Now when you use `retry: retry` without parameters, it uses your defaults:

```dart
void loadData() => mix(
  key: this,
  retry: retry,  // Uses your 5 retries, 200ms delay, etc.
  () async {
    final data = await api.getData();
    emit(data);
  },
);
```

## Available Configuration Classes

### RetryConfig

```dart
RetryConfig.defaults = retry(
  maxRetries: 5,           // Default: 3
  initialDelay: 200.millis, // Default: 350ms
  multiplier: 2.0,          // Default: 2
  maxDelay: 10.sec,         // Default: 5 seconds
);
```

### ThrottleConfig

```dart
ThrottleConfig.defaults = throttle(
  duration: 2.sec,  // Default: 1 second
);
```

### DebounceConfig

```dart
DebounceConfig.defaults = debounce(
  duration: 500.millis,  // Default: 300ms
);
```

### FreshConfig

```dart
FreshConfig.defaults = fresh(
  freshFor: 30.sec,  // Default: 1 second
);
```

### CheckInternetConfig

```dart
CheckInternetConfig.defaults = checkInternet(
  maxRetryDelay: 2.sec,  // Default: 1 second
);
```

### SequentialConfig

```dart
SequentialConfig.defaults = sequential(
  maxQueueSize: 50,      // Default: unlimited
  queueTimeout: 30.sec,  // Default: none
);
```

## Complete Setup Example

```dart
import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:flutter/material.dart';

void main() {
  _configureSuperpowersDefaults();

  runApp(
    Superpowers(
      child: MyApp(),
    ),
  );
}

void _configureSuperpowersDefaults() {
  // Retry: 5 attempts with faster initial retry
  RetryConfig.defaults = retry(
    maxRetries: 5,
    initialDelay: 200.millis,
    multiplier: 2.0,
    maxDelay: 10.sec,
  );

  // Throttle: 2 seconds between calls
  ThrottleConfig.defaults = throttle(
    duration: 2.sec,
  );

  // Debounce: 400ms wait for search
  DebounceConfig.defaults = debounce(
    duration: 400.millis,
  );

  // Fresh: Data valid for 30 seconds
  FreshConfig.defaults = fresh(
    freshFor: 30.sec,
  );

  // Sequential: Limit queue size
  SequentialConfig.defaults = sequential(
    maxQueueSize: 100,
    queueTimeout: 60.sec,
  );
}
```

## How Defaults Work

### Priority Order (lowest to highest)

1. **Built-in defaults** (from bloc_superpowers)
2. **Your global defaults** (set via `Config.defaults`)
3. **MixConfig values** (passed via `config:`)
4. **Explicit parameters** (passed directly to `mix()`)

### Example

```dart
// Built-in default: maxRetries = 3
// Your default: maxRetries = 5
RetryConfig.defaults = retry(maxRetries: 5);

// Uses your default (5)
mix(key: this, retry: retry, () async { ... });

// Overrides to 10
mix(key: this, retry: retry(maxRetries: 10), () async { ... });
```

## When to Change Defaults

**Good candidates for custom defaults:**
- Retry count based on your API reliability
- Throttle duration based on API rate limits
- Debounce duration based on typical user typing speed
- Fresh duration based on how often your data changes

**Consider your app's needs:**
- **Unreliable network?** Increase retry count and max delay
- **Strict API rate limits?** Increase throttle duration
- **Fast-changing data?** Decrease fresh duration
- **Slow typists?** Increase debounce duration

## Resetting Defaults

To reset to built-in defaults (useful in tests):

```dart
void setUp() {
  Superpowers.clear();  // Resets everything including defaults
}
```

Or reset individual configs:

```dart
RetryConfig.defaults = RetryConfig.builtInDefaults;
ThrottleConfig.defaults = ThrottleConfig.builtInDefaults;
```

## User Preferences

Ask the user:
1. **What retry settings?** (attempts, delays, based on network reliability)
2. **What throttle duration?** (based on API rate limits)
3. **What debounce duration?** (based on user interaction speed)
4. **What freshness period?** (based on data update frequency)
