#!/usr/bin/env bash
# Builds BeatGrid for Vercel (or any CI). Vercel's build image has no Flutter,
# so this installs a pinned Flutter SDK first (skipped if `flutter` is on PATH
# and USE_SYSTEM_FLUTTER=1, which is how you test this script locally).
#
# Required environment variables (Vercel > Project > Settings > Environment Variables):
#   SUPABASE_URL        https://<project-ref>.supabase.co
#   SUPABASE_ANON_KEY   the *publishable* key (sb_publishable_...) or legacy anon key
# Optional:
#   FLUTTER_VERSION     default 3.47.6
#   ALLOW_UNCONFIGURED  set to 1 to build without Supabase (auth pages show a notice)
set -euo pipefail

cd "$(dirname "$0")/.."

FLUTTER_VERSION="${FLUTTER_VERSION:-3.47.6}"
SUPABASE_URL="${SUPABASE_URL:-}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"

fail() { echo "error: $*" >&2; exit 1; }

# --- validate configuration --------------------------------------------------
if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_ANON_KEY" ]; then
  if [ "${ALLOW_UNCONFIGURED:-}" = "1" ]; then
    echo "warning: building WITHOUT Supabase settings; accounts will be unavailable."
  else
    fail "SUPABASE_URL and SUPABASE_ANON_KEY must be set (or set ALLOW_UNCONFIGURED=1)."
  fi
else
  case "$SUPABASE_URL" in https://*) ;; *) fail "SUPABASE_URL must start with https://";; esac
  # Refuse privileged keys: anything in the frontend bundle is public.
  case "$SUPABASE_ANON_KEY" in
    sb_secret_*) fail "SUPABASE_ANON_KEY is a secret key. Use the publishable key." ;;
  esac
  case "$SUPABASE_ANON_KEY" in
    eyJ*)
      payload="$(echo "$SUPABASE_ANON_KEY" | cut -d. -f2 | tr '_-' '/+')"
      # base64 needs padding
      while [ $(( ${#payload} % 4 )) -ne 0 ]; do payload="${payload}="; done
      if echo "$payload" | base64 -d 2>/dev/null | grep -q '"role":"service_role"'; then
        fail "SUPABASE_ANON_KEY is a service_role key. Use the anon/publishable key."
      fi
      ;;
  esac
fi

# --- Flutter SDK -------------------------------------------------------------
if [ "${USE_SYSTEM_FLUTTER:-}" = "1" ] && command -v flutter >/dev/null 2>&1; then
  echo "Using Flutter from PATH: $(command -v flutter)"
else
  SDK_DIR="${FLUTTER_SDK_DIR:-$HOME/.flutter-sdk-$FLUTTER_VERSION}"
  if [ ! -x "$SDK_DIR/bin/flutter" ]; then
    echo "Installing Flutter $FLUTTER_VERSION into $SDK_DIR"
    git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$SDK_DIR"
  fi
  # Vercel builds run as root in a container; git otherwise refuses the SDK checkout.
  git config --global --add safe.directory "$SDK_DIR" || true
  export PATH="$SDK_DIR/bin:$PATH"
fi

export MSYS_NO_PATHCONV=1   # Git Bash on Windows would otherwise rewrite "/" in --base-href
export CI=true
export FLUTTER_SUPPRESS_ANALYTICS=true
flutter config --no-analytics >/dev/null 2>&1 || true
flutter --version
flutter config --enable-web >/dev/null
flutter pub get

# --- build -------------------------------------------------------------------
# --csp                      no runtime code generation, so the CSP needs no 'unsafe-eval'
# --no-web-resources-cdn     serve CanvasKit from our own origin (no gstatic.com dependency)
# --base-href /              app is served from the domain root
defines=()
if [ -n "$SUPABASE_URL" ]; then
  defines+=("--dart-define=SUPABASE_URL=$SUPABASE_URL" "--dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY")
fi

flutter build web --release --csp --no-web-resources-cdn --no-wasm-dry-run \
  --base-href / ${defines[@]+"${defines[@]}"}

test -f build/web/index.html || fail "build/web/index.html missing after build"
echo "Build complete: build/web"
