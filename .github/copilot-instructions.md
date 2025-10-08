# Relic Web Server
Relic is a Dart web server based on Shelf that supports middleware. It's currently available as a tech preview with type-safe headers, efficient routing via trie data structures, and enhanced performance features.

Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.

## Working Effectively

### Bootstrap, Build, and Test
- Install Dart SDK 3.5.0 or later:
  - Download: `wget https://storage.googleapis.com/dart-archive/channels/stable/release/3.5.4/sdk/dartsdk-linux-x64-release.zip`
  - Extract: `unzip dartsdk-linux-x64-release.zip && sudo mv dart-sdk /opt/dart`
  - Add to PATH: `export PATH="/opt/dart/bin:$PATH"`
- Install dependencies: `dart pub get` -- takes 5 seconds
- Static analysis: `dart analyze --fatal-infos` -- takes 6 seconds, must pass with no issues
- Format check: `dart format --output=none --set-exit-if-changed .` -- takes 1.5 seconds
- Run tests: `dart test` -- takes 29 seconds, NEVER CANCEL. Set timeout to 60+ minutes. 3029 tests should pass.
- Coverage: `dart pub global activate coverage && dart pub global run coverage:test_with_coverage --branch-coverage -- --reporter=failures-only` -- takes 34 seconds, NEVER CANCEL. Set timeout to 60+ minutes.

### Documentation
- Generate docs: `dart doc --dry-run` -- takes 27 seconds, NEVER CANCEL. Set timeout to 45+ minutes.
- Publish dry run: `dart pub publish --dry-run` -- takes 4.5 seconds, must pass validation
- Build documentation site:
  - Navigate: `cd doc/site`
  - Install: `npm ci` -- takes 49 seconds, NEVER CANCEL. Set timeout to 90+ minutes.
  - Build: `npm run build` -- takes 20 seconds, NEVER CANCEL. Set timeout to 45+ minutes.

### Run the Example Server
- Navigate: `cd example`
- Start: `dart run example.dart` -- starts HTTP server on port 8080
- Test manually: `curl http://localhost:8080/user/Alice/age/25` should return "Hello Alice! To think you are 25 years old."
- Test 404: `curl http://localhost:8080/unknown/path` should return "Sorry, that doesn't compute"

## Validation
- Always manually validate any new code by running the complete test suite after making changes.
- ALWAYS run through at least one complete end-to-end scenario after making changes: start the example server and test both valid routes and 404 handling.
- Always run `dart format .` and `dart analyze --fatal-infos` before you are done or the CI (.github/workflows/dart-tests.yaml) will fail.
- **CRITICAL TIMEOUT VALUES**: 
  - Tests: NEVER CANCEL. Set timeout to 60+ minutes (actual time: ~29 seconds)
  - Coverage tests: NEVER CANCEL. Set timeout to 60+ minutes (actual time: ~34 seconds)  
  - Documentation generation: NEVER CANCEL. Set timeout to 45+ minutes (actual time: ~27 seconds)
  - npm ci: NEVER CANCEL. Set timeout to 90+ minutes (actual time: ~49 seconds)
  - npm run build: NEVER CANCEL. Set timeout to 45+ minutes (actual time: ~20 seconds)

## Common Tasks

### Repository Structure
```
.
├── README.md              -- Main documentation
├── CONTRIBUTING.md        -- Detailed development guidelines  
├── pubspec.yaml          -- Dart package configuration
├── analysis_options.yaml -- Lint rules (uses serverpod_lints)
├── .github/
│   └── workflows/
│       ├── dart-tests.yaml    -- Main CI pipeline
│       ├── benchmark.yaml     -- Performance benchmarks
│       └── publish-documentation.yml  -- Doc site deployment
├── lib/
│   ├── relic.dart        -- Main library exports
│   ├── io_adapter.dart   -- HTTP server adapter
│   └── src/              -- Implementation details
├── example/
│   ├── example.dart      -- Basic HTTP server example
│   └── multi_isolate.dart -- Multi-isolate example
├── test/                 -- Comprehensive test suite (3029 tests)
├── doc/site/             -- Documentation website (Docusaurus)
└── benchmark/            -- Performance benchmarking tools
```

