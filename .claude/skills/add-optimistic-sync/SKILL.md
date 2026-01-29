---
name: add-optimistic-sync
description: Add optimistic sync updates for non-blocking operations where only the final value matters and rapid changes coalesce
---

# Add Optimistic Sync

This skill adds `optimisticSync` for non-blocking operations where only the final value matters and rapid changes coalesce.

## What This Skill Does

Implements optimistic updates for **continuous/rapid operations** like:
- Toggle buttons (like, favorite, bookmark)
- Switches and checkboxes
- Sliders and ratings
- Settings that users may change rapidly

The UI updates immediately on every interaction, but only the final value is synced to the server.

## Instructions

### Step 1: Identify the Operation

Use `optimisticSync` when:
- Users may trigger the same action rapidly (toggle spam)
- Only the final value matters to the server
- Intermediate values can be skipped
- The operation is a sync, not a discrete command

### Step 2: Implement optimisticSync

```dart
import 'package:bloc_superpowers/bloc_superpowers.dart';

class ItemCubit extends Cubit<ItemState> {
  ItemCubit() : super(const ItemState());

  void toggleLike(String itemId) => optimisticSync<bool>(
    // Unique key per item
    key: ('toggleLike', itemId),

    // 1. Return the value to apply (toggle current)
    valueToApply: () => !state.items[itemId]!.isLiked,

    // 2. Apply optimistic value to state
    applyOptimisticValueToState: (state, isLiked) => state.copyWith(
      items: {
        ...state.items,
        itemId: state.items[itemId]!.copyWith(isLiked: isLiked),
      },
    ),

    // 3. Extract value from state (for follow-up detection)
    getValueFromState: (state) => state.items[itemId]!.isLiked,

    // 4. Send value to server
    sendValueToServer: (isLiked) async {
      await api.setLiked(itemId, isLiked);
      return null;
    },
  );
}
```

### Step 3: Understand the Flow

1. **User taps**: UI updates immediately
2. **First request**: Acquires lock, sends to server
3. **User taps again while request in flight**: UI updates, follow-up queued
4. **First request completes**: If state changed, sends follow-up with latest value
5. **State stabilizes**: Lock released when no pending changes

## How Coalescing Works

```
User rapidly toggles: ON → OFF → ON → OFF → ON
                      ↓
UI shows each change immediately
                      ↓
Request 1 sends: ON (locked)
                      ↓
User toggles to OFF, ON while Request 1 in flight
                      ↓
Request 1 completes, state is now ON
                      ↓
Follow-up sends: ON (current value)
                      ↓
No more changes → lock released

Result: Only 2 requests instead of 5, UI always responsive
```

## Required Parameters

| Parameter | Purpose |
|-----------|---------|
| `key` | Unique identifier per item/operation |
| `valueToApply` | Returns the value to apply optimistically |
| `applyOptimisticValueToState` | Applies value to state |
| `getValueFromState` | Extracts current value (for follow-up detection) |
| `sendValueToServer` | Sends value to server |

## Optional Parameters

### Apply Server Response

When the server returns data that should update the state:

```dart
void toggleLike(String itemId) => optimisticSync<bool>(
  key: ('toggleLike', itemId),
  valueToApply: () => !state.items[itemId]!.isLiked,
  applyOptimisticValueToState: (state, isLiked) => state.copyWith(...),
  getValueFromState: (state) => state.items[itemId]!.isLiked,
  sendValueToServer: (isLiked) async {
    final serverValue = await api.setLiked(itemId, isLiked);
    return serverValue;  // Return server confirmation
  },
  // Apply server-confirmed value when stable
  applyServerResponseToState: (state, serverResponse) {
    final serverLiked = serverResponse as bool;
    return state.copyWith(
      items: {
        ...state.items,
        itemId: state.items[itemId]!.copyWith(isLiked: serverLiked),
      },
    );
  },
);
```

### Handle Completion/Errors

The `onFinish` callback is called when sync completes:
- **Timing**: Lock releases BEFORE `onFinish` executes (allowing new syncs to start)
- **On success**: Runs after state stabilizes (no pending changes)
- **On failure**: Runs immediately after request failure
- **Return value**: Returning non-null state applies it to the cubit

