---
name: replace-bloc-listener
description: Convert BlocListener usage to Effect-based approach for clearer side effect handling
---

# Replace BlocListener with Effects

This skill converts `BlocListener` usage to the Effect-based approach from bloc_superpowers.

## What This Skill Does

Replaces `BlocListener` (which listens for state changes) with `Effect` (which explicitly triggers side effects). This provides:
- Clearer intent (explicit effect vs implicit state change)
- No missed effects (effects are stored in state)
- Simpler code (no listener wrapper needed)

## Instructions

### Step 1: Identify BlocListener Usage

Find `BlocListener` widgets that trigger side effects:

```dart
// BEFORE: BlocListener pattern
BlocListener<AuthCubit, AuthState>(
  listenWhen: (previous, current) =>
    previous.isAuthenticated != current.isAuthenticated,
  listener: (context, state) {
    if (state.isAuthenticated) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  },
  child: LoginForm(),
)
```

### Step 2: Add Effect to State

Add an `Effect` field for the side effect:

```dart
// AFTER: Add effect to state
class AuthState {
  final bool isAuthenticated;
  final Effect<String> navigateEffect;  // Add this

  AuthState({
    this.isAuthenticated = false,
    Effect<String>? navigateEffect,
  }) : navigateEffect = navigateEffect ?? Effect.spent();

  AuthState copyWith({
    bool? isAuthenticated,
    Effect<String>? navigateEffect,
  }) => AuthState(
    isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    navigateEffect: navigateEffect ?? this.navigateEffect,
  );
}
```

### Step 3: Emit Effect from Cubit

Instead of just changing state, emit an effect:

```dart
// BEFORE: Just changing state
void login(String email, String password) async {
  final user = await authService.login(email, password);
  emit(state.copyWith(isAuthenticated: true, user: user));
  // Widget was listening for isAuthenticated change
}

// AFTER: Emit explicit effect
void login(String email, String password) => mix(
  key: this,
  () async {
    final user = await authService.login(email, password);
    emit(state.copyWith(
      isAuthenticated: true,
      user: user,
      navigateEffect: Effect('/home'),  // Explicit effect
    ));
  },
);
```

### Step 4: Replace BlocListener with context.effect()

```dart
// BEFORE: BlocListener
class LoginScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (previous, current) =>
        previous.isAuthenticated != current.isAuthenticated,
      listener: (context, state) {
        if (state.isAuthenticated) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      },
      child: LoginForm(),
    );
  }
}

// AFTER: context.effect()
class LoginScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final route = context.effect((AuthCubit c) => c.state.navigateEffect);
    if (route != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, route);
      });
    }

    return LoginForm();
  }
}
```

## Common Conversions

### Navigate on State Change

```dart
// BEFORE
BlocListener<OrderCubit, OrderState>(
  listenWhen: (prev, curr) => prev.orderStatus != curr.orderStatus,
  listener: (context, state) {
    if (state.orderStatus == OrderStatus.completed) {
      Navigator.pushNamed(context, '/order/${state.orderId}');
    }
  },
  child: OrderForm(),
)

// AFTER
// State
final Effect<String> navigateToOrderEffect;

// Cubit
void completeOrder() => mix(
  key: this,
  () async {
    await api.completeOrder();
    emit(state.copyWith(
      orderStatus: OrderStatus.completed,
      navigateToOrderEffect: Effect('/order/${state.orderId}'),
    ));
  },
);

// Widget
Widget build(BuildContext context) {
  final route = context.effect((OrderCubit c) => c.state.navigateToOrderEffect);
  if (route != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushNamed(context, route);
    });
  }
  return OrderForm();
}
```

### Show Snackbar on Error

```dart
// BEFORE
BlocListener<DataCubit, DataState>(
  listenWhen: (prev, curr) => prev.error != curr.error,
  listener: (context, state) {
    if (state.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.error!)),
      );
    }
  },
  child: DataScreen(),
)

// AFTER
// With bloc_superpowers, errors are handled automatically by UserExceptionDialog
// OR use an explicit effect:

// State
final Effect<String> errorMessageEffect;

// Cubit - emit effect on error
void loadData() => mix(
  key: this,
  catchError: (error, stack) {
    emit(state.copyWith(
      errorMessageEffect: Effect(error.toString()),
    ));
  },
  () async {
    final data = await api.getData();
    emit(state.copyWith(data: data));
  },
);

// Widget
Widget build(BuildContext context) {
  final error = context.effect((DataCubit c) => c.state.errorMessageEffect);
  if (error != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    });
  }
  return DataScreen();
}
```

### Show Dialog on Success

```dart
// BEFORE
BlocListener<FormCubit, FormState>(
  listenWhen: (prev, curr) => !prev.isSubmitted && curr.isSubmitted,
  listener: (context, state) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Success'),
        content: Text('Form submitted!'),
      ),
    );
  },
  child: MyForm(),
)

// AFTER
// State
final Effect<String> successDialogEffect;

// Cubit
void submit() => mix(
  key: this,
  () async {
    await api.submit(state.formData);
    emit(state.copyWith(
      isSubmitted: true,
      successDialogEffect: Effect('Form submitted!'),
    ));
  },
);

// Widget
Widget build(BuildContext context) {
  final message = context.effect((FormCubit c) => c.state.successDialogEffect);
  if (message != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Success'),
          content: Text(message),
        ),
      );
    });
  }
  return MyForm();
}
```

### MultiBlocListener to Multiple Effects

```dart
// BEFORE
MultiBlocListener(
  listeners: [
    BlocListener<AuthCubit, AuthState>(...),
    BlocListener<CartCubit, CartState>(...),
    BlocListener<NotificationCubit, NotificationState>(...),
  ],
  child: MyApp(),
)

// AFTER
Widget build(BuildContext context) {
  // Auth effect
  final authRoute = context.effect((AuthCubit c) => c.state.navigateEffect);
  if (authRoute != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacementNamed(context, authRoute);
    });
  }

  // Cart effect
  final cartMessage = context.effect((CartCubit c) => c.state.addedToCartEffect);
  if (cartMessage != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(cartMessage)),
      );
    });
  }

  // Notification effect
  final notification = context.effect((NotificationCubit c) => c.state.showNotificationEffect);
  if (notification != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showNotificationDialog(context, notification);
    });
  }

  return MyApp();
}
```

## Benefits of Effects Over BlocListener

| BlocListener | Effects |
|--------------|---------|
| Implicit (listens for state changes) | Explicit (effect is emitted intentionally) |
| Can miss effects if widget not mounted | Effects stored in state, never missed |
| Requires `listenWhen` logic | No condition needed - effect is the trigger |
| Wrapper widget adds nesting | Just a method call in build |
| Complex with multiple listeners | Multiple effects are simple parallel calls |

## Migration Checklist

For each `BlocListener`:

- [ ] Identify what side effect it triggers
- [ ] Add `Effect<T>` field to state
- [ ] Initialize effect as spent in constructor
- [ ] Add effect to `copyWith`
- [ ] Emit effect in Cubit when appropriate
- [ ] Replace `BlocListener` with `context.effect()` in widget
- [ ] Use `addPostFrameCallback` for dialogs/navigation

## User Preferences

Ask the user:
1. **What side effect does the BlocListener trigger?**
2. **What data needs to be passed?** (determines Effect type)
3. **Are there multiple listeners to convert?**
