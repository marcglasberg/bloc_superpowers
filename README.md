<p align="center">
  <img src="https://blocsuperpowers.org/_astro/superpowers.B7IP1WFP_18Xs88.webp" width="100">
</p>

<p align="center">
  <a href="https://pub.dev/packages/bloc_superpowers"><img src="https://img.shields.io/pub/v/bloc_superpowers?style=flat-square&logo=dart" alt="Pub Version"></a>
  <a href="https://github.com/marcglasberg/bloc_superpowers"><img src="https://img.shields.io/github/stars/marcglasberg/bloc_superpowers?style=social" alt="GitHub stars"></a>
  <img src="https://img.shields.io/github/issues/marcglasberg/bloc_superpowers?style=flat-square" alt="Code Climate issues">
  <img src="https://img.shields.io/github/issues-closed/marcglasberg/bloc_superpowers?style=flat-square" alt="GitHub closed issues">
  <img src="https://img.shields.io/github/contributors/marcglasberg/bloc_superpowers?style=flat-square" alt="GitHub contributors">
  <img src="https://img.shields.io/github/repo-size/marcglasberg/bloc_superpowers?style=flat-square" alt="GitHub repo size">
  <img src="https://img.shields.io/github/forks/marcglasberg/bloc_superpowers?style=flat-square" alt="GitHub forks">
  <img src="https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square" alt="PRs Welcome">
  <a href="https://glasberg.dev/"><img src="https://img.shields.io/badge/Developed%20by%20Marcelo%20Glasberg-blue.svg" alt="Developed by Marcelo Glasberg"></a>
  <a href="https://pub.dev/publishers/glasberg.dev/packages"><img src="https://img.shields.io/pub/publisher/bloc_superpowers.svg" alt="Glasberg.dev on pub.dev"></a>
  <a href="https://pub.dev/packages/bloc_superpowers"><img src="https://badgen.net/pub/flutter-platform/bloc_superpowers" alt="Platforms"></a>
</p>