```dart
void toggleLike(String itemId) => optimisticSync<bool>(
  key: ('toggleLike', itemId),
  // ... required params ...

  // Called when sync completes (success or failure)
  onFinish: (optimisticValue, error) async {
    if (error != null) {
      // Reload from server on error
      final item = await api.getItem(itemId);
      return state.copyWith(
        items: {...state.items, itemId: item},
      );
    }
    return null;  // No state change needed on success
  },
);
```

## Common Patterns

### Toggle Like/Favorite

```dart
void toggleLike(String itemId) => optimisticSync<bool>(
  key: ('toggleLike', itemId),
  valueToApply: () => !state.items[itemId]!.isLiked,
  applyOptimisticValueToState: (state, isLiked) => state.copyWith(
    items: state.items.map((id, item) => MapEntry(
      id,
      id == itemId ? item.copyWith(isLiked: isLiked) : item,
    )),
  ),
  getValueFromState: (state) => state.items[itemId]!.isLiked,
  sendValueToServer: (isLiked) async {
    await api.setLiked(itemId, isLiked);
    return null;
  },
);
```

### Toggle Switch/Checkbox

```dart
void toggleSetting(String settingKey) => optimisticSync<bool>(
  key: ('setting', settingKey),
  valueToApply: () => !state.settings[settingKey]!,
  applyOptimisticValueToState: (state, value) => state.copyWith(
    settings: {...state.settings, settingKey: value},
  ),
  getValueFromState: (state) => state.settings[settingKey]!,
  sendValueToServer: (value) async {
    await api.updateSetting(settingKey, value);
    return null;
  },
);
```

### Slider/Rating Value

```dart
void setRating(String itemId, int rating) => optimisticSync<int>(
  key: ('rating', itemId),
  valueToApply: () => rating,
  applyOptimisticValueToState: (state, rating) => state.copyWith(
    items: {
      ...state.items,
      itemId: state.items[itemId]!.copyWith(rating: rating),
    },
  ),
  getValueFromState: (state) => state.items[itemId]!.rating,
  sendValueToServer: (rating) async {
    await api.setRating(itemId, rating);
    return null;
  },
);
```

### Counter Increment/Decrement

```dart
void incrementCounter(String counterId, int delta) => optimisticSync<int>(
  key: ('counter', counterId),
  valueToApply: () => state.counters[counterId]! + delta,
  applyOptimisticValueToState: (state, value) => state.copyWith(
    counters: {...state.counters, counterId: value},
  ),
  getValueFromState: (state) => state.counters[counterId]!,
  sendValueToServer: (value) async {
    await api.setCounter(counterId, value);
    return null;
  },
);
```

## Widget Integration

```dart
class LikeButton extends StatelessWidget {
  final String itemId;

  @override
  Widget build(BuildContext context) {
    final item = context.watch<ItemCubit>().state.items[itemId]!;

    return IconButton(
      icon: Icon(
        item.isLiked ? Icons.favorite : Icons.favorite_border,
        color: item.isLiked ? Colors.red : null,
      ),
      onPressed: () => context.read<ItemCubit>().toggleLike(itemId),
    );
  }
}
```

## optimisticSync vs Other Approaches

| Approach | Behavior | Best For |
|----------|----------|----------|
| `optimisticSync` | Immediate UI + coalesced requests | Rapid toggles, sliders |
| `optimisticCommand` | Immediate UI + single request | Add/delete/submit |
| `debounce` | Waits for inactivity | Search input |
| `nonReentrant` | Drops duplicates | Load data |

## When to Use optimisticSync

**Good candidates:**
- Like/favorite/bookmark buttons
- Toggle switches
- Sliders and rating controls
- Any setting that users might change rapidly

**Use optimisticCommand instead for:**
- Add/create operations
- Delete operations
- Form submissions
- One-time commands

## User Preferences

Ask the user:
1. **What type of value?** (bool for toggle, int for slider/rating)
2. **Need server confirmation?** (use `applyServerResponseToState`)
3. **Need error recovery?** (use `onFinish` to reload on error)
