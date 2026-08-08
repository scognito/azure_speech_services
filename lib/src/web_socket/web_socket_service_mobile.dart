import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'web_socket_service.dart';

class WebSocketServiceMobile implements WebSocketService {
  const WebSocketServiceMobile();

  @override
  WebSocketChannel connect(Uri uri, {Map<String, String>? headers, Iterable<String>? protocols}) {
    return IOWebSocketChannel.connect(uri, headers: headers, protocols: protocols);
  }
}

WebSocketService getWebSocketService() => WebSocketServiceMobile();
