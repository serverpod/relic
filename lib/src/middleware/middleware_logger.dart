import '../adaptor/context.dart';
import '../logger/logger.dart';
import '../method/request_method.dart';
import 'middleware.dart';

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
Middleware logRequests({
  final Logger? logger,
}) =>
    (final innerHandler) {
      final localLogger = logger ?? logMessage;

      return (final request) async {
        final startTime = DateTime.now();
        final watch = Stopwatch()..start();

        try {
          final newCtx = await innerHandler(request);
          final msg = switch (newCtx) {
            final ResponseContext rc => _message(
                startTime,
                rc.response.statusCode,
                rc.request.requestedUri,
                rc.request.method.value,
                watch.elapsed,
              ),
            final HijackContext hc => '$hc', // TODO
            final NewContext nc => '$nc', // TODO
          };
          localLogger(msg);
          return newCtx;
        } catch (error, stackTrace) {
          final msg = _errorMessage(
            startTime,
            request.request.requestedUri,
            request.request.method,
            watch.elapsed,
            error,
          );

          localLogger(
            msg,
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
  final int statusCode,
  final Uri requestedUri,
  final String method,
  final Duration elapsedTime,
) {
  return '${requestTime.toIso8601String()} '
      '${elapsedTime.toString().padLeft(15)} '
      '${method.padRight(7)} [$statusCode] ' // 7 - longest standard HTTP method
      '${requestedUri.path}${_formatQuery(requestedUri.query)}';
}

String _errorMessage(
  final DateTime requestTime,
  final Uri requestedUri,
  final RequestMethod method,
  final Duration elapsedTime,
  final Object error,
) {
  return '$requestTime\t'
      '$elapsedTime\t'
      '${method.value}\t'
      '${requestedUri.path}'
      '${_formatQuery(requestedUri.query)}\n$error';
}
