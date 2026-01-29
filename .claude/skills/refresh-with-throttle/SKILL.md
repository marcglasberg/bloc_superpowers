---
name: refresh-with-throttle
description: Implement pull-to-refresh with throttle to prevent refresh spam and handle pagination
---

# Implement Pull-to-Refresh with Throttle

This skill implements pull-to-refresh with throttle to prevent refresh spam.

## What This Skill Does

Creates a refresh feature that:
- Throttles refresh requests to prevent spam
- Allows force refresh via pull-to-refresh gesture
- Shows loading state during refresh

## Implementation

### Step 1: Create the Cubit

```dart
import 'package:bloc_superpowers/bloc_superpowers.dart';

class FeedCubit extends Cubit<FeedState> {
  FeedCubit() : super(const FeedState());

  void refresh({bool force = false}) => mix(
    key: this,
    throttle: throttle(
      duration: 5.sec,
      ignoreThrottle: force,      // Force bypasses throttle
      removeLockOnError: true,    // Allow retry after error
    ),
    () async {
      final posts = await api.getPosts();
      emit(state.copyWith(posts: posts));
    },
  );

  void loadMore() => mix(
    key: LoadMore,
    throttle: throttle(duration: 500.millis),  // Throttle scroll loading
    () async {
      if (!state.hasMore) return;

      final nextPage = await api.getPosts(page: state.page + 1);
      emit(state.copyWith(
        posts: [...state.posts, ...nextPage.posts],
        page: state.page + 1,
        hasMore: nextPage.hasMore,
      ));
    },
  );
}
```

### Step 2: Create the Widget

```dart
class FeedScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feed')),
      body: RefreshIndicator(
        onRefresh: () async {
          // Force refresh bypasses throttle
          context.read<FeedCubit>().refresh(force: true);
        },
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final state = context.watch<FeedCubit>().state;

    if (context.isWaiting(FeedCubit) && state.posts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (context.isFailed(FeedCubit) && state.posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: ${context.getException(FeedCubit)}'),
            ElevatedButton(
              onPressed: () => context.read<FeedCubit>().refresh(force: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // Load more when near bottom
        if (notification.metrics.pixels >=
            notification.metrics.maxScrollExtent - 200) {
          context.read<FeedCubit>().loadMore();
        }
        return false;
      },
      child: ListView.builder(
        itemCount: state.posts.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.posts.length) {
            return context.isWaiting(LoadMore)
                ? const Center(child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ))
                : const SizedBox.shrink();
          }
          return PostCard(post: state.posts[index]);
        },
      ),
    );
  }
}
```

## Throttle Options Explained

```dart
throttle(
  duration: 5.sec,          // Minimum time between refreshes
  ignoreThrottle: force,    // true = bypass throttle
  removeLockOnError: true,  // Allow retry after error
)
```

| Option | Behavior |
|--------|----------|
| `duration` | Minimum time between allowed calls |
| `ignoreThrottle` | When true, ignores the throttle and resets timer |
| `removeLockOnError` | When true, allows immediate retry after failure |

## Complete Example

```dart
// State
class FeedState {
  final List<Post> posts;
  final int page;
  final bool hasMore;

  const FeedState({
    this.posts = const [],
    this.page = 1,
    this.hasMore = true,
  });

  FeedState copyWith({
    List<Post>? posts,
    int? page,
    bool? hasMore,
  }) => FeedState(
    posts: posts ?? this.posts,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
  );
}

// Cubit
class FeedCubit extends Cubit<FeedState> {
  final Api api;
  FeedCubit(this.api) : super(const FeedState());

  void loadInitial() => mix(
    key: this,
    () async {
      final result = await api.getPosts(page: 1);
      emit(FeedState(
        posts: result.posts,
        page: 1,
        hasMore: result.hasMore,
      ));
    },
  );

  void refresh({bool force = false}) => mix(
    key: this,
    throttle: throttle(
      duration: 5.sec,
      ignoreThrottle: force,
      removeLockOnError: true,
    ),
    () async {
      final result = await api.getPosts(page: 1);
      emit(FeedState(
        posts: result.posts,
        page: 1,
        hasMore: result.hasMore,
      ));
    },
  );

  void loadMore() => mix(
    key: LoadMore,
    throttle: throttle(duration: 500.millis),
    nonReentrant: nonReentrant,
    () async {
      if (!state.hasMore) return;

      final result = await api.getPosts(page: state.page + 1);
      emit(state.copyWith(
        posts: [...state.posts, ...result.posts],
        page: state.page + 1,
        hasMore: result.hasMore,
      ));
    },
  );
}

// Screen
class FeedScreen extends StatefulWidget {
  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    context.read<FeedCubit>().loadInitial();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<FeedCubit>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<FeedCubit>().state;
    final isRefreshing = context.isWaiting(FeedCubit);
    final isLoadingMore = context.isWaiting(LoadMore);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed'),
        actions: [
          if (isRefreshing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<FeedCubit>().refresh(force: true);
        },
        child: ListView.builder(
          controller: _scrollController,
          itemCount: state.posts.length + 1,
          itemBuilder: (context, index) {
            if (index == state.posts.length) {
              if (isLoadingMore) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (!state.hasMore) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No more posts'),
                  ),
                );
              }
              return const SizedBox.shrink();
            }
            return PostCard(post: state.posts[index]);
          },
        ),
      ),
    );
  }
}
```

## Key Points

1. **Use `force` parameter** for pull-to-refresh
2. **Set `removeLockOnError: true`** to allow retry after failures
3. **Throttle both refresh and loadMore** differently
4. **Keep showing existing data** while refreshing
