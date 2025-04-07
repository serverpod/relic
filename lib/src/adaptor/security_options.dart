/// Platform-agnostic security options for secure server binding
class SecurityOptions {
  /// The underlying security context
  ///
  /// This is intentionally typed as Object to avoid platform-specific
  /// dependencies at the interface level.
  final Object context;

  /// Create security options with the given context
  const SecurityOptions(this.context);
}
