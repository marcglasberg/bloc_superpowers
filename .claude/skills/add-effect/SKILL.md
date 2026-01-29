---
name: add-effect
description: Add Effect fields to state class for one-time UI notifications like snackbars, navigation, or form clearing
---

# Add Effect to State

This skill adds an `Effect` field to a state class for one-time UI notifications.

## What This Skill Does

Adds `Effect<T>` fields to state for triggering one-time side effects like:
- Showing dialogs or snackbars
- Clearing text fields
- Navigating to screens
- Playing sounds or haptic feedback

Effects are automatically consumed after being read, ensuring they trigger only once.

## Instructions

### Step 1: Identify the Side Effect

Ask the user what one-time action they need:
- Show a message/snackbar
- Navigate to a screen
- Clear a form field
- Show a dialog

### Step 2: Add Effect to State

Add an `Effect<T>` field to the state class. **Always initialize as spent:**

```dart
import 'package:bloc_superpowers/bloc_superpowers.dart';

class UserState {
  final User? user;
  final Effect<String> messageEffect;  // For showing messages
  final Effect<bool> clearFormEffect;  // For clearing forms

  UserState({
    this.user,
    Effect<String>? messageEffect,
    Effect<bool>? clearFormEffect,
  })  : messageEffect = messageEffect ?? Effect.spent(),
        clearFormEffect = clearFormEffect ?? Effect.spent();

  UserState copyWith({
    User? user,
    Effect<String>? messageEffect,
    Effect<bool>? clearFormEffect,
  }) {
    return UserState(
      user: user ?? this.user,
      messageEffect: messageEffect ?? this.messageEffect,
      clearFormEffect: clearFormEffect ?? this.clearFormEffect,
    );
  }
}
```

### Step 3: Emit Effects from Cubit

Create new effects using `Effect(value)`:

```dart
class UserCubit extends Cubit<UserState> {
  UserCubit() : super(UserState());

  void saveUser(User user) => mix(
    key: this,
    () async {
      await api.saveUser(user);
      emit(state.copyWith(
        user: user,
        messageEffect: Effect('User saved successfully!'),
      ));
    },
  );

  void clearForm() {
    emit(state.copyWith(
      clearFormEffect: Effect(true),
    ));
  }
}
```

### Step 4: Consume Effects in Widget

Use `context.effect()` in the build method:

```dart
class UserScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Consume message effect
    final message = context.effect((UserCubit c) => c.state.messageEffect);
    if (message != null) {
      // Show snackbar after build completes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      });
    }

    // Consume clear form effect
    final shouldClear = context.effect((UserCubit c) => c.state.clearFormEffect);
    if (shouldClear == true) {
      _formKey.currentState?.reset();
    }

    return Scaffold(
      body: UserForm(key: _formKey),
    );
  }
}
```

## Effect Types

### Untyped Effect (bool-like)

For simple triggers without data:

```dart
// State
final Effect clearEffect;

// Initialize
clearEffect = clearEffect ?? Effect.spent();

// Emit
emit(state.copyWith(clearEffect: Effect()));

// Consume - returns true if new, false if spent
final shouldClear = context.effect((MyCubit c) => c.state.clearEffect);
if (shouldClear) {
  // Do something
}
```

### Typed Effect<T>

For effects that carry data:

```dart
// State
final Effect<String> messageEffect;
final Effect<String> navigateEffect;
final Effect<int> scrollToEffect;

// Emit
emit(state.copyWith(messageEffect: Effect('Hello!')));
emit(state.copyWith(navigateEffect: Effect('/profile')));
emit(state.copyWith(scrollToEffect: Effect(42)));

// Consume - returns value if new, null if spent
final message = context.effect((MyCubit c) => c.state.messageEffect);
if (message != null) showMessage(message);

final route = context.effect((MyCubit c) => c.state.navigateEffect);
if (route != null) Navigator.pushNamed(context, route);

final index = context.effect((MyCubit c) => c.state.scrollToEffect);
if (index != null) scrollController.jumpTo(index.toDouble());
```

## Common Effect Patterns

### Show Snackbar

```dart
// State
final Effect<String> snackbarEffect;

// Cubit
void showSuccess() {
  emit(state.copyWith(snackbarEffect: Effect('Operation successful!')));
}

// Widget
final message = context.effect((MyCubit c) => c.state.snackbarEffect);
if (message != null) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  });
}
```

### Navigate to Screen

```dart
// State
final Effect<String> navigateEffect;

// Cubit
void onLoginSuccess() {
  emit(state.copyWith(navigateEffect: Effect('/home')));
}

// Widget
final route = context.effect((MyCubit c) => c.state.navigateEffect);
if (route != null) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Navigator.pushReplacementNamed(context, route);
  });
}
```

