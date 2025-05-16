# Design: Typed Context Pipeline for Relic

## 1. Introduction and Goals

This document proposes a design for a typed context pipeline in Relic. The primary goal is to achieve **compile-time safety** for middleware and handler composition. This means the Dart analyzer should be able to verify that if a handler (or subsequent middleware) expects certain data to be present in its request context (e.g., an authenticated `User` object), the necessary preceding middleware (e.g., an `AuthenticationMiddleware`) has been correctly configured in the pipeline.

This approach aims to:
*   Catch pipeline configuration errors at compile-time rather than runtime.
*   Improve developer ergonomics by providing clear, type-safe access to context data.
*   Maintain high performance by leveraging zero-cost abstractions like extension types.
*   Avoid a "class explosion" that might occur if every combination of context data required a distinct context class.

## 2. Core Components

The system relies on a few key components:

### 2.1. Relic's `RequestContext` and Stable Request Token

This design utilizes Relic's existing `RequestContext` (defined in `relic/lib/src/adapter/context.dart`). The key aspects of `RequestContext` relevant to this design are:
*   It provides access to the current `Request` object (e.g., via a `request` getter).
*   It contains a stable `token` (e.g., via a `token` getter). This `token` is a unique identifier for the entire lifecycle of a single request and remains constant even if the `RequestContext` instance itself undergoes state transitions (e.g., from `NewContext` to `ResponseContext`).

All request-scoped data attached via `Expando` (managed by `ContextProperty`) will be keyed off this stable `requestToken`. The extension type views defined in this design will wrap an instance of Relic's `RequestContext`.

```dart
// Note: This design uses Relic's existing RequestContext.
// For illustration, its relevant properties would be:
class RequestContext {
  final Request request;
  final Object token; // The stable, unique-per-request token
  // ...
}
// Data is attached via Expandos keyed by 'token', managed by
// ContextProperty and accessed through context views.
```

### 2.2. Data Classes

These are simple Dart classes representing the data that middleware can add to the context.

```dart
class User {
  final String id;
  final String email;
  User({required this.id, required this.email});
}

class Session {
  final String sessionId;
  DateTime expiresAt;
  Session({required this.sessionId, required this.expiresAt});
}
```

### 2.3. `ContextProperty<T>` Helper

To simplify and standardize the management of `Expando`-based context data, a helper class `ContextProperty<T>` is introduced. This class encapsulates an `Expando` and ensures that data is consistently keyed off the stable `requestToken`.

```dart
class ContextProperty<T extends Object> {
  final Expando<T> _expando; // Use token from RequestContext as anchor
  final String? _debugName; // Optional: for Expando's name

  ContextProperty([this._debugName]) : _expando = Expando<T>(_debugName);

  T get(RequestContext requestContext) {
    final value = _expando[requestContext.token];
    if (value == null) {
      throw StateError(
          'ContextProperty value not found. Property: ${_debugName ?? T.toString()}. '
          'Ensure middleware has set this value for the request token.');
    }
    return value;
  }

  T? getOrNull(RequestContext requestContext) {
    return _expando[requestContext.token];
  }

  void set(RequestContext requestContext, T value) {
    _expando[requestContext.token] = value;
  }

  bool exists(RequestContext requestContext) {
    return _expando[requestContext.token] != null;
  }

  void clear(RequestContext requestContext) {
    _expando[requestContext.token] = null; // Clears the association in Expando
  }
}
```
Modules responsible for specific pieces of context data (e.g., `User`, `Session`) will define a private static `ContextProperty<DataType>` instance.

### 2.4. Extension Types for Context Views

Extension types are zero-cost abstractions (wrappers) over an instance of Relic's `RequestContext`. They provide a type-safe "view" or "contract" for accessing and attaching specific data, using `ContextProperty` instances internally.

Each view typically provides:
*   Getters for the data it represents (e.g., `UserContextView.user`).
*   Methods to attach or set its data (e.g., `UserContextView.attachUser(User user)`). These methods use the appropriate `ContextProperty` and the `requestToken`.

