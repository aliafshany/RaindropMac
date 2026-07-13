#!/usr/bin/env bash
# Build a simple drag-to-Applications DMG for RaindropMac.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${MARKETING_VERSION:-}"
if [[ -z "$VERSION" ]]; then
  VERSION=$(/usr/libexec/PlistBuddy -c 'Print :objects:0' /dev/null 2>/dev/null || true)
  VERSION=$(grep -m1 'MARKETING_VERSION' RaindropMac.xcodeproj/project.pbxproj | sed 's/.*= //;s/;//' | tr -d ' ')
fi
VERSION="${VERSION:-1.1.0}"

APP_NAME="RaindropMac"
DERIVED="${DERIVED_DATA_PATH:-$ROOT/build/DerivedDataRelease}"
APP_PATH="${APP_PATH:-$DERIVED/Build/Products/Release/${APP_NAME}.app}"
DIST="$ROOT/dist"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
VOLUME_NAME="${APP_NAME} ${VERSION}"
STAGE="$ROOT/build/dmg_stage"

if [[ ! -d "$APP_PATH" ]]; then
  echo "→ Building Release app…"
  xcodebuild \
    -project RaindropMac.xcodeproj \
    -scheme RaindropMac \
    -configuration Release \
    -derivedDataPath "$DERIVED" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_ALLOWED=YES \
    | xcpretty 2>/dev/null || true
  # xcodebuild without xcpretty if not installed
  if [[ ! -d "$APP_PATH" ]]; then
    xcodebuild \
      -project RaindropMac.xcodeproj \
      -scheme RaindropMac \
      -configuration Release \
      -derivedDataPath "$DERIVED" \
      CODE_SIGN_IDENTITY="-" \
      CODE_SIGNING_ALLOWED=YES
  fi
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: app not found at $APP_PATH" >&2
  exit 1
fi

echo "→ Staging DMG contents…"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP_PATH" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

mkdir -p "$DIST"
rm -f "$DIST/$DMG_NAME"

echo "→ Creating $DIST/$DMG_NAME…"
hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DIST/$DMG_NAME"

echo "✓ Done: $DIST/$DMG_NAME"
ls -lh "$DIST/$DMG_NAME"
