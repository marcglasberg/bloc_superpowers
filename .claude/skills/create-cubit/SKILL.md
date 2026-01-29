---
name: create-cubit
description: Create a new Cubit using mix() function for automatic loading and error state tracking
---

# Create a Cubit with bloc_superpowers

This skill creates a new Cubit that uses the `mix()` function for automatic loading/error
state tracking.

## What This Skill Does

Creates a Cubit class that:

- Uses the `mix()` function to wrap async operations
- Automatically tracks loading states (no `isLoading` field needed)
- Automatically tracks error states (no `errorMessage` field needed)
- Throws `UserException` for user-facing errors

## Instructions

### Step 1: Gather Requirements

Ask the user:

1. **Cubit name**: What should the Cubit be called? (e.g., `UserCubit`, `ProductCubit`)
2. **State type**: What data does the state hold? (e.g., `User`, `List<Product>`, or a
   custom state class)
3. **Methods**: What async operations should the Cubit perform? (e.g., `loadData`, `save`,
   `delete`)

### Step 2: Create the Cubit

Create a Cubit that uses `mix()` with `key: this`:

```dart
import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class UserCubit extends Cubit<User?> {
  UserCubit() : super(null);

  void loadUser() => mix(
    key: this,
    () async {
      final user = await api.getUser();
      if (user == null) throw UserException('Failed to load user');
      emit(user);
    },
  );
}
```

### Step 3: Create the State Class (if needed)

For simple state (single value), use the value type directly:

```dart
class UserCubit extends Cubit<User?> { ... }
```

For complex state with multiple fields, create a state class **without** `isLoading` or
`errorMessage`:

```dart
class UserState {
  final User? user;
  final List<Post> posts;

  const UserState({this.user, this.posts = const []});

  UserState copyWith({User? user, List<Post>? posts}) {
    return UserState(
      user: user ?? this.user,
      posts: posts ?? this.posts,
    );
  }
}

class UserCubit extends Cubit<UserState> {
  UserCubit() : super(const UserState());

  void loadUser() => mix(
    key: this,
    () async {
      final user = await api.getUser();
      if (user == null) throw UserException('Failed to load user');
      emit(state.copyWith(user: user));
    },
  );

  void loadPosts() => mix(
    key: this,
    () async {
      final posts = await api.getPosts();
      emit(state.copyWith(posts: posts));
    },
  );
}
```

### Step 4: Use in Widgets

Show loading and error states using context extensions:

```dart
class UserWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Show loading indicator while loading
    if (context.isWaiting(UserCubit)) {
      return const CircularProgressIndicator();
    }

    // Show error message if failed
    if (context.isFailed(UserCubit)) {
      return Text('Error: ${context.getException(UserCubit)}');
    }

    // Show the data
    final user = context.watch<UserCubit>().state;
    return Text('Hello, ${user?.name ?? "Guest"}');
  }
}
```

## Syntax Variations

The `mix()` function supports multiple declaration patterns:

```dart
// Arrow function with void return (most common)
void loadUser() => mix(
  key: this,
  () async { ... },
);

// Arrow function with Future return (when caller needs to await)
Future<void> loadUser() => mix(
  key: this,
  () async { ... },
);

// Block syntax (when you need additional logic before/after mix)
void loadUser() {
  mix(
    key: this,
    () async { ... },
  );
}
```

## Available Parameters

The `mix()` function accepts optional parameters for enhanced behavior:

| Parameter | Purpose |
|-----------|---------|
| `retry` | Automatically retry failed operations with backoff |
| `nonReentrant` | Prevent concurrent executions of the same operation |
| `checkInternet` | Verify connectivity before executing |
| `fresh` | Cache freshness to skip redundant calls |
| `debounce` | Delay execution to prevent rapid calls |
| `throttle` | Limit execution frequency |
| `sequential` | Execute operations in order |
| `catchError` | Custom error handling |
| `config` | Reusable configuration bundle |

Each parameter has a dedicated skill for detailed usage.

## Key Patterns

### Using `key: this`

When you use `key: this` inside a Cubit method, it becomes the Cubit's `runtimeType`
(e.g., `UserCubit`), not the instance. This means:

- All methods in the Cubit share the same loading/error state
- Widgets check state using the Cubit type: `context.isWaiting(UserCubit)`

### Parameterized Keys (for granular tracking)

For methods with parameters where you need separate loading states per item:

```dart
void loadUser(String userId) => mix(
  key: (UserCubit, userId),  // Composite key using a record
  () async {
    final user = await api.getUser(userId);
    emit(state.copyWith(users: {...state.users, userId: user}));
  },
);

// In widget:
if (context.isWaiting((UserCubit, userId))) { ... }
```

### Throwing UserException

When something goes wrong, throw `UserException` with a user-friendly message:

```dart
void loadUser() => mix(
  key: this,
  () async {
    final user = await api.getUser();
    if (user == null) {
      throw UserException('Could not load your profile. Please try again.');
    }
    emit(user);
  },
);
```

## Complete Example

```dart
import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// State class (no isLoading or errorMessage!)
class TodoState {
  final List<Todo> todos;

  const TodoState({this.todos = const []});

  TodoState copyWith({List<Todo>? todos}) {
    return TodoState(todos: todos ?? this.todos);
  }
}

// Cubit with mix()
class TodoCubit extends Cubit<TodoState> {
  TodoCubit() : super(const TodoState());

  void loadTodos() => mix(
    key: this,
    () async {
      final todos = await api.getTodos();
      emit(state.copyWith(todos: todos));
    },
  );

  void addTodo(String title) => mix(
    key: this,
    () async {
      final newTodo = await api.createTodo(title);
      emit(state.copyWith(todos: [...state.todos, newTodo]));
    },
  );

  void deleteTodo(String id) => mix(
    key: (TodoCubit, 'delete', id),  // Separate key per delete operation
    () async {
      await api.deleteTodo(id);
      emit(state.copyWith(
        todos: state.todos.where((t) => t.id != id).toList(),
      ));
    },
  );
}

// Widget
class TodoScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (context.isWaiting(TodoCubit)) {
      return const Center(child: CircularProgressIndicator());
    }

    if (context.isFailed(TodoCubit)) {
      return Center(
        child: Column(
          children: [
            Text('Error: ${context.getException(TodoCubit)}'),
            ElevatedButton(
              onPressed: () => context.read<TodoCubit>().loadTodos(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final todos = context.watch<TodoCubit>().state.todos;
    return ListView.builder(
      itemCount: todos.length,
      itemBuilder: (context, index) => TodoTile(todo: todos[index]),
    );
  }
}
```
