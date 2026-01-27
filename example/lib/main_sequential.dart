// This example demonstrates the difference between concurrent and sequential
// execution using the `sequential` parameter of the mix() function.
//
// When you tap "Concurrent", 10 increment calls run simultaneously. Since each
// reads the current state before any has finished, they all read the same value
// and the counter ends up at 1 instead of 10.
//
// When you tap "Sequential", the calls are queued and processed one at a time.
// Each call waits for the previous one to complete before starting, so the
// counter correctly increments from 0 to 10.
import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void main() {
  Superpowers.clear();

  runApp(
    BlocProvider(
      create: (_) => CounterCubit(),
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: CounterPage(),
      ),
    ),
  );
}

/// A Cubit that demonstrates concurrent vs sequential execution.
class CounterCubit extends Cubit<int> {
  CounterCubit() : super(0);

  /// Increments the counter WITHOUT sequential protection.
  /// When called 10 times rapidly, all calls read the same initial state
  /// and emit the same value, resulting in incorrect final count.
  Future<void> incrementConcurrent() async {
    return mix(
      key: (CounterCubit, #concurrent),
      () async {
        final currentValue = state;
        await Future.delayed(const Duration(milliseconds: 150));
        emit(currentValue + 1);
        print('Concurrent: emitted ${currentValue + 1}');
      },
    );
  }

  /// Increments the counter WITH sequential protection.
  /// Calls are queued and processed one at a time, ensuring each call
  /// reads the correct state from the previous call.
  Future<void> incrementSequential() async {
    return mix(
      key: (CounterCubit, #sequential),
      sequential: sequential, // Queues calls, processes one at a time
      () async {
        final currentValue = state;
        await Future.delayed(const Duration(milliseconds: 150));
        emit(currentValue + 1);
        print('Sequential: emitted ${currentValue + 1}');
      },
    );
  }

  /// Resets the counter to 0.
  void reset() => emit(0);
}

class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final count = context.watch<CounterCubit>().state;
    final cubit = context.read<CounterCubit>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sequential Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset',
            onPressed: cubit.reset,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count',
              style: const TextStyle(fontSize: 72, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            const Text(
              'Each button calls increment 10 times.\n'
              'Each increment reads state, waits 150ms, then emits state+1.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade100,
                    foregroundColor: Colors.red.shade900,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                  onPressed: () {
                    cubit.reset();
                    print('\n--- Concurrent: Calling 10 times ---');
                    for (var i = 0; i < 10; i++) {
                      cubit.incrementConcurrent();
                    }
                  },
                  child: const Text('Concurrent'),
                ),
                const SizedBox(width: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade100,
                    foregroundColor: Colors.green.shade900,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                  onPressed: () {
                    cubit.reset();
                    print('\n--- Sequential: Calling 10 times ---');
                    for (var i = 0; i < 10; i++) {
                      cubit.incrementSequential();
                    }
                  },
                  child: const Text('Sequential'),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Expected results:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Concurrent: Counter ends at 1\n'
                    '  (All 10 calls read state=0, wait, then emit 1)\n\n'
                    '• Sequential: Counter ends at 10\n'
                    '  (Each call waits for previous to finish)',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
