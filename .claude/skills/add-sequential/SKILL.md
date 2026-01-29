---
name: add-sequential
description: Add sequential queue processing to ensure Cubit method calls execute one after another in order
---

# Add Sequential Queue Processing

This skill queues Cubit method calls and processes them one after another in order.

## What This Skill Does

Adds the `sequential` parameter to a `mix()` call so that:
- Method calls are queued instead of running concurrently
- Each call waits for the previous one to complete
- All calls execute in the order they were made

## Instructions

### Step 1: Identify the Method

Ask the user which Cubit method needs sequential processing, or identify methods that:
- Must execute in order (messages, transactions)
- Should not run concurrently (database writes)
- Every call matters and must complete

### Step 2: Add Sequential

Add `sequential: sequential` to the `mix()` call:

```dart
import 'package:bloc_superpowers/bloc_superpowers.dart';

class ChatCubit extends Cubit<ChatState> {
  ChatCubit() : super(const ChatState());

  void sendMessage(String text) => mix(
    key: this,
    sequential: sequential,  // Add this line
    () async {
      final message = await api.sendMessage(text);
      emit(state.copyWith(
        messages: [...state.messages, message],
      ));
    },
  );
}
```

### Step 3: Understand the Behavior

With `sequential`:
- **First call**: Executes immediately
- **Second call while first is running**: Queued, waits for first to complete
- **Third call**: Queued behind second
- All calls execute in order, one at a time

```dart
// User sends 3 messages rapidly
cubit.sendMessage('Hello');    // Executes immediately
cubit.sendMessage('How');      // Queued (waits for first)
cubit.sendMessage('Are you?'); // Queued (waits for second)
// Result: Messages sent in order: "Hello", "How", "Are you?"
```

## Configuration Options

### Default Parameters

```dart
sequential(
  key: null,              // Uses mix key by default
  maxQueueSize: null,     // Unlimited queue
  queueTimeout: null,     // No timeout
  dropOldest: false,      // Drop newest when queue full
)
```

### Limited Queue Size

Prevent memory issues with large queues:

```dart
void processItem(Item item) => mix(
  key: this,
  sequential: sequential(maxQueueSize: 10),
  () async {
    await api.process(item);
  },
);
```

When queue is full:
- Default: New calls are dropped
- With `dropOldest: true`: Oldest queued call is dropped

### Queue Timeout

Discard calls that wait too long:

```dart
void sendMessage(String text) => mix(
  key: this,
  sequential: sequential(queueTimeout: 30.sec),
  () async {
    await api.sendMessage(text);
  },
);
```

Calls waiting longer than 30 seconds are discarded.

### Latest Wins (Keep Only Most Recent)

For operations where only the final value matters:

```dart
void updateSettings(Settings settings) => mix(
  key: this,
  sequential: sequential.latestWins,
  () async {
    await api.saveSettings(settings);
  },
);
```

`sequential.latestWins` is shorthand for:
```dart
sequential(maxQueueSize: 1, dropOldest: true)
```

### Per-Item Queues with Custom Key

Different items can have separate queues:

```dart
void sendMessage(String chatId, String text) => mix(
  key: this,
  sequential: sequential(key: (ChatCubit, chatId)),
  () async {
    await api.sendMessage(chatId, text);
  },
);
```

With this setup:
- Messages to chat A queue together
- Messages to chat B queue together
- Messages to different chats can run concurrently

## Common Patterns

### Order Processing

```dart
void processOrder(Order order) => mix(
  key: this,
  sequential: sequential,
  () async {
    await api.processOrder(order);
    emit(state.copyWith(
      processedOrders: [...state.processedOrders, order],
    ));
  },
);
```

### Message Sending

```dart
void sendMessage(String text) => mix(
  key: this,
  sequential: sequential(queueTimeout: 30.sec),
  retry: retry,
  () async {
    final message = await api.sendMessage(text);
    emit(state.copyWith(messages: [...state.messages, message]));
  },
);
```

### Per-Chat Message Queue

```dart
void sendMessage(String chatId, String text) => mix(
  key: (SendMessage, chatId),
  sequential: sequential,  // Inherits key from mix
  () async {
    await api.sendMessage(chatId, text);
  },
);
```

### Settings Save (Latest Wins)

```dart
void saveSettings(Settings settings) => mix(
  key: this,
  sequential: sequential.latestWins,
  () async {
    await api.saveSettings(settings);
    emit(settings);
  },
);
```

### Accessing Queue Context

Use `mix.ctx` to access queue information:

```dart
void processItem(Item item) => mix.ctx(
  key: this,
  sequential: sequential,
  (ctx) async {
    final wasQueued = ctx.sequential!.wasQueued;  // Was this call queued?
    final index = ctx.sequential!.index;          // Position in queue

    if (wasQueued) {
      print('Processing queued item at position $index');
    }

    await api.process(item);
  },
);
```

## Sequential vs Non-Reentrant

| Feature | Duplicate Calls | Use Case |
|---------|-----------------|----------|
| `sequential` | Queued and executed in order | Every call matters |
| `nonReentrant` | Dropped/ignored | Only first call matters |

**Use `sequential` for:**
- Sending messages
- Processing orders
- Database mutations
- Any operation where every call must execute

**Use `nonReentrant` for:**
- Loading data
- Refresh operations
- Idempotent actions

## Complete Example

```dart
class OrderCubit extends Cubit<OrderState> {
  OrderCubit() : super(const OrderState());

  // Queue all orders for sequential processing
  void submitOrder(Order order) => mix(
    key: this,
    sequential: sequential(
      maxQueueSize: 100,
      queueTimeout: 60.sec,
    ),
    retry: retry,
    () async {
      emit(state.copyWith(processingOrder: order));
      final result = await api.submitOrder(order);
      emit(state.copyWith(
        processingOrder: null,
        completedOrders: [...state.completedOrders, result],
      ));
    },
  );
}
```

## User Preferences

Ask the user:
1. **Should there be a queue limit?** (to prevent memory issues)
2. **Should calls timeout?** (to discard stale requests)
3. **Latest wins?** (only final value matters)
4. **Per-item queues?** (separate queues by ID)
