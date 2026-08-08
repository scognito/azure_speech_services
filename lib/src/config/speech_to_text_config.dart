import 'package:azure_speech_services/src/constants.dart';
import 'package:azure_speech_services/src/utils/language_utils.dart';

class SpeechToTextConfig {
  final List<String> languages;
  final LanguageIdMode languageIdMode;
  final Duration textClearTimeout;
  final List<String> sanitizedLanguages;

  SpeechToTextConfig({
    List<String> languages = const [Constants.defaultLang],
    this.languageIdMode = LanguageIdMode.atStart,
    this.textClearTimeout = const Duration(seconds: 1),
  }) : languages = List.unmodifiable(languages),
       sanitizedLanguages = List.unmodifiable(languages.map(LanguageUtils.maximizeLocale));
}

enum LanguageIdMode { atStart, continuous }
