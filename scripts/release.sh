#!/bin/bash
set -euo pipefail

SIGNING_IDENTITY="Developer ID Application: Wontae Yang (Z52JGL64CW)"
TEAM_ID="Z52JGL64CW"
BUNDLE_ID="com.wontaeyang.HRM"
APP_NAME="HRM"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

cd "$PROJECT_ROOT"

# Prompt for Apple ID and app-specific password if not set
if [ -z "${APPLE_ID:-}" ]; then
    read -rp "Apple ID: " APPLE_ID
fi
if [ -z "${APP_SPECIFIC_PASSWORD:-}" ]; then
    read -rsp "App-specific password: " APP_SPECIFIC_PASSWORD
    echo
fi

echo "==> Building universal binary..."
swift build -c release --arch arm64 --arch x86_64

echo "==> Creating app bundle..."
rm -rf "${APP_NAME}.app"
mkdir -p "${APP_NAME}.app/Contents/MacOS"
mkdir -p "${APP_NAME}.app/Contents/Resources"
cp ".build/apple/Products/Release/${APP_NAME}" "${APP_NAME}.app/Contents/MacOS/${APP_NAME}"
cp Info.plist "${APP_NAME}.app/Contents/Info.plist"
cp Sources/HRM/Resources/AppIcon.icns "${APP_NAME}.app/Contents/Resources/AppIcon.icns"

echo "==> Signing app bundle..."
codesign --force --options runtime \
    --entitlements "${APP_NAME}.entitlements" \
    --sign "$SIGNING_IDENTITY" \
    "${APP_NAME}.app"

echo "==> Creating zip for notarization..."
rm -f "${APP_NAME}.zip"
ditto -c -k --keepParent "${APP_NAME}.app" "${APP_NAME}.zip"

echo "==> Submitting for notarization..."
xcrun notarytool submit "${APP_NAME}.zip" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID" \
    --password "$APP_SPECIFIC_PASSWORD" \
    --wait

echo "==> Stapling notarization ticket..."
xcrun stapler staple "${APP_NAME}.app"

echo "==> Re-zipping stapled app..."
rm -f "${APP_NAME}.zip"
ditto -c -k --keepParent "${APP_NAME}.app" "${APP_NAME}.zip"

echo "==> Verifying..."
codesign -dvvv "${APP_NAME}.app"
spctl --assess --type execute "${APP_NAME}.app"
xcrun stapler validate "${APP_NAME}.app"

echo ""
echo "Done! To publish:"
echo "  gh release create v1.0 ${APP_NAME}.zip --title \"HRM v1.0\" --notes \"Initial release\""
