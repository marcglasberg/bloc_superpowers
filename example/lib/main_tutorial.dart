// bloc_superpowers Tutorial
//
// This example demonstrates multiple features of bloc_superpowers in a
// realistic Notes app. Each feature is marked with a comment explaining
// what it demonstrates.
//
// Features demonstrated:
// - mix() with key: this
// - context.isWaiting() for loading states
// - context.isFailed() and context.getException() for error states
// - UserException for user-facing errors
// - UserExceptionDialog for automatic error dialogs
// - retry for automatic retry with exponential backoff
// - debounce for search-as-you-type
// - fresh to prevent reloading data too often
// - nonReentrant to prevent double-tap on save
// - Effect to clear the text field after saving
//
import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void main() {
  runApp(const NotesApp());
}

// =============================================================================
// MODEL
// =============================================================================

class Note {
  final String id;
  final String text;
  final DateTime createdAt;

  Note({required this.id, required this.text, required this.createdAt});
}

// =============================================================================
// STATE
// =============================================================================

@immutable
class NotesState {
  final IList<Note> notes;
  final String searchQuery;

  // This demonstrates Effect: a one-time notification to clear the text field.
  final Effect clearInputEffect;

  NotesState({
    Iterable<Note>? notes,
    this.searchQuery = '',
    Effect? clearInputEffect,
  })  : notes = IList.orNull(notes) ?? const IList.empty(),
        clearInputEffect = clearInputEffect ?? Effect.spent();

  bool get isEmpty => notes.isEmpty;

  NotesState copyWith({
    Iterable<Note>? notes,
    String? searchQuery,
    Effect? clearInputEffect,
  }) =>
      NotesState(
        notes: IList(notes ?? this.notes),
        searchQuery: searchQuery ?? this.searchQuery,
        clearInputEffect: clearInputEffect ?? this.clearInputEffect,
      );

  /// Returns a new state without the note with the given id.
  NotesState removeNote(String id) =>
      copyWith(notes: notes.where((n) => n.id != id));

  /// Returns notes filtered by the search query.
  IList<Note> get filteredNotes {
    if (searchQuery.isEmpty) return notes;
    final query = searchQuery.toLowerCase();
    return notes.where((n) => n.text.toLowerCase().contains(query)).toIList();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotesState &&
          notes == other.notes &&
          searchQuery == other.searchQuery &&
          clearInputEffect == other.clearInputEffect;

  @override
  int get hashCode =>
      notes.hashCode ^ searchQuery.hashCode ^ clearInputEffect.hashCode;
}

// =============================================================================
// CUBIT
// =============================================================================

class NotesCubit extends Cubit<NotesState> {
  NotesCubit() : super(NotesState());

  /// Loads notes from the "server".
  void loadNotes({bool force = false}) {
    mix(
      // This demonstrates mix() with key.
      // Using `this` means the key is the Cubit's runtimeType (NotesCubit).
      // This key is used by context.isWaiting() and context.isFailed().
      key: this,

      // This demonstrates fresh: prevents reloading data that's still valid.
      // If loadNotes() was called successfully recently, skip it.
      // Use force: true to bypass this (e.g., pull-to-refresh).
      fresh: fresh(ignoreFresh: force),

      // This demonstrates retry: automatic retry with exponential backoff.
      retry: retry,

      () async {
        // This API request will fail from time to time to demonstrate retry:
        // It will fail on fetches 3, 5, 6, 7, and 8.
        final notes = await api.fetchNotes();

        emit(state.copyWith(notes: notes));
      },
    );
  }

