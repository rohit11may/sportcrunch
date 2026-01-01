#!/bin/bash

# Configuration
PROJECT="SportCrunch.xcodeproj"
SCHEME="SportCrunch"
# Note: iPhone 17 is technically the 2026 default, but ensure it exists in your list
DESTINATION="platform=iOS Simulator,name=iPhone 17" 
DERIVED_DATA=".build"

echo "🧹 Cleaning hidden file metadata..."
xattr -cr .

echo "🛠️  Building $SCHEME..."

# Check if xcbeautify is installed
if command -v xcbeautify >/dev/null 2>&1; then
    FORMATTER="| xcbeautify"
else
    FORMATTER=""
    echo "⚠️  Tip: Install xcbeautify (brew install xcbeautify) for cleaner logs."
fi

# 1. Build the project
# We use eval to handle the optional formatter pipe
# set -o pipefail
eval "xcodebuild build \
  -project '$PROJECT' \
  -scheme '$SCHEME' \
  -destination '$DESTINATION' \
  -derivedDataPath '$DERIVED_DATA' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY=\"\" $FORMATTER"

if [ $? -eq 0 ]; then
    echo "✅ Build Succeeded. Preparing Simulator..."
    
    open -a Simulator
    
    # Get the .app path
    APP_PATH=$(find "$DERIVED_DATA" -name "$SCHEME.app" | head -n 1)
    
    # 2. Install and Launch
    xcrun simctl install booted "$APP_PATH"
    
    # Get Bundle ID from Info.plist
    BUNDLE_ID=$(defaults read "$(pwd)/$APP_PATH/Info" CFBundleIdentifier)
    
    echo "🚀 Launching $BUNDLE_ID..."
    xcrun simctl launch booted "$BUNDLE_ID"
else
    echo "❌ Build Failed."
    exit 1
fi