```dart
// Define a ContextProperty for User data.
// This would typically be a static final field, private to its library,
// in a relevant class or top-level.
final _userProperty = ContextProperty<User>('relic.auth.user');

// Base view that all request contexts can be seen as initially.
// It wraps Relic's RequestContext.
extension type BaseContextView(RequestContext _relicContext) {
  Request get request => _relicContext.request;
}

// A view indicating that User information is available.
extension type UserContextView(RequestContext _relicContext) implements BaseContextView {
  User get user => _userProperty.get(_relicContext);

  void attachUser(User user) {
    _userProperty.set(_relicContext, user);
  }

  // Optional: to check for user presence or get a nullable user
  User? get userOrNull => _userProperty.getOrNull(_relicContext);
  bool get hasUser => _userProperty.exists(_relicContext);
}

// A view indicating that Session information is available.
extension type SessionContextView(RequestContext _relicContext) implements BaseContextView {
  Session get session => _sessionProperty.get(_relicContext);

  void attachSession(Session session) {
    _sessionProperty.set(_relicContext, session);
  }
}
final _sessionProperty = ContextProperty<Session>('relic.session');

// A composite view indicating both User and Session information are available.
extension type UserSessionContextView(RequestContext _relicContext) implements UserContextView, SessionContextView {
  // Getters for 'user' and 'session' are inherited via UserContextView and SessionContextView.
  // The 'attachUser' and 'attachSession' methods are also available if needed,
  // though typically data is attached by the specific middleware responsible for it.
}
```
Middleware will use these view-specific `attach` methods (e.g., `userView.attachUser(newUser)`), which internally leverage `ContextProperty` to manage data associated with the `requestToken`.

## 3. Middleware Definition

Middleware are defined as functions (or methods on stateless service objects) that:
1.  Take an input context view (e.g., `BaseContextView`, `UserContextView`).
2.  Perform their logic, attaching data to the stable `requestToken` (obtained via `inputView.requestToken` or `inputView._relicContext.token`). This is done using the view's `attach` methods (e.g., `inputView.attachUser(user)`), which internally use `ContextProperty`.
3.  Return an output context view (e.g., `UserContextView`, `UserSessionContextView`) that wraps the *same* `RequestContext` instance. The type of the returned view signals the new capabilities/data available via the `requestToken`.

```dart
// This middleware takes a BaseContextView, authenticates the request,
// attaches a User object (via ContextProperty and the requestToken), and returns a UserContextView.
UserContextView authenticationMiddleware(BaseContextView inputView) {
  // Simplified authentication logic
  final token = inputView.request.headers['Authorization'];
  // Create the UserContextView to use its `attachUser` method.
  // The underlying RequestContext (and thus its token) is passed along.
  final userView = UserContextView(inputView._relicContext);

  if (token == 'Bearer valid-token') {
    final user = User(id: 'user-123', email: 'user@example.com');
    userView.attachUser(user); // Use the view's method to attach the user
  } else {
    // Handle failed authentication:
    // Option A: Throw an error that the server translates to a 401/403 response.
    // throw AuthenticationError('Invalid or missing token');
    // Option B: Do not set the user. The UserContextView.user getter would then fail,
    //           or UserContextView would need to expose 'User? get user' or 'bool get hasUser'.
    //           For this design, we assume successful authentication is required if returning UserContextView.
    //           If authentication is optional, the middleware might return a different view type or
    //           UserContextView.user might be nullable.
    // Forcing a User to be present if returning UserContextView makes the contract stronger.
  }

  // Return a UserContextView, wrapping the same (now modified) CoreRequestContext
  return userView;
}
```

## 4. Type-Safe `PipelineBuilder`

The `PipelineBuilder` is a generic class responsible for composing middleware and a final handler in a type-safe manner. It uses Dart's generic type system to track the "shape" (capabilities) of the context view as it evolves through the pipeline.

