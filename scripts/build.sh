#!/bin/bash
set -euo pipefail

# Workspace directory
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "=== Building Sansara Native macOS Browser ==="

BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="Sansara"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
CACHE_DIR="$PROJECT_DIR/.cache/module-cache"

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"
mkdir -p "$CACHE_DIR"

# Find all Swift source files
SWIFT_FILES=()
while IFS= read -r -d $'\0' file; do
    SWIFT_FILES+=("$file")
done < <(find "$PROJECT_DIR/Sources/Sansara" -name "*.swift" -print0)
echo "Compiling ${#SWIFT_FILES[@]} Swift source files..."

swiftc \
    -O \
    -parse-as-library \
    -module-name Sansara \
    -module-cache-path "$CACHE_DIR" \
    -framework AppKit \
    -framework WebKit \
    "${SWIFT_FILES[@]}" \
    -o "$MACOS_DIR/$APP_NAME"

# Copy Info.plist and Resources
cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp -R "$PROJECT_DIR/Resources/"* "$RESOURCES_DIR/" 2>/dev/null || true

# Sign bundle ad-hoc
if command -v codesign &> /dev/null; then
    codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || true
fi

echo "=== Build Successful: $APP_BUNDLE ==="
