#!/bin/bash
set -euo pipefail

# Local release: build → sign → notarize → staple → DMG.
# No CI secrets needed — uses the Developer ID cert already in your keychain
# and your Apple ID app-specific password for notarization.
#
# Usage:
#   ./release.sh 1.1.0
#
# Notarization credentials, in priority order:
#   1. A stored notarytool keychain profile named "browser-picker-notary".
#      Create it once (then you never type the password again):
#        xcrun notarytool store-credentials browser-picker-notary \
#          --apple-id "you@example.com" --team-id 2T95U247C9 \
#          --password "app-specific-password"
#   2. Env vars APPLE_ID, APPLE_PASSWORD (app-specific), APPLE_TEAM_ID.
#   3. If neither is present, the script builds + signs but SKIPS notarization
#      (the DMG will trip Gatekeeper on other machines — fine for local use).

VERSION="${1:?usage: ./release.sh <version>  e.g. ./release.sh 1.1.0}"
APP_NAME="Browser Picker"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
APP="${BUILD_DIR}/${APP_NAME}.app"
DMG="${BUILD_DIR}/Browser-Picker-${VERSION}.dmg"
NOTARY_PROFILE="browser-picker-notary"

echo "==> Building & signing…"
"${PROJECT_DIR}/build.sh"

echo "==> Notarizing…"
ZIP="${BUILD_DIR}/notarize.zip"
ditto -c -k --keepParent "${APP}" "${ZIP}"

if xcrun notarytool history --keychain-profile "${NOTARY_PROFILE}" >/dev/null 2>&1; then
    xcrun notarytool submit "${ZIP}" --keychain-profile "${NOTARY_PROFILE}" --wait
    NOTARIZED=1
elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_PASSWORD:-}" && -n "${APPLE_TEAM_ID:-}" ]]; then
    xcrun notarytool submit "${ZIP}" \
        --apple-id "${APPLE_ID}" --password "${APPLE_PASSWORD}" --team-id "${APPLE_TEAM_ID}" \
        --wait
    NOTARIZED=1
else
    echo "    !! No notarytool profile or APPLE_* env vars found — SKIPPING notarization."
    echo "    !! The DMG will be signed but unnotarized (Gatekeeper warning on other Macs)."
    NOTARIZED=0
fi
rm -f "${ZIP}"

if [[ "${NOTARIZED}" == "1" ]]; then
    echo "==> Stapling…"
    xcrun stapler staple "${APP}"
    xcrun stapler validate "${APP}"
fi

echo "==> Packaging DMG…"
STAGE="$(mktemp -d)"
cp -R "${APP}" "${STAGE}/"
ln -s /Applications "${STAGE}/Applications"
rm -f "${DMG}"
hdiutil create -volname "${APP_NAME}" -srcfolder "${STAGE}" -ov -format UDZO "${DMG}"
rm -rf "${STAGE}"

echo ""
echo "==> Done: ${DMG}"
if [[ "${NOTARIZED}" == "1" ]]; then
    echo "    Signed + notarized + stapled. Opens clean on any Mac."
fi
echo ""
echo "Publish to GitHub (optional):"
echo "    gh release create v${VERSION} \"${DMG}\" \\"
echo "      --repo nathanabrewer/browser-picker \\"
echo "      --title \"Browser Picker ${VERSION}\" --generate-notes"
