// Developed by Marcelo Glasberg (2026) https://glasberg.dev and https://github.com/marcglasberg
// For more info, see: https://pub.dartlang.org/packages/bloc_superpowers and http://blocsuperpowers.org
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart';

/// This example shows a List of posts from JSONPlaceholder API.
///
/// - Scrolling to the bottom of the list will async load the next 10 posts.
///
/// - Scrolling past the top of the list (pull to refresh) will refresh the list
///   and return a future that tells the `RefreshIndicator` when complete.
///
/// - The `isLoadingMore` state prevents the user from loading more
///   while the async action is running.
///
void main() {
  runApp(MyApp());
}

/// The app state, which is a list of post titles and loading flags.
@immutable
class PostsState {
  final List<String> posts;
  final bool isLoadingMore;

  const PostsState({
    required this.posts,
    this.isLoadingMore = false,
  });

  PostsState copy({List<String>? posts, bool? isLoadingMore}) => PostsState(
        posts: posts ?? this.posts,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      );

  static PostsState initialState() =>
      const PostsState(posts: <String>[], isLoadingMore: false);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PostsState &&
          runtimeType == other.runtimeType &&
          _listEquals(posts, other.posts) &&
          isLoadingMore == other.isLoadingMore;

  // Simple list equality check
  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll([...posts, isLoadingMore]);
}

/// A regular Cubit that manages the posts list.
class PostListCubit extends Cubit<PostsState> {
  PostListCubit() : super(PostsState.initialState());

  /// Loads more posts (next 10) from the API.
  Future<void> loadMore() async {
    // Prevent concurrent loads
    if (state.isLoadingMore) return;

    emit(state.copy(isLoadingMore: true));

    try {
      List<String> list = List.from(state.posts);
      int start = state.posts.length;

      // Fetch 10 posts. JSONPlaceholder has 100 posts (IDs 1-100).
      Response response = await get(
        Uri.parse(
            'https://jsonplaceholder.typicode.com/posts?_start=$start&_limit=10'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        for (final post in data) {
          list.add(post['title'] ?? 'Unknown post');
        }
      }

      emit(state.copy(posts: list, isLoadingMore: false));
    } catch (e) {
      emit(state.copy(isLoadingMore: false));
    }
  }

  /// Refreshes the list (loads first 10 posts).
  Future<void> refresh() async {
    try {
      List<String> list = [];

      // Fetch the first 10 posts.
      Response response = await get(
        Uri.parse(
            'https://jsonplaceholder.typicode.com/posts?_start=0&_limit=10'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        for (final post in data) {
          list.add(post['title'] ?? 'Unknown post');
        }
      }

      emit(state.copy(posts: list));
    } catch (e) {
      // Keep existing posts on error
    }
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => PostListCubit(),
        child: const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: MyHomePage(),
        ),
      );
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late ScrollController _controller;

  @override
  void initState() {
    super.initState();

    // Dispatch the initial refresh action
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PostListCubit>().refresh();
    });

    _controller = ScrollController()..addListener(_scrollListener);
  }

  void _scrollListener() {
    // Get the current loading state
    final isLoading = context.read<PostListCubit>().state.isLoadingMore;

    // Load more when scrolled to the bottom
    if (!isLoading &&
        _controller.position.maxScrollExtent == _controller.position.pixels) {
      context.read<PostListCubit>().loadMore();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Select only the posts list from state. Rebuilds only when posts change.
    final posts =
        context.select((PostListCubit cubit) => cubit.state.posts);

    // Check if loading more is in progress
    final isLoading =
        context.select((PostListCubit cubit) => cubit.state.isLoadingMore);

    return Scaffold(
      appBar: AppBar(title: const Text('Infinite Scroll Example')),
      body: posts.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                // The method returns a Future that can be awaited
                await context.read<PostListCubit>().refresh();
              },
              child: ListView.builder(
                controller: _controller,
                itemCount: posts.length + 1,
                itemBuilder: (context, index) {
                  // Show loading spinner at the end
                  if (index == posts.length) {
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Center(
                        child: isLoading
                            ? const CircularProgressIndicator()
                            : const SizedBox(height: 30),
                      ),
                    );
                  } else {
                    return ListTile(
                      leading: CircleAvatar(child: Text('${index + 1}')),
                      title: Text(posts[index]),
                    );
                  }
                },
              ),
            ),
    );
  }
}
