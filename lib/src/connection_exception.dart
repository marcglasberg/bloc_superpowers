// Developed by Marcelo Glasberg (2026) https://glasberg.dev and https://github.com/marcglasberg
// For more info, see: https://pub.dartlang.org/packages/bloc_superpowers and http://blocsuperpowers.org
import 'package:bloc_superpowers/src/user_exception.dart';
import 'package:bloc_superpowers/src/advanced_user_exception.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/foundation.dart';

/// The [ConnectionException] is a type of [UserException] that warns the user
/// when the connection is not working. Use [ConnectionException.noConnectivity]
/// for a simple version that warns the users they should check the connection.
///
/// Example:
/// ```dart
/// throw ConnectionException.noConnectivity;
/// ```
///
/// You can also provide a host name:
/// ```dart
/// throw ConnectionException(host: 'api.example.com');
/// ```
///
/// Or provide a retry callback:
/// ```dart
/// throw ConnectionException.noConnectivityWithRetry(() => kubit.call(MyAction()));
/// ```
///
class ConnectionException extends AdvancedUserException {
  /// Usage: `throw ConnectionException.noConnectivity`;
  static const noConnectivity = ConnectionException();

  /// Usage: `throw ConnectionException.noConnectivityWithRetry(() {...})`;
  ///
  /// A dialog will open. When the user presses OK or dismisses the dialog in any way,
  /// the [onRetry] callback will be called.
  static ConnectionException noConnectivityWithRetry(
          void Function()? onRetry) =>
      ConnectionException(onRetry: onRetry);

  /// Creates a [ConnectionException].
  ///
  /// If you pass it an [onRetry] callback, it will call it when the user presses
  /// the "Ok" button in the dialog. Otherwise, it will just close the dialog.
  ///
  /// If you pass it a [host], it will say "It was not possible to connect to $host".
  /// Otherwise, it will simply say "There is no Internet connection".
  const ConnectionException({
    VoidCallback? onRetry,
    this.host,
    String? errorText,
    bool ifOpenDialog = true,
  }) : super(
          (host == null || host == 'null')
              ? 'There is no Internet'
              : 'It was not possible to connect to $host.',
          reason: 'Please, verify your connection.',
          code: null,
          onOk: onRetry,
          onCancel: null,
          hardCause: null,
          errorText: errorText ?? 'No Internet connection',
          ifOpenDialog: ifOpenDialog,
          props: const IMapConst<String, dynamic>({}),
        );

  final String? host;

  @override
  UserException addReason(String? reason) {
    throw UnsupportedError('ConnectionException does not support addReason.');
  }

  @override
  UserException mergedWith(UserException? anotherUserException) {
    throw UnsupportedError('ConnectionException does not support mergedWith.');
  }

  @override
  UserException withErrorText(String? newErrorText) => ConnectionException(
        host: host,
        onRetry: onOk,
        errorText: newErrorText,
        ifOpenDialog: ifOpenDialog,
      );

  @override
  UserException withDialog(bool ifOpenDialog) => ConnectionException(
        host: host,
        onRetry: onOk,
        errorText: errorText,
        ifOpenDialog: ifOpenDialog,
      );
}
