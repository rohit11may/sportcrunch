import XCTest

final class ExportFlowTests: XCTestCase {
    var app: XCUIApplication!
    var homeScreen: HomeScreen!
    var projectScreen: CompletedProjectScreen!
    var exportScreen: ExportScreen!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()

        // Inject mock completed projects for testing
        app.launchArguments.append("-injectMockProjects")

        app.launch()

        // Force portrait orientation
        XCUIDevice.shared.orientation = .portrait

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
        // Given: A completed project exists on home screen (injected via launch argument)
        // Verify home screen loads
        XCTAssertTrue(homeScreen.createHighlightButton.waitForExistence(timeout: 5),
                      "Home screen should be visible")

        // Look for any project card using shared constant prefix
        let projectCardPredicate = NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Home.projectCardPrefix)
        let projectCards = app.descendants(matching: .any).matching(projectCardPredicate)

        // Wait for project cards to appear (mock data is injected)
        XCTAssertTrue(projectCards.firstMatch.waitForExistence(timeout: 5),
                      "Project card should exist (mock data injected)")

        // When: Tap the project card
        let firstCard = projectCards.firstMatch
        firstCard.tap()

        // Then: Project sheet opens
        XCTAssertTrue(projectScreen.sheet.waitForExistence(timeout: 5),
                      "Completed project sheet should open when tapping project card")
    }

    @MainActor
    func testExportSheetShowsSaveAndShareOptions() throws {
        // Given: A completed project exists (injected via launch argument)
        let projectCardPredicate = NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Home.projectCardPrefix)
        let projectCards = app.descendants(matching: .any).matching(projectCardPredicate)

        XCTAssertTrue(projectCards.firstMatch.waitForExistence(timeout: 5),
                      "Project card should exist (mock data injected)")

        // Navigate to export sheet
        projectCards.firstMatch.tap()
        XCTAssertTrue(projectScreen.sheet.waitForExistence(timeout: 5),
                      "Project sheet should open")

        projectScreen.exportButton.tap()
        XCTAssertTrue(exportScreen.sheet.waitForExistence(timeout: 5),
                      "Export sheet should open")

        // Then: Verify export options are present
        XCTAssertTrue(exportScreen.saveCameraRollButton.waitForExistence(timeout: 3),
                      "Save to Camera Roll button should be visible")
        XCTAssertTrue(exportScreen.shareButton.exists,
                      "Share button should be visible")
        // Then: Only Starred toggle should be present (mock project has starred segments)
        XCTAssertTrue(exportScreen.onlyStarredToggle.waitForExistence(timeout: 3),
                      "Only Starred toggle should be visible (mock project has starred segments)")
    }
}
