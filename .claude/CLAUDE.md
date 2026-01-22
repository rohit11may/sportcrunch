## Rules for searching

When making any code search, instead of using Find tool or grep, use `osgrep`. Do not initially use Find or Search. 
Always try to first use osgrep (see osgrep skill) when doing searches for code in the codebase.

## Rules for building/testing
Always use iPhone 17 device.


### Run All Tests (including UI tests)

xcodebuild test -project SportCrunch.xcodeproj -scheme SportCrunch -destination 'platform=iOS Simulator,name=iPhone 17'

### Run Only UI Tests
Always use -parallel-testing-worker-count 2

xcodebuild test -project SportCrunch.xcodeproj -scheme SportCrunch -destination 'platform=iOS Simulator,name=iPhone 17'
-only-testing:SportCrunchUITests --parallel-testing-worker-count 2

### Run a Specific UI Test Class

xcodebuild test -project SportCrunch.xcodeproj -scheme SportCrunch -destination 'platform=iOS Simulator,name=iPhone 17'
-only-testing:SportCrunchUITests/YourTestClassName

### Run a Specific UI Test Method

xcodebuild test -project SportCrunch.xcodeproj -scheme SportCrunch -destination 'platform=iOS Simulator,name=iPhone 17'
-only-testing:SportCrunchUITests/YourTestClassName/testMethodName


You can also change the destination to use different simulators. To see available simulators:
xcrun simctl list devices


# Rules for gracefully handling changes to xcodeproj

NEVER edit .xcodeproj files directly. If you think a change is required in xcode project configuration, then always defer to the human with instructions
on what you'd like them to do.
