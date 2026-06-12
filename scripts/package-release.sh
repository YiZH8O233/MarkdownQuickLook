#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -z "${XCODEBUILD:-}" ]]; then
  if [[ -x "/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild" ]]; then
    XCODEBUILD="/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild"
  else
    XCODEBUILD="$(/usr/bin/xcrun --find xcodebuild 2>/dev/null || true)"
  fi
fi
DERIVED_DATA="$ROOT_DIR/.build/XcodeDerivedData"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="MarkdownQuickLook.app"
ZIP_NAME="MarkdownQuickLook.zip"

if [[ ! -x "$XCODEBUILD" ]]; then
  echo "error: full Xcode is required to build the release package."
  echo "Set XCODEBUILD=/path/to/xcodebuild if Xcode is installed elsewhere."
  exit 1
fi

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

"$XCODEBUILD" \
  -project "$ROOT_DIR/MarkdownQuickLook.xcodeproj" \
  -scheme MarkdownQuickLook \
  -configuration Release \
  -destination "platform=macOS" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=- \
  DEVELOPMENT_TEAM= \
  clean build

APP_PATH="$DERIVED_DATA/Build/Products/Release/$APP_NAME"

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: built app was not found at $APP_PATH"
  exit 1
fi

/usr/bin/ditto "$APP_PATH" "$DIST_DIR/$APP_NAME"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$DIST_DIR/$APP_NAME" "$DIST_DIR/$ZIP_NAME"

echo "Created $DIST_DIR/$ZIP_NAME"
