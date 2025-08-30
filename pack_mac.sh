#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$ROOT/build"
APP_NAME="MacCleanerApp"
APP_DIR="$BUILD_DIR/app"
APP_BUNDLE="$APP_DIR/${APP_NAME}.app"
EXECUTABLE="$APP_DIR/${APP_NAME}"
INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"

echo "Cleaning build dir..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "CMake configure & build (Release)..."
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build . --config Release -- -j

if [ ! -f "$EXECUTABLE" ]; then
  echo "Executable not found at $EXECUTABLE"
  exit 1
fi

echo "Creating .app bundle..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

cat > "$INFO_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>io.YourCompany.$APP_NAME</string>
    <key>CFBundleVersion</key><string>1.0</string>
    <key>CFBundlePackageType</key><string>APPL</string>
  </dict>
</plist>
EOF

echo "Locating macdeployqt..."
MACDEPLOYQT="$(which macdeployqt 2>/dev/null || true)"
if [ -z "$MACDEPLOYQT" ] && [ -x "/opt/homebrew/opt/qt/bin/macdeployqt" ]; then
  MACDEPLOYQT="/opt/homebrew/opt/qt/bin/macdeployqt"
fi

if [ -z "$MACDEPLOYQT" ]; then
  echo "macdeployqt not found. Install Qt (Homebrew: brew install qt) or add macdeployqt to PATH."
  echo "Partial .app bundle created at: $APP_BUNDLE (not bundled)."
  exit 1
fi

echo "Running macdeployqt (will also create dmg with -dmg)..."
"$MACDEPLOYQT" "$APP_BUNDLE" -dmg

echo "Looking for created dmg..."
DMG_PATH="$(ls -1t "$APP_DIR"/*.dmg 2>/dev/null | head -n1 || true)"
if [ -n "$DMG_PATH" ]; then
  echo "Created dmg: $DMG_PATH"
else
  echo "macdeployqt finished but no .dmg found in $APP_DIR"
fi

echo "Done."