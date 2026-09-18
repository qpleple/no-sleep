#!/bin/bash
# Builds NoSleep.app next to this script. Pass --install to also copy it to /Applications and launch it.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/NoSleep"

# App icon: render once, then build the .icns from it.
ICONSET=".build/AppIcon.iconset"
if [[ ! -f .build/AppIcon.icns ]]; then
    rm -rf "$ICONSET"; mkdir -p "$ICONSET"
    swift make-icon.swift "$ICONSET"
    for s in 16 32 128 256 512; do
        sips -z $s $s "$ICONSET/icon_1024.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
        d=$((s*2))
        sips -z $d $d "$ICONSET/icon_1024.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
    done
    rm "$ICONSET/icon_1024.png"
    iconutil -c icns "$ICONSET" -o .build/AppIcon.icns
fi

APP="NoSleep.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/NoSleep"
cp .build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>NoSleep</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleIdentifier</key><string>com.qpleple.nosleep</string>
    <key>CFBundleName</key><string>NoSleep</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
codesign --force --sign - "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
    pkill -x NoSleep || true
    # Wait for the old instance to exit, otherwise `open` reuses it and nothing stays running.
    for _ in $(seq 1 20); do pgrep -x NoSleep >/dev/null || break; sleep 0.25; done
    rm -rf /Applications/NoSleep.app
    cp -R "$APP" /Applications/
    open /Applications/NoSleep.app
    echo "Installed and launched /Applications/NoSleep.app"
fi
