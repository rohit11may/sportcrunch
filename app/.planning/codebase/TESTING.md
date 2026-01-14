# Testing Patterns

**Analysis Date:** 2026-01-14

## Test Framework

**Runner:**
- XCTest (traditional) - Primary for UI tests
- Swift Testing (iOS 18+, new macro-based testing) - Primary for unit tests
- Both frameworks available

**Assertion Library:**
- XCTest: `XCTAssert*` family of assertions
- Swift Testing: `#expect(...)` macro

**Run Commands:**
```bash
# Via Xcode
Cmd+U                                  # Run all tests

# Via command line
xcodebuild test -scheme SportCrunch    # Run all tests

# Specific test target
xcodebuild test -scheme SportCrunch -only-testing:SportCrunchTests
xcodebuild test -scheme SportCrunch -only-testing:SportCrunchUITests
```

## Test File Organization

**Location:**
- Unit tests: `SportCrunchTests/`
  - E2E detection: `E2E/SegmentDetectionTests.swift`
  - Helpers: `Helpers/SegmentEvaluator.swift`, `TestResourceLoader.swift`
  - Models: `Models/GroundTruth.swift`
- UI tests: `SportCrunchUITests/`
  - E2E flows: `E2E/HighlightCreationFlowTests.swift`, `ExportFlowTests.swift`
  - Screen objects: `Helpers/AppScreen.swift`
  - Test helpers: `Helpers/TestHelpers.swift`
- **Not co-located** with source (separate test targets)

**Naming:**
- Test files: `{Feature}Tests.swift`
- Test target names: `SportCrunchTests`, `SportCrunchUITests`
- Test class names: Match file name
- Screen objects: `{ScreenName}Screen` (e.g., `HomeScreen`, `HighlightCreationScreen`)

**Structure:**
```
SportCrunchTests/
├── SportCrunchTests.swift         # Unit tests entry (Swift Testing)
├── TEST_RESOURCES.md              # Test resources documentation
├── E2E/                           # End-to-end tests
│   └── SegmentDetectionTests.swift
├── Helpers/                       # Test utilities
│   ├── SegmentEvaluator.swift    # IoU-based fuzzy matching
│   └── TestResourceLoader.swift  # Bundle resource loading
├── Models/                        # Test data models
│   └── GroundTruth.swift         # Ground truth segment format
└── TestResources/                 # Test assets
    ├── Videos/                    # Test video files (MP4)
    └── GroundTruth/               # Segment annotations (JSON)

SportCrunchUITests/
├── SportCrunchUITests.swift       # UI tests entry (XCTest)
├── SportCrunchUITestsLaunchTests.swift  # Launch performance
├── E2E/                           # End-to-end UI tests
│   ├── HighlightCreationFlowTests.swift
│   └── ExportFlowTests.swift
├── Helpers/                       # UI test utilities
│   ├── AccessibilityIdentifiers.swift  # Re-export
│   ├── AppScreen.swift           # Screen object patterns
│   └── TestHelpers.swift         # XCTestCase extensions
└── Samples/                       # Sample test videos
```

## Test Structure

**XCTest Suite Organization:**
```swift
import XCTest
@testable import SportCrunch

@MainActor
final class HighlightCreationFlowTests: XCTestCase {
    var app: XCUIApplication!
    var homeScreen: HomeScreen!
    var creationScreen: HighlightCreationScreen!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        
        // Enable test mode
        app.launchArguments.append("-isTestingVideoFlow")
        
        app.launch()
        
        homeScreen = HomeScreen(app: app)
        creationScreen = HighlightCreationScreen(app: app)
    }

    override func tearDownWithError() throws {
        app = nil
        homeScreen = nil
        creationScreen = nil
    }

    @MainActor
    func testCreateHighlightButtonOpensFlow() throws {
        XCTAssertTrue(homeScreen.createHighlightButton.waitForExistence(timeout: 5))
        homeScreen.createHighlightButton.tap()
        XCTAssertTrue(creationScreen.flowContainer.waitForExistence(timeout: 10))
    }
}
```

