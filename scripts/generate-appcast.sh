#!/bin/bash
set -euo pipefail

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  echo "Usage: $0 <dmg-path> <version> [output-path]" >&2
  exit 1
fi

DMG_PATH=$1
VERSION=${2#v}
OUTPUT_PATH=${3:-docs/appcast.xml}
SPARKLE_BIN=${SPARKLE_BIN:-build/SourcePackages/artifacts/sparkle/Sparkle/bin}
GENERATE_APPCAST="$SPARKLE_BIN/generate_appcast"

if [ ! -x "$GENERATE_APPCAST" ]; then
  BUILD_DIR=""
  if BUILD_SETTINGS=$(xcodebuild -project Seahorse.xcodeproj -scheme Seahorse -showBuildSettings 2>/dev/null); then
    while IFS= read -r SETTING; do
      case "$SETTING" in
        *"BUILD_DIR = "*)
          BUILD_DIR=${SETTING#*BUILD_DIR = }
          break
          ;;
      esac
    done <<< "$BUILD_SETTINGS"
  fi
  if [ -n "$BUILD_DIR" ]; then
    SPARKLE_BIN="$(dirname "$(dirname "$BUILD_DIR")")/SourcePackages/artifacts/sparkle/Sparkle/bin"
    GENERATE_APPCAST="$SPARKLE_BIN/generate_appcast"
  fi
fi

if [ ! -f "$DMG_PATH" ]; then
  echo "Error: DMG not found: $DMG_PATH" >&2
  exit 1
fi

if [ ! -x "$GENERATE_APPCAST" ]; then
  echo "Error: Sparkle tools not found. Build Seahorse first or set SPARKLE_BIN." >&2
  exit 1
fi

ARCHIVES_DIR=$(mktemp -d)
trap 'rm -rf "$ARCHIVES_DIR"' EXIT

cp "$DMG_PATH" "$ARCHIVES_DIR/"
if [ -s "$OUTPUT_PATH" ]; then
  cp "$OUTPUT_PATH" "$ARCHIVES_DIR/appcast.xml"
fi

"$GENERATE_APPCAST" \
  --account "${SPARKLE_KEY_ACCOUNT:-Seahorse}" \
  --download-url-prefix "https://github.com/SSBun/Seahorse/releases/download/v$VERSION/" \
  --link "https://github.com/SSBun/Seahorse" \
  --maximum-deltas 0 \
  "$ARCHIVES_DIR"

mkdir -p "$(dirname "$OUTPUT_PATH")"
cp "$ARCHIVES_DIR/appcast.xml" "$OUTPUT_PATH"
xmllint --noout "$OUTPUT_PATH"
echo "Updated $OUTPUT_PATH"
