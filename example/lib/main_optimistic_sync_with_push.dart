// This example is meant to demonstrate the [optimisticSyncWithPush] function in
// action. The screen is split into two halves: the top shows the UI state
// (Cubit), and the bottom shows the simulated database state (server).
//
// ## Use cases to try:
//
// ### 1. Optimistic update
// Tap the heart icon. The UI updates instantly (top half), while the database
// takes ~3.5 seconds to update (bottom half shows "Saving...").
//
// ### 2. Coalescing
// Tap the heart rapidly multiple times while "Saving..." is displayed. Notice:
// - The UI toggles instantly on each tap (always responsive).
// - Only one request is in flight at a time ("Saving 1...").
// - When the request completes, if the current UI state differs from what was
//   sent, a follow-up request is automatically sent ("Saving 2...").
//
// ### 3. Push updates (key feature)
// With "Push database changes" switch ON (default), tap "Liked" or "Not Liked"
// buttons to simulate an external change from another device. The UI updates
// immediately via the simulated WebSocket push. This is the key difference
// from [optimisticSync], which doesn't support push.
//
// ### 4. Push disabled behavior
// Turn OFF the "Push database changes" switch, then tap "Liked" or "Not Liked".
// The database changes but the UI doesn't update (no push). The UI only syncs
// when you tap the heart again.
//
// ### 5. Push during in-flight request
// With push ON, tap the heart to start saving. While "Saving..." is displayed,
// tap "Liked" or "Not Liked" to simulate an external change. Notice how the
// function handles the race condition using revision tracking, ensuring eventual
// consistency.
//
// ### 6. Reload on error
// Tap the heart to start saving. While "Saving..." is displayed, tap "Request
// fails". The UI keeps its optimistic state, but [onFinish]
// is called with the error. In this example, we reload from the database
// to restore the correct state.
//
// ### 7. Persistence
// Close and restart the app. The last known state is persisted using
// shared_preferences and restored on startup.
// When using PUSH, we must persist the server revision as well to ensure
// correct operation across app restarts.
//
// Note: If you DO NOT use push, try [optimisticSync] or
// [optimisticCommand] functions instead. They are much easier to implement
// since they don't require revision tracking.
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

late LikeCubit likeCubit;

/// Key for tracking the toggle like action state.
const toggleLikeKey = 'toggleLike';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Superpowers.clear();

  // Load persisted state.
  var initialState = await loadState();

  // If no persisted state exists, create the default initial state and save it.
  if (initialState == null) {
    initialState = LikeState(liked: false);
    await saveState(initialState);
  }

  // Initialize the server SIMULATION, by setting the like and revision counter.
  // In production, this would be the real server, using a database.
  server.revisionCounter = initialState.getServerRevision(toggleLikeKey) ?? 0;
  server.databaseLiked = initialState.liked;

  likeCubit = LikeCubit(initialState);
  runApp(const MyApp());
}

class LikeState {
  final bool liked;

  /// Stores the last known server revision for each optimisticSyncWithPush
  /// action. Keys are stringified versions of action keys (e.g., "toggleLike").
  /// It's persisted to maintain correct operation across app restarts.
  /// The function uses these revisions to detect stale push updates
  /// and ensure eventual consistency.
  final IMap<String, int> serverRevisionMap;

  LikeState({required this.liked, IMap<String, int>? serverRevisionMap})
      : serverRevisionMap = serverRevisionMap ?? const IMapConst({});

  LikeState copy({bool? isLiked, IMap<String, int>? serverRevisionMap}) =>
      LikeState(
        liked: isLiked ?? liked,
        serverRevisionMap: serverRevisionMap ?? this.serverRevisionMap,
      );

  /// Returns a copy of the state with the server revision updated for the given key.
  LikeState withServerRevision(Object? key, int revision) => copy(
        serverRevisionMap: serverRevisionMap.add(_keyToString(key), revision),
      );

  /// Returns the server revision for the given key, or null if not found.
  int? getServerRevision(Object? key) =>
      serverRevisionMap.get(_keyToString(key));

  Map<String, dynamic> toJson() => {
        'liked': liked,
        'serverRevisionMap': serverRevisionMap.unlock,
      };

  factory LikeState.fromJson(Map<String, dynamic> json) => LikeState(
        liked: json['liked'] as bool? ?? false,
        serverRevisionMap: IMap<String, int>.fromEntries(
          (json['serverRevisionMap'] as Map<String, dynamic>? ?? {})
              .entries
              .map((e) => MapEntry(e.key, e.value as int)),
        ),
      );

  @override
  String toString() =>
      'LikeState(liked: $liked, serverRevisionMap: $serverRevisionMap)';
}

/// Converts an action key to a String for persistence.
String _keyToString(Object? key) => key?.toString() ?? '_default_';



