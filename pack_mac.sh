#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$ROOT/build"
APP_NAME="MacCleanerApp"
APP_DIR="$BUILD_DIR/app"
APP_BUNDLE="$APP_DIR/${APP_NAME}.app"
EXECUTABLE="$APP_DIR/${APP_NAME}"
BIN_IN_BUNDLE="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
REAL_BIN="$APP_BUNDLE/Contents/MacOS/${APP_NAME}.real"
INFO_PLIST_SRC="$ROOT/info.plist"
INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
QML_SRC_DIR="$ROOT/app"
QML_DST_DIR="$APP_BUNDLE/Contents/Resources/qml"
ICNS_REPO_CANDIDATES=("$ROOT/app/${APP_NAME}.icns" "$ROOT/app/icon.icns" "$ROOT/icon.icns" "$ROOT/resources/${APP_NAME}.icns")
DMG_OUTPUT="$APP_DIR/${APP_NAME}.dmg"
STAGING_DIR="$BUILD_DIR/dmg_staging"
DMG_BG_CANDIDATES=("$ROOT/assets/dmg_background.png" "$ROOT/app/dmg_background.png" "$ROOT/resources/dmg_background.png")

echo "Packaging: ROOT=$ROOT BUILD_DIR=$BUILD_DIR"

# Preserve any existing icns created in previous build to avoid deletion by rm -rf build
PRESERVED_ICON_DIR=""
if [ -f "$BUILD_DIR/app/${APP_NAME}.app/Contents/Resources/${APP_NAME}.icns" ]; then
  PRESERVED_ICON_DIR="$(mktemp -d)"
  cp "$BUILD_DIR/app/${APP_NAME}.app/Contents/Resources/${APP_NAME}.icns" "$PRESERVED_ICON_DIR/" || true
  echo "Preserved existing icns at $PRESERVED_ICON_DIR"
fi

# Build
echo "Building (Release)..."
# Clean build but preserve saved icon
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build . --config Release -- -j

if [ ! -f "$EXECUTABLE" ]; then
  echo "ERROR: Executable not found at $EXECUTABLE"
  exit 1
fi

# Create .app bundle skeleton
echo "Creating .app bundle at $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp "$EXECUTABLE" "$BIN_IN_BUNDLE"
chmod +x "$BIN_IN_BUNDLE"

# Copy Info.plist (repo) or write minimal
if [ -f "$INFO_PLIST_SRC" ]; then
  cp "$INFO_PLIST_SRC" "$INFO_PLIST"
  echo "Copied Info.plist from repo"
else
  cat > "$INFO_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>CFBundleName</key><string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key><string>MacCleaner</string>
    <key>CFBundleIdentifier</key><string>io.YourCompany.${APP_NAME}</string>
    <key>CFBundleExecutable</key><string>${APP_NAME}</string>
    <key>CFBundleVersion</key><string>1.0</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSHighResolutionCapable</key><true/>
  </dict>
</plist>
EOF
  echo "Wrote minimal Info.plist"
fi

# Restore preserved icns (if any), else try repo candidates
if [ -n "$PRESERVED_ICON_DIR" ] && [ -f "$PRESERVED_ICON_DIR/${APP_NAME}.icns" ]; then
  cp "$PRESERVED_ICON_DIR/${APP_NAME}.icns" "$APP_BUNDLE/Contents/Resources/${APP_NAME}.icns"
  echo "Restored preserved icns into bundle"
else
  for ic in "${ICNS_REPO_CANDIDATES[@]}"; do
    if [ -f "$ic" ]; then
      cp "$ic" "$APP_BUNDLE/Contents/Resources/${APP_NAME}.icns"
      echo "Copied icns from repo: $ic"
      break
    fi
  done
fi

# If icon present, ensure Info.plist references it
if [ -f "$APP_BUNDLE/Contents/Resources/${APP_NAME}.icns" ]; then
  /usr/libexec/PlistBuddy -c "Delete :CFBundleIconFile" "$INFO_PLIST" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string ${APP_NAME}.icns" "$INFO_PLIST" 2>/dev/null || true
  echo "Info.plist updated with CFBundleIconFile"
fi

