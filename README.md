# BeatGrid

Browser-based beat-making studio and creator community, built with Flutter Web,
Tone.js (audio engine) and Supabase (backend, from Phase 3).

**Status:** Phase 1 (audio-engine technical spike) is complete. See
[docs/ROADMAP.md](docs/ROADMAP.md) for what exists and what is next.

## Requirements

- Flutter 3.47+ (Dart 3.13+) with web support
- Chrome, Edge, Firefox or Safari (desktop) for audio verification
- Node.js is only needed if you want to serve a release build locally with `npx http-server`

## Run

```bash
flutter pub get
flutter run -d chrome
```

Press **Start audio engine** first: browsers only allow audio after a user gesture.

## Check

```bash
flutter analyze
flutter test
flutter build web --release
```

## Layout

- `lib/features/studio/models/beat_pattern.dart` - versioned, validated pattern model
- `lib/features/studio/audio/` - Dart-side audio bridge (`AudioEngine`); the only code that touches JavaScript
- `web/audio/beatgrid_audio_engine.js` - the Tone.js engine that owns scheduling and sound
- `web/audio/tone.min.js` - vendored Tone.js 15.1.22 (MIT)

Audio design and the Dart/JS contract: [docs/AUDIO_ENGINE.md](docs/AUDIO_ENGINE.md).
