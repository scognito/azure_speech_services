import 'dart:async';
import 'dart:typed_data';

import 'package:azure_speech_services/src/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

class MicrophoneService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _hasStarted = false;

  Future<Stream<Uint8List>> start() async {
    if (!await _checkPermission()) {
      throw Exception('Microphone permission not granted');
    }

    const config = RecordConfig(
      encoder: .pcm16bits,
      sampleRate: Constants.audioSampleRate,
      numChannels: Constants.audioChannels,
    );

    // On some browsers, getUserMedia can't honor an exact sample rate and
    // record_web silently hands back audio at its native rate instead (e.g.
    // 48000 Hz) while still reporting it as 16 kHz. This callback fires
    // synchronously during startStream() below whenever that happens, so we
    // can downsample in software and keep every downstream consumer honestly
    // fed 16 kHz PCM.
    int? actualSampleRate;
    await _audioRecorder.setOnConfigChanged((adjusted) {
      actualSampleRate = adjusted.sampleRate;
    });

    debugPrint('Starting microphone stream (16kHz, mono, PCM16)...');

    final stream = await _audioRecorder.startStream(config);
    _isRecording = true;
    _hasStarted = true;

    if (actualSampleRate == null || actualSampleRate == Constants.audioSampleRate) {
      return stream;
    }

    debugPrint(
      'Microphone granted $actualSampleRate Hz instead of the requested '
      '${Constants.audioSampleRate} Hz; resampling in software.',
    );
    final resampler = _LinearResampler(fromRate: actualSampleRate!, toRate: Constants.audioSampleRate);
    return stream.map(resampler.process);
  }

  Future<void> stop() async {
    if (!_isRecording) return;
    debugPrint('Stopping microphone stream');
    await _audioRecorder.stop();
    _isRecording = false;
  }

  Future<bool> _checkPermission() async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) debugPrint('Microphone permission not granted.');
    return hasPermission;
  }

  Future<void> dispose() async {
    if (_isRecording) await stop();
    if (_hasStarted) await _audioRecorder.dispose();
  }
}

/// Streaming linear-interpolation downsampler for mono PCM16 (little-endian)
/// chunks. Carries the fractional read position and the trailing sample
/// across [process] calls so consecutive chunks resample without clicks or
/// drift at their boundaries.
class _LinearResampler {
  final int fromRate;
  final int toRate;
  double _phase = 0;
  int _lastSample = 0;
  bool _hasPreviousSample = false;

  _LinearResampler({required this.fromRate, required this.toRate});

  Uint8List process(Uint8List input) {
    final sampleCount = input.lengthInBytes ~/ 2;
    if (sampleCount == 0) return input;

    final inputView = input.buffer.asByteData(input.offsetInBytes, input.lengthInBytes);
    // extended[0] is the last sample of the previous chunk so interpolation
    // stays continuous across the boundary; for the very first chunk there is
    // no previous sample, so it's seeded with this chunk's own first sample.
    final extended = Int16List(sampleCount + 1);
    extended[0] = _hasPreviousSample ? _lastSample : inputView.getInt16(0, Endian.little);
    for (var i = 0; i < sampleCount; i++) {
      extended[i + 1] = inputView.getInt16(i * 2, Endian.little);
    }

    final ratio = fromRate / toRate;
    final outputSamples = <int>[];
    while (_phase + 1 < extended.length) {
      final index = _phase.floor();
      final frac = _phase - index;
      final s0 = extended[index];
      final s1 = extended[index + 1];
      outputSamples.add((s0 + (s1 - s0) * frac).round().clamp(-32768, 32767));
      _phase += ratio;
    }
    _phase -= sampleCount;
    _lastSample = extended.last;
    _hasPreviousSample = true;

    final output = Uint8List(outputSamples.length * 2);
    final outputView = ByteData.view(output.buffer);
    for (var i = 0; i < outputSamples.length; i++) {
      outputView.setInt16(i * 2, outputSamples[i], Endian.little);
    }
    return output;
  }
}
