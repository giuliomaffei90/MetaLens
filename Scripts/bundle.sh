#!/bin/sh
# Builds MetaLens.app around the SwiftPM binary. Usage: Scripts/bundle.sh [debug|release]
set -e
cd "$(dirname "$0")/.."
CONFIG="${1:-debug}"

swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/MetaLens"
APP=".build/MetaLens.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/MetaLens"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# AppIcon.icon is an Icon Composer document: actool compiles it into Assets.car (Liquid Glass
# on macOS 26+) plus an AppIcon.icns for older systems.
xcrun actool AppIcon.icon --compile "$APP/Contents/Resources" --app-icon AppIcon \
  --include-all-app-icons --platform macosx --target-device mac \
  --minimum-deployment-target 14.0 --output-partial-info-plist "$(mktemp -t metalens-icon)" \
  --output-format human-readable-text >/dev/null

# Make the Finder and the Dock notice the new icon.
touch "$APP"
codesign --force --sign - "$APP" >/dev/null 2>&1 || true

echo "$APP"