```dart
class PipelineBuilder<TCurrentChainInputView, TCurrentChainOutputView> {
  /// The function representing the composed chain of middleware so far.
  /// It transforms an input view (TCurrentChainInputView) to an output view (TCurrentChainOutputView).
  final TCurrentChainOutputView Function(TCurrentChainInputView) _chain;

  PipelineBuilder._(this._chain);

  /// Starts a new pipeline.
  /// The initial view for the chain is `BaseContextView`.
  static PipelineBuilder<BaseContextView, BaseContextView> start() {
    // The initial chain is an identity function: it receives a BaseContextView and returns it.
    return PipelineBuilder._((BaseContextView view) => view);
  }

  /// Adds a middleware to the current pipeline.
  /// - `middleware`: A function that takes the output view of the current chain (`TCurrentChainOutputView`)
  ///   and produces a new view (`TNextChainOutputView`).
  /// Returns a new PipelineBuilder instance representing the extended chain.
  PipelineBuilder<TCurrentChainInputView, TNextChainOutputView> add<TNextChainOutputView>(
    TNextChainOutputView Function(TCurrentChainOutputView currentView) middleware,
  ) {
    // Compose the existing chain with the new middleware:
    // The new chain takes the original input (TCurrentChainInputView),
    // applies the old chain to get TCurrentChainOutputView,
    // then applies the new middleware to get TNextChainOutputView.
    return PipelineBuilder<TCurrentChainInputView, TNextChainOutputView>._(
        (TCurrentChainInputView initialView) {
      final previousOutput = _chain(initialView);
      return middleware(previousOutput);
    });
  }

  /// Finalizes the pipeline with a handler.
  /// - `handler`: A function that takes the final output view of the middleware chain (`TCurrentChainOutputView`)
  ///   and produces a `FutureOr<Response>`.
  /// Returns a single function that takes a `Request`, sets up the context, executes the pipeline,
  /// and returns the `FutureOr<Response>`.
  FutureOr<Response> Function(NewContext request) build(
    FutureOr<Response> Function(TCurrentChainOutputView finalView) handler,
  ) {
    // The fully composed chain from the initial TCurrentChainInputView (which should be BaseContextView for a `start()`ed pipeline)
    // to the final TCurrentChainOutputView.
    final TCurrentChainOutputView Function(TCurrentChainInputView)
        completeMiddlewareChain = _chain;

    return (NewContext ctx) {
      // This cast assumes the pipeline was started with `PipelineBuilder.start()`,
      // making TCurrentChainInputView effectively BaseContextView.
      final initialView =
          BaseContextView(ctx) as TCurrentChainInputView;

      // Execute the middleware chain.
      final finalView = completeMiddlewareChain(initialView);

      // Execute the final handler with the processed context view.
      return handler(finalView);
    };
  }
}
```

## 5. Usage Example

This demonstrates how to build a pipeline and how type errors would be caught.

```dart
// Assuming SessionMiddleware is:
// UserSessionContextView sessionMiddleware(UserContextView userView) { ... }

// Define a handler that expects both User and Session data.
Future<Response> mySecureHandler(UserSessionContextView context) async {
  final user = context.user;
  final session = context.session;
  return Response.ok('User: ${user.email}, Session ID: ${session.sessionId}');
}

void setupServer() {
  final requestHandler = PipelineBuilder.start() // Starts with BaseContextView
      .add(authenticationMiddleware)             // Output view: UserContextView
      .add(sessionMiddleware)                    // Input: UserContextView, Output: UserSessionContextView
      .build(mySecureHandler);                   // Handler expects UserSessionContextView - OK!

  // This handler can now be passed to Relic's server serving mechanism.
  // relicServe(requestHandler, ...);

  // Example of a compile-time error:
  // final faultyHandler = PipelineBuilder.start()
  //     .add(authenticationMiddleware) // Output: UserContextView
  //     // Missing sessionMiddleware
  //     .build(mySecureHandler);      // COMPILE ERROR: mySecureHandler expects UserSessionContextView,
  //                                  // but pipeline only guarantees UserContextView.
}
```

## 6. Benefits

*   **Compile-Time Safety**: The primary goal. Misconfigured pipelines (e.g., missing middleware, incorrect order affecting context data) are caught by the Dart analyzer.
*   **Improved Developer Ergonomics**:
    *   Handlers and middleware can declare precisely the context view (and thus data) they expect.
    *   Access to context data via extension type getters is type-safe and clear (e.g., `context.user`).