**Swift Testing Suite Organization:**
```swift
import Testing
@testable import SportCrunch

struct SportCrunchTests {
    @Test func example() async throws {
        // Use #expect(...) for assertions
    }
}
```

**E2E Detection Test Organization:**
```swift
import XCTest
import AVFoundation
@testable import SportCrunch

@MainActor
final class SegmentDetectionTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        executionTimeAllowance = 180.0  // 3 minutes for video processing
        continueAfterFailure = false
    }

    func testShotDetection_Tennis() async throws {
        // Phase 1: Load test resources
        let videoURL = try TestResourceLoader.loadTestVideo(named: "test_shot_1.mp4")
        let groundTruth = try TestResourceLoader.loadGroundTruth(named: "test_shot_1.json")
        
        // Phase 2: Process video
        let service = RealVideoProcessingService()
        let result = try await service.processVideo(
            sourceURL: videoURL,
            sport: .tennis,
            sportMode: TennisMode.individual
        )
        
        // Phase 3: Evaluate with fuzzy matching
        let evaluation = SegmentEvaluator.evaluate(
            detected: detectedRanges,
            groundTruth: groundTruthRanges,
            iouThreshold: 0.5
        )
        
        // Phase 4: Assert thresholds
        XCTAssertGreaterThan(evaluation.tp, 0)
        XCTAssertLessThan(rates.fpRate, 30.0)
        XCTAssertLessThan(rates.fnRate, 50.0)
    }
}
```

## Screen Object Pattern

**Base Protocol:**
```swift
protocol AppScreen {
    var app: XCUIApplication { get }
}

extension AppScreen {
    func element(_ identifier: String, timeout: TimeInterval = 5) -> XCUIElement {
        let element = app.descendants(matching: .any)[identifier]
        _ = element.waitForExistence(timeout: timeout)
        return element
    }
}
```

**Screen Object Implementation:**
```swift
struct HomeScreen: AppScreen {
    let app: XCUIApplication

    var createHighlightButton: XCUIElement {
        element(AccessibilityID.Home.createHighlightButton)
    }

    var settingsButton: XCUIElement {
        element(AccessibilityID.Home.settingsButton)
    }

    func projectCard(id: String) -> XCUIElement {
        element(AccessibilityID.Home.projectCard(id: id))
    }
}

struct HighlightCreationScreen: AppScreen {
    let app: XCUIApplication

    var flowContainer: XCUIElement { element(AccessibilityID.Creation.flowContainer) }
    var videoLibraryButton: XCUIElement { element(AccessibilityID.Creation.videoLibraryButton) }
    var tennisButton: XCUIElement { element(AccessibilityID.Creation.sportTennisButton) }
    var rallyModeButton: XCUIElement { element(AccessibilityID.Creation.modeRallyButton) }
    var crunchButton: XCUIElement { element(AccessibilityID.Creation.crunchButton) }
}
```

## Accessibility Identifiers

**Shared Identifiers (Single Source of Truth):**
```swift
// Located in: SportCrunch/Shared/AccessibilityIdentifiers.swift
enum AccessibilityID {
    enum Home {
        static let createHighlightButton = "home_createHighlight"
        static let settingsButton = "home_settings"
        static func projectCard(id: String) -> String {
            "home_projectCard_\(id)"
        }
    }

    enum Creation {
        static let flowContainer = "creation_flow"
        static let videoLibraryButton = "creation_videoLibrary"
        static let sportTennisButton = "creation_sport_tennis"
        static let modeRallyButton = "creation_mode_rally"
        static let crunchButton = "creation_crunch"
    }

    enum Project {
        static let sheet = "project_sheet"
        static let segmentNavigator = "project_segmentNavigator"
        static let exportButton = "project_export"
    }
}
```

## Mocking

**Framework:**
- No external mocking library (manual mocks)
- Protocol-based dependency injection enables easy mocking