/// Represents the server's response including the revision number.
class ServerResponse {
  final bool liked;
  final int serverRevision;
  final int localRevision;
  final int deviceId;

  ServerResponse({
    required this.liked,
    required this.serverRevision,
    required this.localRevision,
    required this.deviceId,
  });
}

// Since LikeState is simply a boolean we could have used Cubit<bool> directly.
// However, I'm using a dedicated state class just for example purposes.
class LikeCubit extends Cubit<LikeState> {
  LikeCubit(super.initialState);

  void toggleLike() {
    optimisticSyncWithPush(
      key: toggleLikeKey,
      valueToApply: () => !state.liked,
      getValueFromState: (state) => state.liked,
      applyOptimisticValueToState: (state, optimisticValue) =>
          state.copy(isLiked: optimisticValue),
      getServerRevisionFromState: (key) => state.getServerRevision(key) ?? -1,
      sendValueToServer: (optimisticValue, localRevision, deviceId, informServerRevision) async {
        print('Sending to server: $optimisticValue');
        // Send to server and get response with revision.
        final response = await server.saveLike(
          optimisticValue,
          localRevision,
          deviceId,
        );

        // Store the server revision for use in applyServerResponseToState.
        print('Server response: $response');

        // Inform the function about the server revision.
        informServerRevision(response.serverRevision);

        return response.liked;
      },
      applyServerResponseToState: (state, serverResponse) {
        // Apply both the liked value and the server revision.
        return state
            .copy(isLiked: serverResponse as bool)
            .withServerRevision(toggleLikeKey, server.revisionCounter);
      },
      // If there was an error, revert the state to the database value.
      onFinish: (error) async {
        if (error == null) return null;

        // If there was an error, reload the value from the database.
        bool isLiked = await server.reload();
        return state.copy(isLiked: isLiked);
      },
    );
  }

  /// Handles a WebSocket push update.
  void handlePush({
    required bool liked,
    required int serverRev,
    required int localRev,
    required int deviceId,
  }) {
    print('Incoming metadata: ${(
      serverRevision: serverRev,
      localRevision: localRev,
      deviceId: deviceId,
    )}');

    serverPush(
      key: toggleLikeKey,
      pushMetadata: (
        serverRevision: serverRev,
        localRevision: localRev,
        deviceId: deviceId,
      ),
      getServerRevisionFromState: (key) => state.getServerRevision(key) ?? -1,
      applyServerPushToState: (state, key, serverRevision) =>
          state.copy(isLiked: liked).withServerRevision(key, serverRevision),
    );
  }

  /// Resets all state: deletes persisted state and resets server simulation.
  Future<void> resetAllState() async {
    // Delete persisted state.
    await deleteState();

    // Reset server simulation.
    server.reset();

    // Return fresh initial state.
    emit(LikeState(liked: false));
  }
}



