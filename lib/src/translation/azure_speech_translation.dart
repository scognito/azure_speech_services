import 'dart:typed_data';

import 'package:azure_speech_services/src/config/azure_speech_config.dart';
import 'package:azure_speech_services/src/services/microphone_service.dart';
import 'package:azure_speech_services/src/translation/azure_translation_service.dart';
import 'package:azure_speech_services/src/translation/translation_config.dart';
import 'package:azure_speech_services/src/translation/translation_cubit.dart';

class AzureSpeechTranslation {
  final AzureSpeechConfig config;
  final TranslationConfig translationConfig;

  final TranslationCubit _cubit;
  final MicrophoneService _microphone;
  late final AzureTranslationService _service;

  AzureSpeechTranslation({
    required this.config,
    required this.translationConfig,
    bool debug = false,
  }) : _cubit = TranslationCubit(),
       _microphone = MicrophoneService() {
    _service = AzureTranslationService(
      config: config,
      translationConfig: translationConfig,
      cubit: _cubit,
      micService: _microphone,
      debug: debug,
    );
  }

  Stream<TranslationState> get stream => _cubit.stream;

  bool get isListening => _service.isListening();

  TranslationCubit get cubit => _cubit;

  /// Starts the translation session.
  ///
  /// By default, audio is captured from the device microphone. You can instead
  /// provide an [externalAudioStream] to supply your own audio source — for
  /// example, audio coming from a VoIP call or a file.
  ///
  /// The stream must emit [Uint8List] chunks of raw PCM audio formatted as:
  /// 16 kHz sample rate, mono channel, 16-bit little-endian samples. This
  /// matches exactly the format that the microphone produces and that the WAV
  /// header sent to Azure declares.
  ///
  /// If [externalAudioStream] is `null`, the device microphone is used as normal.
  Future<void> start({Stream<Uint8List>? externalAudioStream}) =>
      _service.startListening(externalAudioStream: externalAudioStream);

  Future<void> stop() => _service.stopListening();

  Future<void> dispose() async {
    await _service.stopListening();
    await _microphone.dispose();
    await _cubit.close();
  }
}
