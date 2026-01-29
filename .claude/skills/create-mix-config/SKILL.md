---
name: create-mix-config
description: Create a reusable MixConfig that bundles common mix() settings for consistent behavior across Cubits
---

# Create Reusable MixConfig

This skill creates a reusable `MixConfig` that bundles common settings for `mix()` calls.

## What This Skill Does

Creates a `MixConfig` object that:
- Combines multiple `mix()` parameters into a reusable configuration
- Can be shared across Cubits and methods
- Reduces code duplication
- Ensures consistent behavior

## Instructions

### Step 1: Identify Common Patterns

Ask the user what settings they commonly use together, such as:
- Retry + internet check for all API calls
- Logging before/after operations
- Standard error handling

### Step 2: Create the MixConfig

Define a `const MixConfig` with the desired parameters:

```dart
import 'package:bloc_superpowers/bloc_superpowers.dart';

const apiCallConfig = MixConfig(
  retry: retry(maxRetries: 3),
  checkInternet: checkInternet,
);
```

### Step 3: Use the Config

Apply it with `config:` in any `mix()` call:

```dart
class UserCubit extends Cubit<User> {
  void loadUser() => mix(
    key: this,
    config: apiCallConfig,  // Apply the config
    () async {
      final user = await api.getUser();
      emit(user);
    },
  );
}

class ProductCubit extends Cubit<ProductState> {
  void loadProducts() => mix(
    key: this,
    config: apiCallConfig,  // Same config, different Cubit
    () async {
      final products = await api.getProducts();
      emit(state.copyWith(products: products));
    },
  );
}
```

## Supported Parameters

`MixConfig` accepts all the same parameters as `mix()`:

```dart
const myConfig = MixConfig(
  // Feature configurations
  retry: retry(...),
  checkInternet: checkInternet(...),
  nonReentrant: nonReentrant,
  throttle: throttle(...),
  debounce: debounce(...),
  fresh: fresh(...),
  sequential: sequential(...),

  // Callbacks
  before: myBeforeCallback,
  after: myAfterCallback,
  wrapRun: myWrapRunCallback,
  catchError: myErrorHandler,
);
```

## Configuration Examples

### Standard API Config

```dart
const apiConfig = MixConfig(
  retry: retry(maxRetries: 3),
  checkInternet: checkInternet,
);
```

### API Config with Logging

```dart
void _logStart() => print('Starting operation...');
void _logEnd() => print('Operation complete');
void _logError(Object error, StackTrace stack) {
  print('Error: $error');
}

const apiConfigWithLogging = MixConfig(
  retry: retry(maxRetries: 3),
  checkInternet: checkInternet,
  before: _logStart,
  after: _logEnd,
  catchError: _logError,
);
```

### Critical Data Config (Unlimited Retry)

```dart
const criticalDataConfig = MixConfig(
  retry: retry.unlimited,
  checkInternet: checkInternet(maxRetryDelay: 1.sec),
);
```

### Background Sync Config

```dart
const backgroundSyncConfig = MixConfig(
  checkInternet: checkInternet(abortSilently: true),
  nonReentrant: nonReentrant,
);
```

### Rate-Limited API Config

```dart
const rateLimitedConfig = MixConfig(
  throttle: throttle(duration: 1.sec),
  retry: retry(maxRetries: 2),
);
```

### Search Config

```dart
const searchConfig = MixConfig(
  debounce: debounce(duration: 300.millis),
  nonReentrant: nonReentrant,
);
```

## Override Config Values

Individual `mix()` calls can override config values:

```dart
const apiConfig = MixConfig(
  retry: retry(maxRetries: 3),
  checkInternet: checkInternet,
);

// Use default retry (3)
void loadUsers() => mix(
  key: this,
  config: apiConfig,
  () async { ... },
);

// Override retry to 5
void loadCriticalData() => mix(
  key: this,
  config: apiConfig,
  retry: retry(maxRetries: 5),  // Overrides config's retry
  () async { ... },
);
```

## Priority Order

Values are resolved in this order (later wins):
1. Built-in defaults
2. Config parameter values
3. Explicit parameters in the `mix()` call

```dart
// Built-in default: retry has maxRetries: 3
// Config: retry(maxRetries: 5)
// Explicit: retry(maxRetries: 10)

mix(
  key: this,
  config: myConfig,           // Uses maxRetries: 5 from config
  retry: retry(maxRetries: 10),  // Overrides to 10
  () async { ... },
);
```

## Where to Define Configs

### Option A: Dedicated Config File

```dart
// lib/config/mix_configs.dart
import 'package:bloc_superpowers/bloc_superpowers.dart';

const apiConfig = MixConfig(
  retry: retry(maxRetries: 3),
  checkInternet: checkInternet,
);

const backgroundConfig = MixConfig(
  checkInternet: checkInternet(abortSilently: true),
  nonReentrant: nonReentrant,
);

const searchConfig = MixConfig(
  debounce: debounce(duration: 300.millis),
);
```

### Option B: In the Cubit File

```dart
// For configs specific to one Cubit
const _orderConfig = MixConfig(
  retry: retry(maxRetries: 5),
  sequential: sequential,
);

class OrderCubit extends Cubit<OrderState> {
  void placeOrder(Order order) => mix(
    key: this,
    config: _orderConfig,
    () async { ... },
  );
}
```

## Complete Example

```dart
// lib/config/mix_configs.dart
import 'package:bloc_superpowers/bloc_superpowers.dart';

void _logError(Object error, StackTrace stack) {
  // Log to your analytics service
  analyticsService.logError(error, stack);
}

/// Standard config for all API calls
const apiConfig = MixConfig(
  retry: retry(maxRetries: 3),
  checkInternet: checkInternet,
  catchError: _logError,
);

/// Config for critical startup data
const criticalDataConfig = MixConfig(
  retry: retry.unlimited,
  checkInternet: checkInternet(maxRetryDelay: 1.sec),
  catchError: _logError,
);

/// Config for background operations
const backgroundConfig = MixConfig(
  checkInternet: checkInternet(abortSilently: true),
  nonReentrant: nonReentrant,
);

/// Config for search operations
const searchConfig = MixConfig(
  debounce: debounce(duration: 300.millis),
);

// Usage in Cubit
class UserCubit extends Cubit<UserState> {
  void loadUser() => mix(
    key: this,
    config: apiConfig,
    () async {
      final user = await api.getUser();
      emit(state.copyWith(user: user));
    },
  );

  void loadInitialData() => mix(
    key: this,
    config: criticalDataConfig,
    () async {
      final data = await api.getInitialData();
      emit(state.copyWith(initialData: data));
    },
  );

  void syncInBackground() => mix(
    key: BackgroundSync,
    config: backgroundConfig,
    () async {
      await api.sync();
    },
  );

  void search(String query) => mix(
    key: Search,
    config: searchConfig,
    () async {
      final results = await api.search(query);
      emit(state.copyWith(searchResults: results));
    },
  );
}
```

## User Preferences

Ask the user:
1. **What parameters should be combined?** (retry, checkInternet, logging, etc.)
2. **Should callbacks be included?** (before, after, catchError)
3. **Where should configs be defined?** (central file vs per-Cubit)
