// Developed by Marcelo Glasberg (2026) https://glasberg.dev and https://github.com/marcglasberg
// For more info, see: https://pub.dartlang.org/packages/bloc_superpowers and http://blocsuperpowers.org

import 'package:bloc_superpowers/src/user_exception_i18n.dart';
import 'package:i18n_extension_core/i18n_extension_core.dart';
import "package:meta/meta.dart";
import 'package:serverpod_serialization/serverpod_serialization.dart';

/// The [UserException] is an immutable class representing an error the user
/// could fix, like wrong typed text, or missing internet connection.
///
/// Async Redux will automatically capture [UserException]s to show them in
/// dialogs created with `UserExceptionDialog` or other UI you define in your
/// widget tree (see the explanation in the docs).
///
/// An [UserException] may have a [message] or an error [code] (if you provide
/// both, the message will be ignored), as well as an optional [reason], which
/// is a more specific text that explains why the exception happened. For example:
///
/// ```dart
/// throw UserException('Invalid email', reason: 'Must have at least 5 characters.');
/// ```
///
/// Method [titleAndContent] returns the title and content used in the error dialog.
/// If the exception has both a [message] an a [reason], the title will be
/// the [message], and its content will be the [reason]. Otherwise, the title
/// will be empty, and the content will be the [message].
///
/// Alternatively, if you provide a numeric [code] instead of a [message].
/// In this case, the message of the exception will be the one associated with
/// the code (see [translateCode] and [codeTranslations]) for more details.
///
/// ---
///
/// The following methods and fields are available only in the `async_redux` package
/// (for Flutter), and are not available for Dart-only code:
///
/// * Method `addCallbacks` is used to add `onOk` and `onCancel` callbacks to the [UserException].
/// The `onOk` callback will be called when the user taps OK in the error dialog.
/// The `onCancel` callback will be called when the user taps CANCEL in the error dialog.
/// If the exception already had callbacks, the new callbacks will be merged with the old ones,
/// and the old callbacks will be called before the new ones.
///
///
/// * Field `onOk` is a callback to be called when the user presses the "Ok" button in
/// the error dialog.
///
/// * Field `onCancel` is a callback to be called when the user presses the "Cancel"
/// button in the error dialog.
///
/// * Method `addCause` adds the given `cause` to the [UserException].
/// Note the added [cause] won't replace the original cause, but will be added to it.
/// If the added [cause] is a `null`, it will return the current exception, unchanged.
/// If the added [cause] is a [String], the [addReason] method will be used to
/// return the new exception.
/// If the added [cause] is a [UserException], the [mergedWith] method will be used to
/// return the new exception.
/// If the added [cause] is any other type, including any other error types, it will be
/// set as the property `hardCause` of the exception. The hard cause is meant to be some
/// error which caused the [UserException], but that is not a [UserException] itself.
/// For example, if `int.parse('a')` throws a `FormatException`, then
/// `throw UserException('Invalid number').addCause(FormatException('Invalid input'))`.
/// will set the `FormatException` as the hard cause.
///
/// * Field `hardCause` the hard cause of the exception, if any, that may have been set
/// by the method `addCause`.
///
/// * Method `addProps` adds key-value pair properties to the [UserException].
/// If the exception already had properties, the new `props` will be merged with the old ones.
///
/// * Field `props` is the properties added to the exception, if any.
/// They are an immutable-map of key-value pairs, of type `IMap<String, dynamic>`.
/// To read the properties, use the `[]` operator, like this: `exception.props['key']`.
/// If the key does not exist, it will return `null`.
///
/// Usage:
///
/// ```dart
/// UserException(message, code: code, reason: reason)
///    .addCallbacks(onOk: onOk, onCancel: onCancel)
///    .addCause(cause)
///    .withProps(props);
/// ```
///
/// Example:
///
/// ```dart
/// throw UserException('Invalid number')
///    .addCause(FormatException('Invalid input'))
///    .addProps({'number': 42}))
///    .addCallbacks(onOk: () => print('OK'), onCancel: () => print('CANCEL'));
/// ```
///
/// ---
///
/// You can define a special `Matcher` for your [UserException], to use in your
/// tests. Create an test util file with this code:
///
/// ```
/// import 'package:matcher/matcher.dart';
/// const Matcher throwsUserException = Throws(const TypeMatcher<UserException>());
/// ```
///
/// Then use it in your tests:
/// ```
/// expect(() => someFunction(), throwsUserException);
/// ```
///
class UserException implements Exception, SerializableException {
  /// Some message shown to the user.
  final String message;

  /// Optionally, instead of [message] we may provide a numeric [code].
  /// This code may have an associated message which is set in the client.
  final int? code;

  /// Another text which is the reason of the user-exception.
  final String? reason;

  /// If `true`, the [UserExceptionDialog] will show in the dialog or similar UI.
  /// If `false` you can still show the error in a different way, usually showing [errorText]
  /// in the UI element that is responsible for the error.
  final bool ifOpenDialog;

