// Developed by Marcelo Glasberg (2026) https://glasberg.dev and https://github.com/marcglasberg
// For more info, see: https://pub.dartlang.org/packages/bloc_superpowers and http://blocsuperpowers.org

/// An exception that can be thrown in the [mix] function callbacks (`action`, `before`,
/// `wrapRun`, `wrapError`) to abort execution immediately.
///
/// When an [AbortException] is thrown:
/// - The `mix` function aborts immediately (no retries are attempted)
/// - The `after` callback is still called (if provided)
/// - No error is shown to the user
/// - The `mix` function returns `null` (cast to `T`)
///
/// This is similar to throwing a [UserException], but without showing any error dialog.
/// It's useful when you want to abort based on some condition (e.g., in `before`) without
/// treating it as an error.
///
/// **Example:**
/// ```dart
/// await mix(
///   before: () {
///     if (!isUserLoggedIn) {
///       throw AbortException();  // Abort silently if user not logged in
///     }
///   },
///   after: () => print('Cleanup runs regardless'),
///   () async {
///     await api.fetchUserData();
///   },
/// );
/// ```
class AbortException implements Exception {
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is AbortException && runtimeType == other.runtimeType;

  @override
  int get hashCode => 0;
}
