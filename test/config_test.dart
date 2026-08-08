import 'package:azure_speech_services/azure_speech_services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AzureSpeechConfig', () {
    test('subscriptionKey constructor sets the key and leaves the token null', () {
      final config = AzureSpeechConfig.subscriptionKey(region: 'westeurope', key: 'my-key');

      expect(config.region, 'westeurope');
      expect(config.subscriptionKey, 'my-key');
      expect(config.authorizationToken, isNull);
    });

    test('authorizationToken constructor sets the token and leaves the key null', () {
      final config = AzureSpeechConfig.authorizationToken(region: 'westeurope', token: 'my-token');

      expect(config.region, 'westeurope');
      expect(config.authorizationToken, 'my-token');
      expect(config.subscriptionKey, isNull);
    });
  });

  group('SpeechToTextConfig', () {
    test('defaults to a single default language with at-start LID', () {
      final config = SpeechToTextConfig();

      expect(config.languages, ['en-US']);
      expect(config.languageIdMode, LanguageIdMode.atStart);
    });

    test('sanitizes bare language codes into full locales', () {
      final config = SpeechToTextConfig(languages: ['en-US', 'it', 'fr']);

      expect(config.sanitizedLanguages, ['en-US', 'it-IT', 'fr-FR']);
    });

    test('exposes an unmodifiable languages list', () {
      final config = SpeechToTextConfig(languages: ['en-US']);

      expect(() => config.languages.add('fr'), throwsUnsupportedError);
    });
  });

  group('TranslationConfig', () {
    test('sanitizes both source and target languages', () {
      final config = TranslationConfig(fromLanguage: 'en', toLanguages: ['it', 'fr-FR']);

      expect(config.sanitizedFromLanguage, 'en-US');
      expect(config.sanitizedToLanguages, ['it-IT', 'fr-FR']);
    });

    test('throws when constructed with no target languages', () {
      expect(
        () => TranslationConfig(fromLanguage: 'en-US', toLanguages: []),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
