import 'package:azure_speech_services/azure_speech_services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late TranslationCubit cubit;

  setUp(() => cubit = TranslationCubit());
  tearDown(() => cubit.close());

  test('starts with an empty, not-listening state', () {
    expect(cubit.state, const TranslationState());
    expect(cubit.isListening, isFalse);
  });

  test('setListening toggles isListening', () {
    cubit.setListening(true);
    expect(cubit.isListening, isTrue);
  });

  test('updateIntermediate sets recognized text, translations, and language', () {
    cubit.updateIntermediate(
      recognizedText: 'hello',
      translations: {'it': 'ciao'},
      detectedLanguage: 'en-US',
    );

    expect(cubit.state.recognizedText, 'hello');
    expect(cubit.state.translations, {'it': 'ciao'});
    expect(cubit.state.detectedLanguage, 'en-US');
    expect(cubit.isListening, isTrue);
  });

  test('addFinalized overwrites recognized text and translations', () {
    cubit.updateIntermediate(recognizedText: 'hel', translations: {'it': 'ci'});
    cubit.addFinalized(recognizedText: 'hello', translations: {'it': 'ciao'});

    expect(cubit.state.recognizedText, 'hello');
    expect(cubit.state.translations, {'it': 'ciao'});
  });

  test('emitError sets the error and stops listening', () {
    cubit.setListening(true);
    cubit.emitError('boom');

    expect(cubit.state.error, 'boom');
    expect(cubit.isListening, isFalse);
  });

  test('clearText resets recognized text and translations', () {
    cubit.updateIntermediate(recognizedText: 'hello', translations: {'it': 'ciao'});
    cubit.clearText();

    expect(cubit.state.recognizedText, isEmpty);
    expect(cubit.state.translations, isEmpty);
  });

  test('reset clears state and stops listening', () {
    cubit.updateIntermediate(recognizedText: 'hello', translations: {'it': 'ciao'});
    cubit.reset();

    expect(cubit.state, const TranslationState());
  });
}