class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LikeCubit>.value(
      value: likeCubit,
      child: Superpowers(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'OptimisticSyncWithPush Demo',
          theme: ThemeData(primarySwatch: Colors.blue),
          home: const MyHomePage(),
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
  late Timer _timer;
  late StreamSubscription<LikeState> _subscription;

  @override
  void initState() {
    super.initState();
    // Refresh the UI periodically to show the database state.
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      setState(() {});
    });

    // Listen to state changes and persist them.
    _subscription = likeCubit.stream.listen((state) {
      saveState(state);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final liked = context.watch<LikeCubit>().state.liked;

    return Scaffold(
      appBar: AppBar(
        title: const Text('OptimisticSyncWithPush Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: 'Reset all state',
            onPressed: () => likeCubit.resetAllState(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Top half: Like button (Cubit state)
          Expanded(
            child: Container(
              color: Colors.blue.shade50,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'UI State (Cubit)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    IconButton(
                      iconSize: 80,
                      icon: Icon(
                        liked ? Icons.favorite : Icons.favorite_border,
                        color: liked ? Colors.red : Colors.grey,
                      ),
                      onPressed: () => likeCubit.toggleLike(),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      liked ? 'Liked' : 'Not Liked',
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Tap rapidly to see coalescing in action!',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Divider
          Container(height: 2, color: Colors.grey.shade400),
          //
          const SimulatedDatabase(),
        ],
      ),
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
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Database State (Simulated)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Icon(
                server.databaseLiked ? Icons.favorite : Icons.favorite_border,
                size: 80,
                color: server.databaseLiked ? Colors.red : Colors.grey,
              ),
              const SizedBox(height: 10),
              Text(
                server.databaseLiked ? 'Liked' : 'Not Liked',
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    server.isRequestInProgress
                        ? 'Saving ${server.requestCount}...'
                        : 'Idle',
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
              const SizedBox(height: 10),
              Text(
                'Updates after server round-trip (${(server.delayBeforeWrite + server.delayAfterWrite) / 1000}s)',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              Text(
                'Number of requests received: ${server.requestCount}',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Simulate external change to the database:',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => server.simulateExternalChange(true),
                          icon: const Icon(Icons.favorite, size: 16),
                          label: const Text('Liked'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade100,
                            foregroundColor: Colors.red.shade900,
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: () => server.simulateExternalChange(false),
                          icon: const Icon(Icons.favorite_border, size: 16),
                          label: const Text('Not Liked'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade200,
                            foregroundColor: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
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
                    const SizedBox(height: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Push database changes',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: server.websocketPushEnabled,
                          onChanged: (value) {
                            setState(() {
                              server.websocketPushEnabled = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



/// Persistence functions using shared_preferences.
const _prefsKey = 'like_state';

Future<LikeState?> loadState() async {
  final prefs = await SharedPreferences.getInstance();
  final jsonString = prefs.getString(_prefsKey);
  if (jsonString == null) return null;
  try {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return LikeState.fromJson(json);
  } catch (e) {
    return null;
  }
}

Future<void> saveState(LikeState state) async {
  final prefs = await SharedPreferences.getInstance();
  final json = jsonEncode(state.toJson());
  await prefs.setString(_prefsKey, json);
}

Future<void> deleteState() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_prefsKey);
}



/// Singleton instance of the simulated server.
final server = SimulatedServer();

/// Simulates a remote server with database, WebSocket push, and request handling.
/// All server-side state and behavior is encapsulated here to clearly separate
/// it from the local app state managed by Cubit.
class SimulatedServer {
  // ---------------------------------------------------------------------------
  // Server State
  // ---------------------------------------------------------------------------

  /// The "database" value stored on the server.
  bool databaseLiked = false;

  /// Whether a request is currently being processed.
  bool isRequestInProgress = false;

  /// Total number of requests received by the server.
  int requestCount = 0;

  /// When true, the next request will fail (for testing error handling).
  bool shouldFail = false;

  /// Whether the server should push changes via "WebSocket" after writes.
  bool websocketPushEnabled = true;

  /// Server-side revision counter. Incremented on each successful write.
  /// In production, this would be managed by the actual server/database.
  int revisionCounter = 0;

  /// Simulated network delay before writing to database (ms).
  int delayBeforeWrite = 1500;

  /// Simulated network delay after writing to database (ms).
  int delayAfterWrite = 2000;

  // ---------------------------------------------------------------------------
  // Server Methods
  // ---------------------------------------------------------------------------

  /// Simulates saving to the database.
  /// Returns a [ServerResponse] with the current liked value and server revision.
  Future<ServerResponse> saveLike(
    bool flag,
    int localRevision,
    int deviceId,
  ) async {
    print('Save started');
    requestCount++;
    isRequestInProgress = true;
    print('flag = $flag, localRev = $localRevision, deviceId = $deviceId');
    await _interruptibleDelay(delayBeforeWrite);

    // Save flag and increment server revision (simulate server-side versioning).
    databaseLiked = flag;
    revisionCounter++;
    final currentServerRev = revisionCounter;

    print(
        'flag = $flag, serverRev = $currentServerRev, localRev = $localRevision, deviceId = $deviceId');
    if (websocketPushEnabled) {
      push(
        isLiked: flag,
        serverRev: currentServerRev,
        localRev: localRevision,
        deviceId: deviceId,
      );
    }

    await _interruptibleDelay(delayAfterWrite);
    isRequestInProgress = false;
    print('flag = $flag, serverRev = $currentServerRev');
    print('Save ended');

    return ServerResponse(
      liked: databaseLiked,
      serverRevision: currentServerRev,
      localRevision: localRevision,
      deviceId: deviceId,
    );
  }

  /// Simulates reloading the current value from the database.
  Future<bool> reload() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return databaseLiked;
  }

  /// Simulates a WebSocket push from the server to the client.
  Future<void> push({
    required bool isLiked,
    required int serverRev,
    required int localRev,
    required int deviceId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));
    likeCubit.handlePush(
      liked: isLiked,
      serverRev: serverRev,
      localRev: localRev,
      deviceId: deviceId,
    );
  }

  /// Simulates an external change to the database (e.g., from another client).
  void simulateExternalChange(bool liked) {
    databaseLiked = liked;
    if (websocketPushEnabled) {
      revisionCounter++;
      push(
        isLiked: databaseLiked,
        serverRev: revisionCounter,
        localRev: Random().nextInt(4294967296),
        deviceId: Random().nextInt(4294967296),
      );
    }
  }

  /// Resets the server to its initial state.
  void reset() {
    databaseLiked = false;
    isRequestInProgress = false;
    requestCount = 0;
    shouldFail = false;
    revisionCounter = 0;
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
