import 'dart:async';
import '../../relic.dart';

/// Extension on [RelicRouter] that cater specifically to [Handler]s.
extension RouterHandlerEx on RelicRouter {
  /// Makes [RelicRouter] callable as a [Handler].
  ///
  /// Performs routing lookup and:
  /// - Returns 405 if path matches but method doesn't (with Allow header)
  /// - Calls fallback handler if set and no route matches
  /// - Returns 404 if no fallback is set and no route matches
  /// - Calls the matched handler if route is found
  ///
  /// Example:
  /// ```dart
  /// final router = RelicRouter()
  ///   ..get('/users/:id', usersHandler)
  ///   ..use('/', logRequests())
  ///   ..fallback = notFoundHandler; // optional, defaults to 404
  ///
  /// await serve(router.asHandler, InternetAddress.anyIPv4, 8080);
  /// ```
  Handler get asHandler => call;

  /// Similar to [HandlerObject] this extension allows a [Router]
  /// to be callable like a [Handler].
  FutureOr<HandledContext> call(final RequestContext ctx) => const Pipeline()
      .addMiddleware(routeWith(this))
      .addHandler(fallback ?? respondWith((_) => Response.notFound()))(ctx);
}
