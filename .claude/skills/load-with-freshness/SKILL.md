---
name: load-with-freshness
description: Load data with freshness caching pattern to skip redundant API calls when data is still fresh
---

# Load Data with Freshness Caching

This skill loads data with freshness caching to prevent redundant API calls.

## What This Skill Does

Creates a loading pattern that:
- Caches data for a specified duration
- Skips redundant loads when data is fresh
- Allows force refresh when needed

## Use Case

Perfect for:
- Screen data that doesn't change frequently
- User profiles
- Settings and configuration
- Product catalogs

## Implementation

### Step 1: Create the Cubit

```dart
import 'package:bloc_superpowers/bloc_superpowers.dart';

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit() : super(const ProfileState());

  void loadProfile({bool force = false}) => mix(
    key: this,
    fresh: fresh(
      freshFor: 30.sec,      // Data stays fresh for 30 seconds
      ignoreFresh: force,    // Force bypasses freshness
    ),
    () async {
      final profile = await api.getProfile();
      emit(state.copyWith(profile: profile));
    },
  );
}
```

### Step 2: Use in Widget

```dart
class ProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Load on screen entry - will skip if fresh
    useEffect(() {
      context.read<ProfileCubit>().loadProfile();
    }, []);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Force refresh bypasses freshness
              context.read<ProfileCubit>().loadProfile(force: true);
            },
          ),
        ],
      ),
      body: ProfileContent(),
    );
  }
}
```

## How Freshness Works

```
User enters screen
    ↓
loadProfile() called
    ↓
Is data fresh? (loaded within 30 seconds)
    ↓
Yes → Skip API call, use existing data
No  → Make API call, update data, mark fresh
```

## Configuration Options

### Duration Examples

```dart
fresh(freshFor: 5.sec)       // Very short - rapidly changing data
fresh(freshFor: 30.sec)      // Short - screen data
fresh(freshFor: 5.minutes)   // Medium - user profile
fresh(freshFor: 1.hours)     // Long - configuration
```

### Per-Item Freshness

```dart
void loadProduct(String productId) => mix(
  key: this,
  fresh: fresh(
    key: (ProductCubit, productId),  // Freshness per product
    freshFor: 5.minutes,
  ),
  () async {
    final product = await api.getProduct(productId);
    emit(state.copyWith(
      products: {...state.products, productId: product},
    ));
  },
);
```

### Shared State Tracking, Per-Item Freshness

```dart
void loadUser(String userId) => mix(
  key: UserCubit,  // Loading state shows ANY user loading
  fresh: fresh(
    key: (UserData, userId),  // Freshness tracked per user
    freshFor: 5.minutes,
  ),
  () async {
    final user = await api.getUser(userId);
    emit(state.copyWith(users: {...state.users, userId: user}));
  },
);
```

## Complete Example

```dart
// State
class ProductState {
  final Map<String, Product> products;
  final List<String> categories;

  const ProductState({
    this.products = const {},
    this.categories = const [],
  });

  ProductState copyWith({
    Map<String, Product>? products,
    List<String>? categories,
  }) => ProductState(
    products: products ?? this.products,
    categories: categories ?? this.categories,
  );
}

// Cubit
class ProductCubit extends Cubit<ProductState> {
  final Api api;
  ProductCubit(this.api) : super(const ProductState());

  // Categories fresh for 1 hour (rarely change)
  void loadCategories({bool force = false}) => mix(
    key: LoadCategories,
    fresh: fresh(
      freshFor: 1.hours,
      ignoreFresh: force,
    ),
    () async {
      final categories = await api.getCategories();
      emit(state.copyWith(categories: categories));
    },
  );

  // Products fresh for 5 minutes
  void loadProducts({bool force = false}) => mix(
    key: this,
    fresh: fresh(
      freshFor: 5.minutes,
      ignoreFresh: force,
    ),
    retry: retry,
    () async {
      final products = await api.getProducts();
      emit(state.copyWith(
        products: {for (var p in products) p.id: p},
      ));
    },
  );

  // Product details fresh per product
  void loadProductDetails(String productId, {bool force = false}) => mix(
    key: (ProductDetails, productId),
    fresh: fresh(
      freshFor: 10.minutes,
      ignoreFresh: force,
    ),
    () async {
      final product = await api.getProductDetails(productId);
      emit(state.copyWith(
        products: {...state.products, productId: product},
      ));
    },
  );
}

// List Screen
class ProductListScreen extends StatefulWidget {
  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  @override
  void initState() {
    super.initState();
    // Load on screen entry - skips if fresh
    context.read<ProductCubit>().loadCategories();
    context.read<ProductCubit>().loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            icon: context.isWaiting(ProductCubit)
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: () {
              // Force refresh
              context.read<ProductCubit>().loadProducts(force: true);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<ProductCubit>().loadProducts(force: true);
        },
        child: ProductGrid(),
      ),
    );
  }
}

// Detail Screen
class ProductDetailScreen extends StatefulWidget {
  final String productId;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Load details - skips if this product's data is fresh
    context.read<ProductCubit>().loadProductDetails(widget.productId);
  }

  @override
  Widget build(BuildContext context) {
    final product = context.watch<ProductCubit>().state.products[widget.productId];
    final isLoading = context.isWaiting((ProductDetails, widget.productId));

    if (isLoading && product == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(product?.name ?? 'Product')),
      body: ProductDetailContent(product: product!),
    );
  }
}
```

## Combining with Other Parameters

```dart
void loadData({bool force = false}) => mix(
  key: this,
  fresh: fresh(
    freshFor: 5.minutes,
    ignoreFresh: force,
  ),
  retry: retry,
  nonReentrant: nonReentrant,
  () async {
    final data = await api.getData();
    emit(data);
  },
);
```

## Manual Cache Control

```dart
// Clear freshness for specific key
Superpowers.removeFreshKey(ProductCubit);
Superpowers.removeFreshKey((ProductDetails, productId));

// Clear all freshness
Superpowers.removeAllFreshKeys();
```

## Key Points

1. **Choose duration wisely** based on how often data changes
2. **Use `force` parameter** for manual refresh
3. **Per-item freshness** for parameterized methods
4. **Combine with retry** for robust loading
5. **Clear freshness** after data mutations
