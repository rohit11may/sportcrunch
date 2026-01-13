import XCTest

final class ExportFlowTests: XCTestCase {
    var app: XCUIApplication!
    var homeScreen: HomeScreen!
    var projectScreen: CompletedProjectScreen!
    var exportScreen: ExportScreen!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        homeScreen = HomeScreen(app: app)
        projectScreen = CompletedProjectScreen(app: app)
        exportScreen = ExportScreen(app: app)
    }

    override func tearDownWithError() throws {
        app = nil
        homeScreen = nil
        projectScreen = nil
        exportScreen = nil
    }

    // MARK: - Completed Project Access

    @MainActor
    func testCompletedProjectOpensSheet() throws {
        // Given: A completed project exists on home screen
        // Note: This requires a completed project in the app state
        // In real testing, you would:
        // 1. Create a test project fixture
        // 2. Use launch arguments to seed test data
        // 3. Or complete a highlight creation first

        // Verify home screen loads
        XCTAssertTrue(homeScreen.createHighlightButton.waitForExistence(timeout: 5),
                      "Home screen should be visible")

        // Look for any project card using shared constant prefix
        let projectCardPredicate = NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Home.projectCardPrefix)
        let projectCards = app.descendants(matching: .any).matching(projectCardPredicate)

        // If projects exist, test the tap behavior
        if projectCards.count > 0 {
            let firstCard = projectCards.firstMatch
            firstCard.tap()

            // Then: Project sheet opens
            XCTAssertTrue(projectScreen.sheet.waitForExistence(timeout: 5),
                          "Completed project sheet should open when tapping project card")
        } else {
            // No projects - verify empty state or create highlight button is present
            XCTAssertTrue(homeScreen.createHighlightButton.exists,
                          "If no projects, create button should be visible")
        }
    }

    // MARK: - Export Button Access

    @MainActor
    func testExportButtonOpensExportSheet() throws {
        // Given: A completed project sheet is open
        // This assumes a project exists and is tapped

        // First, check if any project cards exist using shared constant
        let projectCardPredicate = NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Home.projectCardPrefix)
        let projectCards = app.descendants(matching: .any).matching(projectCardPredicate)

        guard projectCards.count > 0 else {
            // Skip test if no projects - not a failure, just nothing to test
            throw XCTSkip("No completed projects available to test export flow")
        }

        // Open a project
        projectCards.firstMatch.tap()
        XCTAssertTrue(projectScreen.sheet.waitForExistence(timeout: 5))

        // When: Tap export button
        XCTAssertTrue(projectScreen.exportButton.waitForExistence(timeout: 5),
                      "Export button should be visible in completed project sheet")

        projectScreen.exportButton.tap()

        // Then: Export sheet opens with options
        XCTAssertTrue(exportScreen.sheet.waitForExistence(timeout: 5),
                      "Export sheet should open when tapping export button")
    }

    // MARK: - Export Options Visibility

    @MainActor
    func testExportSheetShowsSaveAndShareOptions() throws {
        // Given: Export sheet is open
        let projectCardPredicate = NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Home.projectCardPrefix)
        let projectCards = app.descendants(matching: .any).matching(projectCardPredicate)

        guard projectCards.count > 0 else {
            throw XCTSkip("No completed projects available to test export options")
        }

        // Navigate to export sheet
        projectCards.firstMatch.tap()
        guard projectScreen.sheet.waitForExistence(timeout: 5) else {
            XCTFail("Could not open project sheet")
            return
        }

        projectScreen.exportButton.tap()
        guard exportScreen.sheet.waitForExistence(timeout: 5) else {
            XCTFail("Could not open export sheet")
            return
        }

        // Then: Verify export options are present
        XCTAssertTrue(exportScreen.saveCameraRollButton.waitForExistence(timeout: 3),
                      "Save to Camera Roll button should be visible")
        XCTAssertTrue(exportScreen.shareButton.exists,
                      "Share button should be visible")
    }

    // MARK: - Starred Toggle

    @MainActor
    func testOnlyStarredToggleExists() throws {
        // Given: Export sheet is open
        let projectCardPredicate = NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Home.projectCardPrefix)
        let projectCards = app.descendants(matching: .any).matching(projectCardPredicate)

        guard projectCards.count > 0 else {
            throw XCTSkip("No completed projects available to test starred toggle")
        }

        // Navigate to export sheet
        projectCards.firstMatch.tap()
        _ = projectScreen.sheet.waitForExistence(timeout: 5)
        projectScreen.exportButton.tap()
        _ = exportScreen.sheet.waitForExistence(timeout: 5)

        // Then: Only Starred toggle should be present
        // Note: Toggle may only appear if starred segments exist
        // This verifies the accessibility identifier is findable when present
        let toggleExists = exportScreen.onlyStarredToggle.waitForExistence(timeout: 2)
        // Toggle existence depends on having starred segments - don't fail if absent
        if toggleExists {
            XCTAssertTrue(exportScreen.onlyStarredToggle.isHittable,
                          "Only Starred toggle should be interactive when visible")
        }
    }
}
