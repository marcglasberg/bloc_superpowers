---
name: add-optimistic-command
description: Add optimisticCommand for blocking one-time actions with immediate UI updates and automatic rollback on failure
---

# Add Optimistic Command

This skill adds `optimisticCommand` for one-time actions with immediate UI updates and automatic rollback on failure.

## What This Skill Does

Implements optimistic updates for **blocking, one-time operations** like:
- Creating items (add todo, post message)
- Deleting items
- Form submissions
- File uploads
- Payments

The UI updates immediately, the server operation runs, and on failure the UI rolls back.

## Instructions

### Step 1: Identify the Operation

Use `optimisticCommand` when:
- The action should run once (not coalesce rapid calls)
- UI should update immediately for responsiveness
- Failure should revert the change
- The operation is a discrete command, not a continuous sync

### Step 2: Implement optimisticCommand

```dart
import 'package:bloc_superpowers/bloc_superpowers.dart';

class TodoCubit extends Cubit<TodoState> {
  TodoCubit() : super(const TodoState());

  void addTodo(Todo newTodo) => optimisticCommand(
    key: (AddTodo, newTodo.id),

    // 1. Return the optimistic value (new list with item added)
    optimisticValue: () => state.todoList.add(newTodo),

    // 2. Extract the value from current state
    getValueFromState: (state) => state.todoList,

    // 3. Apply a value back to state
    applyValueToState: (state, value) =>
        state.copyWith(todoList: value as List<Todo>),

    // 4. Send the command to the server
    sendCommandToServer: (optimisticValue) async {
      await api.saveTodo(newTodo);
      return null;  // Return server response if needed
    },
  );
}
```

### Step 3: Understand the Flow

1. **Non-reentrant check**: Prevents duplicate execution
2. **Capture initial state**: For potential rollback
3. **Apply optimistic update**: UI updates immediately
4. **Execute server command**: Async operation
5. **On success**: Optionally apply server response
6. **On failure**: Rollback to initial state (if safe)

**Rollback Safety:** Rollback only occurs if the current state value still matches the optimistic value. This prevents overwriting concurrent changes made by other operations. If another update changed the value while the command was running, rollback is skipped to preserve that newer change.

## Required Parameters

| Parameter | Purpose |
|-----------|---------|
| `key` | Identifies the operation for state tracking and non-reentrant |
| `optimisticValue` | Returns the immediate UI value |
| `getValueFromState` | Extracts the relevant value from state |
| `applyValueToState` | Applies a value back to state |
| `sendCommandToServer` | Executes the server operation |

## Optional Parameters

### Apply Server Response

When the server returns data that should update the state:

```dart
void addTodo(Todo newTodo) => optimisticCommand(
  key: (AddTodo, newTodo.id),
  optimisticValue: () => state.todoList.add(newTodo),
  getValueFromState: (state) => state.todoList,
  applyValueToState: (state, value) =>
      state.copyWith(todoList: value as List<Todo>),
  sendCommandToServer: (optimisticValue) async {
    final savedTodo = await api.saveTodo(newTodo);
    return savedTodo;  // Return server response
  },
  // Replace client-side todo with server-side todo
  applyServerResponseToState: (state, serverResponse) {
    final savedTodo = serverResponse as Todo;
    return state.copyWith(
      todoList: state.todoList
          .where((t) => t.id != newTodo.id)
          .toList()
        ..add(savedTodo),
    );
  },
);
```

### Reload from Server

Reload data after success or failure:

```dart
void deleteTodo(String todoId) => optimisticCommand(
  key: (DeleteTodo, todoId),
  optimisticValue: () =>
      state.todoList.where((t) => t.id != todoId).toList(),
  getValueFromState: (state) => state.todoList,
  applyValueToState: (state, value) =>
      state.copyWith(todoList: value as List<Todo>),
  sendCommandToServer: (optimisticValue) async {
    await api.deleteTodo(todoId);
    return null;
  },
  // Reload after operation
  reloadFromServer: () async {
    return await api.loadTodoList();
  },
  // Control when to reload
  shouldReload: ({
    required currentValue,
    required lastAppliedValue,
    required optimisticValue,
    required rollbackValue,
    required error,
  }) => error != null,  // Only reload on failure
);
```

