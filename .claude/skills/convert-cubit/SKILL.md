---
name: convert-cubit
description: Convert an existing Cubit to use mix() function, removing manual loading and error state management
---

# Convert an Existing Cubit to Use bloc_superpowers

This skill converts an existing Cubit to use the `mix()` function, removing manual loading/error state management.

## What This Skill Does

1. Wraps Cubit method bodies with `mix()`
2. Removes manual `isLoading` and `errorMessage` state management
3. Replaces error handling with `UserException`
4. Updates widgets to use `context.isWaiting()` and `context.isFailed()`

## Instructions

### Step 1: Identify the Cubit to Convert

Ask the user which Cubit they want to convert, or identify Cubits that have:
- `isLoading` field in state
- `errorMessage` or `error` field in state
- Manual `emit(state.copyWith(isLoading: true))` calls
- Try-catch blocks that set error state

### Step 2: Convert the Cubit Methods

**Before (manual state management):**

```dart
class UserCubit extends Cubit<UserState> {
  UserCubit() : super(UserState());

  Future<void> loadUser() async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final user = await api.getUser();
      if (user == null) {
        emit(state.copyWith(isLoading: false, errorMessage: 'Failed to load user'));
        return;
      }
      emit(state.copyWith(user: user, isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }
}
```

**After (with mix):**

```dart
import 'package:bloc_superpowers/bloc_superpowers.dart';

class UserCubit extends Cubit<UserState> {
  UserCubit() : super(UserState());

  void loadUser() => mix(
    key: this,
    () async {
      final user = await api.getUser();
      if (user == null) throw UserException('Failed to load user');
      emit(state.copyWith(user: user));
    },
  );
}
```

### Step 3: Remove Loading/Error Fields from State

**Before:**

```dart
class UserState {
  final User? user;
  final bool isLoading;
  final String? errorMessage;

  UserState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
  });

  UserState copyWith({
    User? user,
    bool? isLoading,
    String? errorMessage,
  }) {
    return UserState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
```

**After:**

```dart
class UserState {
  final User? user;
  const UserState({this.user});

  UserState copyWith({User? user}) {
    return UserState(user: user ?? this.user);
  }
}
```

### Step 4: Update Widgets

**Before (reading state fields):**

```dart
class UserWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<UserCubit>().state;

    if (state.isLoading) {
      return const CircularProgressIndicator();
    }

    if (state.errorMessage != null) {
      return Text('Error: ${state.errorMessage}');
    }

    return Text('Hello, ${state.user?.name}');
  }
}
```

**After (using context extensions):**

```dart
class UserWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (context.isWaiting(UserCubit)) {
      return const CircularProgressIndicator();
    }

    if (context.isFailed(UserCubit)) {
      return Text('Error: ${context.getException(UserCubit)}');
    }

    final state = context.watch<UserCubit>().state;
    return Text('Hello, ${state.user?.name}');
  }
}
```

### Step 5: Handle Multiple Methods

If a Cubit has multiple methods that need separate loading states, use different keys:

**Option A: Same key for all methods (shared loading state)**

```dart
class UserCubit extends Cubit<UserState> {
  void loadUser() => mix(
    key: this,  // All methods share UserCubit key
    () async { ... },
  );

  void updateUser(User user) => mix(
    key: this,  // Same key
    () async { ... },
  );
}

// Widget shows loading for ANY operation:
if (context.isWaiting(UserCubit)) { ... }
```

**Option B: Different keys per method (separate loading states)**

```dart
enum UserAction { load, update, delete }

class UserCubit extends Cubit<UserState> {
  void loadUser() => mix(
    key: UserAction.load,
    () async { ... },
  );

  void updateUser(User user) => mix(
    key: UserAction.update,
    () async { ... },
  );
}

// Widget can check specific operations:
if (context.isWaiting(UserAction.load)) { ... }
if (context.isWaiting(UserAction.update)) { ... }
```

## Conversion Checklist

For each Cubit being converted:

- [ ] Add import: `import 'package:bloc_superpowers/bloc_superpowers.dart';`
- [ ] Wrap method body with `mix(key: this, () async { ... })`
- [ ] Remove `emit(state.copyWith(isLoading: true))` calls
- [ ] Remove `emit(state.copyWith(isLoading: false))` calls
- [ ] Replace error state emissions with `throw UserException('message')`
- [ ] Remove try-catch blocks (unless needed for specific error handling)
- [ ] Remove `isLoading` field from state class
- [ ] Remove `errorMessage`/`error` field from state class
- [ ] Update `copyWith` to remove loading/error parameters
- [ ] Update widgets: replace `state.isLoading` with `context.isWaiting(CubitType)`
- [ ] Update widgets: replace `state.errorMessage` with `context.isFailed(CubitType)` and `context.getException(CubitType)`

## Common Patterns

### Converting Conditional Error Returns

**Before:**
```dart
if (user == null) {
  emit(state.copyWith(isLoading: false, errorMessage: 'Not found'));
  return;
}
```

**After:**
```dart
if (user == null) throw UserException('User not found');
```

### Converting Catch Blocks

**Before:**
```dart
try {
  final data = await api.getData();
  emit(state.copyWith(data: data, isLoading: false));
} catch (e) {
  emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
}
```

**After:**
```dart
mix(
  key: this,
  () async {
    final data = await api.getData();
    emit(state.copyWith(data: data));
  },
);
// Errors automatically tracked; UserExceptionDialog shows them
```

### Converting with Custom Error Messages

**Before:**
```dart
try {
  await api.saveUser(user);
} on NetworkException {
  emit(state.copyWith(errorMessage: 'No internet connection'));
} on ValidationException catch (e) {
  emit(state.copyWith(errorMessage: e.message));
} catch (e) {
  emit(state.copyWith(errorMessage: 'Something went wrong'));
}
```

**After:**
```dart
mix(
  key: this,
  catchError: (error, stackTrace) {
    if (error is NetworkException) {
      throw UserException('No internet connection');
    } else if (error is ValidationException) {
      throw UserException(error.message);
    } else {
      throw UserException('Something went wrong');
    }
  },
  () async {
    await api.saveUser(user);
  },
);
```