**Patterns:**
```swift
// Mock service for testing
final class MockProjectStorageService: ProjectStorageServiceProtocol {
    var projects: [Project] = []
    var shouldThrowError = false

    func loadProjects() -> [Project] {
        return shouldThrowError ? [] : projects
    }

    func saveProject(_ project: Project) {
        projects.append(project)
    }
}

// Mock with configurable return values
final class MockThumbnailService: ThumbnailServiceProtocol {
    var thumbnailDataToReturn: Data? = nil

    func generateThumbnail(from videoURL: URL, maxSize: CGSize?) async -> Data? {
        return thumbnailDataToReturn
    }
}
```

**Test Launch Arguments:**
```swift
// Enable test video injection (bypasses PhotosPicker)
app.launchArguments.append("-isTestingVideoFlow")

// Inject mock completed projects
app.launchArguments.append("-injectMockProjects")

// Specify test video path
app.launchEnvironment["TEST_VIDEO_PATH"] = videoPath
```

**What to Mock:**
- External services: `VideoProcessingServiceProtocol`, `ProjectStorageServiceProtocol`
- Photos library operations (via `VideoLoaderServiceProtocol`)
- Thumbnail generation (via `ThumbnailServiceProtocol`)
- Time/dates (if needed)

**What NOT to Mock:**
- Pure functions and utilities
- Internal business logic
- Domain models (use real instances)

## Fixtures and Factories

**Test Data (Ground Truth):**
```swift
// Located in: SportCrunchTests/Models/GroundTruth.swift
struct GroundTruthSegment: Codable {
    let start: Double
    let end: Double
}

struct GroundTruth: Codable {
    let videoFilename: String
    let sport: String
    let mode: String
    let segments: [GroundTruthSegment]
}
```

**Test Resource Loading:**
```swift
// Located in: SportCrunchTests/Helpers/TestResourceLoader.swift
class TestResourceLoader {
    static func loadTestVideo(named name: String) throws -> URL {
        // Loads from TestResources/Videos/
    }

    static func loadGroundTruth(named name: String) throws -> GroundTruth {
        // Loads from TestResources/GroundTruth/
    }
}
```

**Sample Data in Models:**
```swift
extension Project {
    static let sampleTennis = Project(
        id: UUID(),
        title: "Tennis Match 1",
        createdAt: Date(),
        sport: .tennis,
        // ... more properties
    )
}
```

**Location:**
- Ground truth JSON: `SportCrunchTests/TestResources/GroundTruth/`
- Test videos: `SportCrunchTests/TestResources/Videos/`
- Sample data: Defined in model files as `static let` properties

## Segment Evaluation

**IoU-Based Fuzzy Matching:**
```swift
// Located in: SportCrunchTests/Helpers/SegmentEvaluator.swift
struct SegmentEvaluator {
    /// Calculate Intersection over Union for temporal ranges
    static func iou(detected: TimeRange, groundTruth: TimeRange) -> Double

    /// Evaluate segments using greedy IoU matching
    static func evaluate(
        detected: [TimeRange],
        groundTruth: [TimeRange],
        iouThreshold: Double = 0.5
    ) -> (tp: Int, fp: Int, fn: Int)

    /// Calculate false positive/negative rates as percentages
    static func calculateRates(
        detected: [TimeRange],
        groundTruth: [TimeRange],
        videoDuration: Double
    ) -> (fpRate: Double, fnRate: Double)
}
```

**TimeRange Helper:**
```swift
struct TimeRange {
    let start: Double
    let end: Double
    var duration: Double { end - start }
}
```

## Coverage

**Requirements:**
- No enforced coverage target
- No coverage metrics configured
- E2E tests provide functional coverage

**Configuration:**
- No coverage tool configured
- Xcode's built-in coverage available but not enabled

**View Coverage:**
- Via Xcode: Product → Test → Show Code Coverage (if enabled)

## Test Types

**Unit Tests:**
- Target: `SportCrunchTests`
- Framework: Swift Testing (`@Test`, `#expect`)
- Scope: Test individual functions/classes in isolation
- **Status: PLACEHOLDER** - Entry file exists, no unit tests implemented

