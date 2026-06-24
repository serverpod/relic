import 'dart:collection';

extension StringListExtensions on Iterable<String> {
  /// Processes a list of strings by:
  /// 1. Splitting each element by the given [separator]
  /// 2. Trimming whitespace from each resulting part
  /// 3. Removing empty strings
  /// 4. Removing duplicates while preserving order
  ///
  /// Example:
  /// ```dart
  /// ['apple, banana', 'banana, orange'].splitTrimAndFilterUnique()
  /// // Returns: ['apple', 'banana', 'orange']
  /// ```
  ///
  /// The default separator is comma (",").
  Iterable<String> splitTrimAndFilterUnique({
    final String separator = ',',
    final bool emptyCheck = true,
    final bool noTrim = false,
  }) => LinkedHashSet<String>.from(
    splitAndTrim(separator: separator, emptyCheck: emptyCheck, noTrim: noTrim),
  );

  Iterable<String> splitAndTrim({
    final String separator = ',',
    final bool emptyCheck = true,
    final bool noTrim = false,
  }) => expand(
    (final element) => element.splitAndTrim(
      separator: separator,
      emptyCheck: emptyCheck,
      noTrim: noTrim,
    ),
  );
}

extension StringExtensions on String {
  /// Processes a string by:
  /// 1. Splitting it by the given [separator]
  /// 2. Trimming whitespace from each resulting part
  /// 3. Removing empty strings
  /// 4. Removing duplicates while preserving order
  ///
  /// Example:
  /// ```dart
  /// 'apple, banana, banana, orange'.splitTrimAndFilterUnique()
  /// // Returns: ['apple', 'banana', 'orange']
  /// ```
  ///
  /// The default separator is comma (",").
  Iterable<String> splitTrimAndFilterUnique({
    final String separator = ',',
    final bool emptyCheck = true,
    final bool noTrim = false,
  }) => LinkedHashSet<String>.from(
    splitAndTrim(separator: separator, emptyCheck: emptyCheck, noTrim: noTrim),
  );

  /// Like [splitTrimAndFilterUnique] but preserves order and duplicates.
  ///
  /// Use this where each token is positional and a repeated token is significant.
  Iterable<String> splitAndTrim({
    final String separator = ',',
    final bool emptyCheck = true,
    final bool noTrim = false,
  }) => split(separator)
      .map((final el) => noTrim ? el : el.trim())
      .where((final e) => !emptyCheck || e.isNotEmpty);

  /// Checks if the string is a valid email address.
  bool isValidEmail() {
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(this);
  }

  /// Checks if the string is a valid language code.
  bool isValidLanguageCode() {
    return RegExp(r'^[a-zA-Z]{2,8}(-[a-zA-Z]{2,8})?$').hasMatch(this);
  }
}
