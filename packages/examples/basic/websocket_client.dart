import 'dart:io';

import 'package:web_socket/web_socket.dart';

// doctag<handler-websocket-client>
Future<void> main() async {
  final socket = await WebSocket.connect(Uri.parse('ws://localhost:8080/ws'));

  await for (final event in socket.events) {
    if (event is! TextDataReceived) continue;
    stdout.writeln('< ${event.text}');

    if (event.text.startsWith('Welcome')) {
      stdout.writeln('> hello');
      socket.sendText('hello');
    } else {
      await socket.close();
    }
  }
}

// end:doctag<handler-websocket-client>