### Custom Rollback

Customize how rollback works:

```dart
void addTodo(Todo newTodo) => optimisticCommand(
  key: (AddTodo, newTodo.id),
  // ... required params ...

  // Control whether to rollback
  shouldRollback: ({
    required currentValue,
    required initialValue,
    required optimisticValue,
    required error,
  }) => true,  // Default: always rollback on error

  // Custom rollback state (e.g., show failed status instead of removing)
  rollbackState: ({
    required state,
    required initialValue,
    required optimisticValue,
    required error,
  }) => state.copyWith(
    todoList: state.todoList.map((t) =>
      t.id == newTodo.id ? t.copyWith(status: TodoStatus.failed) : t
    ).toList(),
  ),
);
```

### Separate Non-Reentrant Key

Track loading state globally but prevent duplicates per item:

```dart
void addTodo(Todo newTodo) => optimisticCommand(
  key: AddTodo,  // isWaiting(AddTodo) shows any add in progress
  nonReentrantKey: (AddTodo, newTodo.id),  // Prevents duplicate for same todo
  // ... rest of params ...
);

// Widget
if (context.isWaiting(AddTodo)) {
  // Any add operation is in progress
}
```

## Common Patterns

### Add Item

```dart
void addItem(Item newItem) => optimisticCommand(
  key: (AddItem, newItem.id),
  optimisticValue: () => [...state.items, newItem],
  getValueFromState: (state) => state.items,
  applyValueToState: (state, value) =>
      state.copyWith(items: value as List<Item>),
  sendCommandToServer: (optimisticValue) async {
    await api.createItem(newItem);
    return null;
  },
);
```

### Delete Item

```dart
void deleteItem(String itemId) => optimisticCommand(
  key: (DeleteItem, itemId),
  optimisticValue: () =>
      state.items.where((i) => i.id != itemId).toList(),
  getValueFromState: (state) => state.items,
  applyValueToState: (state, value) =>
      state.copyWith(items: value as List<Item>),
  sendCommandToServer: (optimisticValue) async {
    await api.deleteItem(itemId);
    return null;
  },
);
```

### Update Item

```dart
void updateItem(Item updatedItem) => optimisticCommand(
  key: (UpdateItem, updatedItem.id),
  optimisticValue: () => state.items
      .map((i) => i.id == updatedItem.id ? updatedItem : i)
      .toList(),
  getValueFromState: (state) => state.items,
  applyValueToState: (state, value) =>
      state.copyWith(items: value as List<Item>),
  sendCommandToServer: (optimisticValue) async {
    await api.updateItem(updatedItem);
    return null;
  },
);
```

## Widget Integration

```dart
Widget build(BuildContext context) {
  final isSaving = context.isWaiting((AddTodo, todoId));

  return ListTile(
    title: Text(todo.title),
    trailing: isSaving
        ? const CircularProgressIndicator()
        : const Icon(Icons.check),
  );
}
```

## When to Use optimisticCommand vs optimisticSync

| Scenario | Use |
|----------|-----|
| Add/Delete/Update item | `optimisticCommand` |
| Form submission | `optimisticCommand` |
| Toggle (like/favorite) with fast taps | `optimisticSync` |
| Slider/rating value | `optimisticSync` |
| Settings that change rapidly | `optimisticSync` |

**Rule:** Use `optimisticCommand` for discrete actions, `optimisticSync` for values that may change rapidly.

## User Preferences

Ask the user:
1. **What type of operation?** (add, delete, update)
2. **Need server response in state?** (use `applyServerResponseToState`)
3. **Should reload on failure?** (use `reloadFromServer`)
4. **Custom rollback behavior?** (use `rollbackState`)
