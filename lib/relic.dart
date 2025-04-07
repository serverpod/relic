library;

/// Relic server related exports
export 'dart:io' show InternetAddress;

/// Server adaptor abstractions for platform independence
export 'src/adaptor/adaptor.dart';

/// Body related exports
export 'src/body/body.dart' show Body;
export 'src/body/types/body_type.dart' show BodyType;
export 'src/body/types/mime_type.dart' show MimeType;

/// Handler related exports
export 'src/handler/cascade.dart' show Cascade;
export 'src/handler/handler.dart' show Handler;
export 'src/handler/pipeline.dart' show Pipeline;
export 'src/headers/exception/header_exception.dart'
    show HeaderException, InvalidHeaderException, MissingHeaderException;
export 'src/headers/header_accessor.dart';
// Headers related exports
export 'src/headers/headers.dart';
export 'src/headers/typed/typed_headers.dart';

/// Static handler export
export 'src/io/static/static_handler.dart';

/// Message related exports
export 'src/message/request.dart' show Request, HijackException;
export 'src/message/response.dart' show Response;
export 'src/method/request_method.dart' show RequestMethod;
export 'src/middleware/middleware.dart' show Middleware, createMiddleware;
export 'src/middleware/middleware_extensions.dart' show MiddlewareExtensions;

/// Middleware related exports
export 'src/middleware/middleware_logger.dart' show logRequests;

/// Original implementation - keeping for backward compatibility
export 'src/relic_server.dart';

/// Platform-agnostic server function
export 'src/relic_server_serve.dart';
