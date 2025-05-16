// ignore_for_file: avoid_print

import 'dart:async';
import 'package:relic/src/router/router.dart';

// === Core Stubs (simplified) ===
class Request {
  final Uri uri;
  final Method method;
  final Map<String, String> headers;
  Request({required this.uri, required this.method, this.headers = const {}});
}

class Response {
  final int statusCode;
  final String body;
  Response(this.statusCode, this.body);

  static Response ok(final String body) => Response(200, body);
  static Response notFound(final String body) => Response(404, body);
  static Response unauthorized(final String body) => Response(401, body);
}

class RequestContext {
  final Request request;
  final Object token; // Stable unique token
  RequestContext(this.request, this.token);
}

class NewContext extends RequestContext {
  NewContext(super.request, super.token);
}

// === ContextProperty and Views Stubs ===
class ContextProperty<T extends Object> {
  final Expando<T> _expando;
  final String? _debugName;

  ContextProperty([this._debugName]) : _expando = Expando<T>(_debugName);
  T get(final RequestContext ctx) {
    final val = _expando[ctx.token];
    if (val == null) {
      throw StateError('Property ${_debugName ?? T.toString()} not found');
    }
    return val;
  }

  void set(final RequestContext ctx, final T val) => _expando[ctx.token] = val;
}

extension type BaseContextView(RequestContext _relicContext) {
  Request get request => _relicContext.request;
}

// User data and view
class User {
  final String id;
  final String name;
  User(this.id, this.name);
}

final _userProperty = ContextProperty<User>('user');
extension type UserContextView(RequestContext _relicContext)
    implements BaseContextView {
  User get user => _userProperty.get(_relicContext);
  void attachUser(final User user) => _userProperty.set(_relicContext, user);
}

// Admin data and view
class AdminRole {
  final String roleName;
  AdminRole(this.roleName);
}

final _adminRoleProperty = ContextProperty<AdminRole>('admin_role');
extension type AdminContextView(RequestContext _relicContext)
    implements UserContextView {
  // Admin also has User
  AdminRole get adminRole => _adminRoleProperty.get(_relicContext);
  void attachAdminRole(final AdminRole role) =>
      _adminRoleProperty.set(_relicContext, role);
}

// === PipelineBuilder Stub ===
class PipelineBuilder<TInView extends BaseContextView, TOutView> {
  final TOutView Function(TInView) _chain;
  PipelineBuilder._(this._chain);

  static PipelineBuilder<BaseContextView, BaseContextView> start() {
    return PipelineBuilder._((final BaseContextView view) => view);
  }

  PipelineBuilder<TInView, TNextOutView> add<TNextOutView>(
    final TNextOutView Function(TOutView currentView) middleware,
  ) {
    return PipelineBuilder<TInView, TNextOutView>._(
        (final TInView initialView) {
      final previousOutput = _chain(initialView);
      return middleware(previousOutput);
    });
  }

  FutureOr<Response> Function(NewContext initialContext) build(
    final FutureOr<Response> Function(TOutView finalView) handler,
  ) {
    final TOutView Function(BaseContextView) builtChain =
        _chain as TOutView Function(BaseContextView);
    return (final NewContext initialContext) {
      final initialView = BaseContextView(initialContext)
          as TInView; // Cast for the chain start
      final finalView = builtChain(initialView);
      return handler(finalView);
    };
  }
}

// === Placeholder Middleware ===
// API Auth: Adds User, returns UserContextView
UserContextView apiAuthMiddleware(final BaseContextView inputView) {
  print('API Auth Middleware Running for ${inputView.request.uri.path}');
  if (inputView.request.headers['X-API-Key'] == 'secret-api-key') {
    final userView = UserContextView(inputView._relicContext);
    userView.attachUser(User('api_user_123', 'API User'));
    return userView;
  }
  throw Response(401, 'API Key Required'); // Short-circuiting via exception
}

