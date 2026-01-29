---
name: use-props
description: Use Superpowers.setProp() and prop() for key-value storage with automatic cleanup on logout or test reset
---

# Use Props for Shared Data with Auto-Cleanup

This skill uses `Superpowers.setProp()` and `Superpowers.prop()` for key-value storage with automatic cleanup.

## What This Skill Does

Uses the props system to:
- Store shared data (timers, subscriptions, services)
- Retrieve data from anywhere in the app
- Automatically dispose resources on logout/test reset

## Instructions

### Step 1: Store Data with setProp()

```dart
import 'package:bloc_superpowers/bloc_superpowers.dart';

// Store a timer
Superpowers.setProp('refreshTimer', Timer.periodic(
  Duration(minutes: 5),
  (_) => refreshData(),
));

// Store a stream subscription
Superpowers.setProp('authSubscription', authStream.listen((user) {
  handleAuthChange(user);
}));

// Store any value
Superpowers.setProp('lastSyncTime', DateTime.now());
```

### Step 2: Retrieve Data with prop()

```dart
// Get the timer
final timer = Superpowers.prop<Timer>('refreshTimer');
timer?.cancel();

// Get the subscription
final sub = Superpowers.prop<StreamSubscription>('authSubscription');

// Get any value
final lastSync = Superpowers.prop<DateTime>('lastSyncTime');
```

### Step 3: Automatic Cleanup

Props are automatically disposed when calling `clear()` or `prepareToLogout()`:

```dart
// In tests - resets everything
setUp(() {
  Superpowers.clear();
});

// On logout - clears user data, keeps app config
Future<void> logout() async {
  await Superpowers.prepareToLogout();
  await authService.signOut();
}
```

## Key Types

Keys can be strings, enums, types, or records:

```dart
// String keys
Superpowers.setProp('refreshTimer', timer);
Superpowers.prop<Timer>('refreshTimer');

// Enum keys
enum PropKey { authToken, refreshTimer, syncSubscription }
Superpowers.setProp(PropKey.authToken, 'abc123');
Superpowers.prop<String>(PropKey.authToken);

// Type keys
Superpowers.setProp(MyService, MyService());
Superpowers.prop<MyService>(MyService);

// Record keys (for multiple instances)
Superpowers.setProp((Database, 'primary'), primaryDb);
Superpowers.setProp((Database, 'cache'), cacheDb);
Superpowers.prop<Database>((Database, 'primary'));
```

## Auto-Disposed Types

These types are automatically disposed when `clear()` or `prepareToLogout()` is called:

| Type | Disposal Action |
|------|-----------------|
| `Timer` | `cancel()` |
| `Future` | `ignore()` |
| `StreamSubscription` | `cancel()` |
| `StreamConsumer` | `close()` |
| `Sink` | `close()` |

## Manual Disposal

```dart
// Dispose all props
Superpowers.disposeProps();

// Dispose props matching a condition
Superpowers.disposeProps(({key, value}) => value is Timer);
Superpowers.disposeProps(({key, value}) => key.toString().startsWith('temp'));

// Dispose a single prop
Superpowers.disposeProp('refreshTimer');
Superpowers.disposeProp(PropKey.authToken);
```

## Common Patterns

### Background Refresh Timer

```dart
class AppCubit extends Cubit<AppState> {
  void startBackgroundRefresh() {
    // Cancel existing timer if any
    Superpowers.prop<Timer>('refreshTimer')?.cancel();

    // Start new timer
    Superpowers.setProp('refreshTimer', Timer.periodic(
      const Duration(minutes: 5),
      (_) => loadData(),
    ));
  }

  void stopBackgroundRefresh() {
    Superpowers.disposeProp('refreshTimer');
  }
}
```

### Auth State Listener

```dart
class AuthCubit extends Cubit<AuthState> {
  void init() {
    Superpowers.setProp('authSubscription',
      authService.authStateChanges.listen((user) {
        if (user != null) {
          emit(AuthState.authenticated(user));
        } else {
          emit(const AuthState.unauthenticated());
        }
      }),
    );
  }
}
```

### WebSocket Connection

```dart
class ChatCubit extends Cubit<ChatState> {
  void connect() {
    final channel = WebSocketChannel.connect(Uri.parse(wsUrl));

    Superpowers.setProp('wsChannel', channel);
    Superpowers.setProp('wsSubscription',
      channel.stream.listen((message) {
        handleMessage(message);
      }),
    );
  }

  void disconnect() {
    Superpowers.disposeProp('wsSubscription');
    Superpowers.prop<WebSocketChannel>('wsChannel')?.sink.close();
    Superpowers.disposeProp('wsChannel');
  }
}
```

### Service Locator Pattern

```dart
// In main.dart
void main() {
  // Register services
  Superpowers.setProp(ApiService, ApiService());
  Superpowers.setProp(AuthService, AuthService());
  Superpowers.setProp(StorageService, StorageService());

  runApp(Superpowers(child: MyApp()));
}

// In Cubit
class UserCubit extends Cubit<UserState> {
  final api = Superpowers.prop<ApiService>(ApiService)!;
  final auth = Superpowers.prop<AuthService>(AuthService)!;

  void loadUser() => mix(
    key: this,
    () async {
      final user = await api.getUser(auth.currentUserId);
      emit(state.copyWith(user: user));
    },
  );
}
```

## clear() vs prepareToLogout()

| Method | Behavior |
|--------|----------|
| `Superpowers.clear()` | Resets **everything** including `globalCatchError`, `observer`, and all props |
| `Superpowers.prepareToLogout()` | Clears user data and props, but keeps app-level configuration |

```dart
// In tests - full reset
setUp(() {
  Superpowers.clear();
});

// On logout - keeps globalCatchError and observer
Future<void> logout() async {
  await Superpowers.prepareToLogout();
  await authService.signOut();
  Navigator.pushReplacementNamed(context, '/login');
}
```

## Complete Example

```dart
enum AppProp { refreshTimer, authSubscription, wsConnection }

class AppService {
  void init() {
    // Start refresh timer
    Superpowers.setProp(AppProp.refreshTimer, Timer.periodic(
      const Duration(minutes: 5),
      (_) => syncData(),
    ));

    // Listen to auth changes
    Superpowers.setProp(AppProp.authSubscription,
      authService.onAuthStateChanged.listen((user) {
        if (user == null) {
          handleLogout();
        }
      }),
    );
  }

  void connectWebSocket() {
    final channel = WebSocketChannel.connect(wsUri);
    Superpowers.setProp(AppProp.wsConnection, channel);

    channel.stream.listen((message) {
      handleMessage(message);
    });
  }

  Future<void> logout() async {
    // This will:
    // - Cancel the refresh timer
    // - Cancel the auth subscription
    // - Close the WebSocket (if it implements Sink)
    await Superpowers.prepareToLogout();

    await authService.signOut();
  }
}
```

## User Preferences

Ask the user:
1. **What data needs to be stored?** (timers, subscriptions, services)
2. **What key type to use?** (string, enum, type)
3. **When should it be disposed?** (logout, test reset, manually)
