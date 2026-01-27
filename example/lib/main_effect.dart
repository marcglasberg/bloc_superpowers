import 'dart:convert';

import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart';

// Developed by Marcelo Glasberg (2026) https://glasberg.dev and https://github.com/marcglasberg
// For more info, see: https://pub.dartlang.org/packages/bloc_superpowers and http://blocsuperpowers.org

/// This example demonstrates the use of "effects" (of type [Effect]) to
/// change a controller state, or perform any other one-time operation.
///
/// It shows a text-field, and two buttons.
/// When the first button is tapped, an async process downloads
/// some text from the internet and puts it in the text-field.
///
/// When the second button is tapped, the text-field is cleared.
///
void main() {
  runApp(
    Superpowers(
      child: BlocProvider(
        create: (_) => AppCubit(),
        child: const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: MyHomePage(),
        ),
      ),
    ),
  );
}

/// The app state, which in this case is a counter and two effects.
@immutable
class AppState {
  final int counter;
  final Effect<bool> clearEffect;
  final Effect<String> changeTextEffect;

  AppState({
    required this.counter,
    Effect<bool>? clearEffect,
    Effect<String>? changeTextEffect,
  })  : clearEffect = clearEffect ?? Effect.spent(),
        changeTextEffect = changeTextEffect ?? Effect.spent();

  AppState copy({
    int? counter,
    Effect<bool>? clearEffect,
    Effect<String>? changeTextEffect,
  }) =>
      AppState(
        counter: counter ?? this.counter,
        clearEffect: clearEffect ?? this.clearEffect,
        changeTextEffect: changeTextEffect ?? this.changeTextEffect,
      );

  static AppState initialState() => AppState(counter: 1);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppState &&
          runtimeType == other.runtimeType &&
          counter == other.counter &&
          clearEffect == other.clearEffect &&
          changeTextEffect == other.changeTextEffect;

  @override
  int get hashCode =>
      counter.hashCode ^ clearEffect.hashCode ^ changeTextEffect.hashCode;
}

/// A regular Cubit that uses the standalone [mix] function.
class AppCubit extends Cubit<AppState> {
  AppCubit() : super(AppState.initialState());

  /// Orders the text-controller to clear.
  void clearText() async {
    emit(state.copy(
      clearEffect: Effect(),
    ));
  }

  /// Downloads some new text, and then creates an effect
  /// that tells the text-controller to display that new text.
  /// Uses mix() with before/after to show a modal barrier while running.
  Future<void> changeText() async {
    await mix(
      key: 'changeText',
      //
      () async {
        // Start and wait for some asynchronous process.
        Response response = await get(
          Uri.parse("https://swapi.dev/api/people/${state.counter}/"),
        );
        Map<String, dynamic> json = jsonDecode(response.body);
        String newText = json['name'] ?? 'Unknown Star Wars character';

        emit(state.copy(
          counter: state.counter + 1,
          changeTextEffect: Effect<String>(newText),
        ));
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // --------------

    // 1. Here we track the effect that tells the controller to clear its text.
    // Using context.effect() watches `clearEffect` and consumes the effect.

    var clearText = context.effect((AppCubit c) => c.state.clearEffect);
    if (clearText == true) controller.clear();

    // --------------

    // 2. Here we track the effect that tells the controller to change its text.
    // Using context.effect() watches `changeTextEffect` and consumes the effect.

    String? newText = context.effect((AppCubit c) => c.state.changeTextEffect);
    if (newText != null) controller.text = newText;

    // --------------

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: const Text('Effect Example')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('This is a TextField. Click to edit it:'),
                TextField(controller: controller),
                const SizedBox(height: 20),
                ChangeButton(),
                const SizedBox(height: 20),
                ClearButton(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ChangeButton extends StatelessWidget {
  const ChangeButton({super.key});

  @override
  Widget build(BuildContext context) {
    var isWaiting = context.isWaiting('changeText');

    return FloatingActionButton(
      elevation: isWaiting ? 0 : null,
      onPressed: isWaiting ? null : () => context.read<AppCubit>().changeText(),
      child: isWaiting
          ? const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            )
          : const Text("Change"),
    );
  }
}

class ClearButton extends StatelessWidget {
  const ClearButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => context.read<AppCubit>().clearText(),
      child: const Text("Clear"),
    );
  }
}
