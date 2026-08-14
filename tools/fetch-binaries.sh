#!/usr/bin/env bash
#
# Downloads the runtime binaries (yt-dlp + ffmpeg) bundled into the app.
# Binaries are staged into build/bin/ and injected into the app bundle
# by the release workflow.
#
# Usage:
#   tools/fetch-binaries.sh            # detect local OS
#   tools/fetch-binaries.sh macos      # force macOS binaries
#   tools/fetch-binaries.sh windows    # force Windows binaries

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/build/bin"
mkdir -p "$OUT"

OS="${1:-}"
if [[ -z "$OS" ]]; then
  case "$(uname -s)" in
    Darwin) OS="macos" ;;
    MINGW* | MSYS* | CYGWIN*) OS="windows" ;;
    *) OS="linux" ;;
  esac
fi

download() {
  echo "  -> $2"
  curl -fSL --retry 3 -o "$2" "$1"
}

case "$OS" in
  macos)
    echo "Fetching yt-dlp (macOS universal binary)..."
    download \
      "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos" \
      "$OUT/yt-dlp"
    chmod +x "$OUT/yt-dlp"

    echo "Fetching ffmpeg (macOS static build)..."
    TMP="$OUT/ffmpeg.zip"
    download "https://evermeet.cx/ffmpeg/getrelease/zip" "$TMP"
    unzip -jo "$TMP" -d "$OUT" "ffmpeg" 1>/dev/null
    rm -f "$TMP"
    chmod +x "$OUT/ffmpeg"
    ;;
  windows)
    echo "Fetching yt-dlp.exe..."
    download \
      "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe" \
      "$OUT/yt-dlp.exe"

    echo "Fetching ffmpeg.exe (Windows essentials build)..."
    TMP="$OUT/ffmpeg.zip"
    download "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip" "$TMP"
    UNZIP_DIR="$OUT/ffmpeg_extract"
    rm -rf "$UNZIP_DIR"
    mkdir -p "$UNZIP_DIR"
    unzip -q "$TMP" -d "$UNZIP_DIR"
    FFMPEG_BIN="$(find "$UNZIP_DIR" -type f -name ffmpeg.exe | head -n 1)"
    if [[ -z "$FFMPEG_BIN" ]]; then
      echo "ERROR: ffmpeg.exe not found inside the archive" >&2
      exit 1
    fi
    cp "$FFMPEG_BIN" "$OUT/ffmpeg.exe"
    rm -rf "$UNZIP_DIR" "$TMP"
    ;;
  linux)
    echo "Fetching yt-dlp (linux)..."
    download \
      "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux" \
      "$OUT/yt-dlp"
    chmod +x "$OUT/yt-dlp"
    echo "WARNING: no static ffmpeg source configured for linux; skip ffmpeg."
    ;;
  *)
    echo "ERROR: unknown OS '$OS' (expected 'macos' or 'windows')" >&2
    exit 1
    ;;
esac

ls -lh "$OUT"
echo "Done. Binaries staged in $OUT"
