---
name: add-error-display
description: Add error state handling to widgets using context.isFailed() and context.getException()
---

# Add Error Display with isFailed()

This skill adds error state handling to widgets using `context.isFailed()` and `context.getException()`.

## What This Skill Does

Shows error UI in widgets by:
- Using `context.isFailed(key)` to check if an operation failed
- Using `context.getException(key)` to get the error message
- Displaying appropriate error UI with retry option
- Automatically clearing errors when operation succeeds

## Instructions

### Step 1: Ensure Cubit Uses mix()

The Cubit method must use `mix()` with a key:

```dart
class UserCubit extends Cubit<User?> {
  void loadUser() => mix(
    key: this,
    () async {
      final user = await api.getUser();
      if (user == null) throw UserException('User not found');
      emit(user);
    },
  );
}
```

### Step 2: Add isFailed() to Widget

Check `context.isFailed(key)` in the widget's build method:

```dart
class UserScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Check if failed
    if (context.isFailed(UserCubit)) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: ${context.getException(UserCubit)}'),
            ElevatedButton(
              onPressed: () => context.read<UserCubit>().loadUser(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Check if loading
    if (context.isWaiting(UserCubit)) {
      return const Center(child: CircularProgressIndicator());
    }

    // Show data
    final user = context.watch<UserCubit>().state;
    return Text('Hello, ${user?.name}');
  }
}
```

## Context Extensions

| Extension | Returns | Description |
|-----------|---------|-------------|
| `context.isFailed(key)` | `bool` | True if operation threw an exception |
| `context.getException(key)` | `UserException?` | The exception that was thrown |
| `context.clearException(key)` | `void` | Manually clears the error state |

## Error UI Patterns

### Full Screen Error

```dart
Widget build(BuildContext context) {
  if (context.isFailed(UserCubit)) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              '${context.getException(UserCubit)}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.read<UserCubit>().loadUser(),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
  // ...
}
```

### Inline Error Banner

```dart
Widget build(BuildContext context) {
  return Column(
    children: [
      if (context.isFailed(UserCubit))
        MaterialBanner(
          content: Text('${context.getException(UserCubit)}'),
          actions: [
            TextButton(
              onPressed: () => context.read<UserCubit>().loadUser(),
              child: const Text('Retry'),
            ),
            TextButton(
              onPressed: () => context.clearException(UserCubit),
              child: const Text('Dismiss'),
            ),
          ],
        ),
      // Rest of content
      UserContent(),
    ],
  );
}
```

### Error with Stale Data

Show error but keep displaying old data:

```dart
Widget build(BuildContext context) {
  final state = context.watch<ProductCubit>().state;

  return Column(
    children: [
      // Show error banner if failed, but keep showing products
      if (context.isFailed(ProductCubit))
        Container(
          color: Colors.red.shade100,
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: Text('Failed to refresh: ${context.getException(ProductCubit)}'),
              ),
              TextButton(
                onPressed: () => context.read<ProductCubit>().loadProducts(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),

      // Show existing products even if refresh failed
      Expanded(
        child: ProductsList(products: state.products),
      ),
    ],
  );
}
```

### Per-Item Error

```dart
Widget build(BuildContext context) {
  return ListView.builder(
    itemCount: items.length,
    itemBuilder: (context, index) {
      final item = items[index];
      final key = (DeleteItem, item.id);

      // Check error for this specific item
      if (context.isFailed(key)) {
        return ListTile(
          title: Text(item.name),
          subtitle: Text(
            'Delete failed: ${context.getException(key)}',
            style: const TextStyle(color: Colors.red),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => cubit.deleteItem(item.id),
          ),
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

### Form Submission Error

```dart
Widget build(BuildContext context) {
  return Form(
    child: Column(
      children: [
        // Form fields
        TextFormField(...),
        TextFormField(...),

        // Error message
        if (context.isFailed(SubmitForm))
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              '${context.getException(SubmitForm)}',
              style: const TextStyle(color: Colors.red),
            ),
          ),

        // Submit button
        ElevatedButton(
          onPressed: context.isWaiting(SubmitForm)
              ? null
              : () => context.read<FormCubit>().submit(formData),
          child: context.isWaiting(SubmitForm)
              ? const CircularProgressIndicator()
              : const Text('Submit'),
        ),
      ],
    ),
  );
}
```

## Error Auto-Clearing

Errors are automatically cleared when:
- The operation runs again (and starts successfully)
- You call `context.clearException(key)`

```dart
// Error cleared when loadUser() is called again
context.read<UserCubit>().loadUser();

// Manually clear error
context.clearException(UserCubit);
```

## Complete Example

```dart
class DataScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data')),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    // Error state - full screen
    if (context.isFailed(DataCubit)) {
      return _buildErrorView(context);
    }

    // Loading state
    if (context.isWaiting(DataCubit)) {
      return const Center(child: CircularProgressIndicator());
    }

    // Success state
    final data = context.watch<DataCubit>().state;
    return _buildDataView(context, data);
  }

  Widget _buildErrorView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              '${context.getException(DataCubit)}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.read<DataCubit>().loadData(),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataView(BuildContext context, DataState data) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<DataCubit>().loadData();
      },
      child: ListView.builder(
        itemCount: data.items.length,
        itemBuilder: (context, index) => ListTile(
          title: Text(data.items[index].name),
        ),
      ),
    );
  }
}
```

## User Preferences

Ask the user:
1. **What key should be checked?** (Cubit type, enum, string, or record)
2. **What error UI style?** (full screen, banner, inline text)
3. **Should retry button be included?**
4. **Keep showing stale data on error?**
