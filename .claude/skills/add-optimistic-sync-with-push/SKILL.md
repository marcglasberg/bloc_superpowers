---
name: add-optimistic-sync-with-push
description: Add optimistic sync updates in apps with real-time push (like WebSocket etc) for non-blocking operations where only the final value matters and rapid changes coalesce
---

# Add Optimistic Sync with Server Push

This skill adds `optimisticSyncWithPush` for real-time apps that receive server-pushed updates via WebSockets, Firebase, or SSE.

## What This Skill Does

Implements optimistic updates for apps with:
- Real-time server pushes (WebSocket, Firebase, SSE)
- Multi-device editing
- Revision-based conflict resolution
- Out-of-order update handling

## When to Use

Use `optimisticSyncWithPush` when:
- Your app receives real-time updates from the server
- Multiple devices can modify the same data
- You need "last write wins" conflict resolution
- Updates may arrive out of order

Use `optimisticSync` instead if you don't have server-pushed updates.

## Comparison: optimisticSync vs optimisticSyncWithPush

| Feature | optimisticSync | optimisticSyncWithPush |
|---------|----------------|------------------------|
| Server pushes | Not supported | Full support |
| Multi-device | Single device | Multiple devices |
| Follow-up detection | Value comparison | Revision numbers |
| Complexity | Lower | Higher |

## Instructions

### Step 1: Understand the Requirements

Your server must:
1. Return monotonically increasing revision numbers
2. Accept `localRevision` and `deviceId` from clients
3. Include in pushes: `serverRevision`, `localRevision`, `deviceId`

### Step 2: Set Up State for Revisions

Your state needs to track server revisions:

```dart
class ItemState {
  final Map<String, Item> items;
  final Map<Object, int> revisions;  // Track revisions per key

  const ItemState({
    this.items = const {},
    this.revisions = const {},
  });

  ItemState copyWith({
    Map<String, Item>? items,
    Map<Object, int>? revisions,
  }) => ItemState(
    items: items ?? this.items,
    revisions: revisions ?? this.revisions,
  );
}
```

### Step 3: Implement optimisticSyncWithPush

```dart
import 'package:bloc_superpowers/bloc_superpowers.dart';

class ItemCubit extends Cubit<ItemState> {
  ItemCubit() : super(const ItemState());

  void toggleLike(String itemId) => optimisticSyncWithPush<bool>(
    // Key must match serverPush() key
    key: ('toggleLike', itemId),

    // Return the value to apply optimistically
    valueToApply: () => !state.items[itemId]!.isLiked,

    // Apply optimistic value to state
    applyOptimisticValueToState: (state, isLiked) => state.copyWith(
      items: {
        ...state.items,
        itemId: state.items[itemId]!.copyWith(isLiked: isLiked),
      },
    ),

    // Extract current value from state
    getValueFromState: (state) => state.items[itemId]!.isLiked,

    // Get stored server revision (-1 if unknown)
    getServerRevisionFromState: (state) =>
        state.revisions[('toggleLike', itemId)] ?? -1,

    // Send to server - MUST call informServerRevision()
    sendValueToServer: (
      isLiked,
      localRevision,
      deviceId,
      informServerRevision,
    ) async {
      final response = await api.setLiked(
        itemId: itemId,
        isLiked: isLiked,
        localRevision: localRevision,
        deviceId: deviceId,
      );

      // CRITICAL: Must call this with server's revision
      informServerRevision(response.serverRevision);

      return response.isLiked;  // Return confirmed value
    },

    // Apply server response when stable
    applyServerResponseToState: (state, serverResponse) {
      final confirmedLiked = serverResponse as bool;
      return state.copyWith(
        items: {
          ...state.items,
          itemId: state.items[itemId]!.copyWith(isLiked: confirmedLiked),
        },
      );
    },
  );
}
```

### Step 4: Handle Server Pushes

When your app receives a push from the server (WebSocket message, Firebase update, etc.):

```dart
class ItemCubit extends Cubit<ItemState> {
  // Called when receiving server push
  void handleLikePush(PushData data) => serverPush<bool>(
    // Key must match optimisticSyncWithPush key
    key: ('toggleLike', data.itemId),

    // Push metadata from server
    pushMetadata: (
      data.serverRevision,  // Server's revision number
      data.localRevision,   // Client's revision (echoed back)
      data.deviceId,        // Originating device ID
    ),

    // Get stored revision
    getServerRevisionFromState: (state) =>
        state.revisions[('toggleLike', data.itemId)] ?? -1,

    // Apply push and store new revision
    applyServerPushToState: (state, serverRevision) => state.copyWith(
      items: {
        ...state.items,
        data.itemId: state.items[data.itemId]!.copyWith(isLiked: data.isLiked),
      },
      revisions: {
        ...state.revisions,
        ('toggleLike', data.itemId): serverRevision,
      },
    ),
  );
}
```

## Required Parameters

### For optimisticSyncWithPush

