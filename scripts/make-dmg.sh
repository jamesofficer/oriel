#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

BUILD_DIR="build"
APP="$BUILD_DIR/Build/Products/Release/Oriel.app"

rm -rf "$BUILD_DIR"

xcodebuild -project Oriel.xcodeproj -scheme Oriel -configuration Release \
  -derivedDataPath "$BUILD_DIR" clean build

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
DMG="$BUILD_DIR/Oriel-$VERSION.dmg"

STAGING="$BUILD_DIR/dmg"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create -volname "Oriel" -srcfolder "$STAGING" -ov -format UDZO "$DMG"

echo "Created $DMG"
