// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:typed_data';

import 'package:azure_speech_services/azure_speech_services.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import 'widgets/azure_app_bar.dart';

class TtsScreen extends StatefulWidget {
  final AzureTextToSpeech ttsService;
  final AudioPlayer audioPlayer;

  const TtsScreen({required this.ttsService, required this.audioPlayer});

  @override
  State<TtsScreen> createState() => _TtsScreenState();
}

// some format are not allowed for playback
const _formatsToExclude = {
  AudioOutputFormat.audio16khz16bit32kbpsMonoOpus,
  AudioOutputFormat.audio24khz16bit48kbpsMonoOpus,
  AudioOutputFormat.audio24khz16bit24kbpsMonoOpus,
  AudioOutputFormat.raw8khz8bitMonoPcm,
  AudioOutputFormat.riff8khz8bitMonoPcm,
  AudioOutputFormat.audio48khz128kbitrateMonoMp3,
};

class _TtsScreenState extends State<TtsScreen> {
  late TextEditingController _textEditingController;
  String _textToSpeak = 'Hello, this is a test of Azure Text-to-Speech.';
  TtsVoice? _selectedTtsVoice;
  List<TtsVoice> _availableTtsVoices = [];
  AudioOutputFormat _selectedOutputFormat = AudioOutputFormat.riff16khz16bitMonoPcm;

  AudioPlayer get _audioPlayer => widget.audioPlayer;
  bool _isLoadingVoices = false;
  bool _isSynthesizing = false;

  @override
  void initState() {
    super.initState();
    _textEditingController = TextEditingController(text: _textToSpeak);
    _textEditingController.addListener(() {
      setState(() {
        _textToSpeak = _textEditingController.text;
      });
    });
    _loadVoices();
  }

  Future<void> _loadVoices() async {
    setState(() {
      _isLoadingVoices = true;
    });
    try {
      final voices = await widget.ttsService.listVoices();
      setState(() {
        _availableTtsVoices = voices;
        _selectedTtsVoice = voices.firstWhere(
          (v) => v.locale == 'en-US' && v.gender == 'Female', // Default to a common voice
          orElse: () => voices.first,
        );
      });
    } catch (e) {
      debugPrint('Error loading voices: $e');
      // Optionally show an error message to the user
    } finally {
      setState(() {
        _isLoadingVoices = false;
      });
    }
  }

  Future<void> _showVoicePicker() async {
    final selected = await showModalBottomSheet<TtsVoice>(
      context: context,
      backgroundColor: const Color(0xFF2E3192),
      isScrollControlled: true,
      builder: (context) => _VoiceSearchSheet(voices: _availableTtsVoices),
    );
    if (selected != null) {
      setState(() {
        _selectedTtsVoice = selected;
      });
    }
  }

