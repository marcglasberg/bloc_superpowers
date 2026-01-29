---
name: add-effect-queue
description: Add EffectQueue to state for triggering multiple sequential one-time UI effects
---

# Add Effect Queue to State

This skill adds an `EffectQueue` field to a state class for sequenced one-time UI effects.

## What This Skill Does

Adds `EffectQueue<T>` to state for triggering multiple side effects in order:
- Show toast, then dialog, then navigate
- Execute a sequence of UI actions
- Coordinate multiple side effects from a single Cubit action

This pattern eliminates the need for `BlocListener`. The Cubit declares *what* should happen
(the effects), while the widget determines *how* to execute them (the UI logic).

## When to Use

Use `EffectQueue` when:
- You need to trigger multiple effects in sequence
- Order matters (show message before navigating)
- Multiple effects should execute from one Cubit action

Use simple `Effect<T>` when:
- You only need one effect at a time
- Order doesn't matter

## Instructions

### Step 1: Define Effect Types

Create a sealed class hierarchy for your effects:

```dart
sealed class UiEffect {}

class ShowToast extends UiEffect {
  final String message;
  ShowToast(this.message);
}

class ShowDialog extends UiEffect {
  final String title;
  final String content;
  ShowDialog(this.title, this.content);
}

class Navigate extends UiEffect {
  final String route;
  Navigate(this.route);
}

class ClearForm extends UiEffect {}
```

### Step 2: Add EffectQueue to State

Add an `EffectQueue<UiEffect>` field. **Always initialize as spent:**

```dart
import 'package:bloc_superpowers/bloc_superpowers.dart';

class AppState {
  final User? user;
  final EffectQueue<UiEffect> effectQueue;

  AppState({
    this.user,
    EffectQueue<UiEffect>? effectQueue,
  }) : effectQueue = effectQueue ?? EffectQueue.spent();

  AppState copyWith({
    User? user,
    EffectQueue<UiEffect>? effectQueue,
  }) {
    return AppState(
      user: user ?? this.user,
      effectQueue: effectQueue ?? this.effectQueue,
    );
  }
}
```

### Step 3: Emit Effect Queue from Cubit

Create an `EffectQueue` with a list of effects and a callback for remaining effects:

```dart
class AppCubit extends Cubit<AppState> {
  AppCubit() : super(AppState());

  void onPurchaseComplete() {
    emit(state.copyWith(
      effectQueue: EffectQueue<UiEffect>(
        [
          ShowToast('Purchase successful!'),
          ShowDialog('Thank You', 'Your order has been placed.'),
          Navigate('/orders'),
        ],
        // Callback to emit remaining effects
        (remaining) => emit(state.copyWith(effectQueue: remaining)),
      ),
    ));
  }
}
```

### Step 4: Consume Queue in Widget

Use `context.effectQueue()` in the build method:

```dart
class AppScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    context.effectQueue<AppCubit, UiEffect>(
      // Select the queue
      (cubit) => cubit.state.effectQueue,

      // Handle each effect
      (context, effect) => switch (effect) {
        ShowToast(:final message) =>
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          ),

        ShowDialog(:final title, :final content) =>
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: Text(title),
              content: Text(content),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          ),

        Navigate(:final route) =>
          Navigator.of(context).pushNamed(route),

        ClearForm() =>
          _formKey.currentState?.reset(),
      },
    );

    return Scaffold(
      body: MyContent(),
    );
  }
}
```

## Execution Modes

### One Per Frame (Default)

Effects execute one at a time, with a rebuild between each:

```dart
context.effectQueue<AppCubit, UiEffect>(
  (cubit) => cubit.state.effectQueue,
  onePerFrame: true,  // Default
  (context, effect) => ...,
);
```

### All At Once

All effects execute in a single frame:

```dart
context.effectQueue<AppCubit, UiEffect>(
  (cubit) => cubit.state.effectQueue,
  onePerFrame: false,  // Execute all immediately
  (context, effect) => ...,
);
```

## Common Effect Patterns

### Onboarding Flow

