---
name: use-composite-key
description: Use Dart records as composite keys for per-item or per-parameter loading and error tracking
---

# Use Composite Keys for Granular State Tracking

This skill uses Dart records as composite keys for per-item or per-parameter loading/error tracking.

## What This Skill Does

Uses record keys like `(CubitType, id)` to:
- Track loading/error states for individual items
- Allow concurrent operations on different items
- Show per-item loading indicators
- Handle per-item errors independently

## Instructions

### Step 1: Identify the Need

Use composite keys when:
- Operations have parameters (user ID, product ID, etc.)
- You need per-item loading indicators
- Different items should have independent loading/error states
- Concurrent operations on different items are needed

### Step 2: Use Record Key in Cubit

Instead of `key: this`, use a record combining the action and parameter:

```dart
class ProductCubit extends Cubit<ProductState> {
  // Per-product loading state
  void loadProduct(String productId) => mix(
    key: (LoadProduct, productId),  // Composite key
    () async {
      final product = await api.getProduct(productId);
      emit(state.copyWith(
        products: {...state.products, productId: product},
      ));
    },
  );

  // Per-product delete state
  void deleteProduct(String productId) => mix(
    key: (DeleteProduct, productId),  // Different action, same pattern
    () async {
      await api.deleteProduct(productId);
      emit(state.copyWith(
        products: state.products..remove(productId),
      ));
    },
  );
}
```

### Step 3: Check State in Widget with Same Key

Use the exact same key structure in the widget:

```dart
Widget build(BuildContext context) {
  return ListView.builder(
    itemCount: productIds.length,
    itemBuilder: (context, index) {
      final productId = productIds[index];

      // Check loading for THIS specific product
      if (context.isWaiting((LoadProduct, productId))) {
        return const ProductSkeleton();
      }

      // Check error for THIS specific product
      if (context.isFailed((LoadProduct, productId))) {
        return ProductErrorTile(
          error: context.getException((LoadProduct, productId)),
          onRetry: () => cubit.loadProduct(productId),
        );
      }

      return ProductTile(product: state.products[productId]!);
    },
  );
}
```

## Key Types Comparison

| Key Type | Example | Use Case |
|----------|---------|----------|
| `this` / Type | `key: this` → `UserCubit` | Single operation per Cubit |
| String | `key: 'loadData'` | Named operations |
| Enum | `key: Action.load` | Categorized operations |
| Record | `key: (Action, id)` | Per-parameter operations |

## Key Behavior with `this`

When using `key: this` inside a Cubit method, the key becomes the Cubit's `runtimeType`, not
the instance. This means all instances of the same Cubit type share the same key for state
tracking.

```dart
// Both instances share the same key (UserCubit)
final cubit1 = UserCubit();
final cubit2 = UserCubit();
cubit1.loadUser();  // key: UserCubit
cubit2.loadUser();  // key: UserCubit (same key!)
```

## Key Equality

Dart's standard equality applies to keys:

| Type | Equality | Example |
|------|----------|---------|
| Primitives | Value-based | `'abc' == 'abc'` ✓ |
| Records | Structural | `(LoadUser, 'abc') == (LoadUser, 'abc')` ✓ |
| Objects | Identity (unless `==` overridden) | `MyClass() != MyClass()` |
| Types | Identity | `UserCubit == UserCubit` ✓ |

## Record Key Patterns

### Type + ID

```dart
// In Cubit
mix(key: (UserCubit, userId), ...)

// In Widget
context.isWaiting((UserCubit, userId))
```

### Action Enum + ID

```dart
enum ProductAction { load, delete, update }

// In Cubit
mix(key: (ProductAction.delete, productId), ...)

// In Widget
context.isWaiting((ProductAction.delete, productId))
```

### Multiple Parameters

```dart
// In Cubit - category and subcategory
mix(key: (LoadProducts, categoryId, subcategoryId), ...)

// In Widget
context.isWaiting((LoadProducts, categoryId, subcategoryId))
```

### Named Record Fields

```dart
// In Cubit
mix(key: (action: 'delete', id: productId), ...)

// In Widget
context.isWaiting((action: 'delete', id: productId))
```

## Common Patterns

### Per-Item Delete Button

```dart
class ProductListItem extends StatelessWidget {
  final Product product;

  @override
  Widget build(BuildContext context) {
    final deleteKey = (DeleteProduct, product.id);

    return ListTile(
      title: Text(product.name),
      trailing: context.isWaiting(deleteKey)
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => context.read<ProductCubit>().delete(product.id),
            ),
    );
  }
}
```

### Per-Item Toggle (Like/Favorite)

