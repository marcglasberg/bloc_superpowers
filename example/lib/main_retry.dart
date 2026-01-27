import 'dart:async';

import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// This example demonstrates the [mix] function with retry functionality.
///
/// The screen is split into two halves: the top shows a text input with a save
/// button, and the bottom shows the simulated database state (server).
///
/// ## Use cases to try:
///
/// ### 1. Normal save
/// Type some text and tap "Save". The UI shows "Saving..." while the request
/// takes ~2 seconds. When complete, the text appears in the database list.
///
/// ### 2. Retry on failure
/// Type some text and tap "Save". While "Saving..." is displayed, tap "Request
/// fails". The request will fail, but the retry function will automatically
/// retry with exponential backoff. Watch the console to see retry attempts.
///
/// ### 3. Multiple failures
/// Tap "Request fails" multiple times during retries. The retry will keep
/// retrying (up to maxRetries + 1 total attempts). After all retries are
/// exhausted, the action fails and an error dialog is shown.
///
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Superpowers.clear(); // Initialize static error queue

  runApp(const MyApp());
}

class TextState {
  final IList<String> texts;

  TextState({Iterable<String>? texts})
      : texts = IList.orNull(texts) ?? const IListConst([]);

  TextState copyWith({IList<String>? texts}) =>
      TextState(texts: texts ?? this.texts);

  TextState add(String text) => TextState(texts: texts.add(text));

  @override
  String toString() => 'TextDatabaseState(texts: $texts)';
}

/// A regular Cubit that uses the standalone [mix] function.
class TextCubit extends Cubit<TextState> {
  TextCubit(super.initialState);

  /// Saves text to the server with automatic retry on failure.
  /// Uses the standalone [mix] function with lifecycle methods.
  Future<void> saveText(String text) async {
    return mix.ctx(
      key: TextCubit,
      retry: retry(
        maxRetries: 3,
        initialDelay: 1.sec,
        multiplier: 2.0,
        maxDelay: 5.sec,
        onRetry: (attemptNumber, delay, error, stack) => print(
          'SaveText: Retry $attemptNumber after $delay - Error: $error',
        ),
      ),
      // Called on final failure - throw UserException to show in dialog
      catchError: (error, stackTrace) {
        print('SaveText: Failed after 4 attempts');
        throw UserException(
          'Failed to save "$text". Please try again.'
          '\n'
          'Error we got from the server: $error',
        );
      },
      (MixContext ctx) async {
        var retry = ctx.retry!;

        print('Attempt ${retry.attempt + 1} '
            'of ${retry.config.maxRetries + 1}');

        // Save to server - may throw if shouldFail is true
        await server.saveText(text);

        // If successful, update the local state to match server
        print('SaveText: Success!');
        emit(state.copyWith(texts: state.texts.add(text)));
      },
    );
  }

  /// Clears all texts from the database.
  void clearTexts() {
    server.reset();
    emit(state.copyWith(texts: const IListConst([])));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Superpowers(
      child: BlocProvider<TextCubit>(
        create: (_) => TextCubit(TextState()),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Retry Demo',
          theme: ThemeData(primarySwatch: Colors.blue),
          //
          // Show an error DIALOG for uncaught UserExceptions.
          // Use `UserExceptionToast` instead to show a TOAST.
          home: UserExceptionDialog(
            child: const MyHomePage(),
          ),
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TextCubit, TextState>(
      builder: (context, state) {
        // Check if the "saveText" key we used in the `mix()`
        // function is currently running.
        final isWaiting = context.isWaiting(TextCubit);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Retry Demo'),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: 'Clear all',
                onPressed: () => context.read<TextCubit>().clearTexts(),
              ),
            ],
          ),
          body: Column(
            children: [
              // Top half: Text input and save button
              Expanded(
                child: Container(
                  color: Colors.blue.shade50,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Enter Text to Save!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _textController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Type something...',
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        enabled: !isWaiting,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: isWaiting
                            ? null
                            : () {
                                final text = _textController.text.trim();
                                if (text.isNotEmpty) {
                                  context.read<TextCubit>().saveText(
                                        text,
                                      );
                                  _textController.clear();
                                }
                              },
                        icon: isWaiting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(isWaiting ? 'Saving...' : 'Save'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'The save method uses the mix() function with a retry parameter.'
                        '\n\n'
                        'If the request fails, it will automatically retry with exponential backoff up to 4 times.'
                        '\n\n'
                        'The request itself takes 1.5 second to complete.\n'
                        'During that time you can press the "Request fails" button below to simulate a failure.'
                        '\n\n'
                        'If you fail the request 4 times, it will stop retrying,\n'
                        'and you will see an error dialog.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              // Divider
              Container(height: 2, color: Colors.grey.shade400),
              //
              // Bottom half: Simulated database
              const SimulatedDatabase(),
            ],
          ),
        );
      },
    );
  }
}

class SimulatedDatabase extends StatefulWidget {
  const SimulatedDatabase({super.key});

