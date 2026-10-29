#!/bin/bash
# Builds build/Clawd.app. With --install it copies the app to ~/Applications and opens it.
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release
APP=build/Clawd.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Clawd "$APP/Contents/MacOS/Clawd"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>com.noxaur.clawd</string>
    <key>CFBundleName</key><string>Clawd</string>
    <key>CFBundleExecutable</key><string>Clawd</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
# A designated requirement on the identifier only keeps the Accessibility permission across rebuilds.
codesign --force --sign - -r='designated => identifier "com.noxaur.clawd"' "$APP"
echo "Built $APP"
if [[ "${1:-}" == "--install" ]]; then
    pkill -x Clawd || true
    # Clawd gives back borrowed windows before he quits.
    for _ in $(seq 1 50); do pgrep -x Clawd >/dev/null || break; sleep 0.2; done
    rm -rf ~/Applications/Clawd.app
    mkdir -p ~/Applications
    cp -R "$APP" ~/Applications/
    open ~/Applications/Clawd.app
fi
