// Developed by Marcelo Glasberg (2026) https://glasberg.dev and https://github.com/marcglasberg
// For more info, see: https://pub.dartlang.org/packages/bloc_superpowers and http://blocsuperpowers.org
import 'dart:convert';

import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart';

/// This example shows a counter, a text description, and a button.
/// When the button is tapped, the counter will increment synchronously,
/// while an async process downloads some text description that relates
/// to the counter number (using JSONPlaceholder API).
///
/// If there is no internet connection, it will display a dialog to the
/// user, saying: "Failed to load.". This is implemented with `catchError`
/// in the mix() function, and a `UserExceptionDialog` added below `MaterialApp`.
///
/// Open the console to see when each widget rebuilds. Here are the 4 widgets:
///
/// 1. MyHomePage (red): rebuilds only during the initial build.
///
/// 2. CounterWidget (blue): rebuilds when you press the `+` button.
///
/// 3. DescriptionWidget (yellow): rebuilds only when the user name loads.
///
/// 4. LoadingStatusWidget (grey): rebuilds when the async work starts or finishes.
///
/// It should start like this:
///
/// ```
/// Restarted application in 271ms.
/// 🔴 MyHomePage rebuilt
/// 🔵 CounterWidget rebuilt
/// 💛 DescriptionWidget rebuilt
/// 🍏 LoadingStatusWidget rebuilt
/// ```
///
/// When you press the `+` button, you should immediately see these extra lines:
/// ```
/// 🍏 LoadingStatusWidget rebuilt
/// 🔵 CounterWidget rebuilt
/// ```
///
/// And then, a moment later, when the user name loads:
///
/// ```
/// 🍏 LoadingStatusWidget rebuilt
/// 💛 DescriptionWidget rebuilt
/// ```
///
void main() {
  runApp(MyApp());
}

/// The app state, which in this case is a counter, description, and loading state.
@immutable
class AppState {
  final int counter;
  final String description;
  final bool isLoading;
  final bool hasError;

  const AppState({
    required this.counter,
    required this.description,
    this.isLoading = false,
    this.hasError = false,
  });

  AppState copy({
    int? counter,
    String? description,
    bool? isLoading,
    bool? hasError,
  }) =>
      AppState(
        counter: counter ?? this.counter,
        description: description ?? this.description,
        isLoading: isLoading ?? this.isLoading,
        hasError: hasError ?? this.hasError,
      );

  static AppState initialState() => const AppState(counter: 0, description: "");

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppState &&
          runtimeType == other.runtimeType &&
          counter == other.counter &&
          description == other.description &&
          isLoading == other.isLoading &&
          hasError == other.hasError;

  @override
  int get hashCode =>
      counter.hashCode ^
      description.hashCode ^
      isLoading.hashCode ^
      hasError.hashCode;
}

/// A regular Cubit that uses the standalone [mix] function.
class AppCubit extends Cubit<AppState> {
  AppCubit() : super(AppState.initialState());

  /// Increments the counter by the given amount.
  void increment({required int amount}) =>
      emit(state.copy(counter: state.counter + amount));

  /// Increments the counter by 1, and then gets some description text
  /// relating to the new counter number.
  Future<void> incrementAndGetDescription() async {
    await mix(
      key: 'incrementAndGetDescription',
      config: MixConfig(
        before: () => emit(state.copy(isLoading: true, hasError: false)),
        after: () => emit(state.copy(isLoading: false)),
      ),
      catchError: (error, stackTrace) {
        print('Error in incrementAndGetDescription: $error');
        emit(state.copy(hasError: true));
        throw (error is UserException)
            ? error
            : const UserException('Failed to load.');
      },
      () async {
        // First, we increment the counter, synchronously.
        increment(amount: 1);

        // Then, we start and wait for some asynchronous process.
        // Using JSONPlaceholder API to get a user by ID.
        Response response = await get(
          Uri.parse(
              'https://jsonplaceholder.typicode.com/users/${state.counter}'),
        );
        Map<String, dynamic> json = jsonDecode(response.body);
        String description = json['name'] ?? 'Unknown user';

        // After we get the response, we can modify the state with it.
        emit(state.copy(description: description));
      },
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => AppCubit(),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: UserExceptionDialog(
            child: MyHomePage(),
          ),
        ),
      );
}

/// This is a "smart-widget" that directly accesses the store to dispatch actions.
/// It uses extracted widgets (CounterWidget and DescriptionWidget) that each
/// independently select their own state and rebuild only when needed.
class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    print('🔴 MyHomePage rebuilt');

    return Scaffold(
      appBar: AppBar(title: const Text('Select Example')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CounterWidget(),
            DescriptionWidget(),
            LoadingStatusWidget(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        // Call method directly on the Cubit
        onPressed: () => context.read<AppCubit>().incrementAndGetDescription(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Widget that selects and displays ONLY the counter.
/// Rebuilds ONLY when the counter changes, not when character changes.
class CounterWidget extends StatelessWidget {
  const CounterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    print('🔵 CounterWidget rebuilt');

    // Select only counter. Rebuilds only when counter changes.
    final counter = context.select((AppCubit cubit) => cubit.state.counter);

    return Column(
      children: [
        const Text('User for counter:'),
        Text('$counter', style: const TextStyle(fontSize: 30)),
      ],
    );
  }
}

/// Widget that selects and displays ONLY the description.
/// Rebuilds ONLY when the description changes, not when counter changes.
class DescriptionWidget extends StatelessWidget {
  const DescriptionWidget({super.key});

  @override
  Widget build(BuildContext context) {
    print('💛 DescriptionWidget rebuilt');

    return Text(
      context.select((AppCubit cubit) => cubit.state.description),
      style: const TextStyle(fontSize: 15, color: Colors.black),
      textAlign: TextAlign.center,
    );
  }
}

/// Widget that shows the loading/error status.
/// Rebuilds when isLoading or hasError changes.
class LoadingStatusWidget extends StatelessWidget {
  const LoadingStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    print('🍏 LoadingStatusWidget rebuilt');

    final isLoading = context.select((AppCubit cubit) => cubit.state.isLoading);
    final hasError = context.select((AppCubit cubit) => cubit.state.hasError);

    return Text(
      hasError
          ? 'Error loading user!'
          : isLoading
              ? 'Loading user...'
              : '',
      style: const TextStyle(fontSize: 15, color: Colors.grey),
      textAlign: TextAlign.center,
    );
  }
}