  /// Adds a new note.
  void addNote(String text) {
    mix(
      key: 'addNote',

      // This demonstrates nonReentrant: if the user taps "Add" twice quickly,
      // only the first tap executes. The second is silently ignored.
      nonReentrant: nonReentrant,

      // This demonstrates catchError: transform any error into a UserException.
      // The UserExceptionDialog will show this message to the user.
      catchError: (error, stack) {
        throw UserException('Failed to add note').addReason(error.toString());
      },

      () async {
        // This demonstrates UserException: validate input and throw if invalid.
        if (text.trim().isEmpty) throw StateError("Note can't be empty.");

        final newNote = await api.saveNote(text);

        emit(state.copyWith(
          notes: state.notes.add(newNote),

          // This demonstrates Effect: signal the UI to clear the text field.
          // The Effect is consumed once by the widget, then becomes "spent".
          clearInputEffect: Effect(),
        ));
      },
    );
  }

  /// Deletes a note.
  void removeNote(String noteId) {
    mix(
      key: ('deleteNote', noteId),
      () async {
        await api.deleteNote(noteId);

        // This demonstrates encapsulating state
        // changes in the state class itself.
        emit(state.removeNote(noteId));
      },
    );
  }

  /// Searches notes by query.
  void search(String query) {
    mix(
      key: 'search',

      // This demonstrates debounce: if the user types "hello" quickly,
      // instead of 5 searches (h, he, hel, hell, hello), only 1 search
      // runs after they stop typing for 300ms.
      debounce: debounce,

      () async {
        emit(state.copyWith(searchQuery: query));
      },
    );
  }
}

// =============================================================================
// APP
// =============================================================================

class NotesApp extends StatelessWidget {
  const NotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Superpowers(
      child: BlocProvider(
        create: (_) => NotesCubit()..loadNotes(),
        child: MaterialApp(
          title: 'Notes Tutorial',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
            useMaterial3: true,
          ),

          // This demonstrates UserExceptionDialog: automatically shows an
          // error dialog whenever a mix() call throws a UserException.
          home: UserExceptionDialog(
            child: const NotesScreen(),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SCREEN
// =============================================================================

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // This demonstrates context.isFailed(): returns true if loadNotes() failed.
    final loadFailed = context.isFailed(NotesCubit);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Notes'),
        actions: [RefreshButtonWithLoadingIndicator()],
      ),
      body: Column(
        children: [
          SearchBar(),
          if (loadFailed) ErrorMessage(),
          NotesList(),
          AddNoteInput(),
        ],
      ),
    );
  }
}

class AddNoteInput extends StatefulWidget {
  const AddNoteInput({super.key});

  @override
  State<AddNoteInput> createState() => _AddNoteInputState();
}

class _AddNoteInputState extends State<AddNoteInput> {
  final _controller = TextEditingController();

  static const inputDecoration = InputDecoration(
    hintText: 'Add a new note...',
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
  );

  static List<BoxShadow>? boxShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      blurRadius: 4,
      offset: const Offset(0, -2),
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // This demonstrates Effect: consume the clearInputEffect.
    // Returns true if the effect was just dispatched, false if already spent.
    final clear = context.effect((NotesCubit c) => c.state.clearInputEffect);
    if (clear == true) _controller.clear();

    // This demonstrates context.isWaiting() with a different key.
    final isAddingNote = context.isWaiting('addNote');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: boxShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: inputDecoration,
              onSubmitted: isAddingNote
                  ? null
                  : (text) => context.read<NotesCubit>().addNote(text),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            // Disable button while adding (nonReentrant handles this too,
            // but disabling gives better UX feedback).
            onPressed: isAddingNote
                ? null
                : () => context.read<NotesCubit>().addNote(_controller.text),
            icon: isAddingNote
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.add),
            label: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class RefreshButtonWithLoadingIndicator extends StatelessWidget {
  const RefreshButtonWithLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    // This demonstrates context.isWaiting(): returns true while loadNotes()
    // is running. The widget rebuilds automatically when this changes.
    final isLoadingNotes = context.isWaiting(NotesCubit);

    return isLoadingNotes
        ? const Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        : IconButton(
            icon: const Icon(Icons.refresh),
            // Force reload bypasses the `fresh` check.
            onPressed: () => context.read<NotesCubit>().loadNotes(force: true),
          );
  }
}

