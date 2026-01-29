---
name: setup-bloc-superpowers
description: Add bloc_superpowers package to a Flutter project with Superpowers widget and error dialog configuration
---

# Add bloc_superpowers to a Flutter Project

This skill adds the `bloc_superpowers` package to a Flutter project and configures it
properly.

## What This Skill Does

1. Adds `bloc_superpowers` dependency to `pubspec.yaml`
2. Wraps the app with the `Superpowers` widget (above `MaterialApp`)
3. Adds `UserExceptionDialog` or `UserExceptionToast` for automatic error display (below
   `MaterialApp`)

## Instructions

### Step 1: Add Dependency

Add `bloc_superpowers` to the project's `pubspec.yaml` under `dependencies`:

```yaml
dependencies:
  bloc_superpowers: ^1.0.0
  fast_immutable_collections: ^11.1.0
  flutter_bloc: ^9.1.1 
```

Note:

* `flutter_bloc` is necessary because `bloc_superpowers` enhances it.
* `fast_immutable_collections` should be included (unless the user specifically requests
  beforehand not to), because it allows for better performance and immutability when
  working with states in Cubits.

You can check for the latest package versions on https://pub.dev/packages/bloc_superpowers

Then run `flutter pub get`.

### Step 2: Import

Find the app's root widget (usually in `main.dart` or `app.dart`) and import:

```dart
import 'package:bloc_superpowers/bloc_superpowers.dart';
```

### Step 3: Wrap App with Superpowers Widget

Wrap `MaterialApp` (or `CupertinoApp`) with the `Superpowers` widget.

**IMPORTANT:** The `Superpowers` widget MUST be placed ABOVE `MaterialApp` in the widget
tree. Failing to add it will result in runtime errors when using `context.isWaiting()`,
`context.isFailed()`, or `context.getException()`.

Before:

```dart
Widget build(BuildContext context) {
  return MaterialApp(
    home: HomePage(),
  );
}
```

After:

```dart
import 'package:bloc_superpowers/bloc_superpowers.dart';

Widget build(BuildContext context) {
  return Superpowers(
    child: MaterialApp(
      home: HomePage(),
    ),
  );
}
```

Troubleshooting Tip: If the app does not use `MaterialApp` or `CupertinoApp` directly
find what widget is used to set up navigation and wrap that with `Superpowers`.
In any case, `Superpowers` should be as high as necessary in the widget tree.
Usually, only one `Superpowers` widget is needed for the entire app.

### Step 4: Add Error Dialog/Toast

Add `UserExceptionDialog` (or `UserExceptionToast`) as a wrapper around the app's home
screen. This widget automatically displays errors when Cubits throw `UserException`.

**Place it BELOW `MaterialApp`, usually in the `home` parameter:**

```dart
import 'package:bloc_superpowers/bloc_superpowers.dart';

Widget build(BuildContext context) {
  return Superpowers(
    child: MaterialApp(
      home: UserExceptionDialog(
        child: HomePage(),
      ),
    ),
  );
}
```

If the `home` parameter of the `MaterialApp` is not used, another alternative is to add it
to the `builder`, like this:

```dart
MaterialApp(
  routes: {
    '/': (_) => const HomePage(),
    '/login': (_) => const LoginPage(),
  },
  initialRoute: '/login',
  builder: (context, child) {
    return UserExceptionDialog( // Here!
      child: child!,
    );
  },
);

```

#### Configuration Options

**UserExceptionDialog** accepts these parameters:
- `showErrorsOneByOne: true` - When multiple errors occur simultaneously, they display
  sequentially rather than all at once. This prevents overwhelming users with simultaneous
  dialogs. Recommended to set to `true`.

If the user does not specify, use the **UserExceptionDialog**, which shows errors in a
dialog. Only if the user asks for a toast, use **UserExceptionToast**, which shows errors
as toast notifications.

It's possible to create a custom UI to show errors. If the user wants that, read
the code in this
page https://pub.dev/documentation/bloc_superpowers/latest/bloc_superpowers/UserExceptionDialog-class.html

### Complete Example

Here's a complete setup with `BlocProviders`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_superpowers/bloc_superpowers.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Superpowers(
      child: MultiBlocProvider(
        providers: [
          // Add your BlocProviders here
        ],
        child: MaterialApp(
          title: 'My App',
          home: UserExceptionDialog(
            showErrorsOneByOne: true,
            child: const HomePage(),
          ),
        ),
      ),
    );
  }
}
```

## Verification

After setup, verify the configuration works by:

1. The app has no compile-time errors
2. The import `package:bloc_superpowers/bloc_superpowers.dart` resolves correctly
