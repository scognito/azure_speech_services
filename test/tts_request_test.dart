import 'package:azure_speech_services/azure_speech_services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const voice = TtsVoice(
    name: 'en-US-JennyNeural',
    locale: 'en-US',
    localeName: 'English (United States)',
    localName: 'Jenny',
    gender: 'Female',
  );

  group('TtsRequest', () {
    test('defaults to riff8khz16bitMonoPcm', () {
      const request = TtsRequest(text: 'Hello', voice: voice);

      expect(request.outputFormat, AudioOutputFormat.riff8khz16bitMonoPcm);
    });

    test('renders SSML with the voice locale, gender, name, and text', () {
      const request = TtsRequest(text: 'Hello world', voice: voice);

      final ssml = request.toSsml();

      expect(ssml, contains("xml:lang='en-US'"));
      expect(ssml, contains("xml:gender='Female'"));
      expect(ssml, contains("name='en-US-JennyNeural'"));
      expect(ssml, contains('Hello world'));
    });
  });

  group('TtsVoice', () {
    test('fromJson parses the Azure voices-list response shape', () {
      final voice = TtsVoice.fromJson({
        'ShortName': 'it-IT-ElsaNeural',
        'Locale': 'it-IT',
        'LocaleName': 'Italian (Italy)',
        'LocalName': 'Elsa',
        'Gender': 'Female',
        'DisplayName': 'Elsa',
      });

      expect(voice.name, 'it-IT-ElsaNeural');
      expect(voice.locale, 'it-IT');
      expect(voice.localeName, 'Italian (Italy)');
      expect(voice.localName, 'Elsa');
      expect(voice.gender, 'Female');
      expect(voice.description, 'Elsa');
    });

    test('two voices with the same fields are equal', () {
      expect(voice, const TtsVoice(
        name: 'en-US-JennyNeural',
        locale: 'en-US',
        localeName: 'English (United States)',
        localName: 'Jenny',
        gender: 'Female',
      ));
    });
  });
}
