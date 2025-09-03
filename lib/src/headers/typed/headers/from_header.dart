import 'package:collection/collection.dart';

import '../../../../relic.dart';
import '../../extension/string_list_extensions.dart';

/// A class representing the HTTP `From` header.
///
/// The `From` header is used to indicate the email address of the user making the request.
/// It usually contains a single email address, but in edge cases, it could contain multiple
/// email addresses separated by commas.
final class FromHeader {
  static const codec = HeaderCodec(FromHeader.parse, __encode);
  static List<String> __encode(final FromHeader value) => [value._encode()];

  /// A list of email addresses provided in the `From` header.
  final Iterable<String> emails;

  /// Private constructor for initializing the [emails] list.
  FromHeader({required this.emails}) : assert(emails.isNotEmpty);

  /// Parses a `From` header value and returns a [FromHeader] instance.
  factory FromHeader.parse(final Iterable<String> values) {
    final emails = values.splitTrimAndFilterUnique();
    if (emails.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }

    for (final email in emails) {
      if (!email.isValidEmail()) {
        throw const FormatException('Invalid email format');
      }
    }

    return FromHeader(emails: emails);
  }

  /// Returns the single email address if the list only contains one email.
  String? get singleEmail => emails.length == 1 ? emails.first : null;

  /// Converts the [FromHeader] instance into a string representation
  /// suitable for HTTP headers.

  String _encode() => emails.join(', ');

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is FromHeader &&
          const IterableEquality<String>().equals(emails, other.emails);

  @override
  int get hashCode => const IterableEquality<String>().hash(emails);

  @override
  String toString() {
    return 'FromHeader(emails: $emails)';
  }
}
