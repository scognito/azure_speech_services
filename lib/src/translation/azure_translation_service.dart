// ignore_for_file: avoid-unsafe-collection-methods

import 'dart:async';
import 'dart:convert';

import 'package:azure_speech_services/src/common/azure_speech_service_base.dart';
import 'package:azure_speech_services/src/common/azure_speech_exception.dart';
import 'package:azure_speech_services/src/config/azure_speech_config.dart';
import 'package:azure_speech_services/src/constants.dart';
import 'package:azure_speech_services/src/services/microphone_service.dart';
import 'package:azure_speech_services/src/translation/translation_config.dart';
import 'package:azure_speech_services/src/translation/translation_cubit.dart';
import 'package:flutter/foundation.dart';

class AzureTranslationService extends AzureSpeechServiceBase {
  final TranslationConfig _translationConfig;
  final TranslationCubit _cubit;

  Timer? _textClearTimer;

  AzureTranslationService({
    required AzureSpeechConfig config,
    required TranslationConfig translationConfig,
    required TranslationCubit cubit,
    required MicrophoneService micService,
    bool debug = false,
  }) : _translationConfig = translationConfig,
       _cubit = cubit,
       super(config: config, micService: micService, debug: debug);

  Future<void> startListening({Stream<List<int>>? externalAudioStream}) async {
    if (_cubit.isListening) return;

    _cubit.reset();
    _cubit.setListening(true);

    final requestId = newRequestId();

    try {
      await openSession(
        requestId: requestId,
        buildUri: (params) {
          final allParams = {
            for (final e in params.entries) e.key: [e.value],
            'to': _translationConfig.toLanguages,
          };
          return Uri(
            scheme: 'wss',
            host: '${config.region}.s2s.speech.microsoft.com',
            path: '/speech/universal/v2',
            queryParameters: allParams,
          );
        },
        baseQueryParams: {
          Constants.format: 'simple',
          'lidEnabled': 'true',
          'from': _translationConfig.sanitizedFromLanguage,
          'to': _translationConfig.sanitizedToLanguages.first
              .split('-')
              .first, // Azure needs language in country code only format
        },
        onMessage: _handleIncoming,
        onError: (msg) => _cubit.emitError(msg),
        onDone: () => _cubit.setListening(false),
      );

      sendSpeechConfig(requestId);
      _sendTranslationContext(
        requestId,
        _translationConfig.sanitizedToLanguages.first.split('-').first,
      );
      _resetClearTimer();

      await startAudioStream(
        requestId: requestId,
        externalAudioStream: externalAudioStream?.cast(),
        onError: (msg) => _cubit.emitError(msg),
      );
    } catch (e) {
      final message = e is AzureSpeechException ? e.toString() : 'Failed to start translation: $e';
      debugPrint(message);
      _cubit.emitError(message);
      await stopListening();
    }
  }

  Future<void> stopListening() async {
    _textClearTimer?.cancel();
    _textClearTimer = null;
    await stopSession();
    _cubit.setListening(false);
  }

  bool isListening() => _cubit.isListening;

  void _sendTranslationContext(String requestId, String langCode) {
    sendTextFrame('speech.context', requestId, {
      "phraseOutput": {
        "interimResults": {"resultType": "None"},
        "phraseResults": {"resultType": "None"},
      },
      "phraseDetection": {
        "onInterim": {"action": "Translate"},
        "onSuccess": {"action": "Translate"},
      },
      "translation": {
        "onSuccess": {"action": "None"},
        "output": {
          "interimResults": {"mode": "Always"},
        },
        "targetLanguages": ["$langCode"],
      },
    });
  }

  void _handleIncoming(Object? raw) {
    try {
      if (debug) {
        debugPrint(
          '<<< RECEIVED: ${raw is String ? raw : (raw is List ? 'binary ${raw.length} bytes' : 'unknown')}',
        );
      }
      if (raw is String) {
        final parsed = parseTextFrame(raw);
        final path = parsed.headers[Constants.path];
        if (path != null && parsed.body.isNotEmpty) {
          _processResponse(path, parsed.body);
        }
      } else if (raw is List<int>) {
        final parsed = parseTextFrame(utf8.decode(raw));
        final path = parsed.headers[Constants.path];
        if (path != null) _processResponse(path, parsed.body);
      }
    } catch (e, s) {
      debugPrint('HandleIncoming exception: $e\n$s');
    }
  }

  void _processResponse(String path, String jsonBody) {
    try {
      final trimmed = jsonBody.trim();
      if (trimmed.isEmpty) {
        _cubit.reset();
        return;
      }

      final map = jsonDecode(trimmed) as Map<String, dynamic>;

      if (path.toLowerCase() != 'translation.response') {
        if (debug) debugPrint('Azure translation event: $path — ${map['type'] ?? ''}');
        return;
      }

      final hasHypothesis = map.containsKey('SpeechHypothesis');
      final hasPhrase = map.containsKey('SpeechPhrase');

      if (hasHypothesis) {
        final hypothesis = map['SpeechHypothesis'] as Map<String, dynamic>?;
        final recognized = (hypothesis?['Text'] ?? map['Text']) as String? ?? '';
        final translations = _parseTranslations(map);
        final language = _parsePrimaryLanguage(map);

        _cubit.updateIntermediate(
          recognizedText: recognized,
          translations: translations,
          detectedLanguage: language,
        );
        _resetClearTimer();
      } else if (hasPhrase) {
        final phrase = map['SpeechPhrase'] as Map<String, dynamic>?;
        final status = (phrase?['RecognitionStatus'] ?? map['RecognitionStatus']) as String? ?? '';

        if (status == 'Success') {
          final recognized = (phrase?['DisplayText'] ?? map['DisplayText']) as String? ?? '';
          final translations = _parseTranslations(map);
          final language = _parsePrimaryLanguage(map);

          _cubit.addFinalized(
            recognizedText: recognized,
            translations: translations,
            detectedLanguage: language,
          );
          _resetClearTimer();
        }
      } else {
        if (debug) debugPrint('Azure translation event: $path — ${map['type'] ?? ''}');
      }
    } catch (e) {
      debugPrint('processResponse failed: $e; body: $jsonBody');
    }
  }

  Map<String, String> _parseTranslations(Map<String, dynamic> map) {
    // ignore: avoid-dynamic
    final list = (map['Translations'] ?? map['Translation']?['Translations']) as List<dynamic>?;
    if (list == null) return {};
    return {
      for (final entry in list)
        (entry['Language'] as String? ?? ''):
            (entry['DisplayText'] as String? ?? entry['Text'] as String? ?? ''),
    };
  }

  String? _parsePrimaryLanguage(Map<String, dynamic> map) {
    final languageBlock =
        (map['SpeechHypothesis']?['PrimaryLanguage'] ??
                map['SpeechPhrase']?['PrimaryLanguage'] ??
                map['PrimaryLanguage'])
            as Map<String, dynamic>?;
    return languageBlock?['Language'] as String?;
  }

  void _resetClearTimer() {
    _textClearTimer?.cancel();
    _textClearTimer = Timer(_translationConfig.textClearTimeout, _cubit.clearText);
  }
}
