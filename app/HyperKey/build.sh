#!/bin/bash
# Builds HyperKey.app from the Swift package and ad-hoc signs it for local use.
set -euo pipefail

cd "$(dirname "$0")"

CONFIG="${1:-release}"
APP_NAME="HyperKey"
BUNDLE="build/${APP_NAME}.app"

echo "==> Building ($CONFIG)..."
swift build -c "$CONFIG"

BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)/$APP_NAME"

echo "==> Assembling $BUNDLE..."
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS"
mkdir -p "$BUNDLE/Contents/Resources"
cp Resources/Info.plist "$BUNDLE/Contents/Info.plist"
cp "$BIN_PATH" "$BUNDLE/Contents/MacOS/$APP_NAME"

echo "==> Ad-hoc signing..."
# Sign with the local team if HYPERKEY_SIGN_IDENTITY is set, else ad-hoc (-).
IDENTITY="${HYPERKEY_SIGN_IDENTITY:--}"
codesign --force --options runtime \
    --entitlements HyperKey.entitlements \
    --sign "$IDENTITY" \
    "$BUNDLE"

echo "==> Done: $BUNDLE"
echo "Run with: open \"$BUNDLE\"   (or: \"$BUNDLE/Contents/MacOS/$APP_NAME\" to see logs)"


