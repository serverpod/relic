## Description

This PR introduces `RelicApp`, a new class that extends `RelicRouter` to simplify common usage patterns and reduce boilerplate for getting started with Relic.

- Added `RelicApp` class in `lib/src/router/router.dart` with a `run()` method that handles adapter setup and server lifecycle
- Added `RelicAppIOServeEx` extension in `lib/src/adapter/io/io_serve.dart` providing a convenient `serve()` method with sensible defaults
- Added `IOAdapter.bind()` static factory method for cleaner adapter creation
- Updated all examples to use `RelicApp` instead of `RelicRouter` + `serve()`
- Updated test utilities to use the new pattern

**Why this is beneficial:**
- Matches conventions from popular frameworks (Express, Flask, ASP.NET Core)
- Reduces boilerplate - no need for `.asHandler` extension or `dart:io` imports in simple cases
- Better discoverability through IDE autocomplete
- More intuitive for beginners while maintaining full flexibility for advanced users
- Only ~10 lines of core implementation

**Before:**
```dart
final router = RelicRouter()..get('/hello', handler);
await serve(router.asHandler, InternetAddress.anyIPv4, 8080);
```

**After:**
```dart
final app = RelicApp()..get('/hello', handler);
await app.serve(); // Defaults: localhost:8080
```

## Related Issues

- Fixes: #<issue_number>

## Pre-Launch Checklist

- [x] This update focuses on a single feature or bug fix.
- [x] I have read and followed the [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style) and formatted the code using [dart format](https://dart.dev/tools/dart-format).
- [x] I have referenced at least one issue this PR fixes or is related to.
- [x] I have updated/added relevant documentation (doc comments with `///`), ensuring consistency with existing project documentation.
- [ ] I have added new tests to verify the changes.
- [x] All existing and new tests pass successfully.
- [ ] I have documented any breaking changes below.

## Breaking Changes

- [ ] Includes breaking changes.
- [x] No breaking changes.

This is a purely additive change. All existing code using `RelicRouter` and `serve()` continues to work without modification.

## Additional Notes

- The `serve()` function is still available for users who prefer the functional approach
- `RelicRouter` can still be used directly - `RelicApp` is just a convenience
- Advanced users can still use `app.run()` with custom adapters
- Router composition (`attach()`, `group()`) works seamlessly with `RelicApp`
- This pattern provides a natural extension point for Serverpod integration
