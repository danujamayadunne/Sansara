#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

CACHE_DIR="$PROJECT_DIR/.cache/module-cache"
mkdir -p "$CACHE_DIR"

echo "=== Compiling & Running Sansara Tests ==="

swiftc \
    -parse-as-library \
    -module-cache-path "$CACHE_DIR" \
    -framework AppKit \
    -framework WebKit \
    Sources/Sansara/Core/*.swift \
    Sources/Sansara/UI/Sidebar/*.swift \
    Sources/Sansara/UI/Settings/SettingsWindowController.swift \
    Sources/Sansara/UI/Content/ContentColors.swift \
    Sources/Sansara/UI/Content/TabStripeColors.swift \
    Sources/Sansara/UI/Content/SearchHistoryDropdownView.swift \
    Tests/SansaraTests/SansaraTests.swift \
    -o "$PROJECT_DIR/build/test_runner"

"$PROJECT_DIR/build/test_runner"
rm -f "$PROJECT_DIR/build/test_runner"

echo "=== All Tests Completed Successfully ==="
