# 1.0.7

- Fix `AzureSpeechTranslation.dispose()` leaking the WebSocket session 
- Fix example app leaking the previous STT or Translation service when only the other one's language dropdown changed

# 1.0.6

- Added additional audio formats
- Improved example

# 1.0.5

- Reduce Text-to-Speech latency by reusing a single `http.Client` in `AzureTextToSpeech` instead of opening a fresh connection (TCP+TLS handshake) on every `synthesize()`/`listVoices()` call; add `AzureTextToSpeech.dispose()` to close it

# 1.0.4

- Fix `PlatformException` on dispose when the recorder was never started (e.g. when an external audio stream is supplied and the native recorder is never created)
- Fix `Bad state: Cannot emit new states after calling close` by stopping the STT session (closing the WebSocket and cancelling its subscription) before closing the transcription cubit on dispose, and by making `TranscriptionCubit` ignore emits that race past `close()` (websocket messages, the clear-text timer, or the explicit stop-listening call)

# 1.0.3

- Fix Text to speech sample
- Fix Web STT/Translation silence caused by record_web's broken resampler, by downsampling in software

# 1.0.2

- Fix building and running iOS and Android example

# 1.0.1

- Downgraded record library to 6.2.0 as the 7.x has incompatibilities with azure web services

# 1.0.0

- Initial Version of the library
