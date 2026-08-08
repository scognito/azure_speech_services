import 'package:azure_speech_services/azure_speech_services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late TranscriptionCubit cubit;

  setUp(() => cubit = TranscriptionCubit());
  tearDown(() => cubit.close());

  test('starts with an empty, not-listening state', () {
    expect(cubit.state, const TranscriptionState());
    expect(cubit.isListening, isFalse);
  });

  test('setListening toggles isListening', () {
    cubit.setListening(true);
    expect(cubit.isListening, isTrue);

    cubit.setListening(false);
    expect(cubit.isListening, isFalse);
  });

  test('updateIntermediateText updates the hypothesis and combined text', () {
    cubit.updateIntermediateText('hello', language: 'en-US');

    expect(cubit.state.intermediateText, 'hello');
    expect(cubit.state.text, 'hello');
    expect(cubit.state.detectedLanguage, 'en-US');
  });

  test('addFinalizedText appends to finalizedText and clears the hypothesis', () {
    cubit.updateIntermediateText('hel');
    cubit.addFinalizedText('hello');

    expect(cubit.state.intermediateText, isEmpty);
    expect(cubit.state.finalizedText, ['hello']);
    expect(cubit.state.text, 'hello');
  });

  test('addFinalizedText with empty text only clears the hypothesis', () {
    cubit.updateIntermediateText('hel');
    cubit.addFinalizedText('');

    expect(cubit.state.intermediateText, isEmpty);
    expect(cubit.state.finalizedText, isEmpty);
  });

  test('emitError sets the error and stops listening', () {
    cubit.setListening(true);
    cubit.emitError('boom');

    expect(cubit.state.error, 'boom');
    expect(cubit.isListening, isFalse);
  });

  test('clearText resets text fields but keeps isListening', () {
    cubit.setListening(true);
    cubit.updateIntermediateText('hello');
    cubit.clearText();

    expect(cubit.state.text, isEmpty);
    expect(cubit.state.intermediateText, isEmpty);
    expect(cubit.state.finalizedText, isEmpty);
    expect(cubit.isListening, isTrue);
  });

  test('reset clears text and stops listening', () {
    cubit.setListening(true);
    cubit.updateIntermediateText('hello');
    cubit.reset();

    expect(cubit.state, const TranscriptionState());
  });
}