### Clear Text Field

```dart
// State
final Effect<bool> clearTextEffect;

// Cubit
void onMessageSent() {
  emit(state.copyWith(clearTextEffect: Effect(true)));
}

// Widget
final shouldClear = context.effect((ChatCubit c) => c.state.clearTextEffect);
if (shouldClear == true) {
  _textController.clear();
}
```

### Set Text Field Value

```dart
// State
final Effect<String> setTextEffect;

// Cubit
void loadDraft(String text) {
  emit(state.copyWith(setTextEffect: Effect(text)));
}

// Widget
final text = context.effect((FormCubit c) => c.state.setTextEffect);
if (text != null) {
  _textController.text = text;
}
```

## Important Rules

1. **Always initialize as spent:**
   ```dart
   messageEffect = messageEffect ?? Effect.spent();
   ```

2. **One consumer per effect:** Only one widget should consume each effect

3. **Effects are consumed once:** After reading, the effect becomes "spent"

4. **Use addPostFrameCallback for dialogs/navigation:**
   ```dart
   if (effect != null) {
     WidgetsBinding.instance.addPostFrameCallback((_) {
       // Show dialog, navigate, etc.
     });
   }
   ```

## Effect API Reference

```dart
// Create a new effect
Effect()           // Untyped
Effect(value)      // Typed

// Create a spent effect
Effect.spent()     // Untyped
Effect<T>.spent()  // Typed

// Check state without consuming
effect.isSpent     // true if already consumed
effect.isNotSpent  // true if available
effect.state       // Get value without consuming

// Consume (marks as spent)
effect.consume()   // Returns value (or true/null)
```

## How Effect Equality Works

Effects use custom equality to ensure proper rebuild behavior:

- **Unspent effects** are never equal to other effects, even with identical values. This forces
  a widget rebuild whenever a new effect is emitted.
- **Spent effects** are equal to each other since they're "empty" and shouldn't trigger rebuilds.

This is why emitting `Effect('hello')` twice triggers two separate rebuilds—each new `Effect`
instance is unique until consumed.

## Complete Example

```dart
// State
class ChatState {
  final List<Message> messages;
  final Effect<bool> clearInputEffect;
  final Effect<String> errorEffect;
  final Effect<int> scrollToMessageEffect;

  ChatState({
    this.messages = const [],
    Effect<bool>? clearInputEffect,
    Effect<String>? errorEffect,
    Effect<int>? scrollToMessageEffect,
  })  : clearInputEffect = clearInputEffect ?? Effect.spent(),
        errorEffect = errorEffect ?? Effect.spent(),
        scrollToMessageEffect = scrollToMessageEffect ?? Effect.spent();

  ChatState copyWith({
    List<Message>? messages,
    Effect<bool>? clearInputEffect,
    Effect<String>? errorEffect,
    Effect<int>? scrollToMessageEffect,
  }) => ChatState(
    messages: messages ?? this.messages,
    clearInputEffect: clearInputEffect ?? this.clearInputEffect,
    errorEffect: errorEffect ?? this.errorEffect,
    scrollToMessageEffect: scrollToMessageEffect ?? this.scrollToMessageEffect,
  );
}

// Cubit
class ChatCubit extends Cubit<ChatState> {
  ChatCubit() : super(ChatState());

  void sendMessage(String text) => mix(
    key: this,
    () async {
      final message = await api.sendMessage(text);
      emit(state.copyWith(
        messages: [...state.messages, message],
        clearInputEffect: Effect(true),
        scrollToMessageEffect: Effect(state.messages.length),
      ));
    },
  );
}

// Widget
class ChatScreen extends StatelessWidget {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    // Clear input after sending
    final shouldClear = context.effect((ChatCubit c) => c.state.clearInputEffect);
    if (shouldClear == true) {
      _controller.clear();
    }

    // Scroll to new message
    final scrollTo = context.effect((ChatCubit c) => c.state.scrollToMessageEffect);
    if (scrollTo != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }

    // Show error
    final error = context.effect((ChatCubit c) => c.state.errorEffect);
    if (error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      });
    }

    return Scaffold(
      body: Column(
        children: [
          Expanded(child: MessageList(controller: _scrollController)),
          MessageInput(controller: _controller),
        ],
      ),
    );
  }
}
```

## User Preferences

Ask the user:
1. **What side effect is needed?** (snackbar, navigation, clear field, etc.)
2. **Does it carry data?** (typed Effect<T> vs untyped Effect)
3. **Multiple effects needed?** (add multiple Effect fields)
