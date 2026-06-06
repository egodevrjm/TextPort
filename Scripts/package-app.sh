#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="TextPort"
APP_DIR="$ROOT_DIR/TextPort.app"
ICON_FILE="$ROOT_DIR/Packaging/TextPort.icns"

cd "$ROOT_DIR"
swift build
swift "$ROOT_DIR/Scripts/generate-app-icon.swift"
EXECUTABLE="$(swift build --show-bin-path)/$APP_NAME"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$ROOT_DIR/Packaging/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ICON_FILE" "$APP_DIR/Contents/Resources/TextPort.icns"
cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/$APP_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

codesign --force --deep --sign - "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

echo "Created $APP_DIR"
