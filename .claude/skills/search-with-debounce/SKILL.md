---
name: search-with-debounce
description: Implement search-as-you-type with debounce and loading states to avoid excessive API calls
---

# Implement Search with Debounce

This skill implements search-as-you-type with debounce and loading states.

## What This Skill Does

Creates a search feature that:
- Debounces user input to avoid excessive API calls
- Shows loading state while searching
- Displays results when ready

## Implementation

### Step 1: Create the Cubit

```dart
import 'package:bloc_superpowers/bloc_superpowers.dart';

class SearchState {
  final String query;
  final List<SearchResult> results;

  const SearchState({
    this.query = '',
    this.results = const [],
  });

  SearchState copyWith({
    String? query,
    List<SearchResult>? results,
  }) => SearchState(
    query: query ?? this.query,
    results: results ?? this.results,
  );
}

class SearchCubit extends Cubit<SearchState> {
  SearchCubit() : super(const SearchState());

  void search(String query) => mix(
    key: this,
    debounce: debounce(duration: 300.millis),
    () async {
      // Update query immediately
      emit(state.copyWith(query: query));

      // Skip empty queries
      if (query.trim().isEmpty) {
        emit(state.copyWith(results: []));
        return;
      }

      // Search API
      final results = await api.search(query);
      emit(state.copyWith(results: results));
    },
  );

  void clear() {
    emit(const SearchState());
  }
}
```

### Step 2: Create the Widget

```dart
class SearchScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: SearchField(),
      ),
      body: SearchResults(),
    );
  }
}

class SearchField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Search...',
        border: InputBorder.none,
        suffixIcon: context.isWaiting(SearchCubit)
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : const Icon(Icons.search),
      ),
      onChanged: (value) => context.read<SearchCubit>().search(value),
    );
  }
}

class SearchResults extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<SearchCubit>().state;

    if (state.query.isEmpty) {
      return const Center(
        child: Text('Enter a search term'),
      );
    }

    if (context.isWaiting(SearchCubit)) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (context.isFailed(SearchCubit)) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: ${context.getException(SearchCubit)}'),
            ElevatedButton(
              onPressed: () => context.read<SearchCubit>().search(state.query),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.results.isEmpty) {
      return Center(
        child: Text('No results for "${state.query}"'),
      );
    }

    return ListView.builder(
      itemCount: state.results.length,
      itemBuilder: (context, index) {
        final result = state.results[index];
        return ListTile(
          title: Text(result.title),
          subtitle: Text(result.description),
          onTap: () => Navigator.pushNamed(
            context,
            '/details/${result.id}',
          ),
        );
      },
    );
  }
}
```

## With Per-Category Search

```dart
class SearchCubit extends Cubit<SearchState> {
  void searchInCategory(String category, String query) => mix(
    key: (Search, category),  // Per-category loading state
    debounce: debounce(
      key: (Search, category),  // Per-category debounce
      duration: 300.millis,
    ),
    () async {
      if (query.trim().isEmpty) {
        emit(state.copyWithCategory(category, []));
        return;
      }

      final results = await api.searchInCategory(category, query);
      emit(state.copyWithCategory(category, results));
    },
  );
}

// Widget
class CategorySearchField extends StatelessWidget {
  final String category;

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Search in $category...',
        suffixIcon: context.isWaiting((Search, category))
            ? const CircularProgressIndicator()
            : const Icon(Icons.search),
      ),
      onChanged: (value) =>
          context.read<SearchCubit>().searchInCategory(category, value),
    );
  }
}
```

## Complete Example

```dart
// State
class SearchState {
  final String query;
  final List<Product> results;

  const SearchState({this.query = '', this.results = const []});

  SearchState copyWith({String? query, List<Product>? results}) =>
      SearchState(query: query ?? this.query, results: results ?? this.results);
}

// Cubit
class SearchCubit extends Cubit<SearchState> {
  final Api api;
  SearchCubit(this.api) : super(const SearchState());

  void search(String query) => mix(
    key: this,
    debounce: debounce(duration: 300.millis),
    () async {
      emit(state.copyWith(query: query));

      if (query.trim().isEmpty) {
        emit(state.copyWith(results: []));
        return;
      }

      final results = await api.searchProducts(query);
      emit(state.copyWith(results: results));
    },
  );
}

// Screen
class ProductSearchScreen extends StatefulWidget {
  @override
  State<ProductSearchScreen> createState() => _ProductSearchScreenState();
}

class _ProductSearchScreenState extends State<ProductSearchScreen> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SearchCubit>().state;
    final isSearching = context.isWaiting(SearchCubit);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: 'Search products...',
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: isSearching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          context.read<SearchCubit>().search('');
                        },
                      )
                    : null,
          ),
          onChanged: (value) => context.read<SearchCubit>().search(value),
        ),
      ),
      body: _buildBody(context, state, isSearching),
    );
  }

  Widget _buildBody(BuildContext context, SearchState state, bool isSearching) {
    if (state.query.isEmpty) {
      return const Center(child: Text('Search for products'));
    }

    if (isSearching && state.results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.results.isEmpty) {
      return Center(child: Text('No results for "${state.query}"'));
    }

    return ListView.builder(
      itemCount: state.results.length,
      itemBuilder: (context, index) {
        final product = state.results[index];
        return ListTile(
          leading: Image.network(product.imageUrl, width: 50, height: 50),
          title: Text(product.name),
          subtitle: Text('\$${product.price}'),
          onTap: () => Navigator.pushNamed(context, '/product/${product.id}'),
        );
      },
    );
  }
}
```

## Key Points

1. **Debounce duration**: 300ms is typical for search; adjust based on API speed
2. **Handle empty queries**: Clear results for empty input
3. **Show loading inline**: Use suffix icon in text field
4. **Keep showing results**: Don't clear results while loading new ones