### Key Technologies & Features
- **Language**: Dart 3.5.0+ (strongly typed, null-safe)
- **Architecture**: Middleware-based request/response pipeline
- **Routing**: Efficient trie-based path matching with parameter extraction
- **Headers**: Type-safe HTTP header parsing and validation
- **Body Types**: Uint8List-based for performance (no List<int>)
- **WebSocket**: Built-in WebSocket support with proper lifecycle management
- **Testing**: Comprehensive test coverage with scenario-based validation

### CI Pipeline (GitHub Actions)
The CI runs on multiple Dart versions (3.5.0, stable, beta) and OS (Ubuntu, Windows, macOS):
1. Dependency bounds checking
2. Static analysis (downgraded & upgraded deps)
3. Documentation dry run
4. Pana score check
5. Publish dry run
6. Unit tests with coverage
7. Documentation site build test
8. **PR Title Validation**: All PR titles must follow conventional commits format

### Conventional Commits
- **Required**: All PR titles must follow conventional commits format
- **Validation**: CI check (`.github/workflows/title-validation.yaml`) validates PR titles
- **Allowed types**: `build`, `chore`, `ci`, `docs`, `feat`, `fix`, `perf`, `refactor`, `revert`, `style`, `test`
- **Format**: `type: description` where description starts with uppercase letter
- **Examples**: 
  - `feat: Add new router middleware support`
  - `fix: Handle edge case in header parsing`
  - `docs: Update API documentation for headers`
  - `chore: Update dependencies to latest versions`

### Testing Guidelines
- **Follow Given-When-Then pattern**: Test descriptions and structure must follow the Given-When-Then (GWT) pattern
  - **Group structure**: Include both Given and When in the group description (e.g., `group('Given a NewContext, when withRequest is called with a new Request,', () { ... })`)
  - **Shared setup**: When tests in a group share the same action (the "When"), execute that action in a `setUp` block within the group
  - **Test descriptions**: Each test should describe the "Then" part (e.g., `test('then it returns a NewContext instance', () { ... })`)
  - **Single responsibility**: Each test should validate a single requirement or assertion, not multiple unrelated checks
  - **Separate tests for different requirements**: If validating multiple properties (type, content, token preservation), create separate tests with clear titles
- Use Arrange-Act-Assert pattern in test bodies
- Tests are in `test/` directory mirroring `lib/` structure
- Run specific test files: `dart test test/router/router_test.dart`
- All tests should pass; errors in test output are expected test scenarios

**Example of proper test structure:**
```dart
group('Given a NewContext, when withRequest is called with a new Request,', () {
  late NewContext context;
  late Request newRequest;
  late NewContext newContext;
  
  setUp(() {
    // Arrange
    context = Request(Method.get, Uri.parse('http://test.com')).toContext(Object());
    newRequest = Request(Method.post, Uri.parse('http://test.com/new'));
    // Act (shared action for all tests in this group)
    newContext = context.withRequest(newRequest);
  });
  
  test('then it returns a NewContext instance', () {
    // Assert
    expect(newContext, isA<NewContext>());
  });
  
  test('then the new context contains the new request', () {
    // Assert
    expect(newContext.request, same(newRequest));
  });
});
```

### Common Development Patterns
- **Handlers**: Functions that process RequestContext and return ResponseContext
- **Middleware**: Functions that wrap handlers to add functionality (logging, routing, etc.)
- **Pipeline**: Chain multiple middleware together before final handler
- **Router**: Type-safe routing with parameter extraction via symbols (#name, #age)
- **Body**: Typed request/response bodies (string, bytes, JSON, etc.)
- **Headers**: Strongly-typed header access with validation

### Example Handler Implementation
```dart
ResponseContext hello(final NewContext ctx) {
  final name = ctx.pathParameters[#name];
  final age = int.parse(ctx.pathParameters[#age]!);
  return ctx.respond(Response.ok(
      body: Body.fromString('Hello $name! To think you are $age years old.')));
}
```

### Troubleshooting
- If `dart` command not found: Ensure `/opt/dart/bin` is in PATH
- If tests fail with header parsing errors: These are expected test scenarios, not failures
- If documentation build fails: Ensure Node.js 18+ is installed for doc/site
- If coverage fails: Run `dart pub global activate coverage` first
- Build may take longer on slower systems but should complete within documented timeouts

### Performance Notes
- Router uses trie data structure for O(log n) route matching
- Body processing optimized with Uint8List instead of List<int>
- Headers parsed lazily for better performance
- WebSocket connections support ping/pong for connection health