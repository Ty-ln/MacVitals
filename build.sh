#!/bin/bash
# Builds MacVitals.app with SwiftPM (no Xcode needed) and installs it to ~/Applications.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP=build/MacVitals.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/MacVitals "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
codesign --force --sign - "$APP"

pkill -x MacVitals 2>/dev/null || true
mkdir -p ~/Applications
rm -rf ~/Applications/MacVitals.app
cp -R "$APP" ~/Applications/
echo "Installed ~/Applications/MacVitals.app"
