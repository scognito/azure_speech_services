import 'dart:async';
import 'dart:typed_data';

import 'package:azure_speech_services/src/config/azure_speech_config.dart';
import 'package:azure_speech_services/src/config/speech_to_text_config.dart';
import 'package:azure_speech_services/src/cubit/transcription_cubit.dart';
import 'package:azure_speech_services/src/services/microphone_service.dart';
import 'package:azure_speech_services/src/stt/azure_stt_service.dart';

class AzureSpeechToText {
  final AzureSpeechConfig config;
  final SpeechToTextConfig sttConfig;

  final TranscriptionCubit _cubit;
  final MicrophoneService _microphone;
  late final AzureSttService _service;

  AzureSpeechToText({
    required this.config,
    SpeechToTextConfig? sttConfig,
    bool debug = false,
  }) : sttConfig = sttConfig ?? SpeechToTextConfig(),
       _cubit = TranscriptionCubit(),
       _microphone = MicrophoneService() {
    _service = AzureSttService(
      config: config,
      sttConfig: this.sttConfig,
      cubit: _cubit,
      micService: _microphone,
      debug: debug,
    );
  }

  Stream<TranscriptionState> get stream => _cubit.stream;

  bool get isListening => _service.isListening();

  /// Starts the speech recognition session.
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
  Future<void> start({Stream<Uint8List>? externalAudioStream}) {
    return _service.startListening(externalAudioStream: externalAudioStream);
  }

  Future<void> startWithConfig(SpeechToTextConfig cfg, {Stream<Uint8List>? externalAudioStream}) {
    return _service.startListening(sttConfig: cfg, externalAudioStream: externalAudioStream);
  }

  Future<void> stop() {
    return _service.stopListening();
  }

  Future<void> dispose() async {
    await _microphone.dispose();
    await _cubit.close();
  }

  TranscriptionCubit get cubit => _cubit;
}