  /// Some text to be displayed in the UI element that is responsible for the error.
  /// For example, a text field could show this text in its `errorText` property.
  /// When building your widgets, you can get the [errorText] from the failed action:
  /// `String errorText = context.getException(MyAction)?.errorText`.
  final String? errorText;

  /// Creates a [UserException], given a message [message] of type String,
  /// a [reason] of type String or [UserException], and an optional numeric [code].
  /// All fields are optional, but usually at least the [message] or [code] is provided.
  ///
  /// If [ifOpenDialog] is `false`, the [UserExceptionDialog] will not show the dialog.
  /// The default is `true`, which usually means the error should be shown as state in the
  /// screen.
  const UserException(
    this.message, {
    this.code,
    this.reason,
    this.ifOpenDialog = true,
    this.errorText,
  });

  /// Returns a new [UserException], copied from the current one, but adding the given [reason].
  /// Note the added [reason] won't replace the original reason, but will be added to it.
  @useResult
  @mustBeOverridden
  UserException addReason(String? reason) {
    //
    if (reason == null)
      return this;
    else {
      if (_ifHasMsgOrCode()) {
        return UserException(
          message,
          code: code,
          reason: joinCauses(this.reason, reason),
          ifOpenDialog: ifOpenDialog,
          errorText: errorText,
        );
      } else if (this.reason != null && this.reason!.isNotEmpty)
        return UserException(
          this.reason!,
          reason: reason,
          ifOpenDialog: ifOpenDialog,
          errorText: errorText,
        );
      else
        return UserException(
          reason,
          ifOpenDialog: ifOpenDialog,
          errorText: errorText,
        );
    }
  }

  /// Returns a new [UserException], by merging the current one with the given [anotherUserException].
  /// This simply means the given [anotherUserException] will be used as part of the [reason] of the
  /// current one.
  @useResult
  @mustBeOverridden
  UserException mergedWith(UserException? anotherUserException) {
    //
    if (anotherUserException == null)
      return this;
    else {
      var newReason = joinCauses(
          anotherUserException._msgOrCode(), anotherUserException.reason);

      var mergedException = addReason(newReason);

      // If any of the exceptions has ifOpenDialog `false`, the merged exception will have it too.
      if (ifOpenDialog && !anotherUserException.ifOpenDialog)
        mergedException = mergedException.noDialog;

      // If any of the exceptions has `errorText`, the merged exception will have it too.
      // If both have it, keep the one from the [anotherUserException].
      if (anotherUserException.errorText?.isNotEmpty ?? false)
        mergedException =
            mergedException.withErrorText(anotherUserException.errorText);

      return mergedException;
    }
  }

  /// This exception should NOT open a dialog.
  /// Still, the error may be shown in a different way, usually showing [errorText]
  /// somewhere in the UI.
  /// This is the same as doing: `.withDialog(false)`.
  @useResult
  UserException get noDialog => withDialog(false);

  /// Defines if this exception should open a dialog or not.
  /// If not, it will be shown in a different way, usually showing [errorText]
  /// somewhere in the UI.
  @useResult
  @mustBeOverridden
  UserException withDialog(bool ifOpenDialog) => UserException(
        message,
        reason: reason,
        code: code,
        ifOpenDialog: ifOpenDialog,
        errorText: errorText,
      );

  /// Adds (or replaces, if it already exists) the given [newErrorText].
  /// If the [newErrorText] is `null` or empty, it will remove the [errorText].
  @useResult
  @mustBeOverridden
  UserException withErrorText(String? newErrorText) {
    return UserException(
      message,
      reason: reason,
      code: code,
      ifOpenDialog: ifOpenDialog,
      errorText: newErrorText,
    );
  }

  /// Based on the [message], [code] and [reason], returns the title and content to be
  /// used in some UI to show the exception the user. The UI is usually a dialog or toast.
  ///
  /// If the exception has both a [message] an a [reason], the title will be
  /// the [message], and its content will be the [reason]. Otherwise, the title
  /// will be empty, and the content will be the [message].
  ///
  /// Alternatively, if you provide a numeric [code] instead of a [message], the
  /// text will be the one associated with the code (see [translateCode]
  /// and [codeTranslations]) for more details.
  ///
  @useResult
  (String, String) titleAndContent() {
    if (_ifHasMsgOrCode()) {
      if (reason == null || reason!.isEmpty)
        return ('', _msgOrCode());
      else
        return (_msgOrCode(), reason ?? '');
    }
    //
    else if (reason != null && reason!.isNotEmpty)
      return ('', reason ?? '');
    //
    else
      return ('User Error', '');
  }