class ErrorMessage extends StatelessWidget {
  const ErrorMessage({super.key});

  @override
  Widget build(BuildContext context) {
    // This demonstrates context.getException() to get the error message.
    final errorMessage = context.getException(NotesCubit)!.message;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              errorMessage,
              style: const TextStyle(color: Colors.red),
            ),
          ),
          TextButton(
            onPressed: () => context.read<NotesCubit>().loadNotes(force: true),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// Search bar - demonstrates debounce.
class SearchBar extends StatelessWidget {
  const SearchBar({super.key});

  static const searchDecoration = InputDecoration(
    hintText: 'Search...',
    prefixIcon: Icon(Icons.search),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Color(0xFFCCCCCC)),
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        decoration: searchDecoration,
        // This demonstrates debounce: search is called on every keystroke,
        // but the actual search only runs after 300ms of inactivity.
        onChanged: (query) => context.read<NotesCubit>().search(query),
      ),
    );
  }
}

class NotesList extends StatelessWidget {
  const NotesList({super.key});

  @override
  Widget build(BuildContext context) {
    //
    // This demonstrates context.isWaiting(): returns true while loadNotes()
    // is running. The widget rebuilds automatically when this changes.
    final isLoadingNotes = context.isWaiting(NotesCubit);

    final isEmpty = context.select((NotesCubit c) => c.state.isEmpty);

    final filteredNotes =
        context.select((NotesCubit c) => c.state.filteredNotes);

    final searchQuery = context.select((NotesCubit c) => c.state.searchQuery);

    return Expanded(
      child: isLoadingNotes && isEmpty
          ? const Center(child: CircularProgressIndicator())
          : filteredNotes.isEmpty
              ? Center(
                  child: Text(
                    isEmpty
                        ? 'No notes yet. Add one below!'
                        : 'No notes match "$searchQuery"',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredNotes.length,
                  itemBuilder: (context, index) =>
                      NoteCard(note: filteredNotes[index]),
                ),
    );
  }
}

class NoteCard extends StatelessWidget {
  final Note note;

  const NoteCard({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    // Check if this specific note is being deleted.
    final isDeleting = context.isWaiting(('deleteNote', note.id));

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(note.text),
        subtitle: Text(
          '${note.createdAt.hour}:${note.createdAt.minute.toString().padLeft(2, '0')}',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        trailing: isDeleting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => context.read<NotesCubit>().removeNote(note.id),
              ),
      ),
    );
  }
}

// =============================================================================
// SIMULATED API
// =============================================================================

/// Simulated API with artificial delays and occasional failures.
final api = _SimulatedApi();

class _SimulatedApi {
  final List<Note> _notes = [];
  int _idCounter = 0;
  int _fetchAttempts = 0;

  /// Simulates fetching notes from a server.
  /// Fails on the first attempt to demonstrate retry.
  Future<List<Note>> fetchNotes() async {
    await Future.delayed(const Duration(milliseconds: 800));

    _fetchAttempts++;

    // Fail to demonstrate retry on fetches 3, 5, 6, 7, and 8.
    // Fetch 3 will be retried, and will succeed on the 4th attempt.
    // Fetches 5-8 will be retried 3 times before finally failing.
    if (_fetchAttempts == 3 || (_fetchAttempts >= 5 && _fetchAttempts <= 8)) {
      print('Fetch $_fetchAttempts failed.');
      throw UserException('Network error');
    } else {
      print('Fetch $_fetchAttempts successful.');
    }

    return List.unmodifiable(_notes);
  }

  /// Simulates adding a note to the server.
  Future<Note> saveNote(String text) async {
    await Future.delayed(const Duration(milliseconds: 500));

    final note = Note(
      id: 'note_${++_idCounter}',
      text: text.trim(),
      createdAt: DateTime.now(),
    );
    _notes.insert(0, note);
    return note;
  }

  /// Simulates deleting a note from the server.
  Future<void> deleteNote(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _notes.removeWhere((n) => n.id == id);
  }
}
