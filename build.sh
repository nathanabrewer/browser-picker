#!/bin/bash
set -euo pipefail

APP_NAME="Browser Picker"
BUNDLE_NAME="BrowserPicker"
# Override via environment (e.g. in CI) — falls back to the local defaults.
SIGNING_IDENTITY="${SIGNING_IDENTITY:-9774DA583CBDC6917B54B7C51292CD869167D4BC}"
TEAM_ID="${TEAM_ID:-2T95U247C9}"
BUNDLE_ID="com.nathanbrewer.BrowserPicker"

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"

echo "==> Cleaning build directory..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

echo "==> Creating app bundle structure..."
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

echo "==> Compiling Swift sources..."
swiftc \
    -target arm64-apple-macos13.0 \
    -sdk "$(xcrun --show-sdk-path)" \
    -O \
    -whole-module-optimization \
    -module-name BrowserPicker \
    -emit-executable \
    -o "${APP_BUNDLE}/Contents/MacOS/${BUNDLE_NAME}" \
    "${PROJECT_DIR}/Sources/BrowserDetector.swift" \
    "${PROJECT_DIR}/Sources/Settings.swift" \
    "${PROJECT_DIR}/Sources/PickerView.swift" \
    "${PROJECT_DIR}/Sources/main.swift" \
    -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
    -framework AppKit \
    -framework SwiftUI

echo "==> Copying Info.plist..."
cp "${PROJECT_DIR}/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"

# Generate a simple app icon using system tools
echo "==> Generating app icon..."
python3 "${PROJECT_DIR}/generate_icon.py" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"

echo "==> Creating entitlements..."
cat > "${BUILD_DIR}/entitlements.plist" << 'ENTITLEMENTS'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
</dict>
</plist>
ENTITLEMENTS

echo "==> Signing app bundle..."
codesign --force --deep --sign "${SIGNING_IDENTITY}" \
    --entitlements "${BUILD_DIR}/entitlements.plist" \
    --options runtime \
    --timestamp \
    "${APP_BUNDLE}"

echo "==> Verifying signature..."
codesign --verify --verbose=2 "${APP_BUNDLE}"

echo ""
echo "==> Build complete!"
echo "    ${APP_BUNDLE}"
echo ""
echo "To install:"
echo "    cp -R \"${APP_BUNDLE}\" /Applications/"
echo ""
echo "Then set as default browser in:"
echo "    System Settings > Desktop & Dock > Default web browser"
