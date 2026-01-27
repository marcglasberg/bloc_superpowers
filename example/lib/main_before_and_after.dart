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
/// While the async process is running, a reddish modal barrier will prevent
/// the user from tapping the button. The modal barrier is removed even if
/// the async process ends with an error, which can be simulated by turning
/// off the internet connection (putting the phone in airplane mode).
///
void main() {
  runApp(MyApp());
}

/// The state is a counter, a description, and a waiting flag.
@immutable
class AppState {
  final int counter;
  final String description;
  final bool isWaiting;

  const AppState({
    required this.counter,
    required this.description,
    required this.isWaiting,
  });

  AppState copy({int? counter, String? description, bool? isWaiting}) =>
      AppState(
        counter: counter ?? this.counter,
        description: description ?? this.description,
        isWaiting: isWaiting ?? this.isWaiting,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppState &&
          runtimeType == other.runtimeType &&
          counter == other.counter &&
          description == other.description &&
          isWaiting == other.isWaiting;

  @override
  int get hashCode =>
      counter.hashCode ^ description.hashCode ^ isWaiting.hashCode;
}

/// A regular Cubit that uses the standalone [mix] function.
class AppCubit extends Cubit<AppState> {
  AppCubit() : super(AppState(counter: 0, description: '', isWaiting: false));

  /// This method:
  /// - Adds a modal barrier before starting the async process.
  /// - Increments the counter by 1.
  /// - Loads some description text relating to the new counter number.
  /// - Removes the modal barrier after the async process ends.
  ///
  void incrementAndGetDescription() {
    mix(
      key: 'incrementAndGetDescription',
      config: MixConfig(
        // This adds a modal barrier while the async process is running.
        // Note we could have set `isWaiting` as true directly in the main function,
        // before starting the async process, and then set it to false at the end.
        // However, using `before` and `after` makes the code cleaner and ensures
        // `after` is called even if the async process throws an error.
        //
        before: () => emit(state.copy(isWaiting: true)),
        //
        // This removes the modal barrier when the async process ends,
        // even if there was some error in the process.
        // You can test it by turning off the internet connection.
        after: () => emit(state.copy(isWaiting: false)),
      ),
      //
      () async {
        emit(state.copy(counter: state.counter + 1));

        Response response = await get(
          Uri.parse(
              'https://jsonplaceholder.typicode.com/users/${state.counter}'),
        );

        Map<String, dynamic> json = jsonDecode(response.body);
        String description = json['name'] ?? 'Unknown user';

        emit(state.copy(description: description));
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
        home: MyHomePage(),
      ),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Use context.watch() to rebuild when state changes.
    final state = context.watch<AppCubit>().state;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: const Text('Before and After Example')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('You have pushed the button this many times:'),
                Text('${state.counter}', style: const TextStyle(fontSize: 30)),
                Text(
                  state.description,
                  style: const TextStyle(fontSize: 15),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () =>
                context.read<AppCubit>().incrementAndGetDescription(),
            child: const Icon(Icons.add),
          ),
        ),
        //
        // Show the modal barrier when `waiting` is true. It will block all touch events.
        // We're using `isWaiting` from state to demonstrate how to use the
        // `before` and `after` callbacks of the mix function.
        if (state.isWaiting)
          ModalBarrier(color: Colors.red.withValues(alpha: 0.4)),
      ],
    );
  }
}
