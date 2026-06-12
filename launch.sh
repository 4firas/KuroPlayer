#!/bin/bash
set -e

PROJECT_DIR="$(pwd)"
cd "$PROJECT_DIR"
BINARY="$PROJECT_DIR/.build/debug/KuroPlayer"
APP_DIR="$PROJECT_DIR/KuroPlayer.app"
CONTENTS="$APP_DIR/Contents"

# Build
echo "🔨 Building..."
swift build

# Bundle
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BINARY" "$CONTENTS/MacOS/KuroPlayer"

# Info.plist (always regenerate)
cat > "$CONTENTS/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>KuroPlayer</string>
    <key>CFBundleIdentifier</key>
    <string>com.kuroplayer.app</string>
    <key>CFBundleName</key>
    <string>KuroPlayer</string>
    <key>CFBundleDisplayName</key>
    <string>KuroPlayer</string>
    <key>CFBundleVersion</key>
    <string>1.0.1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.1</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>KuroPlayer Callback</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>kuroplayer</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
PLIST

# Kill previous instance
pkill -f "KuroPlayer.app" 2>/dev/null || true

# Clean extended attributes
xattr -cr "$APP_DIR" 2>/dev/null || true

# Sign
echo "🔑 Signing..."
codesign --force --deep --sign - "$APP_DIR"

# Launch
echo "🚀 Launching..."
open "$APP_DIR"
echo "Done."
