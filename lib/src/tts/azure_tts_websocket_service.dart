import 'dart:async';

import 'package:azure_speech_services/src/common/azure_speech_exception.dart';
import 'package:azure_speech_services/src/common/azure_speech_service_base.dart';
import 'package:azure_speech_services/src/config/azure_speech_config.dart';
import 'package:azure_speech_services/src/config/tts_request.dart';
import 'package:azure_speech_services/src/constants.dart';
import 'package:flutter/foundation.dart';

/// Synthesizes speech over Azure's WebSocket TTS endpoint, delivering audio in chunks as it is
/// generated — unlike the REST-based [AzureTextToSpeech], which only returns once the entire
/// clip has been synthesized. Letting playback start on the first chunk is what actually cuts
/// perceived latency; buffering every chunk before playing would gain nothing over REST.
class AzureTtsWebSocketService extends AzureSpeechServiceBase {
  AzureTtsWebSocketService({required AzureSpeechConfig config, bool debug = false})
    : super(config: config, debug: debug);

  bool _sessionOpen = false;

  // The message handlers for whichever turn is currently in flight. `openSession` only lets us
  // register one `onMessage` callback for the life of the connection, so when the connection is
  // kept open across calls (`closeAfterTurn: false`) these get swapped out per turn instead of
  // re-subscribing. Callers must fully drain one `synthesizeStream()` before starting the next —
  // concurrent overlapping turns on a shared connection are not supported.
  void Function(String raw)? _activeTextHandler;
  void Function(Uint8List raw)? _activeBinaryHandler;
  void Function(String message)? _activeErrorHandler;

  Future<void> _ensureSession() async {
    if (_sessionOpen) return;

    await openSession(
      requestId: newRequestId(),
      buildUri: (params) => Uri.parse(
        'wss://${config.region}.tts.speech.microsoft.com/tts/cognitiveservices/websocket/v1',
      ).replace(queryParameters: params),
      baseQueryParams: const {},
      onMessage: (raw) {
        if (raw is String) {
          _activeTextHandler?.call(raw);
        } else if (raw is List<int>) {
          _activeBinaryHandler?.call(Uint8List.fromList(raw));
        }
      },
      onError: (msg) {
        _sessionOpen = false;
        _activeErrorHandler?.call(msg);
      },
      onDone: () {
        _sessionOpen = false;
      },
    );
    _sessionOpen = true;

    sendTextFrame('speech.config', newRequestId(), {
      'context': {
        'system': {'name': 'FlutterSDK', 'version': '1.0.0'},
      },
    });
  }

  /// Synthesizes [request], yielding audio bytes as chunks arrive from Azure.
  ///
  /// The stream closes normally once the service reports `turn.end`, or with an error if the
  /// connection fails. By default ([closeAfterTurn] `true`) a fresh WebSocket connection is
  /// opened per call and closed once the turn ends, matching how the REST client is used (one
  /// HTTP call per `synthesize()`). Passing `closeAfterTurn: false` keeps the connection open so
  /// a subsequent call reuses it instead of reconnecting — only meaningful once the previous
  /// call's stream has finished; do not start a second call while an unclosed one is still
  /// draining.
  Stream<Uint8List> synthesizeStream(TtsRequest request, {bool closeAfterTurn = true}) {
    final controller = StreamController<Uint8List>();
    final requestId = newRequestId();
    final stopwatch = Stopwatch()..start();
    var chunkCount = 0;

    _activeTextHandler = (raw) {
      final parsed = parseTextFrame(raw);
      final path = parsed.headers[Constants.path]?.toLowerCase();
      if (debug) debugPrint('[tts-ws] +${stopwatch.elapsedMilliseconds}ms <<< $path: ${parsed.body}');
      if (path == 'turn.end') {
        if (!controller.isClosed) controller.close();
        if (closeAfterTurn) {
          _sessionOpen = false;
          unawaited(stopSession());
        }
      }
    };

    _activeBinaryHandler = (raw) {
      final parsed = parseBinaryFrame(raw);
      final path = parsed.headers[Constants.path]?.toLowerCase();
      if (path != 'audio' || parsed.body.isEmpty) return;
      chunkCount++;
      if (debug) {
        debugPrint(
          '[tts-ws] +${stopwatch.elapsedMilliseconds}ms <<< audio chunk #$chunkCount '
          '(${parsed.body.length} bytes)',
        );
      }
      if (!controller.isClosed) controller.add(parsed.body);
    };

    _activeErrorHandler = (msg) {
      if (!controller.isClosed) controller.addError(AzureSpeechException(0, msg));
    };

    Future<void> start() async {
      try {
        await _ensureSession();
        sendTextFrame('synthesis.context', requestId, {
          'synthesis': {
            'audio': {
              'metadataOptions': {
                'bookmarkEnabled': false,
                'sentenceBoundaryEnabled': false,
                'visemeEnabled': false,
                'wordBoundaryEnabled': false,
              },
              'outputFormat': request.outputFormat.value,
            },
          },
        });
        sendRawTextFrame('ssml', requestId, 'application/ssml+xml', request.toSsml());
      } catch (e, s) {
        if (!controller.isClosed) controller.addError(e, s);
        await controller.close();
      }
    }

    unawaited(start());
    return controller.stream;
  }
}