Created
by [Marcelo Glasberg](https://glasberg.dev) _(2026)_ | [LinkedIn](https://linkedin.com/in/marcglasberg/) | [GitHub](https://github.com/marcglasberg/)

#### Contributors

<a href="https://github.com/marcglasberg/bloc_superpowers/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=marcglasberg/bloc_superpowers&columns=9"/>
</a>

# Bloc Superpowers

This package gives **superpowers** to your Cubits.

> Cubits are easier to use than Blocs, but they lack some features that make Blocs
> powerful.
> This package makes Cubits more powerful than Blocs, and even easier to use than before.

### Complete docs → [blocsuperpowers.org](http://blocsuperpowers.org)

## List of features

* [
  `context.isWaiting()`](https://blocsuperpowers.org/get-started/loading-and-error-states):
  Show loading indicators when Cubits load. No explicit loading states needed.

* [
  `context.isFailed()`](https://blocsuperpowers.org/get-started/loading-and-error-states):
  Show error messages when a Cubit fails. No explicit error states needed.

* [`UserException`](https://blocsuperpowers.org/get-started/showing-error-dialogs): A
  Cubit that fails can now just throw exceptions.

* [`UserExceptionDialog`](https://blocsuperpowers.org/get-started/showing-error-dialogs):
  Shows an error dialog when a Cubit throws an exception.

* [`UserExceptionToast`](https://blocsuperpowers.org/get-started/showing-error-dialogs):
  Shows a toast when a Cubit throws an exception.

* [`retry`](https://blocsuperpowers.org/mix-function/retry): Easily retry failed Cubit
  methods.

* [`checkInternet`](https://blocsuperpowers.org/mix-function/check-internet): Check for
  internet connectivity before executing Cubit methods.

* [`nonReentrant`](https://blocsuperpowers.org/mix-function/non-reentrant): Prevent Cubit
  methods from being called simultaneously.

* [`sequential`](https://blocsuperpowers.org/mix-function/sequential): Queue Cubit method
  calls and process them one after another, in order.

* [`fresh`](https://blocsuperpowers.org/mix-function/fresh): Treat Cubit methods as fresh
  for some time. Prevent reloading data too often.

* [`debounce`](https://blocsuperpowers.org/mix-function/debounce): Debounce Cubit method
  calls to avoid rapid successive calls.

* [`throttle`](https://blocsuperpowers.org/mix-function/throttle): Throttle Cubit method
  calls to limit how often they can be called.

* [`catchError`](https://blocsuperpowers.org/advanced/predefined-configurations): Suppress
  errors, rethrow them, or wrap them in user-friendly exceptions.

* [`MixConfig`](https://blocsuperpowers.org/advanced/predefined-configurations): Create
  reusable configurations for the `mix` function.

* [`MixPreset`](https://blocsuperpowers.org/advanced/mix-presets): Create your own
  reusable `mix` functions.

* [
  `optimisticCommand`](https://blocsuperpowers.org/optimistic-functions/optimistic-command):
  Apply a blocking optimistic state change immediately,
  run the command on the server, optionally rolling back and reloading.

* [`optimisticSync`](https://blocsuperpowers.org/optimistic-functions/optimistic-sync):
  Update the UI immediately and send a value to the server,
  with eventual consistency between UI and server.

* [
  `optimisticSyncWithPush`](https://blocsuperpowers.org/optimistic-functions/optimistic-sync-with-push):
  Similar to optimisticSync, but resilient to server-pushed
  updates that may modify the same state.

* [`Effect`](https://blocsuperpowers.org/effects/effects): Allows Cubits to emit one-time
  effects to the UI,
  such as navigation events, dialogs, toasts. Replaces `BlocListener`.

* [`EffectQueue`](https://blocsuperpowers.org/effects/effect-queues): Allows Cubits to
  emit queued one-time effects to the UI,
  ensuring they are shown one after the other.

## Setup

Add the `Superpowers` widget near the top of your widget tree,
somewhere above your `MaterialApp`:

```dart
Widget build(BuildContext context) {
  return Superpowers(
    ...
    child: MaterialApp(
      ...
```

## The complex code we don't need anymore

Consider a Cubit that loads user information from an API.
Without Superpowers, you would typically need a state like this:

```dart
class UserState {
  final User? user;
  final bool isLoading;
  final String? errorMessage;

  UserState({this.user, this.isLoading = false, this.errorMessage});

  UserState copyWith({User? user, bool? isLoading, String? errorMessage}) {
    return UserState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class UserCubit extends Cubit<UserState> {
  UserCubit() : super(UserState());

  void loadData() {
    emit(state.copyWith(isLoading: true, errorMessage: null));

    try {
      final user = await api.loadUser();
      if (user == null) {
        emit(state.copyWith(isLoading: false, errorMessage: 'Failed to load user'));
        return;
      }

      emit(state.copyWith(user: user, isLoading: false, errorMessage: null));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }
}
```

Now let's see how this simplifies with Superpowers.

## The `mix` function

Suppose you have a Cubit like this:

```dart
class UserCubit extends Cubit<User> {
  UserCubit() : super(User());

  void loadData() {
    // Do something
  }
}
```

Wrap the Cubit method body with the `mix` function and provide a key.
In most cases, the Cubit instance itself is used as the key (just write `key: this`):

```dart
class UserCubit extends Cubit<User> {
  UserCubit() : super(User());

  void loadData() => mix(
    key: this,
    () {
      // Do something
    },
  );
}
```

### Loading and error states

Now you no longer need to add `isLoading` or `errorMessage` variables to your state.

Instead, your Cubit method should focus only on loading data and emitting a new state.
If something goes wrong, throw an exception:

```dart
class UserCubit extends Cubit<User> {
  UserCubit() : super(User());

  void loadData() => mix(
    key: this,
    () async {
      final user = await api.loadUser();
      if (user == null) throw UserException('Failed to load');
      emit(user);
    },
  );
}
```

In your widgets, you can react to the loading and error states
using `isWaiting()` and `isFailed()`:

```dart
class MyWidget extends StatelessWidget {
  Widget build(BuildContext context) {
    if (context.isWaiting(UserCubit)) {
      return CircularProgressIndicator();
    }
    if (context.isFailed(UserCubit)) {
      return Text('Error loading');
    }
    return Text(
      'Loaded: ${context.watch<UserCubit>().state}',
    );
  }
}
```

### Error dialog

To show error dialogs when your Cubit methods throw exceptions,
add a `UserExceptionDialog` widget below your `MaterialApp`:

```dart
return MaterialApp(
  home: UserExceptionDialog( // Or use UserExceptionToast
    child: const HomePage(),
  ),
);
```

---

## Mix parameters

### Retry

To retry a failed method using exponential backoff, add `retry: retry` to the `mix`
function:

```dart
class UserCubit extends Cubit<User> {
  UserCubit() : super(User());

  void loadData() => mix(
    key: this,
    retry: retry, // Enables retry
    () {
      // Do something
    },
  );
}
```

You can customize the retry behavior using optional parameters such as the number of
retries,
delay, and backoff multiplier:

```dart
mix(
  key: this,
  retry: retry(
    maxRetries: 10,
    initialDelay: 350.millis,
    multiplier: 2,
    maxDelay: 5.sec,
  ),
  ...
);
```

### Non reentrant

Use `nonReentrant: nonReentrant` to prevent a method from running more than once at the
same time.

If the method is already running, additional calls will be ignored until it completes.

```dart
mix(
  key: this,
  nonReentrant: nonReentrant,
  ...
);
```

### Check internet

Use `checkInternet: checkInternet` to abort the method when there is no internet
connection
and show an error dialog to the user.

```dart
void loadData() {
  mix(
    key: this,
    checkInternet: checkInternet,
    ...
  );
}
```

You can modify this behavior using optional parameters.
For example, you can abort silently or prevent the dialog from opening if one is already
visible:

```dart
mix(
  key: this,
  checkInternet: checkInternet(
    abortSilently: true,
    ifOpenDialog: false,
  ),
  ...
);
```

To keep retrying until the internet connection is restored,
combine `checkInternet` with `retry.unlimited`.

This is useful for loading important data when the app starts:

```dart
mix(
  key: this,
  checkInternet: checkInternet(maxRetryDelay: 1.sec),
  retry: retry.unlimited,
  ...
);
```

---

### Fresh

Use `fresh: fresh` to treat the result of a method as fresh for a period of time.
While the result is considered fresh, repeated calls to the method are skipped.
Once the freshness period ends, the method is allowed to run again.

```dart
void loadData() {
  mix(
    key: this,
    fresh: fresh, // Default is 1 second of freshness
    ...
  );
}
```

You can change how long the result stays fresh using optional parameters:

```dart
mix(
  key: this,
  fresh: fresh(freshFor: 10.sec),
  ...
);
```

For example, when you enter a screen, it loads some information.
If you quickly leave and re-enter the screen, the information is still valid.
Only if you stay away longer will the information be reloaded when you return.

### Debounce

Use `debounce: debounce` to delay method execution
until it stops being called for a period of time.

This is useful when a method is triggered frequently, such as while typing.

```dart
void loadData() {
  mix(
    key: this,
    debounce: debounce, // Default is 300 milliseconds
    ...
  );
}
```

For example, if you type "hello" quickly, instead of making five API calls
(for "h", "he", "hel", "hell", and "hello"), only one call is made after the user
stops typing for 300 milliseconds.

You can modify the debounce duration using optional parameters:

```dart
mix(
  key: this,
  debounce: debounce(duration: 2.sec),
  ...
);
```

---

### Throttle

Use `throttle: throttle` to rate limit a method.
The first call runs immediately.
Any later calls are ignored until the throttle period ends.

```dart
void loadData() {
  mix(
    key: this,
    throttle: throttle, // Default is 1 second
    ...
  );
}
```

This is useful for actions that should not run too often,
such as refresh buttons, scroll handlers, or API polling.

You can customize the throttle behavior using optional parameters:

```dart
void refreshPosts({bool force = false}) {
  mix(
    key: this,
    throttle: throttle(
      ignoreThrottle: force,
      removeLockOnError: true,
      duration: 5.sec,
    ),
    ...
  );
}
```

With this setup:

* `refreshPosts()` respects the throttle period.
* `refreshPosts(force: true)` runs immediately and resets the throttle timer.

### Sequential

Use `sequential: sequential` to ensure that method calls run one at a time,
in the order they were called.

Each call waits for the previous one to finish before starting.

```dart
void processOrder(Order order) {
  mix(
    key: this,
    sequential: sequential, // Queue orders and process one at a time
    ...
  );
}
```

By default, the queue has no size limit and no timeout.
You can add limits using optional parameters:

```dart
mix(
  key: this,
  sequential: sequential(
    maxQueueSize: 10,
    queueTimeout: 30.sec,
  ),
  ...
);
```

By default, when the queue is full or items time out, newer method calls are dropped.

You can change this to a "latest wins" behavior,
where older queued calls are dropped and only the most recent waiting call is kept:

```dart
mix(
  key: this,
  sequential: sequential.latestWins,
  ...
);
```

---

## How keys work

The `mix` function uses a main `key` parameter to identify an action.

```dart
class UserCubit extends Cubit<User> {
  UserCubit() : super(User());

  void loadData() => mix(
    key: this, // Here
    () {
      // Do something
    },
  );
}
```

When you use `key: this`, it is the same as `key: runtimeType`,
because `mix` treats Cubit instance keys as their runtime-type.
In the example above, both resolve to `UserCubit`.

Because of this, your widgets can reference the same key to check loading and error
states:

```dart
class MyWidget extends StatelessWidget {

  Widget build(BuildContext context) {
    if (context.isWaiting(UserCubit)) return CircularProgressIndicator();    
    if (context.isFailed(UserCubit)) return Text('Error');    
    return Text('Loaded: ${context.watch<UserCubit>().state}',
    );
  }
}
```

### Using different key types

Keys are not limited to types. You can use any value that uniquely identifies the action.

The key can be a string:

```dart
// In the Cubit
mix(
  key: 'someKey', // Here
  ...
);

// In the widget
if (context.isWaiting('someKey')) return CircularProgressIndicator();
if (context.isFailed('someKey')) return Text('Error');
```

The key can also be an enum value:

```dart
enum ActionType { loadUser, saveSettings }

// In the Cubit
mix(
  key: ActionType.loadUser, // Here
  ...
);

// In the widget
if (context.isWaiting(ActionType.loadUser)) return CircularProgressIndicator();
if (context.isFailed(ActionType.loadUser)) return Text('Error');
```

The key can also be a Dart record, which is useful when the action depends on parameters:

```dart
class UserCubit extends Cubit<User> {
  UserCubit() : super(User());

  void loadUser(String userId) => mix(
    key: (UserCubit, userId), // Here
    () {
      // Do something
    },
  );
}
```

```dart
// In the widget
if (context.isWaiting((UserCubit, userId))) return CircularProgressIndicator();
if (context.isFailed((UserCubit, userId))) return Text('Error');
```

### Override keys

While `mix` has a main `key`,
parameters `retry`, `fresh`, `debounce`, `throttle`, and `sequential`
each accept their own `key` parameter.

This lets you control granularity by tracking state with one key while applying behavior
with another.

```dart
void loadUser(String userId) {
  mix(
    key: UserCubit, // State tracking uses UserCubit
    fresh: fresh(
      key: (UserCubit, userId), // Freshness tracked per user ID
      freshFor: 5.sec,
    ),
    () async {
      var user = await api.loadUser(userId);
      emit(
        state.copyWith(
          users: {...state.users, userId: user},
        ),
      );
    },
  );
}
```

In this example, `context.isWaiting(UserCubit)` reflects whether any user is currently
loading.
At the same time, freshness is tracked separately for each user ID.

Loading user "A" does not affect the freshness of user "B".

---

## Advanced features

### Global defaults

You can customize default configurations globally for your app.

For example, to change the default retry behavior:

```dart
RetryConfig.defaults = retry(
  maxRetries: 5,
  initialDelay: 200.millis,
  multiplier: 2.0,
  maxDelay: 10.sec,
);
```

### Accessing internal context

You can use `mix.ctx` instead of `mix` to access internal information, such as retry
attempts or queue position.

```dart
mix.ctx(
  key: this,
  retry: retry,
  sequential: sequential,
  (ctx) async {
    var attempt = ctx.retry!.attempt;
    var wasQueued = ctx.sequential!.wasQueued;
    var index = ctx.sequential!.index;
    ...
  },
);
```

### Error handling with `catchError`

If you add a `catchError` parameter, you can handle errors directly inside `mix`.

You can suppress errors, rethrow them, or wrap them in user-friendly exceptions.

Log and suppress all errors:

```dart
mix(
  key: this,
  catchError: (error, stackTrace) {
    logError(error, stackTrace);
  },
  ...
);
```

Log and rethrow all errors:

```dart
mix(
  key: this,
  catchError: (error, stackTrace) {
    logError(error, stackTrace);
    throw error; // Preserves the original stack trace
  },
  ...
);
```

Wrap all errors in a `UserException`:

```dart
mix(
  key: this,
  catchError: (error, stackTrace) {
    throw UserException('Operation failed').addCause(error);
  },
  ...
);
```

### Reusable configurations

You can define reusable configurations and apply them using the `config` parameter.

```dart
// Check internet, retry, and log start, finish, and error messages
const checkInternetRetryAndLog = MixConfig(
  checkInternet: checkInternet,
  retry: retry,
  before: () => Log.info('Starting'),
  after: () => Log.info('Finished'),
  catchError: (error, stackTrace) => Log.error('Failed', error),
);
```

Later, reuse the configuration:

```dart
mix(
  key: this,
  config: checkInternetRetryAndLog, // Here
  ...
);
```

---

## Presets

Instead of calling the `mix` function directly every time, you can define reusable
functions called **presets**.

A preset bundles a common configuration so it can be reused across your app.

For example, the following preset checks for an internet connection, retries up to five
times, logs when the operation
starts and finishes, and wraps all errors in a `UserException`.

```dart
// Define once
const checkInternetRetryAndLog() = MixPreset(
  key: this,
  checkInternet: checkInternet,
  retry: retry(maxRetries: 5),
  before: () => Log.info('Starting'),
  after: () => Log.info('Finished'),
  catchError: (error, stackTrace) {
    logError(error);
    throw UserException('Operation failed').addCause(error);
  },
);
```

You can then use the preset like a regular function:

```dart
void fetchUsers() {
  checkInternetRetryAndLog( // Here
    key: this,
    () async {
      final users = await api.getUsers();
      emit(state.copyWith(users: users));
    },
  );
}
```

---

## The optimistic functions

The Superpowers package provides three functions for optimistic UI updates.

They allow you to update the UI immediately while sending changes to the server.
Based on the server response, they can roll back changes, reload data, or issue follow-up
requests.

* `optimisticCommand` is for **blocking** operations that represent a **command**,
  something that should run on the
  server once per call.

* `optimisticSync` is for **non-blocking** operations where only the final value matters
  and intermediate values can be
  skipped, while still reaching eventual consistency with the server.

* `optimisticSyncWithPush` is similar to `optimisticSync` but also supports *
  *server-pushed updates** and multi-device
  writes using "last write wins" semantics.

To use these functions, you provide a few straightforward callbacks.
The functions handle the complex optimistic logic for you.

Here is an example implementation to illustrate the idea:

```dart
class TodoCubit extends Cubit<TodoState> {
  TodoCubit() : super(TodoState());

  void addTodo(Todo newTodo) {
    optimisticCommand(
      key: (AddTodo, newTodo.id),
      optimisticValue: () => state.todoList.add(newTodo),
      getValueFromState: (state) => state.todoList,
      applyValueToState: (state, value) =>
        state.copyWith(todoList: value as IList<Todo>),
      sendCommandToServer: (optimisticValue) async {
        await api.saveTodo(newTodo);
        return null;
      },
    );
  }
}
```

---

## Effects

Effects are one-time notifications stored in your state.
They are used to trigger side effects in widgets, such as showing dialogs, clearing text
fields,
or navigating to new screens.

Effects replace `BlocListener` but are much easier to use.

Effects are automatically consumed after being read, which ensures they only trigger once.

You can read and consume effects directly inside the `build` method using
`context.effect()`.

To demonstrate, assume your Cubit needs to clear a text field and also update its text.
You define two effects in the state: `clearEffect` and `changeTextEffect`.

```dart
// In your state
class UserState {
  final User? user;
  final Effect<bool> clearEffect; // Here
  final Effect<String> changeTextEffect; // Here

  UserState(
    this.user,
    Effect<bool>? clearEffect,
    Effect<String>? changeTextEffect,
  ) : clearEffect = clearEffect ?? Effect.spent(),
      changeTextEffect = changeTextEffect ?? Effect.spent();

  UserState copyWith({ ... });
}
```

In your Cubit, create new effects using `Effect()`:

```dart
void clearText() =>
  emit(state.copyWith(clearEffect: Effect(true)));

void changeText(String newText) =>
  emit(state.copyWith(changeTextEffect: Effect(newText)));
```

In your widget, read and consume the effects using `context.effect()`:

```dart
Widget build(BuildContext context) {

  var clear = context.effect((UserCubit c) => c.state.clearEffect);
  if (clear) controller.clear();

  var newText = context.effect((UserCubit c) => c.state.changeTextEffect);
  if (newText != null) controller.text = newText;

  return TextField(controller: controller);
}
```

---

## EffectQueue

Effect queues allow you to trigger multiple side effects in a specific order.

The Cubit emits a list of effects, and the widget provides a handler that interprets each
effect.

This makes it easy to coordinate UI actions like showing a toast, then a dialog, then
navigating to another screen.

You can choose to execute all effects in order within a single frame, or one effect per
frame.

### Defining effects

First, define the possible UI effects:

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
```

### Adding the queue to state

Your state includes an `EffectQueue`:

```dart
class AppState {
  final EffectQueue<UiEffect> effectQueue;
  ...
}
```

### Emitting effects from the Cubit

The Cubit describes what should happen by emitting `UiEffect` objects in order:

```dart
void triggerSequentialEffects() {
  emit(state.copyWith(
    effectQueue: EffectQueue<UiEffect>(
      [
        Navigate('/success'),
        ShowToast('Welcome!'),
        ShowDialog('Info', 'You have arrived.'),
      ],
      (remaining) =>
        emit(state.copyWith(effectQueue: remaining)),
    ),
  ));
}
```

### Handling effects in the widget

In your widget, use `context.effectQueue` to process the effects:

```dart
Widget build(BuildContext context) {

  context.effectQueue<AppCubit, UiEffect>(

    // Select the queue
    (cubit) => cubit.state.effectQueue,

    // Execute one effect per frame or all at once
    onePerFrame: true,

    (context, effect) => switch (effect) {

      // Show a toast
      ShowToast(:final message) =>
        ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message))),

      // Show a dialog
      ShowDialog(:final title, :final content) =>
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(title),
            content: Text(content),
          ),
        ),

      // Navigate
      Navigate(:final route) =>
        Navigator.of(context).pushNamed(route),
    },
  );

  return Text('My App');
}
```

---

## Global error handling

Use `Superpowers.globalCatchError` to handle all errors in one place.

This is useful for centralized logging and for converting technical errors
(like `FirebaseException` or `DioException`) into user-friendly messages.

```dart
void main() {
  Superpowers.globalCatchError = (error, stackTrace, key) {
    // Log all errors
    logError(error, stackTrace);

    // Convert to a friendly message
    if (error is UserException) throw error;
    else throw UserException('Something went wrong. Please try again.');
  };

  runApp(Superpowers(child: MaterialApp(...)));
}
```

The handler receives the error, its stack trace, and the `key` from the `mix` call.

If the handler returns normally, the error is suppressed.
If it throws a `UserException`, the error dialog appears.
If it throws anything else, the error propagates (useful in debug mode).

The global handler only runs when local `catchError` handlers don't suppress the error.

---

## Observer

Use `Superpowers.observer` to watch all `mix` calls in your app.

The observer is called twice for each `mix` call: once when it starts, and once when it
ends.

This is useful for performance tracking, analytics, debugging, and error monitoring.

```dart
void main() {
  Superpowers.observer = (isStart, key, metrics, error, stackTrace, duration) {
    if (isStart) {
      print('Starting: $key');
    } else {
      print('Finished: $key in ${duration?.inMilliseconds}ms');
    }
  };

  runApp(Superpowers(child: MaterialApp(...)));
}
```

The observer receives:

* `isStart`: `true` at start, `false` at end.
* `key`: The key from the `mix` call.
* `metrics`: Custom data you provide via the `metrics` parameter.
* `error` and `stackTrace`: The error that occurred, or `null` if successful.
* `duration`: How long the operation took.

You can pass custom data to the observer using the `metrics` parameter.
A common pattern is to pass the Cubit itself to access its state:

```dart
void loadUser() => mix(
  key: this,
  metrics: () => this, // Pass the Cubit to the observer
  () async {
    final user = await api.getUser();
    emit(state.copyWith(user: user));
  },
);
```

The `metrics` callback is called at start and end, so you can see how the state changed.

When using `retry`, the observer is called only once at the start and once at the end,
not for each retry attempt.

---

## Props

Use `Superpowers.setProp()` and `Superpowers.prop<T>()` to store and retrieve
key-value data across your app.

```dart
// Save
Superpowers.setProp('refreshTimer', Timer.periodic(
  Duration(minutes: 5),
  (_) => refreshData(),
));

// Read
var timer = Superpowers.prop<Timer>('refreshTimer');
```

The main benefit is **automatic cleanup**. When you call `Superpowers.clear()` in tests
or `Superpowers.prepareToLogout()` when the user logs out, all props are cleared
and disposable types (`Timer`, `StreamSubscription`, `Sink`, etc.) are automatically
canceled or closed.

```dart
// In tests
setUp(() {
  Superpowers.clear(); // Resets everything
});

// On logout
Future<void> logout() async {
  await Superpowers.prepareToLogout(); // Clears user data, keeps app config
  await authService.signOut();
}
```

The difference between `clear()` and `prepareToLogout()`:
`clear()` resets everything including `globalCatchError` and `observer`.
`prepareToLogout()` clears user data but keeps your app-level configuration.

***

### Complete docs → [blocsuperpowers.org](http://blocsuperpowers.org)

***

## By Marcelo Glasberg

<a href="https://glasberg.dev">_glasberg.dev_</a>
<br>
<a href="https://github.com/marcglasberg">_github.com/marcglasberg_</a>
<br>
<a href="https://www.linkedin.com/in/marcglasberg/">
_linkedin.com/in/marcglasberg/_</a>
<br>
<a href="https://twitter.com/glasbergmarcelo">_twitter.com/glasbergmarcelo_</a>
<br>
<a href="https://stackoverflow.com/users/3411681/marcg">
_stackoverflow.com/users/3411681/marcg_</a>
<br>
<a href="https://medium.com/@marcglasberg">_medium.com/@marcglasberg_</a>
<br>

*I wrote Google's official Flutter documentation on layout rules*:

* <a href="https://flutter.dev/docs/development/ui/layout/constraints">
  Understanding
  constraints</a>

*The Flutter packages I've authored:*

* <a href="https://pub.dev/packages/async_redux">async_redux</a>
* <a href="https://pub.dev/packages/provider_for_redux">provider_for_redux</a>
* <a href="https://pub.dev/packages/i18n_extension">i18n_extension</a>
* <a href="https://pub.dev/packages/align_positioned">align_positioned</a>
* <a href="https://pub.dev/packages/network_to_file_image">
  network_to_file_image</a>
* <a href="https://pub.dev/packages/image_pixels">image_pixels</a>
* <a href="https://pub.dev/packages/matrix4_transform">matrix4_transform</a>
* <a href="https://pub.dev/packages/back_button_interceptor">
  back_button_interceptor</a>
* <a href="https://pub.dev/packages/indexed_list_view">indexed_list_view</a>
* <a href="https://pub.dev/packages/animated_size_and_fade">
  animated_size_and_fade</a>
* <a href="https://pub.dev/packages/assorted_layout_widgets">
  assorted_layout_widgets</a>
* <a href="https://pub.dev/packages/weak_map">weak_map</a>
* <a href="https://pub.dev/packages/themed">themed</a>
* <a href="https://pub.dev/packages/bdd_framework">bdd_framework</a>
* <a href="https://pub.dev/packages/tiktoken_tokenizer_gpt4o_o1">
  tiktoken_tokenizer_gpt4o_o1</a>

*The JavaScript/TypeScript packages I've authored:*

* [Kiss State, for React](https://kissforreact.org/) (similar to Async Redux,
  but for React)
* [Easy BDD Tool, for Jest](https://www.npmjs.com/package/easy-bdd-tool-jest)

*My Medium Articles:*

* <a href="https://medium.com/flutter-community/i18n-extension-flutter-b966f4c65df9">
  i18n_extension</a> 
  (versions: <a href="https://medium.com/flutterando/qual-a-forma-f%C3%A1cil-de-traduzir-seu-app-flutter-para-outros-idiomas-ab5178cf0336">
  Português</a>)
* <a href="https://medium.com/flutter-community/flutter-the-advanced-layout-rule-even-beginners-must-know-edc9516d1a2">
  Flutter: The Advanced Layout Rule Even Beginners Must Know</a> 
  (versions: <a href="https://habr.com/ru/post/500210/">русский</a>)
* <a href="https://medium.com/flutter-community/the-new-way-to-create-themes-in-your-flutter-app-7fdfc4f3df5f">
  The New Way to create Themes in your Flutter App</a> 