*   **Minimal Runtime Overhead for Views**: Extension types are intended to be zero-cost compile-time wrappers. The `ContextProperty` helper encapsulates `Expando` lookups/attachments, which are generally efficient.
*   **No Class Explosion**: Avoids needing a distinct context `class` for every possible combination of middleware. Extension types provide views, and `ContextProperty` manages data association with the stable `requestToken`.
*   **Clarity and Documentation**: The type signatures of middleware and handlers explicitly document their context dependencies. View methods (e.g., `attachUser`) and `ContextProperty` provide clear, discoverable APIs for data management.
*   **Modularity & Encapsulation**: `ContextProperty` encapsulates `Expando` usage. Modules define their data properties cleanly.

## 7. Middleware Paradigm Shift and Implications

This typed pipeline introduces a shift from the traditional `Middleware = Handler Function(Handler innerHandler)` pattern previously used. Understanding these changes is crucial:

*   **New Middleware Signature**: Middleware in this design are functions with a signature like `OutputView Function(InputView)`. They transform context views rather than wrapping an inner handler.
*   **Linear Chain**: The `PipelineBuilder` composes middleware into a linear chain of context transformations. Each middleware is expected to process the context and pass control (via its return value) to the next stage defined by the builder.
*   **Short-Circuiting (e.g., Denying Access)**:
    *   Middleware should not directly return a `Response` to short-circuit the pipeline.
    *   Instead, if a middleware needs to stop processing and return an error (e.g., an authentication middleware denying access due to an invalid token), it should **throw a specific exception** (e.g., `AuthorizationRequiredError("Invalid token")`, `PaymentRequiredError()`).
    *   The main server error handling logic (external to this pipeline execution) would then catch these specific exceptions and convert them into appropriate HTTP `Response` objects (e.g., status codes 401, 403, 402).
    *   This keeps middleware focused on context validation/transformation, with exceptions managing early exits.
*   **Complex Conditional Logic or "Nested" Operations**:
    *   The `InputView -> OutputView` signature doesn't inherently support conditional invocation of different sub-handlers or complex branching within the middleware itself in the same way the `Handler Function(Handler)` pattern does.
    *   Such logic is often best placed within the **final handler** (the function passed to `PipelineBuilder.build(...)`). This handler receives the fully prepared, type-safe context. Inside this handler, developers can use standard Dart control flow (`if/else`, `switch`) or call other services/functions which might internally manage their own complex operations (potentially even using other `PipelineBuilder` instances for sub-tasks if appropriate, though this is advanced).
    *   Alternatively, a middleware could add data to the context that signals a specific route or action, which subsequent middleware or the final handler then interprets.
*   **Trade-offs**:
    *   **Gained**: Strong compile-time type safety for the data flowing through the request context. This significantly reduces a class of runtime errors due to misconfigured pipelines.
    *   **Different Flexibility**: Some dynamic flexibility found in the `Handler Function(Handler)` pattern (e.g., complex around-logic, dynamically choosing the next handler in the chain from within a middleware) is handled differently (e.g., via exceptions, or by moving logic into handlers). For many common middleware tasks (logging, data enrichment, simple auth checks), the typed pipeline offers a clearer and safer model.

## 8. General Considerations

*   **PipelineBuilder Complexity**: The implementation of `PipelineBuilder`, especially its generic typing, is somewhat complex, but this complexity is encapsulated for the end-user.
*   **Boilerplate for `ContextProperty` and Views**: Each new piece of context data requires defining a `ContextProperty` instance and corresponding view methods. However, this is more structured and less error-prone than raw `Expando` usage.
*   **Learning Curve**: Developers using the framework will need to understand context views, `ContextProperty`, the role of `requestToken`, the pipeline builder, and the implications of the new middleware paradigm.
*   **Discipline with `requestToken`**: The `ContextProperty` helper ensures that data is keyed off the stable `token` within the `RequestContext`, mitigating direct misuse of `Expando`s with transient `RequestContext` instances themselves as keys.
*   **Middleware Return Types**: Middleware authors must be careful to return the correct context view type that accurately reflects the data they've attached via `ContextProperty` and the `requestToken`.
