// Developed by Marcelo Glasberg (2026) https://glasberg.dev and https://github.com/marcglasberg
// For more info, see: https://pub.dartlang.org/packages/bloc_superpowers and http://blocsuperpowers.org

import 'dart:async';
import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:flutter/material.dart';

/// A widget that listens to [UserException]s from [Superpowers] and displays them
/// as toast notifications (SnackBars).
///
/// Use it like this:
///
/// ```dart
/// class MyApp extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) => BlocProvider(
///     create: (_) => MySuperpowers(),
///     child: MaterialApp(
///       home: Scaffold(
///         body: UserExceptionToast(
///           child: MyHomePage(),
///         ),
///       ),
///     ),
///   );
/// }
/// ```
///
/// **Important:** [UserExceptionToast] requires a [Scaffold] ancestor in the
/// widget tree because it uses [ScaffoldMessenger] to show [SnackBar]s.
///
/// When an action throws a [UserException] with [UserException.ifOpenDialog]
/// set to `true` (the default), the exception is added to [Superpowers]'s static
/// error queue and this widget will display it as a toast.
///
/// You can customize the toast by providing [onShowUserExceptionToast].
///
/// See also:
/// - [UserExceptionDialog], which shows exceptions in dialogs instead of toasts.
///
class UserExceptionToast extends StatefulWidget {
  /// The child widget to display.
  final Widget child;

  /// Custom toast implementation. If not provided, a default [SnackBar]
  /// will be shown.
  final ShowUserExceptionToast? onShowUserExceptionToast;

  /// The duration to show the toast. Defaults to 4 seconds.
  final Duration duration;

  /// The behavior of the SnackBar. Defaults to [SnackBarBehavior.floating].
  final SnackBarBehavior behavior;

  /// If true (the default), errors are shown one at a time. The next toast
  /// will only appear after the current one is dismissed.
  ///
  /// If false, multiple toasts may queue up and display sequentially
  /// through the ScaffoldMessenger's built-in queue.
  final bool showErrorsOneByOne;

  /// Optional action label for the SnackBar action button.
  /// If not provided and the exception has an [AdvancedUserException.onOk] callback,
  /// defaults to 'OK'.
  final String? actionLabel;

  const UserExceptionToast({
    required this.child,
    this.onShowUserExceptionToast,
    this.duration = const Duration(seconds: 4),
    this.behavior = SnackBarBehavior.floating,
    this.showErrorsOneByOne = true,
    this.actionLabel,
    super.key,
  });

  @override
  State<UserExceptionToast> createState() => _UserExceptionToastState();
}

class _UserExceptionToastState extends State<UserExceptionToast> {
  StreamSubscription<UserException>? _subscription;

  /// Tracks whether a toast is currently being shown.
  /// Used when [showErrorsOneByOne] is true to prevent queueing toasts.
  bool _isShowingToast = false;

  @override
  void initState() {
    super.initState();
    _subscription = Superpowers.onUserException.listen(_onUserException);
  }

  void _onUserException(UserException _) {
    // If showing one by one and a toast is already showing, skip.
    // The toast will check for more errors when it closes.
    if (widget.showErrorsOneByOne && _isShowingToast) {
      return;
    }

    _showNextError();
  }

  void _showNextError() {
    final exception = Superpowers.getAndRemoveFirstError();
    if (exception != null) {
      _isShowingToast = true;
      // Use scheduleMicrotask instead of addPostFrameCallback.
      // addPostFrameCallback waits for the next frame, but if the app is idle
      // (no animations, no user interaction), no frame is scheduled and the
      // toast would never show until something triggers a rebuild.
      scheduleMicrotask(() {
        if (mounted) _showToast(exception);
      });
    }
  }

  void _showToast(UserException exception) {
    if (widget.onShowUserExceptionToast != null) {
      widget.onShowUserExceptionToast!(context, exception);
      // For custom toasts, we can't know when they close,
      // so we reset the flag immediately and check for more errors.
      // Custom implementations should handle sequential display themselves.
      if (widget.showErrorsOneByOne) {
        _isShowingToast = false;
        _showNextError();
      }
    } else {
      _defaultShowToast(context, exception);
    }
  }

  void _defaultShowToast(BuildContext context, UserException exception) {
    // Get title and content from the exception
    final (title, content) = exception.titleAndContent();

    // Build the message: combine title and content if both present
    final message = title.isNotEmpty ? '$title: $content' : content;

    // Handle toast dismissal and callbacks
    void handleDismiss(SnackBarClosedReason reason) {
      if (reason == SnackBarClosedReason.action) {
        exception.onOk?.call();
      } else {
        // Toast dismissed without pressing action button
        if (exception.onCancel == null) {
          exception.onOk?.call();
        } else {
          exception.onCancel?.call();
        }
      }

      // When showing errors one by one, check for more errors after toast closes
      if (widget.showErrorsOneByOne) {
        _isShowingToast = false;
        _showNextError();
      }
    }

    // Determine action label
    final actionLabel =
        widget.actionLabel ?? (exception.onOk != null ? 'OK' : null);

    final snackBar = SnackBar(
      content: Text(message),
      duration: widget.duration,
      behavior: widget.behavior,
      action: actionLabel != null
          ? SnackBarAction(
              label: actionLabel,
              onPressed: () {
                // Action handled in handleDismiss
              },
            )
          : null,
    );

    ScaffoldMessenger.of(context)
        .showSnackBar(snackBar)
        .closed
        .then(handleDismiss);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Callback type for custom [UserException] toast implementations.
///
/// Parameters:
/// - [context]: The build context to use for showing the toast.
/// - [userException]: The exception to display.
typedef ShowUserExceptionToast = void Function(
  BuildContext context,
  UserException userException,
);
