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
  curl -fSL --retry 5 --retry-delay 5 --retry-all-errors -o "$2" "$1"
}

unzip_single() {
  # Extract a single member from a (possibly mirrored) zip archive, verifying
  # the archive is complete first to catch truncated downloads.
  local archive="$1" member="$2" dest="$3"
  if ! unzip -t "$archive" 1>/dev/null 2>&1; then
    echo "ERROR: $archive is corrupt (truncated download?)" >&2
    exit 1
  fi
  unzip -jo "$archive" -d "$dest" "$member" 1>/dev/null
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
    unzip_single "$TMP" "ffmpeg" "$OUT"
    rm -f "$TMP"
    chmod +x "$OUT/ffmpeg"

    echo "Fetching ffprobe (macOS static build)..."
    TMP="$OUT/ffprobe.zip"
    download "https://evermeet.cx/ffmpeg/getrelease/ffprobe/zip" "$TMP"
    unzip_single "$TMP" "ffprobe" "$OUT"
    rm -f "$TMP"
    chmod +x "$OUT/ffprobe"
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
    FFPROBE_BIN="$(find "$UNZIP_DIR" -type f -name ffprobe.exe | head -n 1)"
    if [[ -z "$FFPROBE_BIN" ]]; then
      echo "ERROR: ffprobe.exe not found inside the archive" >&2
      exit 1
    fi
    cp "$FFPROBE_BIN" "$OUT/ffprobe.exe"
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
