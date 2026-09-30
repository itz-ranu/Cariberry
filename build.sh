#!/bin/bash
# Builds Cariberry.app  a self-contained macOS agent app. No Xcode required,
# just the Command Line Tools (swift + iconutil + sips).
set -euo pipefail

cd "$(dirname "$0")"
APP="Cariberry.app"
BUNDLE_ID="com.desktoppup.cariberry"

echo " compiling"
swift build -c release
BIN=".build/release/DesktopPup"

echo " assembling $APP..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/DesktopPup"

echo " drawing app icon"
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
"$BIN" --render-icon "$ICONSET/icon_512x512@2x.png" >/dev/null
for size in 16 32 64 128 256 512; do
  sips -z $size $size "$ICONSET/icon_512x512@2x.png" \
       --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size*2)) $((size*2)) "$ICONSET/icon_512x512@2x.png" \
       --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Cariberry</string>
    <key>CFBundleDisplayName</key><string>Cariberry</string>
    <key>CFBundleExecutable</key><string>DesktopPup</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>Cariberry peeks at the page title of your front browser tab so it can bark when you drift into Reels and cheer when you are working.</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>Wonders (Cariberry's voice assistant) listens for "Hey Cranberry" so you can talk to her hands-free.</string>
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>Wonders transcribes your voice on-device to hear "Hey Cranberry" and whatever you say after it.</string>
    <key>CranberryProjectPath</key>
    <string>$(pwd)</string>
</dict>
</plist>
PLIST
# Ad-hoc signature keeps macOS from re-asking for permissions on every rebuild.
# `|| true` used to swallow this entirely, including a real failure, which would
# make the build look successful while shipping an unsigned app that Gatekeeper
# rejects. Show the actual error and stop instead.
if ! codesign --force --sign - "$APP"; then
  echo " codesign failed — see the error above. The app was assembled but is not signed." >&2
  exit 1
fi

echo " built $(pwd)/$APP"
echo "  run it with:  open \"$APP\""

