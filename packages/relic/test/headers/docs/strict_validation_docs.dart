/// ## Header Validation
///
/// Header validation occurs when request handlers access header properties through
/// the `touchHeaders` callback in `getServerRequestHeaders`. When the callback
/// accesses a header property (e.g., `h.age`), the header value is parsed and
/// validated. If the header is empty or invalid, an exception is thrown.
///
/// When `touchHeaders` doesn't access a header property, no validation occurs,
/// and invalid headers can be accessed using `.valueOrNullIfInvalid` without
/// throwing exceptions.
///
/// This approach ensures that validation only happens when headers are actually
/// used, preventing potential issues in request handling while maintaining
/// performance for unused headers.
class HeaderValidationDocs {}
