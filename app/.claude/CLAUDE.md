## Rules for building/testing
Always use iPhone 17 device.


### Run All Tests (including UI tests)

xcodebuild test -project SportCrunch.xcodeproj -scheme SportCrunch -destination 'platform=iOS Simulator,name=iPhone 17'

### Run Only UI Tests

xcodebuild test -project SportCrunch.xcodeproj -scheme SportCrunch -destination 'platform=iOS Simulator,name=iPhone 17'
-only-testing:SportCrunchUITests

### Run a Specific UI Test Class

xcodebuild test -project SportCrunch.xcodeproj -scheme SportCrunch -destination 'platform=iOS Simulator,name=iPhone 17'
-only-testing:SportCrunchUITests/YourTestClassName

### Run a Specific UI Test Method

xcodebuild test -project SportCrunch.xcodeproj -scheme SportCrunch -destination 'platform=iOS Simulator,name=iPhone 17'
-only-testing:SportCrunchUITests/YourTestClassName/testMethodName


You can also change the destination to use different simulators. To see available simulators:
xcrun simctl list devices
