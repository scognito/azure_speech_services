# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

This is the demo app for the `azure_speech_services` package (see `../CLAUDE.md` for the
package's own architecture and the melos commands that operate on the whole monorepo). It depends
on the package via `path: ../` and exercises all three features — Speech-to-Text, Text-to-Speech,
and Translation — as three tabs in a single `BottomNavigationBar` (`lib/main.dart`).

## Setup

The app reads Azure credentials from a `.env` file at the root of this directory (loaded via
`flutter_dotenv` in `lib/main.dart`, declared as a Flutter asset in `pubspec.yaml`). It must define:

```
AZURE_REGION=...
AZURE_SUBSCRIPTION_KEY=...
```

There is no `.env.example` checked in — `.env` already exists locally but is untracked; do not
print or commit its contents.

## Running

Run as a normal Flutter app from this directory (`flutter run`), or via melos from the repo root.
This package has its own `test/` directory, so `melos run test` (from the repo root) includes it —
but `test/widget_test.dart` is still the unmodified Flutter counter-app template and does not test
this app; treat it as a placeholder rather than real coverage when reasoning about test gaps here.

## Structure

- `lib/main.dart` — app entry point and `_AzureSpeechToTextExampleState`, which owns the three
  service instances (`AzureSpeechToText`, `AzureTextToSpeech`, `AzureSpeechTranslation`) and
  recreates the STT/Translation services whenever their language selection changes
  (`_initAzureServices`, called from `_onLanguageChanged` / `_onTranslationFromChanged` /
  `_onTranslationToChanged`). Services are constructed with `debug: true`.
- `lib/stt_screen.dart` — STT tab. `BlocBuilder<TranscriptionCubit, TranscriptionState>` driving a
  language dropdown (single language, `.atStart` LID over 4 languages picked via the `autodetect`
  pseudo-option, or `.continuous` LID over 10 languages picked via the `continuous` pseudo-option)
  and a start/stop mic FAB.
- `lib/translation_screen.dart` — Translation tab. `BlocBuilder<TranslationCubit,
  TranslationState>` driving from/to language dropdowns and a source/translated text card pair;
  translated-text lookup falls back from exact locale to base language to "first available"
  (`_TranslationCards`).
- `lib/tts_screen.dart` — TTS tab. Loads the voice catalog via `listVoices()` on init, lets the
  user search/pick a `TtsVoice` and an `AudioOutputFormat`, then `synthesize()`s and plays back
  through `just_audio`. `_formatsToExclude` filters out formats that are not viable for local
  playback here. Playback needs two format-specific workarounds, both documented in-file:
  - `raw-*` formats are headerless PCM/A-law/mu-law — `_wrapForPlayback`/`_buildWavHeader`
    synthesize a WAV header client-side so `just_audio` can decode them (`riff-*` formats already
    have one).
  - `_contentTypeFor` maps format to MIME type for `just_audio`; bare-Opus `audio-*-opus` formats
    have no container and are excluded above because most desktop decoders can't play them,
    unlike the ogg/webm-wrapped Opus variants.
- `lib/widgets/azure_app_bar.dart` — shared header widget used by all three screens.
