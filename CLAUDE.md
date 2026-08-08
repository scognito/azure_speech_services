# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

`azure_speech_services` is a Flutter package providing real-time Speech-to-Text (STT),
Text-to-Speech (TTS), and real-time Translation via Microsoft Azure Cognitive Services. It talks
directly to Azure's WebSocket/REST APIs — there is no Azure SDK binary dependency. It targets
Mobile (iOS/Android), Desktop (macOS/Windows/Linux), and Web.

The repo is a melos-managed monorepo with two packages: the root package (the library) and
`example/` (a demo app that consumes it via a `path: ../` dependency).

The public entrypoint file is `lib/azure_speech_services.dart`, matching the package name; import
it as `package:azure_speech_services/azure_speech_services.dart`.

## Commands

All commands run through melos scripts defined in `pubspec.yaml` (there is no separate
`melos.yaml`). Run melos commands from the repo root.

```sh
# One-time setup
dart pub global activate melos   # or: make activate-melos
melos bootstrap

# Format
melos run format
melos run check_formatting        # fails if formatting is needed

# Analyze
melos run analyze                 # flutter analyze --fatal-warnings --fatal-infos
melos run dcm_analyze              # dart_code_metrics analyze
melos run dcm                      # dcm: duplication, unused code/files/l10n, deps, params

# Test
melos run test                    # runs flutter test --dart-define=TESTING=true in packages with a test/ dir
melos run test_with_coverage

# Run everything CI-style
melos run check                   # analyze && dcm_analyze && dcm && test
melos run quality_checks          # bootstrap && check_formatting && analyze && test

# Misc
melos run fix                     # dart fix --apply across packages
melos run clean:deep              # flutter clean everywhere
```

To run a single test file directly (bypassing melos):

```sh
flutter test lib/test/azure_stt_flutter_test.dart --dart-define=TESTING=true
```

Git hooks (`prepare-commit-msg`) can be installed via `make install-hooks` or `make` (default
target also activates melos).

## Architecture

The three features (STT, Translation, TTS) follow the same layered pattern; understanding one
means understanding all three.

### Layering (STT as the reference)

```
AzureSpeechToText            (public facade — lib/src/stt/azure_speech_to_text.dart)
  -> AzureSttService          (protocol/session logic — lib/src/stt/azure_stt_service.dart)
       extends AzureSpeechServiceBase   (shared WS session plumbing — lib/src/common/azure_speech_service_base.dart)
  -> TranscriptionCubit        (state emission — lib/src/cubit/)
  -> MicrophoneService         (mic capture — lib/src/services/microphone_service.dart)
```

`AzureSpeechTranslation` / `AzureTranslationService` / `TranslationCubit` mirror this exact
structure under `lib/src/translation/`. TTS is simpler and stateless — `AzureTextToSpeech` in
`lib/src/tts/` makes plain REST calls (`listVoices`, `synthesize`) with no WebSocket/cubit layer.

### `AzureSpeechServiceBase` (lib/src/common/azure_speech_service_base.dart)

Shared base class for the two WebSocket-based services (STT, Translation). Owns:

- **Auth**: exchanges a subscription key for a short-lived token via Azure's `issueToken` REST
  endpoint (non-Web), or passes credentials as query params directly (Web — browsers can't set
  custom WebSocket headers, so `authorizationToken` should always be used on Web).
- **Session lifecycle**: `openSession` (connect + wire up message/error/done handlers),
  `startAudioStream` (pipe mic or an external `Stream<Uint8List>` of raw 16kHz/mono/16-bit PCM
  into the socket), `stopSession`.
- **Azure's custom framing protocol**: text frames are `header: value\r\n...\r\n\r\nbody`; binary
  frames are a 2-byte big-endian header-length prefix + headers + binary payload (see
  `sendWavHeader`, `sendBinaryAudio`, `_serializeBinaryConnectionMessage`,
  `parseTextFrame`). This is a hand-rolled reimplementation of the Speech SDK's WebSocket
  protocol — don't confuse it with plain JSON-over-WebSocket.

### Conditional platform imports for WebSockets

`lib/src/web_socket/` provides three implementations of the same `WebSocketService` abstract
class (`web_socket_service.dart`), selected at compile time via conditional imports:

- `web_socket_service_stub.dart` — default/fallback
- `web_socket_service_mobile.dart` — used when `dart.library.io` is available (mobile/desktop)
- `web_socket_service_web.dart` — used when `dart.library.html` is available (Web)

`azure_speech_service_base.dart` selects between them with the
`if (dart.library.io) ... if (dart.library.html) ...` import pattern. When touching WebSocket
connection logic, check whether the change needs to be made in all three files, and remember that
Web auth must go through query params while mobile/desktop use the `Authorization` header.

### State: cubit pattern (flutter_bloc)

Each streaming feature exposes a `Cubit`/`State` pair (`TranscriptionCubit`/`TranscriptionState`,
`TranslationCubit`/`TranslationState`) rather than raw callbacks. The facade (`AzureSpeechToText`,
`AzureSpeechTranslation`) exposes both a plain `Stream<...>` (`.stream`) for simple consumption and
the underlying `.cubit` for `BlocProvider`/`BlocBuilder` use in Flutter widget trees. Text state
distinguishes `intermediateText` (live hypothesis, no punctuation) from `finalizedText` (confirmed
sentences); a timer (`textClearTimeout`, reset on every new hypothesis/phrase) clears the text
after silence.

### Language Identification (LID)

`SpeechToTextConfig.languages.length` implicitly selects the STT mode sent to Azure — 1 language
skips LID entirely; 2-4 defaults to `languageIdMode: .atStart` (`DetectAtAudioStart`); more (up to
10) requires `.continuous` (`DetectContinuous`). Bare language codes get expanded to full locales
by `lib/src/utils/language_utils.dart` before being sent. This logic lives in
`AzureSttService.startListening` / `_sendSpeechContext` — any change to LID behavior needs to
touch both the config validation and the outgoing `speech.context` payload.

### Config

`AzureSpeechConfig` (lib/src/config/azure_speech_config.dart) is shared across STT, TTS, and
Translation, and enforces exactly one auth method via two named constructors:
`.subscriptionKey(region, key)` or `.authorizationToken(region, token)`. Feature-specific configs
(`SpeechToTextConfig`, `TranslationConfig`, `TtsRequest`) are separate and independent of it.

### Code quality tooling

`analysis_options.yaml` extends `dart_code_metrics_presets` (recommended, metrics, intl, bloc
presets) with project-specific rule overrides (e.g. `prefer-single-widget-per-file: false`,
`avoid-cubits: false`). `dcm` (dart_code_metrics) is run separately from `flutter analyze` via the
melos scripts above and checks unused code/files, duplication, and dependencies — CI-equivalent
local checks are `melos run check`.