# Ensure QML copied
if [ -d "$QML_SRC_DIR" ]; then
  mkdir -p "$QML_DST_DIR"
  cp -R "$QML_SRC_DIR"/* "$QML_DST_DIR"/ || true
  echo "Copied QML to bundle Resources ($QML_DST_DIR)"
fi

# Locate macdeployqt (prefer Homebrew/official Qt)
MACDEPLOYQT=""
if [ -x "/opt/homebrew/opt/qt/bin/macdeployqt" ]; then
  MACDEPLOYQT="/opt/homebrew/opt/qt/bin/macdeployqt"
elif [ -x "/usr/local/opt/qt/bin/macdeployqt" ]; then
  MACDEPLOYQT="/usr/local/opt/qt/bin/macdeployqt"
else
  QMAKE="$(which qmake 2>/dev/null || true)"
  if [ -n "$QMAKE" ]; then
    BIN_DIR="$("$QMAKE" -query QT_INSTALL_BINS 2>/dev/null || true)"
    if [ -n "$BIN_DIR" ] && [ -x "$BIN_DIR/macdeployqt" ]; then
      MACDEPLOYQT="$BIN_DIR/macdeployqt"
    fi
  fi
  if [ -z "$MACDEPLOYQT" ]; then
    MACDEPLOYQT="$(which macdeployqt 2>/dev/null || true)"
    if [[ "$MACDEPLOYQT" == *anaconda* || "$MACDEPLOYQT" == *conda* ]]; then
      echo "WARNING: macdeployqt from conda detected ($MACDEPLOYQT). Prefer Qt build's macdeployqt."
    fi
  fi
fi

if [ -z "$MACDEPLOYQT" ]; then
  echo "ERROR: macdeployqt not found. Install Qt (brew install qt) and retry."
  exit 1
fi
echo "macdeployqt: $MACDEPLOYQT"

# Decide whether to pass -qmldir: only pass when directory exists and contains QML files
PASS_QMLDIR=0
if [ -d "$QML_DST_DIR" ]; then
  if find "$QML_DST_DIR" -type f \( -iname '*.qml' -o -iname '*.js' -o -iname 'qmldir' -o -iname '*.qmltypes' \) -print -quit | grep -q .; then
    PASS_QMLDIR=1
  else
    echo "QML dir exists but contains no .qml/.js/qmldir files; skipping -qmldir to avoid macdeployqt error."
  fi
fi

# Run macdeployqt capturing output; treat failure as fatal
MD_OUT="$(mktemp)"
set +e
if [ "$PASS_QMLDIR" -eq 1 ]; then
  echo "Running: $MACDEPLOYQT \"$APP_BUNDLE\" -qmldir \"$QML_DST_DIR\" -verbose=2"
  "$MACDEPLOYQT" "$APP_BUNDLE" -qmldir "$QML_DST_DIR" -verbose=2 >"$MD_OUT" 2>&1
  MD_EXIT=$?
else
  echo "Running: $MACDEPLOYQT \"$APP_BUNDLE\" -verbose=2"
  "$MACDEPLOYQT" "$APP_BUNDLE" -verbose=2 >"$MD_OUT" 2>&1
  MD_EXIT=$?
fi
set -e

if [ "$MD_EXIT" -ne 0 ]; then
  echo "macdeployqt failed (exit $MD_EXIT). Log:"
  sed -n '1,200p' "$MD_OUT" || true
  echo "Full log saved to: $MD_OUT"
  echo "Aborting packaging because bundle is incomplete."
  exit 1
else
  echo "macdeployqt succeeded. (truncated output):"
  sed -n '1,120p' "$MD_OUT" || true
  rm -f "$MD_OUT"
fi

# Post-deploy checks (should exist now)
echo "Post-deploy summary:"
if [ -d "$APP_BUNDLE/Contents/Frameworks" ]; then
  ls -la "$APP_BUNDLE/Contents/Frameworks" || true
else
  echo "No Frameworks directory found in bundle"
fi
if [ -d "$APP_BUNDLE/Contents/PlugIns" ]; then
  ls -la "$APP_BUNDLE/Contents/PlugIns" || true
else
  echo "No PlugIns directory found in bundle"
fi
if [ -f "$APP_BUNDLE/Contents/PlugIns/platforms/libqcocoa.dylib" ]; then
  echo "Platform plugin OK"
else
  echo "WARNING: libqcocoa missing"
fi

# Create launcher wrapper (move real binary and use wrapper to prefer bundled Qt)
if [ ! -f "$REAL_BIN" ]; then
  mv "$BIN_IN_BUNDLE" "$REAL_BIN"
  cat > "$BIN_IN_BUNDLE" <<'SH'
#!/usr/bin/env bash
DIR="$(cd "$(dirname "$0")" && pwd)"
APP_CONTENTS="$(cd "$DIR/.." && pwd)"
FRAMEWORKS="$APP_CONTENTS/Frameworks"
PLUGINS="$APP_CONTENTS/PlugIns"
if [ -d "$FRAMEWORKS" ]; then
  export DYLD_FRAMEWORK_PATH="$FRAMEWORKS${DYLD_FRAMEWORK_PATH:+:}$DYLD_FRAMEWORK_PATH"
  export DYLD_LIBRARY_PATH="$FRAMEWORKS${DYLD_LIBRARY_PATH:+:}$DYLD_LIBRARY_PATH"
fi
if [ -d "$PLUGINS" ]; then
  export QT_PLUGIN_PATH="$PLUGINS${QT_PLUGIN_PATH:+:}$QT_PLUGIN_PATH"
fi
export QML2_IMPORT_PATH="$APP_CONTENTS/Resources/qml${QML2_IMPORT_PATH:+:}$QML2_IMPORT_PATH"
exec "$DIR/$(basename "$0").real" "$@"
SH
  chmod +x "$BIN_IN_BUNDLE"
  echo "Installed launcher wrapper"
fi

# Prepare DMG staging with Applications symlink
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# background
mkdir -p "$STAGING_DIR/.background"
BG_FOUND=""
for bg in "${DMG_BG_CANDIDATES[@]}"; do
  if [ -f "$bg" ]; then
    cp "$bg" "$STAGING_DIR/.background/background.png"
    BG_FOUND="$STAGING_DIR/.background/background.png"
    break
  fi
done

# Create read/write DMG, mount, set layout via AppleScript, convert to compressed
TMP_DMG="$BUILD_DIR/${APP_NAME}_temp.dmg"
[ -f "$TMP_DMG" ] && rm -f "$TMP_DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING_DIR" -ov -format UDRW "$TMP_DMG" >/dev/null

MOUNT_POINT="/Volumes/$APP_NAME"
if ! hdiutil attach "$TMP_DMG" -mountpoint "$MOUNT_POINT" -nobrowse -noverify -noautoopen >/dev/null 2>&1; then
  echo "ERROR: failed to mount temporary DMG ($TMP_DMG)"
  exit 1
fi
sleep 1

if [ -d "$MOUNT_POINT" ]; then
  if [ -n "$BG_FOUND" ]; then
    mkdir -p "$MOUNT_POINT/.background"
    cp "$BG_FOUND" "$MOUNT_POINT/.background/background.png" || true
  fi

  /usr/bin/osascript <<EOD
tell application "Finder"
  try
    set d to disk "$APP_NAME"
    open d
    set current view of container window of d to icon view
    set toolbar visible of container window of d to false
    set statusbar visible of container window of d to false
    set the bounds of container window of d to {100, 100, 700, 420}
    try
      set background picture of container window of d to POSIX file "${MOUNT_POINT}/.background/background.png"
    end try
    delay 0.4
    set icon size of container window of d to 72
    try
      set position of item "${APP_NAME}.app" of container window of d to {140, 180}
    end try
    try
      set position of item "Applications" of container window of d to {480, 180}
    end try
    close container window of d
    update d
  end try
end tell
EOD

  sleep 0.5
  hdiutil detach "$MOUNT_POINT" -quiet
else
  echo "WARN: mount point not found"
fi

# Convert
[ -f "$DMG_OUTPUT" ] && rm -f "$DMG_OUTPUT"
if ! hdiutil convert "$TMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_OUTPUT" >/dev/null 2>&1; then
  echo "ERROR: failed to convert DMG to compressed image"
  exit 1
fi
rm -f "$TMP_DMG"

if [ -f "$DMG_OUTPUT" ]; then
  echo "DMG ready: $DMG_OUTPUT"
else
  echo "DMG creation failed"
  exit 1
fi

echo "Packaging done. Test by running:"
echo "  open \"$APP_BUNDLE\""
echo "  or run from terminal to see logs:"
echo "  \"$APP_BUNDLE/Contents/MacOS/${APP_NAME}\""