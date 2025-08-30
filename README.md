MacCleaner - README
====================

About this project
------------
MacCleaner is a small Qt (C++/QML) utility that scans user cache/log directories and reports reclaimable files.
It is implemented in C++ with Qt6 (Qt Core + Qt Quick) and a QML frontend. A small Objective-C++ helper moves files to Trash on macOS.

Tech stack
----------
- C++17
- Qt 6 (Core, Quick, QuickControls2)
- QML for UI
- CMake for build
- macdeployqt / windeployqt for packaging
- Optional: Homebrew on macOS to install Qt

Build (developer)
-----------------
Prerequisites:
- Qt 6 development (qmake, macdeployqt)
- CMake >= 3.16
- A C++ toolchain (e.g. Xcode on macOS)

Common steps (macOS):
1. From project root:
```
   mkdir build && cd build
   cmake .. -DCMAKE_BUILD_TYPE=Release
   cmake --build . --config Release -- -j
```
2. Run the app:
```
   build/app/MacCleanerApp.app/Contents/MacOS/MacCleanerApp  (or run the .app)
```
Packaging for macOS (user-friendly .dmg)
---------------------------------------
1. On macOS install Qt (or brew install qt).
2. From project root run: 
```./pack_mac.sh```
   - Script builds Release, creates a .app bundle and runs macdeployqt to bundle Qt and create a .dmg.
3. The resulting .dmg will be in build/app/ if macdeployqt succeeded.

Notes:
- For App Store or Gatekeeper distribution you must sign and notarize the app (not covered here).
- If macdeployqt is missing, install Qt and add its bin to PATH.

Distribution
------------
- For macOS, distribute the .dmg produced by pack_mac.sh.

Usage
-----
- Launch the app, click "Start Scan" to enumerate junk findings.
- Use the "Trash" action to move files to Trash (macOS implementation integrated via mac/Trash.mm).
- No admin permissions are requested; the app only scans user-writable directories by default.

Contact / Repository
--------------------
- Keep README.md or release notes in your repo with the generated .dmg attached to releases.

