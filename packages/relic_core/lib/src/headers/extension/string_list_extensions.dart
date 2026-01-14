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
  }) => LinkedHashSet<String>.from(
    splitAndTrim(separator: separator, emptyCheck: emptyCheck),
  );

  Iterable<String> splitAndTrim({
    final String separator = ',',
    final bool emptyCheck = true,
  }) => expand((final element) => element.split(separator))
      .map((final el) => el.trim())
      .where((final e) => !emptyCheck || e.isNotEmpty);
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
  }) {
    final filtered = split(separator)
        .map((final el) => noTrim ? el : el.trim())
        .where((final e) => !emptyCheck || e.isNotEmpty);
    return LinkedHashSet<String>.from(filtered);
  }

  /// Checks if the string is a valid email address.

  bool isValidEmail() {
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(this);
  }

  bool isValidLanguageCode() {
    return RegExp(r'^[a-zA-Z]{2,8}(-[a-zA-Z]{2,8})?$').hasMatch(this);
  }
}