  /// Use this to set the locale used by method [titleAndContent] to translate the
  /// text "Reason:" used to explain the chain of reasons in the [UserException].
  ///
  /// If you remove the locale with `setDefaultLocale(null)`, the default will
  /// be English of the Unites States.
  ///
  /// Note: This uses the `i18n_extension_core` package from https://pub.dev/packages/i18n_extension_core
  ///
  /// IMPORTANT: If you already use `i18n_extension_core` (in your Dart-only code)
  /// or `i18n_extension` (in your Flutter app), there is no need to ever
  /// call [UserException.setLocale], because the locale will already have been set.
  ///
  static void setLocale(String? localeStr) => DefaultLocale.set(localeStr);

  /// Joins the given strings, such as the second is the reason for the first.
  /// Will return a message such as "first\n\nReason: second".
  /// You can change this variable to inject another way to join them.
  static var joinCauses = (
    String? first,
    String? second,
  ) {
    if (first == null || first.isEmpty) return second ?? "";
    if (second == null || second.isEmpty) return first;
    return "$first${defaultJoinString()}$second";
  };

  /// The default text to join the reasons in a string.
  /// You can change this variable to inject another way to join them.
  static var defaultJoinString = () => "\n\n${"Reason:".i18n} ";

  /// If you use error [code]s, you may provide their respective text messages here,
  /// by providing a `Translations` object from the `i18n_extension` package. You can
  /// only provide messages in English, or in multiple other languages.
  ///
  /// If you are NOT using the `i18n_extension`, you can ignore [codeTranslations]
  /// and instead just modify the [translateCode] method to return a string from the [code].
  ///
  /// Example with English only:
  ///
  /// ```dart
  /// UserException.codeTranslations = Translations.byId<int>('en', {
  ///    1: { 'en': 'Invalid email' },
  ///    2: { 'en': 'There is no connection' },
  /// });
  /// ```
  ///
  /// Example with multiple languages:
  ///
  /// ```dart
  /// UserException.codeTranslations = Translations.byId<int>('en', {
  ///    1: { 'en': 'Invalid email', 'pt': 'Email inválido' },
  ///    2: { 'en': 'There is no connection', 'pt': 'Não há conexão' },
  /// });
  /// ```
  static Translations? codeTranslations;

  /// The [translateCode] method is called to convert error [code]s into text messages.
  /// If you are using use the `i18n_extension`, you may provide [codeTranslations].
  /// If you are NOT using the `i18n_extension`, you can instead modify
  /// the [translateCode] method to return a string from the [code] in any way you want.
  ///
  static String Function(int?) translateCode = (int? code) =>
      (codeTranslations == null)
          ? (code?.toString() ?? '')
          : localize(code, codeTranslations!);

  /// If there is a [code], and this [code] has a translation, return the translation.
  /// If the translation is empty, return the [message].
  /// If the is no [code], return the [message].
  /// Otherwise, return an empty text.
  String _msgOrCode() {
    var code = this.code;
    if (code != null) {
      String codeAsText = translateCode(code);
      return codeAsText.isNotEmpty ? codeAsText : message;
    } else
      return message;
  }

  bool _ifHasMsgOrCode() => (message.isNotEmpty) || code != null;

  /// Converts the exception into a JSON map.
  /// This is compatible with Serverpod.
  @override
  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'code': code,
      'reason': reason,
      'ifOpenDialog': ifOpenDialog,
      'errorText': errorText,
    };
  }

  /// Creates a UserException instance from a JSON map.
  /// This is compatible with Serverpod.
  factory UserException.fromJson(Map<String, dynamic> json) {
    return UserException(
      json['message'] as String? ?? '',
      code: json['code'] as int?,
      reason: json['reason'] as String?,
      ifOpenDialog: json['ifOpenDialog'] as bool? ?? true,
      errorText: json['errorText'] as String?,
    );
  }

  /// Returns a new instance with some fields replaced by new values.
  /// This is compatible with Serverpod.
  UserException copyWith({
    String? message,
    int? code,
    String? reason,
    bool? ifOpenDialog,
    String? errorText,
  }) {
    return UserException(
      message ?? this.message,
      code: code ?? this.code,
      reason: reason ?? this.reason,
      ifOpenDialog: ifOpenDialog ?? this.ifOpenDialog,
      errorText: errorText ?? this.errorText,
    );
  }

  @override
  String toString() {
    return 'UserException{${[
      joinCauses(_msgOrCode(), reason)
          .replaceAll('  ', ' ')
          .replaceAll('\n', '|')
          .replaceAll('||', '|'),
      (ifOpenDialog ? null : 'ifOpenDialog: false'),
      ((errorText?.isNotEmpty ?? false) ? 'errorText: "$errorText"' : null),
    ].where((x) => x?.isNotEmpty ?? false).join(', ')}}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserException &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          code == other.code &&
          reason == other.reason &&
          ifOpenDialog == other.ifOpenDialog &&
          errorText == other.errorText;

  @override
  int get hashCode =>
      message.hashCode ^
      code.hashCode ^
      reason.hashCode ^
      ifOpenDialog.hashCode ^
      errorText.hashCode;
}
