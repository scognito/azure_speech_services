/// Flutter package for real-time Speech-to-Text and Text-to-Speech using Microsoft Azure Cognitive Services.
///
/// This library provides a reactive, stream-based API for speech recognition
/// and text synthesis with support for multiple languages and automatic language detection.
library azure_speech_services;

export 'package:azure_speech_services/src/common/azure_speech_exception.dart'
    show AzureSpeechException, AzureTtsException;
export 'package:azure_speech_services/src/config/azure_speech_config.dart';
export 'package:azure_speech_services/src/config/speech_to_text_config.dart';
export 'package:azure_speech_services/src/config/tts_request.dart';
export 'package:azure_speech_services/src/cubit/transcription_cubit.dart'
    show TranscriptionCubit, TranscriptionState;
export 'package:azure_speech_services/src/stt/azure_speech_to_text.dart';
export 'package:azure_speech_services/src/translation/azure_speech_translation.dart';
export 'package:azure_speech_services/src/translation/translation_config.dart';
export 'package:azure_speech_services/src/translation/translation_cubit.dart'
    show TranslationCubit, TranslationState;
export 'package:azure_speech_services/src/tts/azure_text_to_speech.dart';
export 'package:azure_speech_services/src/utils/language_utils.dart' show LanguageUtils;
