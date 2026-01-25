#!/bin/bash
# scripts/test-unit.sh
# Runs Algorithm/Unit tests (SportCrunchTests) in headless mode.

# Usage: ./scripts/test-unit.sh [Destination]
# Example: ./scripts/test-unit.sh "platform=iOS Simulator,name=iPhone 17 Pro"

set -e

# Default configuration
PROJECT="app/SportCrunch.xcodeproj"
SCHEME="SportCrunch"
DERIVED_DATA="app/.build"
DESTINATION="${1:-platform=iOS Simulator,name=iPhone 17 Pro}"

# Check for formatter
if command -v xcbeautify >/dev/null 2>&1; then
    FORMATTER="| xcbeautify"
else
    FORMATTER=""
    echo "⚠️  xcbeautify not found. Output will be verbose."
fi

echo "🧪 Running Unit/Algorithm Tests on $DESTINATION..."

# Pre-boot simulator headlessly to prevent UI popup
if [[ "$DESTINATION" == *"name="* ]]; then
    DEV_NAME=$(echo "$DESTINATION" | sed -n 's/.*name=\([^,]*\).*/\1/p')
    echo "   Booting $DEV_NAME (headless)..."
    xcrun simctl boot "$DEV_NAME" 2>/dev/null || true
fi

# Run Test
# -only-testing:SportCrunchTests ensures we don't run UI tests here
eval "xcodebuild test \
  -project '$PROJECT' \
  -scheme '$SCHEME' \
  -destination '$DESTINATION' \
  -derivedDataPath '$DERIVED_DATA' \
  -only-testing:SportCrunchTests \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY=\"\" \
  $FORMATTER"