| Parameter | Purpose |
|-----------|---------|
| `key` | Unique identifier (must match serverPush key) |
| `valueToApply` | Returns optimistic value |
| `applyOptimisticValueToState` | Applies value to state |
| `getValueFromState` | Extracts current value |
| `getServerRevisionFromState` | Returns stored revision (-1 if unknown) |
| `sendValueToServer` | Sends to server, **must call informServerRevision()** |
| `applyServerResponseToState` | Applies server response when stable |

### For serverPush

| Parameter | Purpose |
|-----------|---------|
| `key` | Must match optimisticSyncWithPush key |
| `pushMetadata` | Tuple: (serverRevision, localRevision, deviceId) |
| `getServerRevisionFromState` | Returns stored revision |
| `applyServerPushToState` | Applies push and stores revision |

## Critical: informServerRevision

The `sendValueToServer` callback **MUST** call `informServerRevision()` with the server's revision. Failing to call this throws a `StateError`.

```dart
sendValueToServer: (value, localRevision, deviceId, informServerRevision) async {
  final response = await api.update(value, localRevision, deviceId);

  // REQUIRED - must call this!
  informServerRevision(response.serverRevision);

  return response.confirmedValue;
},
```

## Error Handling with onFinish

Use `onFinish` to recover from errors:

```dart
void toggleLike(String itemId) => optimisticSyncWithPush<bool>(
  key: ('toggleLike', itemId),
  // ... required params ...

  // Called when sync completes (success or failure)
  onFinish: (error) async {
    if (error != null) {
      // Reload from server on error
      final item = await api.getItem(itemId);
      return state.copyWith(
        items: {...state.items, itemId: item},
      );
    }
    return null;  // No state change on success
  },
);
```

## Device ID

By default, a random device ID is generated per app run. To persist across sessions:

```dart
void main() {
  // Set custom device ID generator
  optimisticSyncWithPushDeviceId = () => getPersistedDeviceId();

  runApp(MyApp());
}
```

## How Conflict Resolution Works

1. **User A** toggles like on Device 1 (revision 5)
2. **User B** toggles like on Device 2 (revision 5)
3. Both send to server with localRevision: 5
4. Server processes Device 1 first → revision 6
5. Server processes Device 2 → revision 7 (last write wins)
6. Both devices receive pushes with revision 7
7. Both UIs converge to the same state

## Complete Example

```dart
// State
class ItemState {
  final Map<String, Item> items;
  final Map<Object, int> revisions;

  const ItemState({
    this.items = const {},
    this.revisions = const {},
  });

  ItemState copyWith({
    Map<String, Item>? items,
    Map<Object, int>? revisions,
  }) => ItemState(
    items: items ?? this.items,
    revisions: revisions ?? this.revisions,
  );
}

// Cubit
class ItemCubit extends Cubit<ItemState> {
  final WebSocketService _ws;

  ItemCubit(this._ws) : super(const ItemState()) {
    // Listen for server pushes
    _ws.onLikeUpdate.listen(_handleLikePush);
  }

  // User action
  void toggleLike(String itemId) => optimisticSyncWithPush<bool>(
    key: ('like', itemId),
    valueToApply: () => !state.items[itemId]!.isLiked,
    applyOptimisticValueToState: (state, isLiked) => state.copyWith(
      items: {
        ...state.items,
        itemId: state.items[itemId]!.copyWith(isLiked: isLiked),
      },
    ),
    getValueFromState: (state) => state.items[itemId]!.isLiked,
    getServerRevisionFromState: (state) =>
        state.revisions[('like', itemId)] ?? -1,
    sendValueToServer: (isLiked, localRev, deviceId, informRev) async {
      final resp = await api.setLiked(itemId, isLiked, localRev, deviceId);
      informRev(resp.revision);  // CRITICAL
      return resp.isLiked;
    },
    applyServerResponseToState: (state, isLiked) => state.copyWith(
      items: {
        ...state.items,
        itemId: state.items[itemId]!.copyWith(isLiked: isLiked as bool),
      },
    ),
  );

  // Server push handler
  void _handleLikePush(LikePushData data) => serverPush<bool>(
    key: ('like', data.itemId),
    pushMetadata: (data.serverRev, data.localRev, data.deviceId),
    getServerRevisionFromState: (state) =>
        state.revisions[('like', data.itemId)] ?? -1,
    applyServerPushToState: (state, serverRev) => state.copyWith(
      items: {
        ...state.items,
        data.itemId: state.items[data.itemId]!.copyWith(isLiked: data.isLiked),
      },
      revisions: {
        ...state.revisions,
        ('like', data.itemId): serverRev,
      },
    ),
  );
}
```

## User Preferences

Ask the user:
1. **What real-time technology?** (WebSocket, Firebase, SSE)
2. **What data is being synced?** (likes, settings, etc.)
3. **How are revisions tracked on server?**
4. **Need persistent device ID?**
