---
name: add-loading-indicator
description: Add loading state tracking to widgets using context.isWaiting() for spinners and skeletons
---

# Add Loading Indicator with isWaiting()

This skill adds loading state tracking to widgets using `context.isWaiting()`.

## What This Skill Does

Shows loading indicators in widgets by:
- Using `context.isWaiting(key)` to check if an operation is in progress
- Displaying appropriate loading UI (spinner, skeleton, overlay)
- Automatically updating when the operation completes

## Instructions

### Step 1: Ensure Cubit Uses mix()

The Cubit method must use `mix()` with a key:

```dart
class UserCubit extends Cubit<User> {
  void loadUser() => mix(
    key: this,  // Key used for tracking
    () async {
      final user = await api.getUser();
      emit(user);
    },
  );
}
```

### Step 2: Add isWaiting() to Widget

Check `context.isWaiting(key)` in the widget's build method:

```dart
class UserScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Check if loading
    if (context.isWaiting(UserCubit)) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // Show data
    final user = context.watch<UserCubit>().state;
    return Text('Hello, ${user.name}');
  }
}
```

## Key Matching

The key in `isWaiting()` must match the key in `mix()`:

```dart
// In Cubit
mix(key: this, ...)           // → context.isWaiting(UserCubit)
mix(key: UserCubit, ...)      // → context.isWaiting(UserCubit)
mix(key: 'loadUser', ...)     // → context.isWaiting('loadUser')
mix(key: LoadAction.user, ...)// → context.isWaiting(LoadAction.user)
mix(key: (UserCubit, id), ...)// → context.isWaiting((UserCubit, id))
```

## Loading UI Patterns

### Full Screen Replacement

```dart
Widget build(BuildContext context) {
  if (context.isWaiting(UserCubit)) {
    return const Center(child: CircularProgressIndicator());
  }
  return UserProfile();
}
```

### Inline Loading Indicator

```dart
Widget build(BuildContext context) {
  return Column(
    children: [
      if (context.isWaiting(UserCubit))
        const LinearProgressIndicator(),
      UserProfile(),
    ],
  );
}
```

### Overlay Loading

```dart
Widget build(BuildContext context) {
  return Stack(
    children: [
      UserProfile(),
      if (context.isWaiting(UserCubit))
        Container(
          color: Colors.black26,
          child: const Center(child: CircularProgressIndicator()),
        ),
    ],
  );
}
```

### Button Loading State

```dart
Widget build(BuildContext context) {
  final isLoading = context.isWaiting(SaveUser);

  return ElevatedButton(
    onPressed: isLoading ? null : () => cubit.saveUser(user),
    child: isLoading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Text('Save'),
  );
}
```

### Skeleton Loading

```dart
Widget build(BuildContext context) {
  if (context.isWaiting(ProductCubit)) {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (_, __) => const ProductSkeleton(),
    );
  }

  final products = context.watch<ProductCubit>().state.products;
  return ListView.builder(
    itemCount: products.length,
    itemBuilder: (_, i) => ProductCard(product: products[i]),
  );
}
```

### Per-Item Loading

```dart
Widget build(BuildContext context) {
  return ListView.builder(
    itemCount: items.length,
    itemBuilder: (context, index) {
      final item = items[index];

      // Check loading for this specific item
      if (context.isWaiting((DeleteItem, item.id))) {
        return const ListTile(
          title: Text('Deleting...'),
          trailing: CircularProgressIndicator(),
        );
      }

      return ListTile(
        title: Text(item.name),
        trailing: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () => cubit.deleteItem(item.id),
        ),
      );
    },
  );
}
```

## Multiple Loading States

### Check Any of Multiple Keys

```dart
Widget build(BuildContext context) {
  final isLoading = context.isWaiting(LoadUsers) ||
                    context.isWaiting(LoadPosts);

  if (isLoading) {
    return const CircularProgressIndicator();
  }
  // ...
}
```

### Different Indicators for Different Operations

```dart
Widget build(BuildContext context) {
  return Column(
    children: [
      // Header with user loading
      if (context.isWaiting(LoadUser))
        const LinearProgressIndicator()
      else
        UserHeader(),

      // Posts section with its own loading
      if (context.isWaiting(LoadPosts))
        const PostsSkeleton()
      else
        PostsList(),
    ],
  );
}
```

## Complete Example

```dart
// Cubit with multiple operations
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit() : super(const ProfileState());

  void loadProfile() => mix(
    key: LoadProfile,
    () async {
      final profile = await api.getProfile();
      emit(state.copyWith(profile: profile));
    },
  );

  void updateAvatar(File image) => mix(
    key: UpdateAvatar,
    () async {
      final url = await api.uploadAvatar(image);
      emit(state.copyWith(avatarUrl: url));
    },
  );

  void saveSettings(Settings settings) => mix(
    key: SaveSettings,
    () async {
      await api.saveSettings(settings);
      emit(state.copyWith(settings: settings));
    },
  );
}

// Widget with loading states
class ProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Full screen loading for initial load
    if (context.isWaiting(LoadProfile)) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final state = context.watch<ProfileCubit>().state;

    return Scaffold(
      body: Column(
        children: [
          // Avatar with overlay loading
          Stack(
            children: [
              CircleAvatar(backgroundImage: NetworkImage(state.avatarUrl)),
              if (context.isWaiting(UpdateAvatar))
                const Positioned.fill(
                  child: CircularProgressIndicator(),
                ),
            ],
          ),

          // Settings section
          SettingsForm(
            settings: state.settings,
            onSave: (s) => context.read<ProfileCubit>().saveSettings(s),
          ),

          // Save button with loading
          ElevatedButton(
            onPressed: context.isWaiting(SaveSettings)
                ? null
                : () => context.read<ProfileCubit>().saveSettings(state.settings),
            child: context.isWaiting(SaveSettings)
                ? const CircularProgressIndicator()
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}
```

## User Preferences

Ask the user:
1. **What key should be checked?** (Cubit type, enum, string, or record)
2. **What loading UI style?** (full screen, inline, overlay, skeleton)
3. **Should buttons be disabled while loading?**