  @override
  State<SimulatedDatabase> createState() => _SimulatedDatabaseState();
}

class _SimulatedDatabaseState extends State<SimulatedDatabase> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    // Refresh the UI periodically to show the database state.
    _timer = Timer.periodic(50.millis, (_) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        color: Colors.green.shade50,
        child: Column(
          children: [
            const SizedBox(height: 16),
            const Text(
              'Database State (Simulated)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // Status row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  server.isRequestInProgress ? 'Saving...' : 'Idle',
                  style: TextStyle(
                    fontSize: 16,
                    color: server.isRequestInProgress
                        ? Colors.orange
                        : Colors.grey,
                    fontWeight: server.isRequestInProgress
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                const SizedBox(width: 10),
                if (server.isRequestInProgress)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.orange,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Saved texts list
            Expanded(
              child: server.databaseTexts.isEmpty
                  ? const Center(
                      child: Text(
                        'No texts saved yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: server.databaseTexts.length,
                      itemBuilder: (context, index) {
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green.shade200,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            title: Text(server.databaseTexts[index]),
                          ),
                        );
                      },
                    ),
            ),
            // Control buttons
            Container(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: server.isRequestInProgress
                    ? () {
                        server.shouldFail = true;
                      }
                    : null,
                icon: const Icon(Icons.error_outline, size: 16),
                label: const Text('Request fails'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade100,
                  foregroundColor: Colors.orange.shade900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Singleton instance of the simulated server.
final server = SimulatedServer();

/// Simulates a remote server with a text database.
class SimulatedServer {
  /// The "database" of saved texts on the server.
  List<String> databaseTexts = [];

  /// Whether a request is currently being processed.
  bool isRequestInProgress = false;

  /// When true, the next request will fail (for testing retry behavior).
  bool shouldFail = false;

  /// Simulated network delay for save operation (1.5 seconds).
  int saveDelay = 1500;

  /// Simulates saving text to the database.
  Future<void> saveText(String text) async {
    isRequestInProgress = true;

    try {
      await _interruptibleDelay(saveDelay);

      // Save succeeded - add to database
      databaseTexts.add(text);
    } finally {
      isRequestInProgress = false;
    }
  }

  /// Resets the server to its initial state.
  void reset() {
    databaseTexts = [];
    isRequestInProgress = false;
    shouldFail = false;
  }

  /// Interruptible delay that checks [shouldFail] every 50ms.
  /// Allows simulating mid-flight request failures.
  Future<void> _interruptibleDelay(int milliseconds) async {
    const checkInterval = 50;
    int remaining = milliseconds;
    while (remaining > 0) {
      if (shouldFail) {
        shouldFail = false;
        isRequestInProgress = false;
        throw Exception('Simulated server error');
      }
      final wait = remaining < checkInterval ? remaining : checkInterval;
      await Future.delayed(Duration(milliseconds: wait));
      remaining -= checkInterval;
    }
  }
}
