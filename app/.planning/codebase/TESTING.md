# Testing Patterns

**Analysis Date:** 2026-01-10

## Test Framework

**Runner:**
- XCTest (traditional)
- Swift Testing (iOS 18+, new macro-based testing)
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
```

## Test File Organization

**Location:**
- Unit tests: `SportCrunchTests/SportCrunchTests.swift`
- UI tests: `SportCrunchUITests/SportCrunchUITests.swift`
- UI launch tests: `SportCrunchUITests/SportCrunchUITestsLaunchTests.swift`
- **Not co-located** with source (separate test targets)

**Naming:**
- Test files: `{Feature}Tests.swift`
- Test target names: `SportCrunchTests`, `SportCrunchUITests`
- Test class names: Match file name

**Structure:**
```
SportCrunchTests/
└── SportCrunchTests.swift         # Unit tests (placeholder only)

SportCrunchUITests/
├── SportCrunchUITests.swift       # UI tests (placeholder only)
└── SportCrunchUITestsLaunchTests.swift  # Launch performance tests
```

## Test Structure

**XCTest Suite Organization:**
```swift
import XCTest
@testable import SportCrunch

@MainActor
final class SportCrunchUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        // Teardown code
    }

    func testExample() throws {
        let app = XCUIApplication()
        app.launch()
        // Test code here
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

**Patterns:**
- XCTest: Use `setUpWithError()` for per-test setup
- XCTest: Use `tearDownWithError()` for cleanup
- Swift Testing: No explicit setup/teardown (use init/deinit)
- `@MainActor` for UI-related tests

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
```

**What to Mock:**
- External services: `VideoProcessingServiceProtocol`, `ProjectStorageServiceProtocol`
- File system operations (via protocols)
- AVFoundation operations (via protocols)
- Time/dates (if needed)

**What NOT to Mock:**
- Pure functions and utilities
- Internal business logic
- Domain models (use real instances)

## Fixtures and Factories

**Test Data:**
```swift
// Sample data in models (Project.swift)
extension Project {
    static let sampleTennis = Project(
        id: UUID(),
        title: "Tennis Match 1",
        createdAt: Date(),
        sport: .tennis,
        // ... more properties
    )

    static let sampleCompleted = Project(
        id: UUID(),
        title: "Completed Match",
        status: .completed(result: sampleResult),
        // ... more properties
    )
}
```

**Location:**
- Sample data: Defined in model files as `static let` properties
- Factory functions: Not used (prefer static sample data)
- Shared fixtures: Would go in `SportCrunchTests/Fixtures/` (not yet created)

## Coverage

**Requirements:**
- No enforced coverage target
- No coverage metrics configured
- Tests are placeholder only (no actual coverage)

**Configuration:**
- No coverage tool configured
- Xcode's built-in coverage available but not enabled

**View Coverage:**
- Via Xcode: Product → Test → Show Code Coverage (if enabled)

## Test Types

**Unit Tests:**
- Target: `SportCrunchTests`
- Scope: Test individual functions/classes in isolation
- Mocking: Mock all external dependencies
- **Status: NOT IMPLEMENTED** - Only placeholder test exists

**Integration Tests:**
- No dedicated integration test target
- Could test service interactions
- **Status: NOT IMPLEMENTED**

**UI Tests:**
- Target: `SportCrunchUITests`
- Framework: XCTest with `XCUIApplication`
- Scope: Test full user flows
- **Status: MINIMAL** - Only launch performance test implemented

## Common Patterns

**Async Testing (Swift Testing):**
```swift
@Test func processVideo() async throws {
    let service = RealVideoProcessingService()
    let result = await service.processVideo(
        sourceURL: testVideoURL,
        sport: .tennis,
        sportMode: TennisMode.rally
    )
    #expect(result.segments.count > 0)
}
```

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

**Error Testing:**
```swift
@Test func throwsOnInvalidURL() async throws {
    let service = RealVideoProcessingService()
    await #expect(throws: ProcessingError.invalidVideoURL) {
        try await service.processVideo(
            sourceURL: URL(string: "invalid")!,
            sport: .tennis,
            sportMode: nil
        )
    }
}
```

**UI Testing:**
```swift
func testLaunchPerformance() throws {
    if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
```

**Snapshot Testing:**
- Not used in this codebase

## Testing Infrastructure

**Mock Implementations:**
- `MockProjectStorageService` - In-memory project storage (referenced in previews)
- `DummyVideoProcessingService` - Simulated processing with delays (in `VideoProcessingService.swift`)
- Pattern: Protocols enable easy mock injection

**Test Utilities:**
- Sample data in models for previews/testing
- No dedicated test utility functions yet

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

**Critical Gap:**
- **Zero actual test coverage** for core functionality
- Placeholder tests exist but contain no assertions
- No tests for:
  - `AudioAnalyzer` (724 lines of signal processing)
  - `VisualValidator` (653 lines of motion detection)
  - `VideoExporter` (849 lines of video composition)
  - `VideoProcessingService` (884 lines of orchestration)
  - `ProjectStorageService` persistence logic

**Good Foundations:**
- Protocol-based architecture enables easy testing
- Mock implementations already exist
- Sample data available for test fixtures

**Recommendations:**
1. Implement unit tests for `AudioAnalyzer` and `VisualValidator` algorithms
2. Add integration tests for `VideoProcessingService` pipeline
3. Test error handling paths in all services
4. Add UI tests for highlight creation flow
5. Configure code coverage reporting

---

*Testing analysis: 2026-01-10*
*Update when test patterns change*
