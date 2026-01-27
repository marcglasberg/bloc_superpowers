// Developed by Marcelo Glasberg (2026) https://glasberg.dev and https://github.com/marcglasberg
// For more info, see: https://pub.dartlang.org/packages/bloc_superpowers and http://blocsuperpowers.org
import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// This example shows how to show a spinner while any of two operations
/// (increment and multiply) is running.
///
/// In the original Superpowers version, you would write:
///
/// ```dart
/// context.isWaiting([IncrementAction, MultiplyAction])
/// ```
///
/// We track the loading state in the Cubit's state:
///
/// ```dart
/// state.isCalculating
/// ```
///
/// The state tracks whether any calculation is in progress, which achieves
/// the same effect but with explicit state management.
///
/// In more detail:
/// - There are two floating action buttons: one to increment the counter
///   and another to multiply it by 2.
/// - When any of the buttons is tapped, its respective method is called.
/// - While any of the methods is running, both buttons show a spinner
///   and are disabled.
///
void main() {
  runApp(const MyApp());
}

/// The app state, which in this case is a counter and a calculating flag.
@immutable
class AppState {
  final int counter;
  final bool isCalculating;

  const AppState({required this.counter, this.isCalculating = false});

  AppState copy({int? counter, bool? isCalculating}) => AppState(
        counter: counter ?? this.counter,
        isCalculating: isCalculating ?? this.isCalculating,
      );

  @override
  String toString() =>
      'AppState{counter: $counter, isCalculating: $isCalculating}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppState &&
          runtimeType == other.runtimeType &&
          counter == other.counter &&
          isCalculating == other.isCalculating;

  @override
  int get hashCode => counter.hashCode ^ isCalculating.hashCode;
}

/// A regular Cubit that uses the standalone [mix] function.
class AppCubit extends Cubit<AppState> {
  AppCubit() : super(const AppState(counter: 0));

  /// Increments the counter by 1 after a 1 second delay.
  /// Uses mix() with before/after to track the calculating state.
  Future<void> increment() async {
    await mix(
      key: 'increment',
      config: MixConfig(
        before: () => emit(state.copy(isCalculating: true)),
        after: () => emit(state.copy(isCalculating: false)),
      ),
      () async {
        await Future.delayed(const Duration(seconds: 1));
        emit(state.copy(counter: state.counter + 1));
      },
    );
  }

  /// Multiplies the counter by 2 after a 1 second delay.
  /// Uses mix() with before/after to track the calculating state.
  Future<void> multiply() async {
    await mix(
      key: 'multiply',
      config: MixConfig(
        before: () => emit(state.copy(isCalculating: true)),
        after: () => emit(state.copy(isCalculating: false)),
      ),
      () async {
        await Future.delayed(const Duration(seconds: 1));
        emit(state.copy(counter: state.counter * 2));
      },
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AppCubit(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const MyHomePage(),
      ),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Use context.select() to rebuild only when relevant state changes.
    int counter = context.select((AppCubit cubit) => cubit.state.counter);

    // Instead of context.isWaiting([IncrementAction, MultiplyAction]),
    // we use the isCalculating flag from state.
    // This triggers rebuilds when the calculating state changes.
    bool isCalculating =
        context.select((AppCubit cubit) => cubit.state.isCalculating);

    return MyHomePageContent(
      title: 'IsWaiting multiple actions',
      counter: counter,
      isCalculating: isCalculating,
      increment: () => context.read<AppCubit>().increment(),
      multiply: () => context.read<AppCubit>().multiply(),
    );
  }
}

class MyHomePageContent extends StatelessWidget {
  const MyHomePageContent({
    super.key,
    required this.title,
    required this.counter,
    required this.isCalculating,
    required this.increment,
    required this.multiply,
  });

  final String title;
  final int counter;
  final bool isCalculating;
  final VoidCallback increment, multiply;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Result:'),
            Text(
              '$counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            onPressed: isCalculating ? null : increment,
            elevation: isCalculating ? 0 : 6,
            backgroundColor: isCalculating ? Colors.grey[300] : Colors.blue,
            child: isCalculating
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  )
                : const Icon(Icons.add),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: isCalculating ? null : multiply,
            elevation: isCalculating ? 0 : 6,
            backgroundColor: isCalculating ? Colors.grey[300] : Colors.blue,
            child: isCalculating
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  )
                : const Icon(Icons.close),
          )
        ],
      ),
    );
  }
}
