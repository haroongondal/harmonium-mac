#!/bin/sh
set -e
cd "$(dirname "$0")"
swift build -c release
APP=build/Harmonium.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Harmonium "$APP/Contents/MacOS/"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Harmonium</string>
<key>CFBundleIdentifier</key><string>com.outsentia.harmonium</string>
<key>CFBundleExecutable</key><string>Harmonium</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
echo "Built $APP"
