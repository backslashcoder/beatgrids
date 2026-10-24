# BeatGrid

Browser-based beat-making studio and creator community, built with Flutter Web,
Tone.js (audio engine) and Supabase (backend, from Phase 3).

**Status:** Phases 1-3 are built (audio spike, design system/shell, Supabase auth and database). The Supabase migrations still need to be applied to your project (see below). See
[docs/ROADMAP.md](docs/ROADMAP.md) for what exists and what is next.

## Requirements

- Flutter 3.47+ (Dart 3.13+) with web support
- Chrome, Edge, Firefox or Safari (desktop) for audio verification
- Node.js is only needed if you want to serve a release build locally with `npx http-server`

## Configure Supabase

1. Copy `config/dart_defines.example.json` to `config/dart_defines.local.json` (git-ignored) and fill in the project URL and **publishable** key (Project Settings > API). Never use the secret/service-role key.
2. Apply the schema once: `node supabase/bundle.mjs`, paste `supabase/apply_all.sql` into the Supabase dashboard SQL editor and run it. (Or `supabase link` + `supabase db push`.)
3. Authentication > URL Configuration: set Site URL to your deployed origin and add `http://localhost:*/**` as a redirect URL so confirmation and password-reset links return to the app.

Without step 1 the app still runs (studio, home) and the auth pages say accounts are unavailable.

## Run

```bash
flutter pub get
flutter run -d chrome --dart-define-from-file=config/dart_defines.local.json
```

Press **Start audio engine** first: browsers only allow audio after a user gesture.

## Check

```bash
flutter analyze
flutter test
flutter build web --release --dart-define-from-file=config/dart_defines.local.json
cd supabase/tests && npm install && npm test   # database/RLS tests, no Docker needed
```

## Deploy

Vercel + Supabase setup is in [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) (`vercel.json`, `scripts/vercel_build.sh`).

## Layout

- `lib/features/studio/models/beat_pattern.dart` - versioned, validated pattern model
- `lib/features/studio/audio/` - Dart-side audio bridge (`AudioEngine`); the only code that touches JavaScript
- `web/audio/beatgrid_audio_engine.js` - the Tone.js engine that owns scheduling and sound
- `web/audio/tone.min.js` - vendored Tone.js 15.1.22 (MIT)

Audio design and the Dart/JS contract: [docs/AUDIO_ENGINE.md](docs/AUDIO_ENGINE.md).
