// Developed by Marcelo Glasberg (2026) https://glasberg.dev and https://github.com/marcglasberg
// For more info, see: https://pub.dartlang.org/packages/bloc_superpowers and http://blocsuperpowers.org
import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// This example shows a counter and a button.
/// When the button is tapped, the counter will increment asynchronously.
///
/// While the action is running:
/// - The FAB shows a spinner instead of the plus icon
/// - The FAB is disabled (can't be pressed again)
/// - The counter text is greyed out
///
/// Instead of using context.isWaiting(ActionType), we track the waiting state
/// directly in the Cubit's state.
///
void main() {
  runApp(MyApp());
}

/// The app state, which in this case is a counter and a waiting flag.
@immutable
class AppState {
  final int counter;
  final bool isWaiting;

  const AppState({required this.counter, this.isWaiting = false});

  AppState copy({int? counter, bool? isWaiting}) => AppState(
        counter: counter ?? this.counter,
        isWaiting: isWaiting ?? this.isWaiting,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppState &&
          runtimeType == other.runtimeType &&
          counter == other.counter &&
          isWaiting == other.isWaiting;

  @override
  int get hashCode => counter.hashCode ^ isWaiting.hashCode;

  @override
  String toString() => 'AppState{counter: $counter, isWaiting: $isWaiting}';
}

/// A regular Cubit that uses the standalone [mix] function.
class AppCubit extends Cubit<AppState> {
  AppCubit() : super(const AppState(counter: 0));

  /// Waits for 2 seconds, then increments the counter by 1.
  /// Uses mix() with before/after to track the waiting state.
  Future<void> waitAndIncrement() async {
    await mix(
      key: 'waitAndIncrement',
      config: MixConfig(
        // Set waiting to true before the async work starts, to false when done.
        before: () => emit(state.copy(isWaiting: true)),
        after: () => emit(state.copy(isWaiting: false)),
      ),
      //
      () async {
        await Future.delayed(const Duration(seconds: 2));
        emit(state.copy(counter: state.counter + 1));
      },
    );
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => AppCubit(),
        child: const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: HomePage(),
        ),
      );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Check if the action is running to show spinner and disable button.
    // Instead of context.isWaiting(ActionType), we use state.isWaiting.
    final isWaiting = context.select((AppCubit cubit) => cubit.state.isWaiting);

    return Scaffold(
      appBar: AppBar(title: const Text('Show Spinner Example')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('You have pushed the button this many times:'),
            CounterWidget(),
          ],
        ),
      ),
      // Here we disable the button while the async work is running.
      floatingActionButton: isWaiting
          ? const FloatingActionButton(
              disabledElevation: 0,
              onPressed: null,
              child: SizedBox(
                width: 25,
                height: 25,
                child: CircularProgressIndicator(),
              ),
            )
          : FloatingActionButton(
              disabledElevation: 0,
              onPressed: () => context.read<AppCubit>().waitAndIncrement(),
              child: const Icon(Icons.add),
            ),
    );
  }
}

class CounterWidget extends StatelessWidget {
  const CounterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppCubit>().state;

    return Text(
      '${state.counter}',
      style: TextStyle(
        fontSize: 40,
        color: state.isWaiting ? Colors.grey[350] : Colors.black,
      ),
    );
  }
}
