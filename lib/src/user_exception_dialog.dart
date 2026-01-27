// Developed by Marcelo Glasberg (2026) https://glasberg.dev and https://github.com/marcglasberg
// For more info, see: https://pub.dartlang.org/packages/bloc_superpowers and http://blocsuperpowers.org
import 'dart:async';
import 'package:bloc_superpowers/bloc_superpowers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A widget that listens to [UserException]s from [Superpowers] and displays them
/// in a dialog.
///
/// Use it like this:
///
/// ```dart
/// class MyApp extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) => BlocProvider(
///     create: (_) => MySuperpowers(),
///     child: MaterialApp(
///       home: UserExceptionDialog(
///         child: MyHomePage(),
///       ),
///     ),
///   );
/// }
/// ```
///
/// When an action throws a [UserException] with [UserException.ifOpenDialog]
/// set to `true` (the default), the exception is added to [Superpowers]'s static
/// error queue and this widget will display it in a dialog.
///
/// You can customize the dialog by providing [onShowUserExceptionDialog].
///
/// See also:
/// - [UserExceptionToast], which shows exceptions as toast notifications (SnackBars).
///
class UserExceptionDialog extends StatefulWidget {
  /// The child widget to display.
  final Widget child;

  /// Custom dialog implementation. If not provided, a default platform-aware
  /// dialog will be shown (Material on Android/Web, Cupertino on iOS).
  final ShowUserExceptionDialog? onShowUserExceptionDialog;

  /// If false (the default), the dialog will use the root navigator context.
  /// If true, it will use the local context of this widget.
  ///
  /// Set this to true if you're placing the [UserExceptionDialog] above the
  /// app's Navigator (e.g., in the `builder` parameter of [MaterialApp]).
  final bool useLocalContext;

  /// Optional navigator key to use for showing dialogs.
  /// If provided and [useLocalContext] is false, this key's context will be used.
  final GlobalKey<NavigatorState>? navigatorKey;

  /// If true (the default), errors are shown one at a time. The next error
  /// dialog will only appear after the current one is dismissed.
  ///
  /// If false, multiple error dialogs may appear stacked on top of each other
  /// if multiple errors occur quickly.
  final bool showErrorsOneByOne;

  const UserExceptionDialog({
    required this.child,
    this.onShowUserExceptionDialog,
    this.useLocalContext = false,
    this.navigatorKey,
    this.showErrorsOneByOne = true,
    super.key,
  });

  @override
  State<UserExceptionDialog> createState() => _UserExceptionDialogState();
}

class _UserExceptionDialogState extends State<UserExceptionDialog> {
  StreamSubscription<UserException>? _subscription;

  /// Tracks whether a dialog is currently being shown.
  /// Used when [showErrorsOneByOne] is true to prevent stacking dialogs.
  bool _isShowingDialog = false;

  @override
  void initState() {
    super.initState();
    _subscription = Superpowers.onUserException.listen(_onUserException);
  }

  void _onUserException(UserException _) {
    // If showing one by one and a dialog is already showing, skip.
    // The dialog will check for more errors when it closes.
    if (widget.showErrorsOneByOne && _isShowingDialog) {
      return;
    }

    _showNextError();
  }

  void _showNextError() {
    final exception = Superpowers.getAndRemoveFirstError();
    if (exception != null) {
      _isShowingDialog = true;
      // Use scheduleMicrotask instead of addPostFrameCallback.
      // addPostFrameCallback waits for the next frame, but if the app is idle
      // (no animations, no user interaction), no frame is scheduled and the
      // dialog would never show until something triggers a rebuild.
      scheduleMicrotask(() {
        if (mounted) _showDialog(exception);
      });
    }
  }

  void _showDialog(UserException exception) {
    if (widget.onShowUserExceptionDialog != null) {
      widget.onShowUserExceptionDialog!(
        context,
        exception,
        widget.useLocalContext,
      );
      // For custom dialogs, we can't know when they close,
      // so we reset the flag immediately and check for more errors.
      // Custom implementations should handle sequential display themselves.
      if (widget.showErrorsOneByOne) {
        _isShowingDialog = false;
        _showNextError();
      }
    } else {
      _defaultShowDialog(context, exception, widget.useLocalContext);
    }
  }

  void _defaultShowDialog(
    BuildContext context,
    UserException exception,
    bool useLocalContext,
  ) {
    // Determine which context to use for the dialog
    BuildContext dialogContext = context;
    if (!useLocalContext) {
      final navigatorContext = widget.navigatorKey?.currentContext;
      if (navigatorContext != null) {
        dialogContext = navigatorContext;
      }
    }

    // Get title and content from the exception
    final (title, content) = exception.titleAndContent();

    // Handle dialog dismissal and callbacks
    void handleDismiss(int? result) {
      if (result == 1) {
        exception.onOk?.call();
      } else if (result == 2) {
        exception.onCancel?.call();
      } else {
        // Dialog dismissed without pressing a button
        if (exception.onCancel == null) {
          exception.onOk?.call();
        } else {
          exception.onCancel?.call();
        }
      }

      // When showing errors one by one, check for more errors after dialog closes
      if (widget.showErrorsOneByOne) {
        _isShowingDialog = false;
        _showNextError();
      }
    }

    // Show platform-appropriate dialog
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      _showCupertinoDialog(
          dialogContext, title, content, exception, handleDismiss);
    } else {
      _showMaterialDialog(
          dialogContext, title, content, exception, handleDismiss);
    }
  }

  void _showCupertinoDialog(
    BuildContext context,
    String title,
    String content,
    UserException exception,
    void Function(int?) onDismiss,
  ) {
    showCupertinoDialog<int>(
      context: context,
      builder: (BuildContext ctx) {
        return CupertinoAlertDialog(
          title: title.isNotEmpty ? Text(title) : null,
          content: Text(content),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.of(ctx).pop(1),
            ),
            if (exception.onCancel != null)
              CupertinoDialogAction(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(ctx).pop(2),
              ),
          ],
        );
      },
    ).then(onDismiss);
  }

  void _showMaterialDialog(
    BuildContext context,
    String title,
    String content,
    UserException exception,
    void Function(int?) onDismiss,
  ) {
    showDialog<int>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: title.isNotEmpty ? Text(title) : null,
          content: Text(content),
          actions: [
            if (exception.onCancel != null)
              TextButton(
                child: const Text('CANCEL'),
                onPressed: () => Navigator.of(ctx).pop(2),
              ),
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(ctx).pop(1),
            ),
          ],
        );
      },
    ).then(onDismiss);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Callback type for custom [UserException] dialog implementations.
///
/// Parameters:
/// - [context]: The build context to use for showing the dialog.
/// - [userException]: The exception to display.
/// - [useLocalContext]: Whether to use the local context or navigator context.
typedef ShowUserExceptionDialog = void Function(
  BuildContext context,
  UserException userException,
  bool useLocalContext,
);
