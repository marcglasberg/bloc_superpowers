// Developed by Marcelo Glasberg (2026) https://glasberg.dev and https://github.com/marcglasberg
// For more info, see: https://pub.dartlang.org/packages/bloc_superpowers and http://blocsuperpowers.org
import 'dart:async';

import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// This example lets you enter a name and click save.
/// If the name has less than 4 chars, an error dialog will be shown,
/// and the error text will also be displayed inline in red.
///
/// This demonstrates:
/// - [UserExceptionDialog] for showing error dialogs
/// - Tracking error state in the Cubit for inline error display
/// - Using mix() catchError to transform errors into UserExceptions
///
/// Instead of context.isFailed and context.getException, we track error state
/// directly in the Cubit's state.
///
void main() {
  Superpowers.clear(); // Initialize static error queue for UserExceptionDialog
  runApp(MyApp());
}

/// The state managed by UserNameCubit.
@immutable
class UserNameState {
  final String savedName;
  final String? errorText;

  const UserNameState({this.savedName = '', this.errorText});

  UserNameState copy(
          {String? savedName, String? errorText, bool clearError = false}) =>
      UserNameState(
        savedName: savedName ?? this.savedName,
        errorText: clearError ? null : (errorText ?? this.errorText),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserNameState &&
          runtimeType == other.runtimeType &&
          savedName == other.savedName &&
          errorText == other.errorText;

  @override
  int get hashCode => savedName.hashCode ^ errorText.hashCode;
}

/// A regular Cubit that uses the standalone [mix] function.
class UserNameCubit extends Cubit<UserNameState> {
  UserNameCubit() : super(const UserNameState());

  /// Clears the error state when the user types a valid name.
  void clearError() {
    if (state.errorText != null) {
      emit(state.copy(clearError: true));
    }
  }

  /// Saves the user name.
  /// Throws a [UserException] if the name has less than 4 characters.
  Future<void> saveUser(String name) async {
    await mix(
      key: 'saveUser',
      //
      config: MixConfig(
        // Clear any previous error before trying to save.
        before: () => emit(state.copy(clearError: true)),
      ),
      //
      // Transform errors into UserExceptions for dialog display.
      // Also save the errorText in state for inline display.
      catchError: (error, stackTrace) {
        // Extract errorText from the UserException if it's one.
        String? errorText;
        if (error is UserException) {
          errorText = error.errorText;
        }
        emit(state.copy(errorText: errorText ?? 'An error occurred.'));

        // Throw a wrapped error to show in dialog with callbacks.
        throw const UserException("Save failed")
            .addCause(error)
            .addCallbacks(onOk: () => print("Dialog was dismissed."));
        // Note we could also have a CANCEL button here:
        // .addCallbacks(onOk: ..., onCancel: () => print("CANCEL pressed, or dialog dismissed."));
      },
      //
      () async {
        if (name.length < 4) {
          throw UserException(
            'Name needs 4 letters or more.',
            errorText: 'At least 4 letters.',
          );
        }

        // Save the name on success.
        emit(state.copy(savedName: name));
      },
    );
  }
}

/// To display errors, put [UserExceptionDialog] in your widget tree
/// (typically below [MaterialApp]).
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => UserNameCubit(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: UserExceptionDialog(child: MyHomePage()),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  TextEditingController? controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController();
  }

  @override
  Widget build(BuildContext context) {
    // Use context.watch() to rebuild when state changes.
    final state = context.watch<UserNameCubit>().state;

    // Get error text from state (instead of context.getException).
    final errorText = state.errorText;
    final isFailed = errorText != null;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: const Text('Show Error Dialog Example')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Type a name and save:\n(See error if less than 4 chars)',
                    textAlign: TextAlign.center,
                  ),
                  //
                  TextField(
                    controller: controller,
                    onChanged: (text) {
                      // Clear error when user types 4 or more characters.
                      if (text.length >= 4) {
                        context.read<UserNameCubit>().clearError();
                      }
                    },
                    onSubmitted: (String text) =>
                        context.read<UserNameCubit>().saveUser(text),
                  ),
                  const SizedBox(height: 30),
                  //
                  // If saving failed, show the error text in red.
                  if (isFailed)
                    Text(
                      errorText,
                      style: const TextStyle(color: Colors.red),
                    ),
                  //
                  Text('Current Name: ${state.savedName}'),
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () =>
                context.read<UserNameCubit>().saveUser(controller!.text),
            child: const Text('Save'),
          ),
        ),
      ],
    );
  }
}
