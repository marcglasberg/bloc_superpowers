import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Developed by Marcelo Glasberg (2026) https://glasberg.dev and https://github.com/marcglasberg
// For more info, see: https://pub.dartlang.org/packages/bloc_superpowers and http://blocsuperpowers.org

/// This example demonstrates the use of [EffectQueue] to trigger multiple
/// side effects in sequence.
///
/// When consuming the effect with [SuperpowersContextExtension.effectQueue]
/// we use `onePerFrame: true` (the default), so each effect executes
/// in a separate frame, which triggers a rebuild for the next effect.
/// If `onePerFrame` is set to `false`, all effects execute at once in the
/// next frame (always in order).
///
/// The Cubit emits a list of effect objects (keeping business logic clean),
/// and the widget provides a handler that interprets each effect (keeping
/// UI concerns in the UI layer).
///
/// When the button is tapped, three effects are triggered in order:
/// 1. Navigation to a new screen occurs
/// 2. A SnackBar is shown
/// 3. A dialog is displayed
///
void main() {
  runApp(
    Superpowers(
      child: BlocProvider(
        create: (_) => AppCubit(),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: const MyHomePage(),
          routes: {
            '/success': (_) => const SuccessScreen(),
          },
        ),
      ),
    ),
  );
}

// ============================================================================
// UI Effects - Define what can happen (no UI code here)
// ============================================================================

/// Sealed class defining all possible UI effects.
/// The Cubit uses these to describe WHAT should happen.
/// The Widget decides HOW to execute each effect.
sealed class UiEffect {}

class ShowToast extends UiEffect {
  final String message;

  ShowToast(this.message);
}

class ShowDialog extends UiEffect {
  final String title;
  final String text;

  ShowDialog(this.title, this.text);
}

class Navigate extends UiEffect {
  final String route;

  Navigate(this.route);
}

// ============================================================================
// State
// ============================================================================

@immutable
class AppState {
  final EffectQueue<UiEffect> effectQueue;

  AppState({EffectQueue<UiEffect>? effectQueue})
      : effectQueue = effectQueue ?? EffectQueue.spent();

  AppState copy({EffectQueue<UiEffect>? effectQueue}) =>
      AppState(effectQueue: effectQueue ?? this.effectQueue);

  static AppState initialState() => AppState();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppState &&
          runtimeType == other.runtimeType &&
          effectQueue == other.effectQueue;

  @override
  int get hashCode => effectQueue.hashCode;
}

// ============================================================================
// Cubit - Clean business logic, no UI code
// ============================================================================

class AppCubit extends Cubit<AppState> {
  AppCubit() : super(AppState.initialState());

  /// Triggers a sequence of three side effects.
  /// Note: The Cubit only describes WHAT should happen using effect objects.
  /// It has no knowledge of how toasts, dialogs, or navigation work.
  void triggerSequentialEffects() {
    emit(state.copy(
      effectQueue: EffectQueue(
        [
          Navigate('/success'),
          ShowToast('Step 2: SnackBar shown!'),
          ShowDialog(
              'Step 3: Dialog', 'Appears after the navigation and SnackBar.'),
        ],
        (remaining) => emit(state.copy(effectQueue: remaining)),
      ),
    ));
  }

  /// Resets the state to initial.
  void reset() {
    emit(AppState.initialState());
  }
}

// ============================================================================
// Widget - UI layer handles HOW to execute effects
// ============================================================================

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Consume queued effects with a handler that interprets each effect.
    // The Cubit says WHAT, the handler says HOW.
    context.effectQueue<AppCubit, UiEffect>(
      (cubit) => cubit.state.effectQueue,
      (ctx, effect) => switch (effect) {
        ShowToast(:final message) => _toast(ctx, message),
        ShowDialog(:final title, text: final text) => _dialog(ctx, title, text),
        Navigate(:final route) => _navigate(ctx, route),
      },
      onePerFrame: false, // Process all effects in one frame
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Effect Queue Example')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.playlist_play, size: 64, color: Colors.blue),
              const SizedBox(height: 24),
              const Text(
                'Effect Queue Demo',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Press the button to trigger three effects in sequence:\n'
                '1. Navigate to Success Screen\n'
                '2. Show a SnackBar\n'
                '3. Show a Dialog',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () =>
                    context.read<AppCubit>().triggerSequentialEffects(),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Sequence'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Object?> _navigate(BuildContext ctx, String route) =>
      Navigator.of(ctx).pushNamed(route);

  Future<dynamic> _dialog(BuildContext ctx, String title, String content) {
    return showDialog(
      context: ctx,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> _toast(
      BuildContext ctx, String message) {
    return ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
    );
  }
}

class SuccessScreen extends StatelessWidget {
  const SuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Success!')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, size: 100, color: Colors.green),
              const SizedBox(height: 24),
              const Text(
                'Step 1: Navigation Complete!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'The remaining effects will now execute:\n'
                '2. SnackBar will be shown\n'
                '3. Dialog will be displayed',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  context.read<AppCubit>().reset();
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.replay),
                label: const Text('Go Back & Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
