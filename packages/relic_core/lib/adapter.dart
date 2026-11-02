/// What an adapter implementation needs beyond `relic_core.dart`.
///
/// The `Adapter` contract itself, with `AdapterExchange`, `Listener` and
/// `RelicWebSocket`, is in `package:relic_core/relic_core.dart`, since the
/// server names those types. This library carries the toolkit for
/// implementing them: response framing and head encoding, the WebSocket
/// wire format and the framed socket over a byte channel.
library;

export 'src/adapter/adapter.dart' show ExchangeEndState;
export 'src/adapter/response_framing.dart';
export 'src/adapter/response_head.dart';
export 'src/util/http_date.dart' show httpDateLine, stampedDate;
export 'src/util/util.dart' show statusMayHaveBody;
export 'src/web_socket/framed_web_socket.dart';
export 'src/web_socket/relic_web_socket_base.dart';
export 'src/web_socket/web_socket_frame.dart';
export 'src/web_socket/web_socket_handshake.dart';
