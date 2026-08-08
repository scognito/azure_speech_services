import 'package:web_socket_channel/web_socket_channel.dart';

abstract class WebSocketService {
  WebSocketChannel connect(Uri uri, {Map<String, String>? headers, Iterable<String>? protocols});
}