```dart
sealed class OnboardingEffect {}
class ShowWelcome extends OnboardingEffect {}
class RequestPermissions extends OnboardingEffect {}
class ShowTutorial extends OnboardingEffect {}
class NavigateToHome extends OnboardingEffect {}

void startOnboarding() {
  emit(state.copyWith(
    effectQueue: EffectQueue<OnboardingEffect>(
      [
        ShowWelcome(),
        RequestPermissions(),
        ShowTutorial(),
        NavigateToHome(),
      ],
      (remaining) => emit(state.copyWith(effectQueue: remaining)),
    ),
  ));
}
```

### Form Submission

```dart
sealed class FormEffect {}
class ShowSaving extends FormEffect {}
class ShowSuccess extends FormEffect {
  final String message;
  ShowSuccess(this.message);
}
class ClearForm extends FormEffect {}
class NavigateBack extends FormEffect {}

void submitForm(FormData data) => mix(
  key: this,
  () async {
    await api.submit(data);
    emit(state.copyWith(
      effectQueue: EffectQueue<FormEffect>(
        [
          ShowSuccess('Form submitted!'),
          ClearForm(),
          NavigateBack(),
        ],
        (remaining) => emit(state.copyWith(effectQueue: remaining)),
      ),
    ));
  },
);
```

### Error with Recovery Options

```dart
sealed class ErrorEffect {}
class ShowError extends ErrorEffect {
  final String message;
  ShowError(this.message);
}
class OfferRetry extends ErrorEffect {
  final VoidCallback onRetry;
  OfferRetry(this.onRetry);
}
class LogError extends ErrorEffect {
  final Object error;
  LogError(this.error);
}

void onError(Object error) {
  emit(state.copyWith(
    effectQueue: EffectQueue<ErrorEffect>(
      [
        LogError(error),
        ShowError('Something went wrong'),
        OfferRetry(() => loadData()),
      ],
      (remaining) => emit(state.copyWith(effectQueue: remaining)),
    ),
  ));
}
```

## Complete Example

```dart
// Effects
sealed class CheckoutEffect {}

class ShowProcessing extends CheckoutEffect {}

class ShowSuccess extends CheckoutEffect {
  final String orderId;
  ShowSuccess(this.orderId);
}

class SendConfirmationEmail extends CheckoutEffect {
  final String email;
  SendConfirmationEmail(this.email);
}

class NavigateToOrder extends CheckoutEffect {
  final String orderId;
  NavigateToOrder(this.orderId);
}

// State
class CheckoutState {
  final Cart cart;
  final EffectQueue<CheckoutEffect> effectQueue;

  CheckoutState({
    required this.cart,
    EffectQueue<CheckoutEffect>? effectQueue,
  }) : effectQueue = effectQueue ?? EffectQueue.spent();

  CheckoutState copyWith({
    Cart? cart,
    EffectQueue<CheckoutEffect>? effectQueue,
  }) => CheckoutState(
    cart: cart ?? this.cart,
    effectQueue: effectQueue ?? this.effectQueue,
  );
}

// Cubit
class CheckoutCubit extends Cubit<CheckoutState> {
  CheckoutCubit(Cart cart) : super(CheckoutState(cart: cart));

  void placeOrder(String email) => mix(
    key: this,
    () async {
      final order = await api.placeOrder(state.cart);

      emit(state.copyWith(
        cart: Cart.empty(),
        effectQueue: EffectQueue<CheckoutEffect>(
          [
            ShowSuccess(order.id),
            SendConfirmationEmail(email),
            NavigateToOrder(order.id),
          ],
          (remaining) => emit(state.copyWith(effectQueue: remaining)),
        ),
      ));
    },
  );
}

// Widget
class CheckoutScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    context.effectQueue<CheckoutCubit, CheckoutEffect>(
      (cubit) => cubit.state.effectQueue,
      onePerFrame: true,
      (context, effect) => switch (effect) {
        ShowProcessing() =>
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const AlertDialog(
              content: CircularProgressIndicator(),
            ),
          ),

        ShowSuccess(:final orderId) =>
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Order $orderId placed!')),
          ),

        SendConfirmationEmail(:final email) =>
          emailService.sendConfirmation(email),

        NavigateToOrder(:final orderId) =>
          Navigator.pushReplacementNamed(
            context,
            '/order/$orderId',
          ),
      },
    );

    return CheckoutForm();
  }
}
```

## User Preferences

Ask the user:
1. **What effects are needed?** (toast, dialog, navigation, etc.)
2. **What's the sequence?** (order matters)
3. **One per frame or all at once?**
