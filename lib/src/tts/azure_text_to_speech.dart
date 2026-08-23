import 'dart:convert';

import 'package:azure_speech_services/src/common/auth_headers.dart';
import 'package:azure_speech_services/src/common/azure_speech_exception.dart';
import 'package:azure_speech_services/src/config/azure_speech_config.dart';
import 'package:azure_speech_services/src/config/tts_request.dart';
import 'package:http/http.dart' as http;

class AzureTextToSpeech {
  final AzureSpeechConfig config;
  final http.Client _client;

  /// [client] can be supplied for testing; a single [http.Client] is otherwise
  /// created and reused for the lifetime of this instance so that repeated
  /// requests to Azure reuse the same TCP/TLS connection instead of paying a
  /// fresh handshake on every call. Call [dispose] when done with it.
  AzureTextToSpeech({required this.config, http.Client? client})
    : _client = client ?? http.Client();

  Future<List<TtsVoice>> listVoices() async {
    final url = Uri.parse(
      'https://${config.region}.tts.speech.microsoft.com/cognitiveservices/voices/list',
    );

    final response = await _client.get(url, headers: buildAuthHeaders(config));

    if (response.statusCode != 200) {
      throw AzureTtsException(response);
    }

    // ignore: avoid-dynamic
    final List<dynamic> jsonList = json.decode(response.body);
    return jsonList.map((e) => TtsVoice.fromJson(e)).toList();
  }

  Future<List<int>> synthesize(TtsRequest request) async {
    final url = Uri.parse('https://${config.region}.tts.speech.microsoft.com/cognitiveservices/v1');

    final response = await _client.post(
      url,
      headers: {
        ...buildAuthHeaders(config),
        'Content-Type': 'application/ssml+xml',
        'X-Microsoft-OutputFormat': request.outputFormat.value,
      },
      body: utf8.encode(request.toSsml()),
    );

    if (response.statusCode != 200) {
      throw AzureTtsException(response);
    }

    return response.bodyBytes;
  }

  void dispose() {
    _client.close();
  }
}