  Future<void> _synthesizeAndPlay() async {
    if (_selectedTtsVoice == null || _textToSpeak.isEmpty) {
      return;
    }

    final stopwatch = Stopwatch()..start();

    setState(() {
      _isSynthesizing = true;
    });

    try {
      final audioBytes = await widget.ttsService.synthesize(
        TtsRequest(
          text: _textToSpeak,
          voice: _selectedTtsVoice!,
          outputFormat: _selectedOutputFormat,
        ),
      );

      await _audioPlayer.stop();
      await _audioPlayer.setAudioSource(
        MyCustomSource(
          _wrapForPlayback(audioBytes, _selectedOutputFormat),
          contentType: _contentTypeFor(_selectedOutputFormat),
        ),
      );

      unawaited(
        _audioPlayer.playerStateStream.firstWhere((state) => state.playing).then((_) {
          stopwatch.stop();
          debugPrint(
            'Button press to audio playback start: ${stopwatch.elapsedMilliseconds}ms '
            '(${_selectedOutputFormat.value})',
          );
        }),
      );

      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Error synthesizing speech: $e');
      // Optionally show an error message to the user
    } finally {
      setState(() {
        _isSynthesizing = false;
      });
    }
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                AzureAppBar(),
                Expanded(
                  child: Column(
                    children: [
                      TextField(
                        controller: _textEditingController,
                        style: const TextStyle(color: Colors.white),
                        textDirection: TextDirection.ltr,
                        maxLines: 5,
                        decoration: InputDecoration(
                          labelText: 'Text to Speak',
                          labelStyle: TextStyle(color: Colors.white.withAlpha(204)),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white.withAlpha(51)),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _isLoadingVoices
                          ? const CircularProgressIndicator()
                          : InkWell(
                              onTap: _availableTtsVoices.isEmpty ? null : _showVoicePicker,
                              borderRadius: BorderRadius.circular(30),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(51),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _selectedTtsVoice == null
                                                ? 'Select a voice'
                                                : '${_selectedTtsVoice!.localName} (${_selectedTtsVoice!.gender})',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (_selectedTtsVoice != null)
                                            Text(
                                              '[${_selectedTtsVoice!.locale}]',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.arrow_drop_down, color: Colors.white),
                                  ],
                                ),
                              ),
                            ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(51),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<AudioOutputFormat>(
                            value: _selectedOutputFormat,
                            dropdownColor: const Color(0xFF2E3192),
                            iconEnabledColor: Colors.white,
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                            items: AudioOutputFormat.values
                                .where((format) => !_formatsToExclude.contains(format))
                                .map(
                                  (format) =>
                                      DropdownMenuItem(value: format, child: Text(format.value)),
                                )
                                .toList(),
                            onChanged: (format) {
                              if (format == null) return;
                              setState(() {
                                _selectedOutputFormat = format;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: FloatingActionButton.large(
                    onPressed: _isSynthesizing ? null : _synthesizeAndPlay,
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blueAccent,
                    child: _isSynthesizing
                        ? const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                          )
                        : const Icon(Icons.volume_up),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet listing [TtsVoice]s, filterable by name or locale.
class _VoiceSearchSheet extends StatefulWidget {
  final List<TtsVoice> voices;

  const _VoiceSearchSheet({required this.voices});

  @override
  State<_VoiceSearchSheet> createState() => _VoiceSearchSheetState();
}

class _VoiceSearchSheetState extends State<_VoiceSearchSheet> {
  late final TextEditingController _searchController;
  late List<TtsVoice> _filteredVoices;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _filteredVoices = widget.voices;
  }

  void _onSearchChanged(String query) {
    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredVoices = widget.voices
          .where(
            (voice) =>
                voice.localName.toLowerCase().contains(lowerQuery) ||
                voice.locale.toLowerCase().contains(lowerQuery),
          )
          .toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search by name or locale',
                  hintStyle: TextStyle(color: Colors.white.withAlpha(153)),
                  prefixIcon: const Icon(Icons.search, color: Colors.white),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white.withAlpha(51)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _filteredVoices.isEmpty
                    ? const Center(
                        child: Text('No voices found', style: TextStyle(color: Colors.white)),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _filteredVoices.length,
                        itemBuilder: (context, index) {
                          final voice = _filteredVoices[index];
                          return ListTile(
                            title: Text(
                              '${voice.localName} (${voice.gender})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '[${voice.locale}]',
                              style: TextStyle(color: Colors.white.withAlpha(204)),
                            ),
                            onTap: () => Navigator.of(context).pop(voice),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// `raw-*` formats are headerless — Azure returns bare samples with no container, unlike
/// `riff-*` (which is the same PCM/mulaw data wrapped in a real RIFF/WAV header). Telling
/// just_audio "this is audio/wav" for headerless bytes fails to decode (macOS: error -11800)
/// since there's no header to parse. Synthesize one client-side so playback works either way;
/// riff/mp3/ogg/webm formats already carry their own container and pass through unchanged.
List<int> _wrapForPlayback(List<int> bytes, AudioOutputFormat format) {
  final params = _rawPcmParamsFor(format);
  if (params == null) return bytes;
  return [..._buildWavHeader(dataLength: bytes.length, params: params), ...bytes];
}

typedef _RawPcmParams = ({int sampleRate, int bitsPerSample, int audioFormatTag});

/// Sample rate / bit depth / WAVE format tag (1 = PCM, 6 = A-law, 7 = mu-law) for each
/// headerless `raw-*` format — `null` for anything else (already containered, or unparseable).
_RawPcmParams? _rawPcmParamsFor(AudioOutputFormat format) {
  switch (format) {
    case AudioOutputFormat.raw8khz8bitMonoMulaw:
      return (sampleRate: 8000, bitsPerSample: 8, audioFormatTag: 7);
    case AudioOutputFormat.raw8khz8bitMonoAlaw:
      return (sampleRate: 8000, bitsPerSample: 8, audioFormatTag: 6);
    case AudioOutputFormat.raw8khz8bitMonoPcm:
      return (sampleRate: 8000, bitsPerSample: 8, audioFormatTag: 1);
    case AudioOutputFormat.raw8khz16bitMonoPcm:
      return (sampleRate: 8000, bitsPerSample: 16, audioFormatTag: 1);
    case AudioOutputFormat.raw16khz16bitMonoPcm:
      return (sampleRate: 16000, bitsPerSample: 16, audioFormatTag: 1);
    case AudioOutputFormat.raw22050hz16bitMonoPcm:
      return (sampleRate: 22050, bitsPerSample: 16, audioFormatTag: 1);
    case AudioOutputFormat.raw24khz16bitMonoPcm:
      return (sampleRate: 24000, bitsPerSample: 16, audioFormatTag: 1);
    case AudioOutputFormat.raw44100hz16bitMonoPcm:
      return (sampleRate: 44100, bitsPerSample: 16, audioFormatTag: 1);
    case AudioOutputFormat.raw48khz16bitMonoPcm:
      return (sampleRate: 48000, bitsPerSample: 16, audioFormatTag: 1);
    default:
      return null;
  }
}

List<int> _buildWavHeader({required int dataLength, required _RawPcmParams params}) {
  const channels = 1;
  final byteRate = params.sampleRate * channels * params.bitsPerSample ~/ 8;
  final blockAlign = channels * params.bitsPerSample ~/ 8;

  final buffer = Uint8List(44);
  final view = ByteData.view(buffer.buffer);

  buffer.setRange(0, 4, 'RIFF'.codeUnits);
  view.setUint32(4, 36 + dataLength, Endian.little);
  buffer.setRange(8, 12, 'WAVE'.codeUnits);
  buffer.setRange(12, 16, 'fmt '.codeUnits);
  view.setUint32(16, 16, Endian.little);
  view.setUint16(20, params.audioFormatTag, Endian.little);
  view.setUint16(22, channels, Endian.little);
  view.setUint32(24, params.sampleRate, Endian.little);
  view.setUint32(28, byteRate, Endian.little);
  view.setUint16(32, blockAlign, Endian.little);
  view.setUint16(34, params.bitsPerSample, Endian.little);
  buffer.setRange(36, 40, 'data'.codeUnits);
  view.setUint32(40, dataLength, Endian.little);

  return buffer;
}

/// The MIME type just_audio needs to decode [format] correctly. By the time this is used the
/// audio has already been through [_wrapForPlayback], so raw/riff formats are both real
/// (WAV-wrapped) PCM/mulaw/alaw. `audio-*-opus` formats are bare Opus packets with no container
/// — most desktop decoders (including just_audio on macOS/Linux) can't play these without one,
/// unlike the ogg/webm-wrapped Opus formats, which are fine.
String _contentTypeFor(AudioOutputFormat format) {
  final value = format.value;
  if (value.contains('mp3')) return 'audio/mpeg';
  if (value.startsWith('raw') || value.startsWith('riff')) return 'audio/wav';
  if (value.startsWith('ogg')) return 'audio/ogg';
  if (value.startsWith('webm')) return 'audio/webm';
  if (value.contains('opus')) return 'audio/opus';
  return 'audio/mpeg';
}

/// Custom AudioSource for just_audio to play in-memory audio bytes.
class MyCustomSource extends StreamAudioSource {
  final List<int> _audioBytes;
  final String _contentType;

  MyCustomSource(this._audioBytes, {required String contentType})
    : _contentType = contentType,
      super(tag: 'MyCustomSource');

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _audioBytes.length;
    return StreamAudioResponse(
      sourceLength: _audioBytes.length,
      contentLength: end - start,
      offset: start,
      contentType: _contentType,
      stream: Stream.value(Uint8List.fromList(_audioBytes.sublist(start, end))),
    );
  }
}
