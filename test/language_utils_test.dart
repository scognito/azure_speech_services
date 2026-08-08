import 'package:azure_speech_services/src/constants.dart';
import 'package:azure_speech_services/src/utils/language_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LanguageUtils.maximizeLocale', () {
    test('returns the input unchanged when it already has a region', () {
      expect(LanguageUtils.maximizeLocale('en-US'), 'en-US');
      expect(LanguageUtils.maximizeLocale('it-IT'), 'it-IT');
    });

    test('expands a bare language code to its most likely locale', () {
      expect(LanguageUtils.maximizeLocale('it'), 'it-IT');
      expect(LanguageUtils.maximizeLocale('fr'), 'fr-FR');
    });

    test('is case-insensitive on bare language codes', () {
      expect(LanguageUtils.maximizeLocale('IT'), 'it-IT');
    });

    test('falls back to the default language for an unknown bare code', () {
      expect(LanguageUtils.maximizeLocale('xx'), Constants.defaultLang);
    });
  });

  group('LanguageUtils.getSupportedLanguages', () {
    test('returns a non-empty list of known locales', () {
      final languages = LanguageUtils.getSupportedLanguages();

      expect(languages, isNotEmpty);
      expect(languages, contains('en-US'));
      expect(languages, contains('it-IT'));
    });

    test('contains no duplicates', () {
      final languages = LanguageUtils.getSupportedLanguages();

      expect(languages.toSet().length, languages.length);
    });
  });
}