```dart
class LikeButton extends StatelessWidget {
  final String itemId;
  final bool isLiked;

  @override
  Widget build(BuildContext context) {
    final key = (ToggleLike, itemId);

    if (context.isWaiting(key)) {
      return const CircularProgressIndicator();
    }

    return IconButton(
      icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border),
      onPressed: () => context.read<ItemCubit>().toggleLike(itemId),
    );
  }
}

// In Cubit
void toggleLike(String itemId) => mix(
  key: (ToggleLike, itemId),
  () async {
    await api.toggleLike(itemId);
    emit(state.copyWith(
      likedItems: state.likedItems.contains(itemId)
          ? state.likedItems.remove(itemId)
          : state.likedItems.add(itemId),
    ));
  },
);
```

### Per-Item Expansion/Load Details

```dart
class ExpandableItem extends StatelessWidget {
  final Item item;

  @override
  Widget build(BuildContext context) {
    final loadKey = (LoadDetails, item.id);

    return ExpansionTile(
      title: Text(item.name),
      onExpansionChanged: (expanded) {
        if (expanded && !state.hasDetails(item.id)) {
          context.read<ItemCubit>().loadDetails(item.id);
        }
      },
      children: [
        if (context.isWaiting(loadKey))
          const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          )
        else if (context.isFailed(loadKey))
          ListTile(
            title: Text('Error: ${context.getException(loadKey)}'),
            trailing: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => context.read<ItemCubit>().loadDetails(item.id),
            ),
          )
        else
          ItemDetails(details: state.getDetails(item.id)),
      ],
    );
  }
}
```

## Combining with Other mix() Parameters

### Per-Item with Non-Reentrant

```dart
void processItem(String itemId) => mix(
  key: (ProcessItem, itemId),
  nonReentrant: nonReentrant,  // Inherits key from mix
  () async {
    await api.process(itemId);
  },
);
```

### Per-Item with Throttle

```dart
void refreshItem(String itemId) => mix(
  key: (RefreshItem, itemId),
  throttle: throttle,  // Throttle per item
  () async {
    final item = await api.getItem(itemId);
    emit(state.copyWith(items: {...state.items, itemId: item}));
  },
);
```

### Shared State Tracking, Per-Item Freshness

```dart
void loadUser(String userId) => mix(
  key: UserCubit,  // State tracking shows ANY user loading
  fresh: fresh(
    key: (UserCubit, userId),  // Freshness tracked per user
    freshFor: 5.sec,
  ),
  () async {
    final user = await api.getUser(userId);
    emit(state.copyWith(users: {...state.users, userId: user}));
  },
);

// Widget shows loading for any user
if (context.isWaiting(UserCubit)) { ... }
```

## Complete Example

```dart
// Cubit
class CartCubit extends Cubit<CartState> {
  CartCubit() : super(const CartState());

  void updateQuantity(String itemId, int quantity) => mix(
    key: (UpdateQuantity, itemId),
    debounce: debounce(duration: 500.millis),
    () async {
      await api.updateCartItem(itemId, quantity);
      emit(state.copyWith(
        items: state.items.map((item) =>
          item.id == itemId ? item.copyWith(quantity: quantity) : item
        ).toList(),
      ));
    },
  );

  void removeItem(String itemId) => mix(
    key: (RemoveItem, itemId),
    () async {
      await api.removeFromCart(itemId);
      emit(state.copyWith(
        items: state.items.where((i) => i.id != itemId).toList(),
      ));
    },
  );
}

// Widget
class CartItemTile extends StatelessWidget {
  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final removeKey = (RemoveItem, item.id);
    final updateKey = (UpdateQuantity, item.id);

    return ListTile(
      title: Text(item.name),
      subtitle: context.isWaiting(updateKey)
          ? const Text('Updating...')
          : Text('Qty: ${item.quantity}'),
      trailing: context.isWaiting(removeKey)
          ? const CircularProgressIndicator()
          : IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => context.read<CartCubit>().removeItem(item.id),
            ),
      onTap: () => _showQuantityDialog(context),
    );
  }
}
```

## Best Practices

- **Use `key: this`** for simple single-method scenarios where one loading state is enough
- **Use records** for parameterized actions - include only distinguishing parameters
- **Keep keys minimal** - don't include unnecessary data in keys
- **Share Types across Cubits** for coordinated features that need to show the same state
- **Be consistent** - use the same key pattern for related operations

## User Preferences

Ask the user:
1. **What parameters need separate tracking?** (item ID, user ID, etc.)
2. **What action types exist?** (load, delete, update, etc.)
3. **Should actions be enums or strings?**
