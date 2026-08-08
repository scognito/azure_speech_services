import 'package:web_socket_channel/html.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'web_socket_service.dart';

class WebSocketServiceWeb implements WebSocketService {
  const WebSocketServiceWeb();

  @override
  WebSocketChannel connect(Uri uri, {Map<String, String>? headers, Iterable<String>? protocols}) {
    return HtmlWebSocketChannel.connect(uri, protocols: protocols);
  }
}

WebSocketService getWebSocketService() => WebSocketServiceWeb();
