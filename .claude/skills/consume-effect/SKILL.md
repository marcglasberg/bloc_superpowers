---
name: consume-effect
description: Add context.effect() to widgets to consume and react to one-time effects from state
---

# Consume Effects in Widgets

This skill adds `context.effect()` to widgets to consume and react to one-time effects from state.

## What This Skill Does

Consumes `Effect<T>` fields in widgets to:
- Read the effect value
- Automatically mark it as spent
- Trigger side effects (snackbars, navigation, etc.)

## Instructions

### Step 1: Ensure State Has Effect

The state must have an `Effect<T>` field:

```dart
class AppState {
  final Effect<String> messageEffect;

  AppState({Effect<String>? messageEffect})
    : messageEffect = messageEffect ?? Effect.spent();
}
```

### Step 2: Add context.effect() to Widget

Use `context.effect()` in the build method:

```dart
import 'package:bloc_superpowers/bloc_superpowers.dart';

class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Consume the effect - returns value if new, null if spent
    final message = context.effect((MyCubit c) => c.state.messageEffect);

    if (message != null) {
      // React to the effect
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      });
    }

    return Scaffold(
      body: MyContent(),
    );
  }
}
```

## context.effect() Syntax

```dart
// For typed Effect<T>
final value = context.effect((CubitType c) => c.state.effectField);
// Returns: T? (value if new, null if spent)

// For untyped Effect
final triggered = context.effect((CubitType c) => c.state.effectField);
// Returns: bool (true if new, false if spent)
```

## Common Consumption Patterns

### Show Snackbar

```dart
Widget build(BuildContext context) {
  final message = context.effect((AppCubit c) => c.state.snackbarEffect);

  if (message != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    });
  }

  return MyWidget();
}
```

### Navigate to Screen

```dart
Widget build(BuildContext context) {
  final route = context.effect((AuthCubit c) => c.state.navigateEffect);

  if (route != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacementNamed(context, route);
    });
  }

  return LoginForm();
}
```

### Show Dialog

```dart
Widget build(BuildContext context) {
  final dialogData = context.effect((OrderCubit c) => c.state.dialogEffect);

  if (dialogData != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(dialogData.title),
          content: Text(dialogData.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    });
  }

  return OrderSummary();
}
```

### Clear Text Field

```dart
class ChatInput extends StatefulWidget {
  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    // Clear text when effect is triggered
    final shouldClear = context.effect((ChatCubit c) => c.state.clearInputEffect);
    if (shouldClear == true) {
      _controller.clear();
    }

    return TextField(controller: _controller);
  }
}
```

### Set Text Field Value

```dart
Widget build(BuildContext context) {
  final newText = context.effect((FormCubit c) => c.state.setTextEffect);
  if (newText != null) {
    _controller.text = newText;
  }

  return TextField(controller: _controller);
}
```

### Play Sound/Haptic

```dart
Widget build(BuildContext context) {
  final sound = context.effect((GameCubit c) => c.state.playSoundEffect);
  if (sound != null) {
    audioPlayer.play(sound);
  }

  final haptic = context.effect((ButtonCubit c) => c.state.hapticEffect);
  if (haptic == true) {
    HapticFeedback.mediumImpact();
  }

  return GameBoard();
}
```

### Scroll to Position

```dart
Widget build(BuildContext context) {
  final scrollTo = context.effect((ListCubit c) => c.state.scrollEffect);

  if (scrollTo != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        scrollTo,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  return ListView(controller: _scrollController, ...);
}
```

## Multiple Effects

Handle multiple effects in the same widget:

```dart
Widget build(BuildContext context) {
  // Effect 1: Show message
  final message = context.effect((MyCubit c) => c.state.messageEffect);
  if (message != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    });
  }

  // Effect 2: Clear form
  final shouldClear = context.effect((MyCubit c) => c.state.clearFormEffect);
  if (shouldClear == true) {
    _formKey.currentState?.reset();
  }

  // Effect 3: Navigate
  final route = context.effect((MyCubit c) => c.state.navigateEffect);
  if (route != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushNamed(context, route);
    });
  }

  return MyForm(key: _formKey);
}
```

## Why Use addPostFrameCallback?

For effects that trigger dialogs, snackbars, or navigation, use `addPostFrameCallback` to:
- Avoid calling these during build
- Ensure the widget tree is stable
- Prevent "setState during build" errors

```dart
// ❌ Don't do this - can cause errors
if (effect != null) {
  showDialog(...);  // Called during build!
}

// ✓ Do this - waits for build to complete
if (effect != null) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    showDialog(...);  // Safe - called after build
  });
}
```

## Important Rules

1. **One consumer per effect:** Only one widget should consume each effect
2. **Effects consume once:** After `context.effect()` returns a value, it returns null on subsequent calls
3. **Use addPostFrameCallback:** For dialogs, navigation, snackbars
4. **Check for null/false:** Always check the return value before acting

## Complete Example

```dart
class OrderScreen extends StatefulWidget {
  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  final _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    // Success message
    final successMsg = context.effect((OrderCubit c) => c.state.successEffect);
    if (successMsg != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMsg),
            backgroundColor: Colors.green,
          ),
        );
      });
    }

    // Error message
    final errorMsg = context.effect((OrderCubit c) => c.state.errorEffect);
    if (errorMsg != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
          ),
        );
      });
    }

    // Scroll to new item
    final scrollToEnd = context.effect((OrderCubit c) => c.state.scrollToEndEffect);
    if (scrollToEnd == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }

    // Navigate after order complete
    final orderId = context.effect((OrderCubit c) => c.state.navigateToOrderEffect);
    if (orderId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/order/$orderId');
      });
    }

    return Scaffold(
      body: OrderList(scrollController: _scrollController),
    );
  }
}
```

## User Preferences

Ask the user:
1. **What effect type is being consumed?** (message, navigation, clear field, etc.)
2. **What action should occur?** (show snackbar, navigate, clear controller)
3. **Need multiple effects?** (handle each separately)
