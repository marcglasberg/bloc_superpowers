---
name: retry-until-internet
description: Combine checkInternet with retry.unlimited for persistent loading of critical data until connection returns
---

# Retry Until Internet Returns

This skill combines `checkInternet` with `retry.unlimited` for persistent loading of critical data.

## What This Skill Does

Creates a pattern that:
- Checks for internet connectivity
- Retries indefinitely until connection is restored
- Automatically loads data when internet returns

## Use Case

Perfect for:
- Critical app startup data
- Configuration that must be loaded
- Data that the app cannot function without

## Instructions

### Step 1: Combine checkInternet and retry.unlimited

```dart
import 'package:bloc_superpowers/bloc_superpowers.dart';

class AppCubit extends Cubit<AppState> {
  AppCubit() : super(const AppState());

  void loadInitialData() => mix(
    key: this,
    checkInternet: checkInternet,
    retry: retry.unlimited,
    () async {
      final config = await api.getAppConfig();
      final user = await api.getCurrentUser();
      emit(state.copyWith(config: config, user: user));
    },
  );
}
```

### Step 2: Configure Retry Delay (Optional)

Control how frequently it rechecks:

```dart
void loadInitialData() => mix(
  key: this,
  checkInternet: checkInternet(maxRetryDelay: 1.sec),
  retry: retry.unlimited(maxDelay: 5.sec),
  () async {
    final config = await api.getAppConfig();
    emit(state.copyWith(config: config));
  },
);
```

## How It Works

```
App starts
    ↓
Check internet → No internet
    ↓
Wait 1 second, retry
    ↓
Check internet → No internet
    ↓
Wait 2 seconds, retry (exponential backoff)
    ↓
Check internet → No internet
    ↓
Wait 4 seconds, retry
    ↓
... keeps trying ...
    ↓
Check internet → Has internet!
    ↓
Execute API call
    ↓
Success! Data loaded
```

## Configuration Options

### Fast Retry

For critical data that needs to load ASAP:

```dart
void loadCriticalData() => mix(
  key: this,
  checkInternet: checkInternet(maxRetryDelay: 500.millis),
  retry: retry.unlimited(
    initialDelay: 500.millis,
    maxDelay: 2.sec,
  ),
  () async {
    final data = await api.getCriticalData();
    emit(data);
  },
);
```

### Slow Retry

For less critical data:

```dart
void loadOptionalData() => mix(
  key: this,
  checkInternet: checkInternet(maxRetryDelay: 5.sec),
  retry: retry.unlimited(
    initialDelay: 2.sec,
    maxDelay: 30.sec,
  ),
  () async {
    final data = await api.getOptionalData();
    emit(state.copyWith(optionalData: data));
  },
);
```

## Widget Integration

Show loading state while waiting for internet:

```dart
class SplashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (context.isWaiting(AppCubit)) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Waiting for connection...'),
          ],
        ),
      );
    }

    if (context.isFailed(AppCubit)) {
      // This shouldn't happen with unlimited retry,
      // but handle just in case
      return const Center(child: Text('Error loading'));
    }

    // Data loaded, navigate away
    return const HomeScreen();
  }
}
```

## Complete Example

```dart
// Cubit
class AppCubit extends Cubit<AppState> {
  AppCubit() : super(const AppState());

  void init() => mix(
    key: this,
    checkInternet: checkInternet(maxRetryDelay: 1.sec),
    retry: retry.unlimited(maxDelay: 10.sec),
    () async {
      // Load all critical startup data
      final config = await api.getConfig();
      final user = await api.getCurrentUser();
      final features = await api.getFeatureFlags();

      emit(state.copyWith(
        config: config,
        user: user,
        features: features,
        isInitialized: true,
      ));
    },
  );
}

// Main
void main() {
  runApp(
    Superpowers(
      child: BlocProvider(
        create: (_) => AppCubit()..init(),  // Start loading immediately
        child: const MyApp(),
      ),
    ),
  );
}

// Splash Screen
class SplashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppCubit>().state;

    if (state.isInitialized) {
      // Navigate to home when loaded
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/home');
      });
    }

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const FlutterLogo(size: 100),
            const SizedBox(height: 32),
            if (context.isWaiting(AppCubit)) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Loading...'),
            ],
          ],
        ),
      ),
    );
  }
}
```

## Reusable Config/Preset

Create a reusable configuration:

```dart
// Config
const criticalLoadConfig = MixConfig(
  checkInternet: checkInternet(maxRetryDelay: 1.sec),
  retry: retry.unlimited(maxDelay: 10.sec),
);

// Usage
void loadData() => mix(
  key: this,
  config: criticalLoadConfig,
  () async { ... },
);

// Or as a preset
const criticalLoad = MixPreset(
  checkInternet: checkInternet(maxRetryDelay: 1.sec),
  retry: retry.unlimited(maxDelay: 10.sec),
);

// Usage
void loadData() => criticalLoad(
  key: this,
  () async { ... },
);
```

## Key Points

1. **Use for critical data** that the app cannot function without
2. **Configure delays** based on urgency
3. **Show user feedback** ("Waiting for connection...")
4. **Create reusable configs** for consistent behavior
