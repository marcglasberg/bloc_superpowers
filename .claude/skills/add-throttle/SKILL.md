---
name: add-throttle
description: Add throttle rate limiting to prevent too-frequent method calls for refresh, scroll, or API limits
---

# Add Throttle Rate Limiting

This skill rate-limits method execution to prevent too-frequent calls.

## What This Skill Does

Adds the `throttle` parameter to a `mix()` call so that:
- The first call executes immediately
- Subsequent calls within the throttle period are ignored
- After the period expires, the next call executes

## Instructions

### Step 1: Identify the Method

Ask the user which Cubit method needs throttling, or identify methods that:
- Could be triggered rapidly (scroll events, button spam)
- Should not execute too frequently (refresh, sync)
- Need rate limiting for performance or API limits

### Step 2: Add Throttle

Add `throttle: throttle` to the `mix()` call:

```dart
import 'package:bloc_superpowers/bloc_superpowers.dart';

class DataCubit extends Cubit<DataState> {
  DataCubit() : super(const DataState());

  void refresh() => mix(
    key: this,
    throttle: throttle,  // Add this line (default: 1 second)
    () async {
      final data = await api.fetchData();
      emit(state.copyWith(data: data));
    },
  );
}
```

### Step 3: Configure Duration

The default throttle duration is **1 second**. Customize as needed:

```dart
void refresh() => mix(
  key: this,
  throttle: throttle(duration: 5.sec),  // Rate limit to once per 5 seconds
  () async {
    final data = await api.fetchData();
    emit(state.copyWith(data: data));
  },
);
```

## How Throttle Works

```
User taps refresh rapidly: tap → tap → tap → tap → tap
                           ↓     ✗     ✗     ✗     ✗
                        executes (ignored until 1 second passes)
                           ↓
                     1 second later...
                           ↓
                        tap → executes
```

First call runs immediately, subsequent calls are blocked for the throttle period.

## Configuration Options

### Duration Examples

```dart
throttle                              // 1 second (default)
throttle(duration: 500.millis)        // 500ms
throttle(duration: 5.sec)             // 5 seconds
throttle(duration: 1.minutes)         // 1 minute
```

### Remove Lock on Error

Allow immediate retry if the method fails:

```dart
void refresh() => mix(
  key: this,
  throttle: throttle(
    duration: 5.sec,
    removeLockOnError: true,  // Allow retry after failure
  ),
  () async {
    final data = await api.fetchData();
    emit(state.copyWith(data: data));
  },
);
```

### Force Bypass Throttle

Allow bypassing the throttle with a parameter:

```dart
void refresh({bool force = false}) => mix(
  key: this,
  throttle: throttle(
    duration: 5.sec,
    ignoreThrottle: force,  // When true, ignores throttle
  ),
  () async {
    final data = await api.fetchData();
    emit(state.copyWith(data: data));
  },
);

// Normal call - respects throttle
cubit.refresh();

// Force refresh - ignores throttle
cubit.refresh(force: true);
```

### Per-Item Throttle with Custom Key

Different items can have separate throttle timers:

```dart
void refreshFeed(String feedId) => mix(
  key: this,
  throttle: throttle(key: (FeedCubit, feedId)),
  () async {
    final posts = await api.fetchFeed(feedId);
    emit(state.copyWith(feeds: {...state.feeds, feedId: posts}));
  },
);
```

With this setup:
- Refreshing feed "A" has its own throttle timer
- Refreshing feed "B" has its own throttle timer
- You can refresh different feeds independently

## Common Patterns

### Pull-to-Refresh

```dart
void refresh({bool force = false}) => mix(
  key: this,
  throttle: throttle(
    duration: 5.sec,
    ignoreThrottle: force,
    removeLockOnError: true,
  ),
  () async {
    final data = await api.getData();
    emit(state.copyWith(data: data));
  },
);

// In widget
RefreshIndicator(
  onRefresh: () async {
    context.read<DataCubit>().refresh(force: true);
  },
  child: DataList(),
)
```

### Scroll-Based Loading

```dart
void loadMore() => mix(
  key: LoadMore,
  throttle: throttle(duration: 500.millis),
  () async {
    final nextPage = await api.getNextPage(state.currentPage + 1);
    emit(state.copyWith(
      items: [...state.items, ...nextPage.items],
      currentPage: state.currentPage + 1,
    ));
  },
);
```

### Like/Favorite Button

```dart
void toggleLike(String itemId) => mix(
  key: (ToggleLike, itemId),
  throttle: throttle(duration: 1.sec),
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

### API with Rate Limits

```dart
void fetchData() => mix(
  key: this,
  throttle: throttle(duration: 1.sec),  // Match API rate limit
  retry: retry,
  () async {
    final data = await rateLimitedApi.getData();
    emit(data);
  },
);
```

## Throttle vs Debounce vs Fresh

| Feature | First Call | Subsequent Calls | Best For |
|---------|------------|------------------|----------|
| **Throttle** | Executes immediately | Blocked until period ends | Refresh, scroll, rate limits |
| **Debounce** | Waits for inactivity | Reset timer | Search, validation |
| **Fresh** | Executes if stale | Skipped if fresh | Caching loaded data |

**Throttle:** "Execute now, then wait before allowing again"
**Debounce:** "Wait until user stops, then execute"
**Fresh:** "Skip if we already have recent data"

## Manual Lock Control

Clear throttle locks manually when needed:

```dart
// Clear throttle for a specific key
Superpowers.removeThrottleLock(DataCubit);
Superpowers.removeThrottleLock((FeedCubit, feedId));

// Clear all throttle locks
Superpowers.removeAllThrottleLocks();
```

## Complete Example

```dart
class FeedCubit extends Cubit<FeedState> {
  FeedCubit() : super(const FeedState());

  // Throttle refresh to once per 5 seconds
  void refresh({bool force = false}) => mix(
    key: this,
    throttle: throttle(
      duration: 5.sec,
      ignoreThrottle: force,
      removeLockOnError: true,
    ),
    retry: retry,
    () async {
      final posts = await api.getPosts();
      emit(state.copyWith(posts: posts));
    },
  );

  // Throttle scroll-based loading
  void loadMore() => mix(
    key: LoadMore,
    throttle: throttle(duration: 500.millis),
    () async {
      if (state.hasMore) {
        final nextPage = await api.getPosts(page: state.page + 1);
        emit(state.copyWith(
          posts: [...state.posts, ...nextPage.posts],
          page: state.page + 1,
          hasMore: nextPage.hasMore,
        ));
      }
    },
  );
}

// Widget
class FeedScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<FeedCubit>().refresh(force: true);
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.pixels >=
              notification.metrics.maxScrollExtent - 200) {
            context.read<FeedCubit>().loadMore();
          }
          return false;
        },
        child: PostsList(),
      ),
    );
  }
}
```

## User Preferences

Ask the user:
1. **What duration?** (depends on use case and API limits)
2. **Allow force bypass?** (for pull-to-refresh)
3. **Remove lock on error?** (allow retry after failure)
4. **Per-item throttle?** (separate limits by ID)
