---
name: add-non-reentrant
description: Add non-reentrant protection to prevent a Cubit method from running multiple times simultaneously
---

# Add Non-Reentrant Protection

This skill prevents a Cubit method from running multiple times simultaneously.

## What This Skill Does

Adds the `nonReentrant` parameter to a `mix()` call so that:
- If the method is already running, additional calls are ignored
- The duplicate call returns immediately without executing
- Only one instance of the method runs at a time

This is equivalent to `droppable()` from the `bloc_concurrency` package, but for Cubit methods.

## Instructions

### Step 1: Identify the Method

Ask the user which Cubit method needs non-reentrant protection, or identify methods that:
- Could be triggered multiple times rapidly (button spam, scroll events)
- Should not run concurrently (data loading, form submission)
- Would cause issues if executed simultaneously

### Step 2: Add Non-Reentrant

Add `nonReentrant: nonReentrant` to the `mix()` call:

```dart
import 'package:bloc_superpowers/bloc_superpowers.dart';

class UserCubit extends Cubit<User> {
  UserCubit() : super(User());

  void loadData() => mix(
    key: this,
    nonReentrant: nonReentrant,  // Add this line
    () async {
      final user = await api.loadUser();
      emit(user);
    },
  );
}
```

### Step 3: Understand the Behavior

With `nonReentrant`:
- **First call**: Executes normally
- **Second call while first is running**: Returns immediately, does nothing
- **Call after first completes**: Executes normally

```dart
// User taps "Load" button rapidly 3 times
cubit.loadData();  // ✓ Executes
cubit.loadData();  // ✗ Ignored (first still running)
cubit.loadData();  // ✗ Ignored (first still running)
// First call completes
cubit.loadData();  // ✓ Executes (previous call finished)
```

## Common Patterns

### Load Data with Non-Reentrant

Prevent duplicate API calls:

```dart
void loadProducts() => mix(
  key: this,
  nonReentrant: nonReentrant,
  () async {
    final products = await api.getProducts();
    emit(state.copyWith(products: products));
  },
);
```

### Non-Reentrant with Retry

Combine for robust data loading:

```dart
void loadData() => mix(
  key: this,
  nonReentrant: nonReentrant,
  retry: retry,
  () async {
    final data = await api.getData();
    emit(data);
  },
);
```

### Form Submission

Prevent double-submit:

```dart
void submitForm(FormData data) => mix(
  key: this,
  nonReentrant: nonReentrant,
  () async {
    await api.submit(data);
    emit(state.copyWith(submitted: true));
  },
);
```

### Per-Item Non-Reentrant with Custom Key

Allow concurrent operations for different items, but prevent duplicate operations on the same item:

```dart
void processItem(String itemId) => mix(
  key: this,
  nonReentrant: nonReentrant(key: (ProcessItem, itemId)),
  () async {
    await api.processItem(itemId);
  },
);
```

With this setup:
- `processItem('A')` and `processItem('B')` can run concurrently
- `processItem('A')` called twice rapidly: second call is ignored

### Delete with Per-Item Protection

```dart
void deleteItem(String id) => mix(
  key: (DeleteItem, id),  // State tracking per item
  nonReentrant: nonReentrant,  // Inherits key from mix
  () async {
    await api.deleteItem(id);
    emit(state.copyWith(
      items: state.items.where((i) => i.id != id).toList(),
    ));
  },
);
```

## Non-Reentrant vs Sequential

| Feature | Behavior |
|---------|----------|
| `nonReentrant` | Drops duplicate calls while running |
| `sequential` | Queues calls and processes one at a time |

Use `nonReentrant` when:
- You want to ignore duplicate requests
- Only the first call matters
- Example: Loading data, user taps refresh multiple times

Use `sequential` when:
- You want to process all calls in order
- Every call matters
- Example: Sending chat messages

## When to Use Non-Reentrant

**Good candidates:**
- Load/refresh data buttons
- Form submissions
- Login/logout actions
- Any action where rapid duplicate calls should be ignored

**Not recommended:**
- Operations where every call matters (use `sequential` instead)
- Operations that should queue up
- Increment/decrement counters

## Complete Example

```dart
class ProductCubit extends Cubit<ProductState> {
  ProductCubit() : super(const ProductState());

  // Prevent duplicate loads
  void loadProducts() => mix(
    key: this,
    nonReentrant: nonReentrant,
    retry: retry,
    () async {
      final products = await api.getProducts();
      emit(state.copyWith(products: products));
    },
  );

  // Prevent double-delete on same item
  void deleteProduct(String id) => mix(
    key: (DeleteProduct, id),
    nonReentrant: nonReentrant,
    () async {
      await api.deleteProduct(id);
      emit(state.copyWith(
        products: state.products.where((p) => p.id != id).toList(),
      ));
    },
  );

  // Prevent double-submit
  void checkout() => mix(
    key: Checkout,
    nonReentrant: nonReentrant,
    () async {
      final order = await api.checkout(state.cart);
      emit(state.copyWith(order: order, cart: []));
    },
  );
}
```
