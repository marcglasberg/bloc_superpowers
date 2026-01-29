---
name: create-mix-preset
description: Create a callable MixPreset function that replaces mix() with preconfigured settings
---

# Create Reusable MixPreset

This skill creates a `MixPreset` - a callable reusable function that replaces `mix()` with preconfigured settings.

## What This Skill Does

Creates a `MixPreset` that:
- Works like a custom `mix()` function with preset parameters
- Can be called directly instead of using `mix()`
- Supports all the same parameters as `mix()`
- Allows per-call overrides

## MixPreset vs MixConfig

| Feature | MixConfig | MixPreset |
|---------|-----------|-----------|
| Usage | `mix(config: myConfig, ...)` | `myPreset(...)` |
| Callable | No | Yes |
| Default key | No | Yes |
| Code style | Passes to mix() | Replaces mix() |

## Instructions

### Step 1: Identify the Pattern

Ask the user what common pattern they want to encapsulate:
- Standard API calls
- Critical data loading
- Background sync operations

### Step 2: Create the MixPreset

Define a `const MixPreset` with the desired parameters:

```dart
import 'package:bloc_superpowers/bloc_superpowers.dart';

const apiCall = MixPreset(
  retry: retry,
  checkInternet: checkInternet,
);
```

### Step 3: Use the Preset

Call it directly instead of `mix()`:

```dart
class UserCubit extends Cubit<User> {
  void loadUser() => apiCall(
    key: this,
    () async {
      final user = await api.getUser();
      emit(user);
    },
  );
}
```

## Configuration Examples

### Standard API Preset

```dart
const apiCall = MixPreset(
  retry: retry(maxRetries: 3),
  checkInternet: checkInternet,
);

// Usage
void loadData() => apiCall(
  key: this,
  () async {
    final data = await api.getData();
    emit(data);
  },
);
```

### Preset with Default Key

Avoid repeating the key by setting a default:

```dart
const userApiCall = MixPreset(
  key: UserCubit,  // Default key
  retry: retry,
  checkInternet: checkInternet,
);

// Usage - key is optional
void loadUser() => userApiCall(
  () async {
    final user = await api.getUser();
    emit(user);
  },
);
```

### Preset with Logging

```dart
void _logStart() => print('API call starting...');
void _logEnd() => print('API call complete');
void _logError(Object error, StackTrace stack) => print('Error: $error');

const loggedApiCall = MixPreset(
  retry: retry,
  checkInternet: checkInternet,
  before: _logStart,
  after: _logEnd,
  catchError: _logError,
);
```

### Critical Data Preset

```dart
const criticalLoad = MixPreset(
  retry: retry.unlimited,
  checkInternet: checkInternet(maxRetryDelay: 1.sec),
);

// Usage
void loadAppConfig() => criticalLoad(
  key: this,
  () async {
    final config = await api.getConfig();
    emit(config);
  },
);
```

### Background Sync Preset

```dart
const backgroundSync = MixPreset(
  checkInternet: checkInternet(abortSilently: true),
  nonReentrant: nonReentrant,
);

// Usage
void sync() => backgroundSync(
  key: Sync,
  () async {
    await api.syncData();
  },
);
```

## Accessing Context with .ctx()

Use `.ctx()` to access retry attempts and other context info:

```dart
const apiCall = MixPreset(
  retry: retry,
);

void loadData() => apiCall.ctx(
  key: this,
  (ctx) async {
    final attempt = ctx.retry!.attempt;  // 0, 1, 2, ...
    print('Attempt ${attempt + 1}');

    final data = await api.getData();
    emit(data);
  },
);
```

## Overriding Preset Values

Explicit parameters override preset values:

```dart
const apiCall = MixPreset(
  retry: retry(maxRetries: 3),
  checkInternet: checkInternet,
);

// Uses preset retry (3 attempts)
void loadUsers() => apiCall(
  key: this,
  () async { ... },
);

// Overrides to 10 attempts
void loadCriticalData() => apiCall(
  key: this,
  retry: retry(maxRetries: 10),  // Overrides preset
  () async { ... },
);
```

