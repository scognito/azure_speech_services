// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:typed_data';

import 'package:azure_speech_services/azure_speech_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:just_audio/just_audio.dart';

import 'widgets/azure_app_bar.dart';

class TtsScreen extends StatefulWidget {
  final AzureTextToSpeech ttsService;
  final AzureTtsWebSocketService ttsWebSocketService;
  final AudioPlayer audioPlayer;

  const TtsScreen({
    required this.ttsService,
    required this.ttsWebSocketService,
    required this.audioPlayer,
  });

  @override
  State<TtsScreen> createState() => _TtsScreenState();
}

class _TtsScreenState extends State<TtsScreen> {
  late TextEditingController _textEditingController;
  String _textToSpeak = 'Hello, this is a test of Azure Text-to-Speech.';
  TtsVoice? _selectedTtsVoice;
  List<TtsVoice> _availableTtsVoices = [];

  AudioPlayer get _audioPlayer => widget.audioPlayer;
  bool _isLoadingVoices = false;
  bool _isSynthesizing = false;
  bool _isSynthesizingWs = false;

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
          (v) =>
              v.locale == 'en-US' &&
              v.gender == 'Female', // Default to a common voice
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
          // Same westeurope wideband-vocoder slowdown affects REST too — it's an Azure-backend
          // issue independent of transport. See the outputFormat comment on the WebSocket
          // button below for the full explanation.
          outputFormat: AudioOutputFormat.riff8khz16bitMonoPcm,
        ),
      );

      await _audioPlayer.stop();
      await _audioPlayer.setAudioSource(MyCustomSource(audioBytes));

      unawaited(
        _audioPlayer.playerStateStream.firstWhere((state) => state.playing).then((
          _,
        ) {
          stopwatch.stop();
          debugPrint(
            'Button press to audio playback start: ${stopwatch.elapsedMilliseconds}ms',
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

  /// Same phrase as [_synthesizeAndPlay], but via [AzureTtsWebSocketService] and a
  /// `flutter_soloud` buffer stream — audio starts playing on the first chunk instead of
  /// waiting for the whole response, which is the latency comparison this button exists for.
  Future<void> _synthesizeAndPlayWebSocket() async {
    if (_selectedTtsVoice == null || _textToSpeak.isEmpty) {
      return;
    }

    final stopwatch = Stopwatch()..start();

    setState(() {
      _isSynthesizingWs = true;
    });

    final source = SoLoud.instance.setBufferStream(
      maxBufferSizeBytes: 1024 * 1024 * 10,
      bufferingType: BufferingType.released,
      // Defaults to 2 seconds of buffered audio before un-pausing, which defeats the point of
      // streaming for a short phrase — start on (nearly) the first chunk instead.
      bufferingTimeNeeds: 0.05,
      format: BufferType.auto,
    );

    try {
      SoLoud.instance.play(source);

      var firstChunk = true;
      await for (final chunk in widget.ttsWebSocketService.synthesizeStream(
        TtsRequest(
          text: _textToSpeak,
          voice: _selectedTtsVoice!,
          // Wideband formats (16kHz+) hit a confirmed, Azure-side "wideband-vocoder slowdown"
          // in westeurope (reproduced with the official JS SDK too, see the parallel JS
          // diagnostic at /Users/piero/Desktop/tmp/js). riff-8khz-16bit-mono-pcm — narrowband,
          // but still 16-bit — avoids it while staying reasonably listenable.
          outputFormat: AudioOutputFormat.riff8khz16bitMonoPcm,
        ),
      )) {
        if (firstChunk) {
          firstChunk = false;
          stopwatch.stop();
          debugPrint(
            'Button press to first audio chunk (WebSocket): ${stopwatch.elapsedMilliseconds}ms',
          );
        }
        SoLoud.instance.addAudioDataStream(source, chunk);
      }
      SoLoud.instance.setDataIsEnded(source);

      await source.allInstancesFinished.first;
    } catch (e) {
      debugPrint('Error synthesizing speech (WebSocket): $e');
    } finally {
      setState(() {
        _isSynthesizingWs = false;
      });
    }
  }

  /// Diagnostic only: runs the same phrase twice, keeping the WebSocket connection open between
  /// the two turns (`closeAfterTurn: false` on the first), to check whether Azure's synthesis
  /// delay is a per-connection warm-up cost (turn B would be fast) or a fixed per-request cost
  /// (turn B stalls the same as turn A). Doesn't play audio — just drains both streams so the
  /// plugin's own `[tts-ws] +Nms <<< ...` debug logs show the timing for each turn.
  Future<void> _testConnectionReuse() async {
    if (_selectedTtsVoice == null) return;

    setState(() {
      _isSynthesizingWs = true;
    });

    const phrase = 'Hello, this is a test of Azure Text-to-Speech.';
    // Confirmed narrowband format that avoids the westeurope wideband-vocoder slowdown — see
    // the outputFormat comment in _synthesizeAndPlayWebSocket for the full explanation.
    const format = AudioOutputFormat.riff8khz16bitMonoPcm;
    try {
      debugPrint('--- turn A (opens connection, $format) ---');
      await for (final _ in widget.ttsWebSocketService.synthesizeStream(
        TtsRequest(text: phrase, voice: _selectedTtsVoice!, outputFormat: format),
        closeAfterTurn: false,
      )) {}

      debugPrint('--- turn B (reused connection, $format) ---');
      await for (final _ in widget.ttsWebSocketService.synthesizeStream(
        TtsRequest(text: phrase, voice: _selectedTtsVoice!, outputFormat: format),
      )) {}
    } catch (e) {
      debugPrint('Error testing connection reuse: $e');
    } finally {
      setState(() {
        _isSynthesizingWs = false;
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
                          labelStyle: TextStyle(
                            color: Colors.white.withAlpha(204),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.white.withAlpha(51),
                            ),
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
                              onTap: _availableTtsVoices.isEmpty
                                  ? null
                                  : _showVoicePicker,
                              borderRadius: BorderRadius.circular(30),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                    const Icon(
                                      Icons.arrow_drop_down,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FloatingActionButton(
                            heroTag: 'rest',
                            onPressed: _isSynthesizing ? null : _synthesizeAndPlay,
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.blueAccent,
                            child: _isSynthesizing
                                ? const CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.blueAccent,
                                    ),
                                  )
                                : const Icon(Icons.volume_up),
                          ),
                          const SizedBox(height: 4),
                          const Text('REST', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                      const SizedBox(width: 24),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FloatingActionButton(
                            heroTag: 'websocket',
                            onPressed: _isSynthesizingWs ? null : _synthesizeAndPlayWebSocket,
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.deepPurple,
                            child: _isSynthesizingWs
                                ? const CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.deepPurple,
                                    ),
                                  )
                                : const Icon(Icons.stream),
                          ),
                          const SizedBox(height: 4),
                          const Text('WebSocket', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                      const SizedBox(width: 24),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FloatingActionButton(
                            heroTag: 'reuse-test',
                            onPressed: _isSynthesizingWs ? null : _testConnectionReuse,
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.teal,
                            child: const Icon(Icons.link),
                          ),
                          const SizedBox(height: 4),
                          const Text('Reuse Test', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ],
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
                        child: Text(
                          'No voices found',
                          style: TextStyle(color: Colors.white),
                        ),
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
                              style: TextStyle(
                                color: Colors.white.withAlpha(204),
                              ),
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

/// Custom AudioSource for just_audio to play in-memory audio bytes.
class MyCustomSource extends StreamAudioSource {
  final List<int> _audioBytes;

  MyCustomSource(this._audioBytes) : super(tag: 'MyCustomSource');

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _audioBytes.length;
    return StreamAudioResponse(
      sourceLength: _audioBytes.length,
      contentLength: end - start,
      offset: start,
      // Matches the riff8khz16bitMonoPcm outputFormat used by _synthesizeAndPlay — update if
      // the example ever changes which AudioOutputFormat it requests.
      contentType: 'audio/wav',
      stream: Stream.value(Uint8List.fromList(_audioBytes.sublist(start, end))),
    );
  }
}
