#!/bin/bash
set -e

APP_NAME="DefaultApps"
BUNDLE_ID="com.defaultapps.app"
VERSION="${VERSION:-1.0.0}"
UNIVERSAL="${UNIVERSAL:-false}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$SCRIPT_DIR/build/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "==> Building release binary..."
cd "$SCRIPT_DIR"

if [ "$UNIVERSAL" = "true" ]; then
    echo "    Building universal binary (arm64 + x86_64)..."
    swift build -c release --arch arm64 --arch x86_64 2>&1
    BUILD_DIR="$SCRIPT_DIR/.build/apple/Products/Release"
else
    swift build -c release 2>&1
    BUILD_DIR="$SCRIPT_DIR/.build/release"
fi

echo "==> Creating app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"

# Copy binary
cp "$BUILD_DIR/$APP_NAME" "$MACOS/$APP_NAME"

# Create Info.plist
cat > "$CONTENTS/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>Default Apps</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

# Generate a simple app icon using system tool (optional, creates a generic icon)
# If you want a custom icon, replace AppIcon.icns in Resources/

echo "==> Done!"
echo "    App bundle: $APP_DIR"
echo ""
echo "    To install, run:"
echo "      cp -r \"$APP_DIR\" /Applications/"
echo ""
echo "    To open:"
echo "      open \"$APP_DIR\""
