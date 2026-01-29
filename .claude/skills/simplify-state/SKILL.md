---
name: simplify-state
description: Remove isLoading and errorMessage fields from state classes and use context.isWaiting() and context.isFailed() instead
---

# Simplify State Classes with bloc_superpowers

This skill removes `isLoading` and `errorMessage` fields from state classes and updates widgets to use `context.isWaiting()` and `context.isFailed()` instead.

## What This Skill Does

1. Identifies state classes with loading/error fields
2. Removes those fields from the state class
3. Updates the `copyWith` method
4. Updates all widgets that reference those fields

## Instructions

### Step 1: Identify State Classes to Simplify

Look for state classes that have any of these fields:
- `isLoading`, `loading`, `isProcessing`
- `errorMessage`, `error`, `errorText`, `failure`
- `status` enums like `StateStatus.loading`, `StateStatus.error`

### Step 2: Remove Loading/Error Fields from State

**Before:**

```dart
class ProductState {
  final List<Product> products;
  final bool isLoading;
  final String? errorMessage;
  final Product? selectedProduct;
  final bool isSaving;

  const ProductState({
    this.products = const [],
    this.isLoading = false,
    this.errorMessage,
    this.selectedProduct,
    this.isSaving = false,
  });

  ProductState copyWith({
    List<Product>? products,
    bool? isLoading,
    String? errorMessage,
    Product? selectedProduct,
    bool? isSaving,
  }) {
    return ProductState(
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      selectedProduct: selectedProduct ?? this.selectedProduct,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}
```

**After:**

```dart
class ProductState {
  final List<Product> products;
  final Product? selectedProduct;

  const ProductState({
    this.products = const [],
    this.selectedProduct,
  });

  ProductState copyWith({
    List<Product>? products,
    Product? selectedProduct,
  }) {
    return ProductState(
      products: products ?? this.products,
      selectedProduct: selectedProduct ?? this.selectedProduct,
    );
  }
}
```

### Step 3: Update Cubit Methods

Remove all loading/error state emissions from the Cubit:

**Before:**

```dart
class ProductCubit extends Cubit<ProductState> {
  ProductCubit() : super(const ProductState());

  Future<void> loadProducts() async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final products = await api.getProducts();
      emit(state.copyWith(products: products, isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> saveProduct(Product product) async {
    emit(state.copyWith(isSaving: true));
    try {
      await api.saveProduct(product);
      emit(state.copyWith(isSaving: false));
    } catch (e) {
      emit(state.copyWith(isSaving: false, errorMessage: e.toString()));
    }
  }
}
```

**After:**

```dart
import 'package:bloc_superpowers/bloc_superpowers.dart';

enum ProductAction { load, save }

class ProductCubit extends Cubit<ProductState> {
  ProductCubit() : super(const ProductState());

  void loadProducts() => mix(
    key: ProductAction.load,
    () async {
      final products = await api.getProducts();
      emit(state.copyWith(products: products));
    },
  );

  void saveProduct(Product product) => mix(
    key: ProductAction.save,
    () async {
      await api.saveProduct(product);
    },
  );
}
```

### Step 4: Update Widget Loading Checks

**Before:**

```dart
Widget build(BuildContext context) {
  final state = context.watch<ProductCubit>().state;

  if (state.isLoading) {
    return const Center(child: CircularProgressIndicator());
  }

  // ... rest of widget
}
```

**After:**

```dart
Widget build(BuildContext context) {
  if (context.isWaiting(ProductAction.load)) {
    return const Center(child: CircularProgressIndicator());
  }

  final state = context.watch<ProductCubit>().state;
  // ... rest of widget
}
```

### Step 5: Update Widget Error Checks

**Before:**

```dart
Widget build(BuildContext context) {
  final state = context.watch<ProductCubit>().state;

  if (state.errorMessage != null) {
    return Column(
      children: [
        Text('Error: ${state.errorMessage}'),
        ElevatedButton(
          onPressed: () => context.read<ProductCubit>().loadProducts(),
          child: const Text('Retry'),
        ),
      ],
    );
  }

  // ... rest of widget
}
```

**After:**

```dart
Widget build(BuildContext context) {
  if (context.isFailed(ProductAction.load)) {
    return Column(
      children: [
        Text('Error: ${context.getException(ProductAction.load)}'),
        ElevatedButton(
          onPressed: () => context.read<ProductCubit>().loadProducts(),
          child: const Text('Retry'),
        ),
      ],
    );
  }

  final state = context.watch<ProductCubit>().state;
  // ... rest of widget
}
```

### Step 6: Update Save/Submit Button States

**Before:**

```dart
ElevatedButton(
  onPressed: state.isSaving ? null : () => cubit.saveProduct(product),
  child: state.isSaving
      ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : const Text('Save'),
)
```

**After:**

```dart
ElevatedButton(
  onPressed: context.isWaiting(ProductAction.save)
      ? null
      : () => context.read<ProductCubit>().saveProduct(product),
  child: context.isWaiting(ProductAction.save)
      ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : const Text('Save'),
)
```

## Choosing Keys Strategy

### Option A: Use Cubit Type (Simple)

When all methods share the same loading state:

```dart
// Cubit
void loadProducts() => mix(key: this, () async { ... });
void refreshProducts() => mix(key: this, () async { ... });

// Widget
if (context.isWaiting(ProductCubit)) { ... }
```

### Option B: Use Enum (Multiple Operations)

When different operations need separate loading states:

```dart
enum ProductAction { load, save, delete }

// Cubit
void loadProducts() => mix(key: ProductAction.load, () async { ... });
void saveProduct(p) => mix(key: ProductAction.save, () async { ... });
void deleteProduct(id) => mix(key: ProductAction.delete, () async { ... });

// Widget
if (context.isWaiting(ProductAction.load)) { ... }  // Loading products
if (context.isWaiting(ProductAction.save)) { ... }  // Saving
```

### Option C: Use Records (Per-Item Operations)

When you need loading states per item:

```dart
// Cubit
void deleteProduct(String id) => mix(
  key: (ProductAction.delete, id),
  () async { ... },
);

// Widget - show spinner on specific item being deleted
if (context.isWaiting((ProductAction.delete, product.id))) {
  return const CircularProgressIndicator();
}
```

## Context Extension Reference

| Extension | Purpose | Example |
|-----------|---------|---------|
| `context.isWaiting(key)` | Check if operation is in progress | `context.isWaiting(UserCubit)` |
| `context.isFailed(key)` | Check if operation failed | `context.isFailed(UserCubit)` |
| `context.getException(key)` | Get the exception that was thrown | `context.getException(UserCubit)` |
| `context.clearException(key)` | Manually clear the error state | `context.clearException(UserCubit)` |

## Migration Checklist

For each state class:

- [ ] Remove `isLoading` / `loading` / `isProcessing` fields
- [ ] Remove `errorMessage` / `error` / `failure` fields
- [ ] Remove `status` enum if only used for loading/error
- [ ] Update `copyWith` method
- [ ] Update constructor

For each Cubit:

- [ ] Add `import 'package:bloc_superpowers/bloc_superpowers.dart';`
- [ ] Wrap methods with `mix()`
- [ ] Choose appropriate keys (Type, enum, or record)
- [ ] Remove loading state emissions
- [ ] Remove error state emissions
- [ ] Replace error handling with `throw UserException()`

For each widget:

- [ ] Replace `state.isLoading` with `context.isWaiting(key)`
- [ ] Replace `state.errorMessage != null` with `context.isFailed(key)`
- [ ] Replace `state.errorMessage` with `context.getException(key)`
- [ ] Update button disabled states
- [ ] Update loading indicator conditions