## Priority Order

Values resolve in order (later wins):
1. Built-in defaults
2. Preset values
3. Explicit call parameters

## Complete Example

```dart
// lib/presets/api_presets.dart
import 'package:bloc_superpowers/bloc_superpowers.dart';

/// Standard API call with retry and internet check
const apiCall = MixPreset(
  retry: retry(maxRetries: 3),
  checkInternet: checkInternet,
);

/// Critical data that must eventually load
const criticalLoad = MixPreset(
  retry: retry.unlimited,
  checkInternet: checkInternet(maxRetryDelay: 1.sec),
);

/// Background sync that fails silently
const backgroundSync = MixPreset(
  checkInternet: checkInternet(abortSilently: true),
  nonReentrant: nonReentrant,
);

/// Search with debounce
const searchCall = MixPreset(
  debounce: debounce(duration: 300.millis),
);

// Usage in Cubit
class ProductCubit extends Cubit<ProductState> {
  ProductCubit() : super(const ProductState());

  // Standard API call
  void loadProducts() => apiCall(
    key: this,
    () async {
      final products = await api.getProducts();
      emit(state.copyWith(products: products));
    },
  );

  // Critical data
  void loadCategories() => criticalLoad(
    key: LoadCategories,
    () async {
      final categories = await api.getCategories();
      emit(state.copyWith(categories: categories));
    },
  );

  // Background sync
  void syncFavorites() => backgroundSync(
    key: SyncFavorites,
    () async {
      await api.syncFavorites(state.favorites);
    },
  );

  // Search
  void search(String query) => searchCall(
    key: Search,
    () async {
      final results = await api.search(query);
      emit(state.copyWith(searchResults: results));
    },
  );

  // Override retry for specific case
  void loadProductDetails(String id) => apiCall(
    key: (ProductDetails, id),
    retry: retry(maxRetries: 5),  // More retries for this
    () async {
      final details = await api.getProductDetails(id);
      emit(state.copyWith(
        productDetails: {...state.productDetails, id: details},
      ));
    },
  );
}
```

## When to Use MixPreset vs MixConfig

**Use MixPreset when:**
- You want a cleaner, callable syntax
- You have a default key for the preset
- You prefer `myPreset(...)` over `mix(config: ..., ...)`

**Use MixConfig when:**
- You want to pass configuration to `mix()` explicitly
- You're combining multiple configs
- You prefer the explicit `config:` parameter style

## Advanced: MixPreset.withUserContext

For injecting parameters into every action (dependency injection pattern):

```dart
final apiCall = MixPreset.withUserContext<
    ({String baseUrl, void Function(String) log}),  // P: injected params type
    ({String env, bool verbose})                     // C: call-time config type
>(
  params: (ctx, config) => (
    baseUrl: config.env == 'prod'
        ? 'https://api.example.com'
        : 'https://staging.example.com',
    log: (msg) {
      if (config.verbose) {
        final attempt = ctx.retry?.attempt ?? 0;
        debugPrint('[API Attempt $attempt] $msg');
      }
    },
  ),
  defaultConfig: (env: 'dev', verbose: false),
  retry: retry,
  checkInternet: checkInternet,
);

// Usage - actions receive injected params
await apiCall(
  key: 'fetchUsers',
  config: (env: 'prod', verbose: true),
  (ctx) async {
    ctx.log('Fetching users...');
    return await http.get('${ctx.baseUrl}/users');
  },
);
```

**Key points:**
- `params` function receives `MixContext` - can access retry metadata
- Params are rebuilt on each retry attempt with updated context
- Error handlers compose: preset handler runs first, then call-site handler

**Use `MixPreset.withUserContext` when:**
- Injecting services or utilities into actions
- Injected params need runtime context access (like retry attempt)
- Encapsulating sophisticated setup logic

## User Preferences

Ask the user:
1. **What should the preset include?** (retry, checkInternet, logging, etc.)
2. **Should it have a default key?** (to make key optional in calls)
3. **Need context access?** (for retry attempt info)