// Admin Auth: Adds User and AdminRole, returns AdminContextView
AdminContextView adminAuthMiddleware(final BaseContextView inputView) {
  print('Admin Auth Middleware Running for ${inputView.request.uri.path}');
  if (inputView.request.headers['X-Admin-Token'] ==
      'super-secret-admin-token') {
    final userView = UserContextView(inputView._relicContext);
    userView.attachUser(User('admin_user_007', 'Admin User'));

    final adminView = AdminContextView(inputView._relicContext);
    adminView.attachAdminRole(AdminRole('super_admin'));
    return adminView;
  }
  throw Response(401, 'Admin Token Required');
}

T generalLoggingMiddleware<T extends BaseContextView>(final T inputView) {
  // Weird analyzer bug inputView cannot be null here.
  // Compiler and interpreter don't complain. Trying:
  //   final req = inputView!.request;
  // won't work ¯\_(ツ)_/¯
  // ignore: unchecked_use_of_nullable_value
  final req = inputView.request;
  print('Logging: ${req.method} ${req.uri.path}');
  return inputView;
}

// === Endpoint Handlers ===
FutureOr<Response> handleApiUserDetails(final UserContextView context) {
  print('Handling API User Details for ${context.user.name}');
  return Response.ok('API User: ${context.user.name} (id: ${context.user.id})');
}

FutureOr<Response> handleAdminDashboard(final AdminContextView context) {
  print(
      'Handling Admin Dashboard for ${context.user.name} (${context.adminRole.roleName})');
  return Response.ok(
      'Admin: ${context.user.name}, Role: ${context.adminRole.roleName}');
}

FutureOr<Response> handlePublicInfo(final BaseContextView context) {
  print('Handling Public Info for ${context.request.uri.path}');
  return Response.ok('This is public information.');
}

typedef Handler = FutureOr<Response> Function(NewContext);

void main() async {
  // === 1. Build Specialized Pipeline Handlers ===
  final apiHandler = PipelineBuilder.start()
      .add(generalLoggingMiddleware)
      .add(apiAuthMiddleware)
      .build(handleApiUserDetails);

  final adminHandler = PipelineBuilder.start()
      .add(generalLoggingMiddleware)
      .add(adminAuthMiddleware)
      .build(handleAdminDashboard);

  final publicHandler = PipelineBuilder.start()
      .add(generalLoggingMiddleware)
      .build(handlePublicInfo);

  // === 2. Configure Top-Level Router ===
  final topLevelRouter = Router<Handler>()
    ..any('/api/users/**', apiHandler)
    ..any('/admin/dashboard/**', adminHandler)
    ..any('/public/**', publicHandler);

  // === 3. Main Server Request Handler ===
  FutureOr<Response> mainServerRequestHandler(final Request request) {
    final initialContext = NewContext(request, Object());
    print('\nProcessing ${request.method} ${request.uri.path}');

    try {
      final targetPipelineHandler =
          topLevelRouter.lookup(request.method, request.uri.path)?.value;

      if (targetPipelineHandler != null) {
        return targetPipelineHandler(initialContext);
      } else {
        print('No top-level route matched.');
        return Response.notFound('Service endpoint not found.');
      }
    } on Response catch (e) {
      print('Request short-circuited with response: ${e.statusCode}');
      return e;
    } catch (e) {
      print('Unhandled error: $e');
      return Response(500, 'Internal Server Error');
    }
  }

  // === Simulate some requests ===
  final requests = [
    Request(
      uri: Uri.parse('/api/users/123'),
      method: Method.get,
      headers: {'X-API-Key': 'secret-api-key'},
    ),
    Request(
      uri: Uri.parse('/api/users/456'),
      method: Method.get,
      headers: {'X-API-Key': 'wrong-key'},
    ),
    Request(
      uri: Uri.parse('/admin/dashboard'),
      method: Method.get,
      headers: {'X-Admin-Token': 'super-secret-admin-token'},
    ),
    Request(uri: Uri.parse('/public/info'), method: Method.get),
    Request(uri: Uri.parse('/unknown/path'), method: Method.get),
  ];

  for (final req in requests) {
    final res = await mainServerRequestHandler(req);
    print('Response for ${req.uri.path}: ${res.statusCode} - ${res.body}');
  }
}
