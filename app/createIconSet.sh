#!/usr/bin/env bash
set -euo pipefail

# Create .icns from a source PNG.
# Usage: ./createIconSet.sh [path/to/source.png]
# Default source: ./assets/appicon.png (relative to this script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_PNG="${1:-$SCRIPT_DIR/assets/appicon.png}"

# Output .icns inside build app bundle Resources
OUT_ICNS_DIR="$(cd "$SCRIPT_DIR/.."/build 2>/dev/null || true; pwd -P)"
# fallback if build path not present, use repo/build
OUT_ICNS_DIR="$SCRIPT_DIR/../build/app/MacCleanerApp.app/Contents/Resources"
OUT_ICNS="$(cd "$OUT_ICNS_DIR" 2>/dev/null || true; echo "$OUT_ICNS_DIR/MacCleanerApp.icns")"

if [ ! -f "$SRC_PNG" ]; then
  echo "ERROR: icon source not found: $SRC_PNG"
  echo "Place a PNG (e.g. 1024x1024) at $SCRIPT_DIR/assets/appicon.png or pass path as first arg."
  exit 1
fi

# Ensure output directory exists
OUT_DIR="$(dirname "$OUT_ICNS")"
mkdir -p "$OUT_DIR"

# create temp iconset dir
TMP_DIR="$(mktemp -d)"
TMP_ICONSET="$TMP_DIR/MacCleanerApp.iconset"
mkdir -p "$TMP_ICONSET"

cleanup() {
  if [ "${KEEP_TMP:-0}" -eq 0 ]; then
    rm -rf "$TMP_DIR"
  else
    echo "Temporary iconset kept for inspection: $TMP_ICONSET"
  fi
}
trap cleanup EXIT

# helper to generate and verify a size
gen() {
  local size_px=$1
  local out_name=$2
  sips -z "$size_px" "$size_px" "$SRC_PNG" --out "$TMP_ICONSET/$out_name" >/dev/null 2>&1 || true
  if [ ! -f "$TMP_ICONSET/$out_name" ]; then
    echo "Failed to create $out_name (size ${size_px}x${size_px})"
    KEEP_TMP=1
    ls -la "$TMP_ICONSET" || true
    exit 1
  fi
}

# generate required iconset files (Apple iconutil expected names)
gen 16  icon_16x16.png
gen 32  icon_16x16@2x.png
gen 32  icon_32x32.png
gen 64  icon_32x32@2x.png
gen 128 icon_128x128.png
gen 256 icon_128x128@2x.png
gen 256 icon_256x256.png
gen 512 icon_256x256@2x.png
gen 512 icon_512x512.png
gen 1024 icon_512x512@2x.png

# ensure output directory exists (again)
mkdir -p "$OUT_DIR"

# run iconutil and capture output
ICONUTIL_OUT="$(mktemp)"
if command -v iconutil >/dev/null 2>&1 && iconutil -c icns -o "$OUT_ICNS" "$TMP_ICONSET" >"$ICONUTIL_OUT" 2>&1; then
  echo "Created icns: $OUT_ICNS"
  KEEP_TMP=0
  rm -f "$ICONUTIL_OUT"
  exit 0
else
  echo "iconutil failed. Output:"
  if [ -f "$ICONUTIL_OUT" ]; then cat "$ICONUTIL_OUT"; fi
  echo "Contents of temporary iconset ($TMP_ICONSET):"
  ls -la "$TMP_ICONSET"
  echo "Leaving temporary files for inspection: $TMP_ICONSET"
  KEEP_TMP=1
  exit 1
fi