**E2E Detection Tests:**
- Target: `SportCrunchTests`
- Framework: XCTest (for async/await support)
- Location: `SportCrunchTests/E2E/`
- Scope: Full detection pipeline with real video processing
- Example: `SegmentDetectionTests.swift` - Tests shot detection against ground truth
- **Status: IMPLEMENTED** - IoU-based evaluation with configurable thresholds

**UI Tests:**
- Target: `SportCrunchUITests`
- Framework: XCTest with `XCUIApplication`
- Location: `SportCrunchUITests/E2E/`
- Scope: Test full user flows
- Examples:
  - `HighlightCreationFlowTests.swift` - Creation wizard navigation
  - `ExportFlowTests.swift` - Export sheet functionality
- **Status: IMPLEMENTED** - Core user flows covered

**Launch Performance Tests:**
- Location: `SportCrunchUITests/SportCrunchUITestsLaunchTests.swift`
- Scope: Measure app launch time
- **Status: IMPLEMENTED**

## Common Patterns

**Async Testing (XCTest):**
```swift
func testProcessVideo() async throws {
    let service = RealVideoProcessingService()
    let result = try await service.processVideo(
        sourceURL: testVideoURL,
        sport: .tennis,
        sportMode: TennisMode.rally
    )
    XCTAssertGreaterThan(result.segments.count, 0)
}
```

**Waiting for Elements:**
```swift
// Wait for existence
XCTAssertTrue(element.waitForExistence(timeout: 10))

// Wait for non-existence
extension XCUIElement {
    func waitForNonExistence(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
}

// Wait for hittable
extension XCTestCase {
    func waitForHittable(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND isHittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
```

**Predicate Matching for Dynamic Elements:**
```swift
// Match project cards by prefix
let projectCardPredicate = NSPredicate(
    format: "identifier BEGINSWITH %@",
    AccessibilityID.Home.projectCardPrefix
)
let projectCards = app.descendants(matching: .any).matching(projectCardPredicate)
XCTAssertTrue(projectCards.firstMatch.waitForExistence(timeout: 5))
```

## Testing Infrastructure

**Mock Implementations:**
- `MockProjectStorageService` - In-memory project storage
- `MockThumbnailService` - Configurable thumbnail return
- `MockVideoLoaderService` - Simulated video loading
- `MockProcessingReportManager` - No-op debug reporting
- `DummyVideoProcessingService` - Simulated processing with delays

**Test Utilities:**
- `SegmentEvaluator` - IoU-based fuzzy matching for detection accuracy
- `TestResourceLoader` - Bundle resource loading for test videos/ground truth
- `TestHelpers` - XCTestCase extensions for common operations
- Screen objects - Semantic access to UI elements

**Preview Support:**
- Extensive use of SwiftUI Previews for manual testing
- Example:
  ```swift
  #Preview("Home") {
      let appState = AppState(
          projectStorageService: MockProjectStorageService(withSampleData: true)
      )
      return ContentView()
          .environmentObject(appState)
  }
  ```

## Current State

**Implemented:**
- ✅ E2E detection tests with IoU-based evaluation
- ✅ UI tests for highlight creation flow
- ✅ UI tests for export flow
- ✅ Screen object pattern with shared accessibility identifiers
- ✅ Test resource loading infrastructure
- ✅ Ground truth format and parsing
- ✅ Segment evaluation with fuzzy matching
- ✅ Launch performance tests

**Good Foundations:**
- Protocol-based architecture enables easy testing
- Mock implementations exist for key services
- Sample data available for test fixtures
- Shared accessibility identifiers eliminate string duplication
- Screen object pattern provides maintainable UI tests

**Gaps to Address:**
- Unit tests for core algorithms (`AudioAnalyzer`, `VisualValidator`)
- Integration tests for service interactions
- Code coverage reporting not configured
- Additional E2E detection tests for different sports/modes

**Test Resources:**
- See `SportCrunchTests/TEST_RESOURCES.md` for:
  - Directory structure
  - Ground truth JSON format
  - Video requirements
  - Adding resources to Xcode
  - Troubleshooting guide

---

*Testing analysis: 2026-01-14*
*Update when test patterns change*
