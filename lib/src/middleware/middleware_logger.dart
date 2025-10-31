import '../../relic.dart';
import '../logger/logger.dart';

/// Middleware which prints the time of the request, the elapsed time for the
/// inner handlers, the response's status code and the request URI.
///
/// If [logger] is passed, it's called for each request. The `msg` parameter is
/// a formatted string that includes the request time, duration, request method,
/// and requested path. When an exception is thrown, it also includes the
/// exception's string and stack trace; otherwise, it includes the status code.
/// The `isError` parameter indicates whether the message is caused by an error.
///
/// If [logger] is not passed, the message is just passed to [print].
Middleware logRequests({final Logger? logger}) => (final innerHandler) {
  final localLogger = logger ?? logMessage;

  return (final ctx) async {
    final startTime = DateTime.now();
    final watch = Stopwatch()..start();

    try {
      final handledCtx = await innerHandler(ctx);
      final msg = switch (handledCtx) {
        final ResponseContext rc => '${rc.response.statusCode}',
        final HijackedContext _ => 'hijacked',
        final ConnectionContext _ => 'connected',
      };
      localLogger(_message(startTime, handledCtx.request, watch.elapsed, msg));
      return handledCtx;
    } catch (error, stackTrace) {
      localLogger(
        _errorMessage(startTime, ctx.request, watch.elapsed, error),
        type: LoggerType.error,
        stackTrace: stackTrace,
      );

      rethrow;
    }
  };
};

String _formatQuery(final String query) {
  return query == '' ? '' : '?$query';
}

String _message(
  final DateTime requestTime,
  final Request request,
  final Duration elapsedTime,
  final String message,
) {
  final method = request.method.value;
  final requestedUri = request.url;

  return '${requestTime.toIso8601String()} '
      '${elapsedTime.toString().padLeft(15)} '
      '${method.padRight(7)} [$message] ' // 7 - longest standard HTTP method
      '${requestedUri.path}${_formatQuery(requestedUri.query)}';
}

String _errorMessage(
  final DateTime requestTime,
  final Request request,
  final Duration elapsedTime,
  final Object error,
) {
  return _message(requestTime, request, elapsedTime, 'ERROR: $error');
}
