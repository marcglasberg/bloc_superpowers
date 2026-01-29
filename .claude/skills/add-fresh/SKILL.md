---
name: add-fresh
description: Add freshness caching to prevent redundant method executions within a time period
---

# Add Freshness Caching

This skill adds freshness caching to prevent redundant method executions within a time period.

## What This Skill Does

Adds the `fresh` parameter to a `mix()` call so that:
- Data is treated as valid for a specified duration
- Repeated calls within the freshness period are skipped
- The method only re-executes after data becomes stale

## Instructions

### Step 1: Identify the Method

Ask the user which Cubit method needs freshness caching, or identify methods that:
- Load data that doesn't change frequently
- Are called multiple times (e.g., when entering/leaving screens)
- Would benefit from avoiding redundant API calls

### Step 2: Add Basic Freshness

Add `fresh: fresh` to the `mix()` call:

```dart
import 'package:bloc_superpowers/bloc_superpowers.dart';

class UserCubit extends Cubit<User> {
  UserCubit() : super(User());

  void loadData() => mix(
    key: this,
    fresh: fresh,  // Add this line (default: 1 second)
    () async {
      final user = await api.loadUser();
      if (user == null) throw UserException('Failed to load user');
      emit(user);
    },
  );
}
```

### Step 3: Configure Freshness Duration

The default freshness period is **1 second**. Customize based on how often data changes:

```dart
void loadData() => mix(
  key: this,
  fresh: fresh(freshFor: 5.sec),  // Data valid for 5 seconds
  () async {
    final user = await api.loadUser();
    emit(user);
  },
);
```

## Configuration Options

### Duration Examples

```dart
fresh                           // 1 second (default)
fresh(freshFor: 5.sec)          // 5 seconds
fresh(freshFor: 30.sec)         // 30 seconds
fresh(freshFor: 5.minutes)      // 5 minutes
fresh(freshFor: 1.hours)        // 1 hour
```

### Force Refresh

Allow bypassing freshness with a parameter:

```dart
void loadData({bool force = false}) => mix(
  key: this,
  fresh: fresh(
    freshFor: 5.sec,
    ignoreFresh: force,  // When true, ignores freshness
  ),
  () async {
    final data = await api.getData();
    emit(data);
  },
);

// Normal call - respects freshness
cubit.loadData();

// Force refresh - ignores freshness
cubit.loadData(force: true);
```

### Per-Parameter Freshness with Custom Key

Track freshness separately for different parameters:

```dart
void loadUser(String userId) => mix(
  key: this,  // State tracking uses UserCubit
  fresh: fresh(
    key: (UserCubit, userId),  // Freshness tracked per userId
    freshFor: 5.sec,
  ),
  () async {
    final user = await api.loadUser(userId);
    emit(state.copyWith(users: {...state.users, userId: user}));
  },
);
```

With this setup:
- `context.isWaiting(UserCubit)` shows loading for any user
- Loading user "A" doesn't affect freshness of user "B"

## Behavior Details

### Success Case

```dart
cubit.loadData();  // ✓ Executes, data loaded, marked fresh
// ... 2 seconds later (within 5 sec freshness) ...
cubit.loadData();  // ✗ Skipped, data still fresh
// ... 4 more seconds later (total 6 sec, past freshness) ...
cubit.loadData();  // ✓ Executes, data reloaded
```

### Error Case

If the method fails, freshness is **not** set. This allows immediate retry:

```dart
cubit.loadData();  // ✗ Fails with error
cubit.loadData();  // ✓ Executes immediately (not marked fresh due to error)
```

## Common Patterns

### Screen Data Loading

Prevent reloading when navigating back to a screen:

```dart
void loadScreenData() => mix(
  key: this,
  fresh: fresh(freshFor: 30.sec),
  () async {
    final data = await api.getScreenData();
    emit(data);
  },
);
```

### Pull-to-Refresh with Force

```dart
void loadProducts({bool force = false}) => mix(
  key: this,
  fresh: fresh(freshFor: 1.minutes, ignoreFresh: force),
  () async {
    final products = await api.getProducts();
    emit(state.copyWith(products: products));
  },
);

// In widget
RefreshIndicator(
  onRefresh: () => cubit.loadProducts(force: true),
  child: ProductList(),
)
```

### Freshness with Retry

```dart
void loadData() => mix(
  key: this,
  fresh: fresh(freshFor: 10.sec),
  retry: retry,
  () async {
    final data = await api.getData();
    emit(data);
  },
);
```

### Freshness with Non-Reentrant

```dart
void loadData() => mix(
  key: this,
  fresh: fresh(freshFor: 5.sec),
  nonReentrant: nonReentrant,
  retry: retry,
  () async {
    final data = await api.getData();
    emit(data);
  },
);
```

## Manual Cache Control

Clear freshness manually when needed:

```dart
// Clear freshness for a specific key
Superpowers.removeFreshKey(UserCubit);
Superpowers.removeFreshKey((UserCubit, userId));

// Clear all freshness keys
Superpowers.removeAllFreshKeys();
```

Use cases for manual clearing:
- After user logout (clear all user data freshness)
- After data mutation (force reload on next access)
- In tests (reset between test cases)

## When to Use Fresh

**Good candidates:**
- User profile data
- Settings/configuration
- Product catalogs
- Any data loaded when entering screens

**Consider freshness duration:**
- **Short (1-5 sec)**: Rapidly changing data, but avoid duplicate calls
- **Medium (30 sec - 5 min)**: Screen data, user profiles
- **Long (10+ min)**: Configuration, rarely changing data

**Not recommended:**
- Real-time data (use polling or WebSockets instead)
- Data that must always be current

## Complete Example

```dart
class ProductCubit extends Cubit<ProductState> {
  ProductCubit() : super(const ProductState());

  // Products stay fresh for 1 minute
  void loadProducts({bool force = false}) => mix(
    key: this,
    fresh: fresh(freshFor: 1.minutes, ignoreFresh: force),
    retry: retry,
    () async {
      final products = await api.getProducts();
      emit(state.copyWith(products: products));
    },
  );

  // Product details fresh per product ID
  void loadProductDetails(String productId) => mix(
    key: (ProductDetails, productId),
    fresh: fresh(freshFor: 30.sec),
    () async {
      final details = await api.getProductDetails(productId);
      emit(state.copyWith(
        productDetails: {...state.productDetails, productId: details},
      ));
    },
  );
}
```

## User Preferences

Ask the user:
1. **How long should data stay fresh?** (depends on how often it changes)
2. **Should there be a force refresh option?** (for pull-to-refresh)
3. **Per-item freshness?** (for parameterized methods)
