---
name: consume-effect-queue
description: Add context.effectQueue() to widgets to consume and process queued effects in sequence
---

# Consume Effect Queue in Widgets

This skill adds `context.effectQueue()` to widgets to consume and process queued effects in order.

## What This Skill Does

Consumes `EffectQueue<T>` in widgets to:
- Process effects one at a time in sequence
- Handle each effect type with pattern matching
- Automatically advance through the queue

## Instructions

### Step 1: Ensure State Has EffectQueue

The state must have an `EffectQueue<T>` field with defined effect types:

```dart
sealed class UiEffect {}
class ShowToast extends UiEffect { final String message; ShowToast(this.message); }
class Navigate extends UiEffect { final String route; Navigate(this.route); }

class AppState {
  final EffectQueue<UiEffect> effectQueue;

  AppState({EffectQueue<UiEffect>? effectQueue})
    : effectQueue = effectQueue ?? EffectQueue.spent();
}
```

### Step 2: Add context.effectQueue() to Widget

Use `context.effectQueue()` in the build method:

```dart
import 'package:bloc_superpowers/bloc_superpowers.dart';

class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    context.effectQueue<MyCubit, UiEffect>(
      // 1. Select the queue from state
      (cubit) => cubit.state.effectQueue,

      // 2. Handle each effect type
      (context, effect) => switch (effect) {
        ShowToast(:final message) =>
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          ),

        Navigate(:final route) =>
          Navigator.pushNamed(context, route),
      },
    );

    return Scaffold(
      body: MyContent(),
    );
  }
}
```

## context.effectQueue() Syntax

```dart
context.effectQueue<CubitType, EffectType>(
  // Selector: extract queue from state
  (cubit) => cubit.state.effectQueue,

  // Handler: process each effect
  (context, effect) => /* handle effect */,

  // Optional: execution mode
  onePerFrame: true,  // Default: true
);
```

## Execution Modes

### One Per Frame (Default)

Effects process one at a time, with a rebuild between each:

```dart
context.effectQueue<MyCubit, UiEffect>(
  (c) => c.state.effectQueue,
  onePerFrame: true,  // Default - sequential with rebuilds
  (context, effect) => handleEffect(effect),
);
```

Good for:
- Effects that need to complete before the next starts
- Dialogs that need to be dismissed
- Visual feedback between effects

### All At Once

All effects process in a single frame:

```dart
context.effectQueue<MyCubit, UiEffect>(
  (c) => c.state.effectQueue,
  onePerFrame: false,  // All effects execute immediately
  (context, effect) => handleEffect(effect),
);
```

Good for:
- Logging effects
- Non-visual effects
- Effects that can overlap

## Pattern Matching Effects

Use Dart 3 pattern matching to handle different effect types:

```dart
(context, effect) => switch (effect) {
  // Destructure properties
  ShowToast(:final message) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    ),

  // Multiple properties
  ShowDialog(:final title, :final content) =>
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(content),
      ),
    ),

  // No properties
  ClearForm() =>
    _formKey.currentState?.reset(),

  // Navigate with dynamic route
  Navigate(:final route) =>
    Navigator.pushNamed(context, route),

  // Complex handling
  ShowConfirmation(:final message, :final onConfirm, :final onCancel) =>
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(onPressed: onCancel, child: Text('Cancel')),
          TextButton(onPressed: onConfirm, child: Text('Confirm')),
        ],
      ),
    ),
},
```

## Common Queue Patterns

### Onboarding Flow

```dart
sealed class OnboardingEffect {}
class WelcomeDialog extends OnboardingEffect {}
class PermissionRequest extends OnboardingEffect { final String permission; ... }
class TutorialOverlay extends OnboardingEffect {}
class NavigateToHome extends OnboardingEffect {}

// In widget
context.effectQueue<OnboardingCubit, OnboardingEffect>(
  (c) => c.state.effectQueue,
  onePerFrame: true,  // Show one step at a time
  (context, effect) => switch (effect) {
    WelcomeDialog() => showWelcomeDialog(context),
    PermissionRequest(:final permission) => requestPermission(permission),
    TutorialOverlay() => showTutorial(context),
    NavigateToHome() => Navigator.pushReplacementNamed(context, '/home'),
  },
);
```

### Form Submission Feedback

```dart
sealed class FormEffect {}
class ShowSaving extends FormEffect {}
class HideSaving extends FormEffect {}
class ShowSuccess extends FormEffect { final String message; ... }
class ClearForm extends FormEffect {}
class NavigateBack extends FormEffect {}

// In widget
context.effectQueue<FormCubit, FormEffect>(
  (c) => c.state.effectQueue,
  (context, effect) => switch (effect) {
    ShowSaving() => _showLoadingOverlay(),
    HideSaving() => _hideLoadingOverlay(),
    ShowSuccess(:final message) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      ),
    ClearForm() => _formKey.currentState?.reset(),
    NavigateBack() => Navigator.pop(context),
  },
);
```

### Error Recovery Flow

```dart
sealed class ErrorEffect {}
class LogError extends ErrorEffect { final Object error; ... }
class ShowErrorMessage extends ErrorEffect { final String message; ... }
class OfferRetry extends ErrorEffect { final VoidCallback onRetry; ... }

// In widget
context.effectQueue<DataCubit, ErrorEffect>(
  (c) => c.state.effectQueue,
  (context, effect) => switch (effect) {
    LogError(:final error) => analytics.logError(error),
    ShowErrorMessage(:final message) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      ),
    OfferRetry(:final onRetry) =>
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Error'),
          content: Text('Would you like to retry?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onRetry();
              },
              child: Text('Retry'),
            ),
          ],
        ),
      ),
  },
);
```

## Complete Example

```dart
// Effects
sealed class CheckoutEffect {}

class ShowProgress extends CheckoutEffect {
  final String message;
  ShowProgress(this.message);
}

class HideProgress extends CheckoutEffect {}

class ShowSuccess extends CheckoutEffect {
  final String orderId;
  ShowSuccess(this.orderId);
}

class SendReceipt extends CheckoutEffect {
  final String email;
  SendReceipt(this.email);
}

class NavigateToOrder extends CheckoutEffect {
  final String orderId;
  NavigateToOrder(this.orderId);
}

// Widget
class CheckoutScreen extends StatefulWidget {
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  OverlayEntry? _progressOverlay;

  void _showProgress(String message) {
    _progressOverlay = OverlayEntry(
      builder: (_) => Material(
        color: Colors.black54,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(message, style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_progressOverlay!);
  }

  void _hideProgress() {
    _progressOverlay?.remove();
    _progressOverlay = null;
  }

  @override
  Widget build(BuildContext context) {
    context.effectQueue<CheckoutCubit, CheckoutEffect>(
      (c) => c.state.effectQueue,
      onePerFrame: true,
      (context, effect) => switch (effect) {
        ShowProgress(:final message) => _showProgress(message),

        HideProgress() => _hideProgress(),

        ShowSuccess(:final orderId) =>
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Order $orderId placed successfully!'),
              backgroundColor: Colors.green,
            ),
          ),

        SendReceipt(:final email) =>
          emailService.sendReceipt(email),

        NavigateToOrder(:final orderId) =>
          Navigator.pushReplacementNamed(context, '/order/$orderId'),
      },
    );

    return Scaffold(
      appBar: AppBar(title: Text('Checkout')),
      body: CheckoutForm(),
    );
  }
}
```

## User Preferences

Ask the user:
1. **What effects are in the queue?** (define sealed class hierarchy)
2. **One per frame or all at once?** (based on visual requirements)
3. **How should each effect be handled?** (snackbar, dialog, navigation, etc.)
