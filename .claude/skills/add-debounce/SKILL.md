---
name: add-debounce
description: Add debounce to delay method execution until after a period of inactivity for search or validation
---

# Add Debounce

This skill delays method execution until after a period of inactivity, useful for search-as-you-type and form validation.

## What This Skill Does

Adds the `debounce` parameter to a `mix()` call so that:
- Each call resets a timer
- The method only executes after the timer completes without new calls
- Only the final call in a rapid sequence executes

## Instructions

### Step 1: Identify the Method

Ask the user which Cubit method needs debouncing, or identify methods that:
- Are triggered by user typing (search, validation)
- Fire rapidly and only the final value matters
- Would cause performance issues if called too frequently

### Step 2: Add Debounce

Add `debounce: debounce` to the `mix()` call:

```dart
import 'package:bloc_superpowers/bloc_superpowers.dart';

class SearchCubit extends Cubit<SearchState> {
  SearchCubit() : super(const SearchState());

  void search(String query) => mix(
    key: this,
    debounce: debounce,  // Add this line (default: 300ms)
    () async {
      final results = await api.search(query);
      emit(state.copyWith(results: results));
    },
  );
}
```

### Step 3: Configure Duration

The default debounce duration is **300 milliseconds**. Customize as needed:

```dart
void search(String query) => mix(
  key: this,
  debounce: debounce(duration: 500.millis),  // Wait 500ms of inactivity
  () async {
    final results = await api.search(query);
    emit(state.copyWith(results: results));
  },
);
```

## How Debounce Works

```
User types: "h" → "he" → "hel" → "hell" → "hello"
            ↓      ↓       ↓        ↓         ↓
         reset   reset   reset    reset    timer starts
                                            ↓
                                      300ms passes
                                            ↓
                                    search("hello") executes
```

Instead of 5 API calls, only 1 call is made with the final value.

## Configuration Options

### Duration Examples

```dart
debounce                              // 300ms (default)
debounce(duration: 100.millis)        // 100ms (faster response)
debounce(duration: 500.millis)        // 500ms (more delay)
debounce(duration: 1.sec)             // 1 second
```

### Per-Category Debounce with Custom Key

Different parameters can have separate debounce timers:

```dart
void searchInCategory(String category, String query) => mix(
  key: this,
  debounce: debounce(key: (SearchCubit, category)),
  () async {
    final results = await api.searchInCategory(category, query);
    emit(state.copyWith(results: results));
  },
);
```

With this setup:
- Searching in "Books" has its own debounce timer
- Searching in "Movies" has its own debounce timer
- Typing in both categories simultaneously works independently

## Common Patterns

### Search-as-You-Type

```dart
class SearchCubit extends Cubit<SearchState> {
  SearchCubit() : super(const SearchState());

  void search(String query) => mix(
    key: this,
    debounce: debounce(duration: 300.millis),
    () async {
      if (query.isEmpty) {
        emit(state.copyWith(results: []));
        return;
      }
      final results = await api.search(query);
      emit(state.copyWith(results: results));
    },
  );
}

// In widget
TextField(
  onChanged: (value) => context.read<SearchCubit>().search(value),
)
```

### Form Validation

```dart
void validateEmail(String email) => mix(
  key: ValidateEmail,
  debounce: debounce(duration: 500.millis),
  () async {
    final isValid = await api.checkEmailAvailable(email);
    emit(state.copyWith(emailError: isValid ? null : 'Email taken'));
  },
);
```

### Auto-Save

```dart
void autoSave(String content) => mix(
  key: AutoSave,
  debounce: debounce(duration: 2.sec),  // Save after 2 seconds of inactivity
  () async {
    await api.saveDraft(content);
    emit(state.copyWith(lastSaved: DateTime.now()));
  },
);
```

### Debounce with Loading State

```dart
void search(String query) => mix(
  key: this,
  debounce: debounce(duration: 300.millis),
  () async {
    final results = await api.search(query);
    emit(state.copyWith(results: results));
  },
);

// In widget
Widget build(BuildContext context) {
  return Column(
    children: [
      TextField(
        onChanged: (value) => context.read<SearchCubit>().search(value),
      ),
      if (context.isWaiting(SearchCubit))
        const LinearProgressIndicator(),
      // ... results list
    ],
  );
}
```

## Debounce vs Throttle

| Feature | Behavior | Best For |
|---------|----------|----------|
| **Debounce** | Executes **after** inactivity | Search, validation, auto-save |
| **Throttle** | Executes **first** call, ignores rest | Scroll, resize, refresh |

**Debounce example:** User types "hello"
- Only searches for "hello" (after typing stops)

**Throttle example:** User scrolls rapidly
- Loads data immediately, ignores rapid scroll events for 1 second

## Complete Example

```dart
class SearchCubit extends Cubit<SearchState> {
  SearchCubit() : super(const SearchState());

  void search(String query) => mix(
    key: this,
    debounce: debounce(duration: 300.millis),
    () async {
      if (query.trim().isEmpty) {
        emit(state.copyWith(results: [], query: ''));
        return;
      }

      final results = await api.search(query);
      emit(state.copyWith(results: results, query: query));
    },
  );

  void searchInCategory(String category, String query) => mix(
    key: (Search, category),  // State tracking per category
    debounce: debounce(key: (Search, category)),  // Debounce per category
    () async {
      final results = await api.searchInCategory(category, query);
      emit(state.copyWith(
        categoryResults: {...state.categoryResults, category: results},
      ));
    },
  );
}

// Widget
class SearchScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<SearchCubit>().state;

    return Column(
      children: [
        TextField(
          decoration: const InputDecoration(hintText: 'Search...'),
          onChanged: (value) => context.read<SearchCubit>().search(value),
        ),
        if (context.isWaiting(SearchCubit))
          const LinearProgressIndicator(),
        Expanded(
          child: ListView.builder(
            itemCount: state.results.length,
            itemBuilder: (context, index) => ListTile(
              title: Text(state.results[index].title),
            ),
          ),
        ),
      ],
    );
  }
}
```

## User Preferences

Ask the user:
1. **What duration?** (300ms is good for search, longer for auto-save)
2. **Per-parameter debounce?** (separate timers for different inputs)
