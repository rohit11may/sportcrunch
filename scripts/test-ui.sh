#!/bin/bash
# scripts/test-ui.sh
# Runs UI Tests (SportCrunchUITests) in headless mode with parallelization control.

# Usage: ./scripts/test-ui.sh [WorkerCount] [Destination]
# Example: ./scripts/test-ui.sh 4
# Example: ./scripts/test-ui.sh 2 "platform=iOS Simulator,name=iPhone 17 Pro"

set -e

# Default configuration
PROJECT="app/SportCrunch.xcodeproj"
SCHEME="SportCrunch"
DERIVED_DATA="app/.build"
WORKERS="${1:-3}" # Default to 3 parallel workers
DESTINATION="${2:-platform=iOS Simulator,name=iPhone 17}"

# Check for formatter
if command -v xcbeautify >/dev/null 2>&1; then
    FORMATTER="| xcbeautify"
else
    FORMATTER=""
    echo "⚠️  xcbeautify not found. Output will be verbose."
fi

echo "🧪 Running UI Tests with $WORKERS parallel workers on $DESTINATION..."

# Pre-boot simulator headlessly
if [[ "$DESTINATION" == *"name="* ]]; then
    DEV_NAME=$(echo "$DESTINATION" | sed -n 's/.*name=\([^,]*\).*/\1/p')
    echo "   Booting $DEV_NAME (headless)..."
    xcrun simctl boot "$DEV_NAME" 2>/dev/null || true
fi

# Run Test
# -only-testing:SportCrunchUITests ensures we don't run unit tests here
# -parallel-testing-enabled YES forces parallelization
# -parallel-testing-worker-count controls the concurrency
eval "xcodebuild test \
  -project '$PROJECT' \
  -scheme '$SCHEME' \
  -destination '$DESTINATION' \
  -derivedDataPath '$DERIVED_DATA' \
  -only-testing:SportCrunchUITests \
  -parallel-testing-enabled YES \
  -parallel-testing-worker-count $WORKERS \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY=\"\" \
  $FORMATTER"
