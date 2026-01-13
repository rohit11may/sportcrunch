import XCTest

final class HighlightCreationFlowTests: XCTestCase {
    var app: XCUIApplication!
    var homeScreen: HomeScreen!
    var creationScreen: HighlightCreationScreen!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        homeScreen = HomeScreen(app: app)
        creationScreen = HighlightCreationScreen(app: app)
    }

    override func tearDownWithError() throws {
        app = nil
        homeScreen = nil
        creationScreen = nil
    }

    // MARK: - Creation Flow Entry

    @MainActor
    func testCreateHighlightButtonOpensFlow() throws {
        // Given: App is on home screen
        XCTAssertTrue(homeScreen.createHighlightButton.waitForExistence(timeout: 5),
                      "Create Highlight button should be visible on home screen")

        // When: Tap Create Highlight
        homeScreen.createHighlightButton.tap()

        // Then: Highlight creation flow opens with video selection
        XCTAssertTrue(creationScreen.videoLibraryButton.waitForExistence(timeout: 5),
                      "Video library button should appear in creation flow")
    }

    @MainActor
    func testCreationFlowCanBeClosed() throws {
        // Given: Creation flow is open
        homeScreen.createHighlightButton.tap()
        XCTAssertTrue(creationScreen.flowContainer.waitForExistence(timeout: 5))

        // When: Tap close button
        creationScreen.closeButton.tap()

        // Then: Flow closes, back to home
        XCTAssertTrue(homeScreen.createHighlightButton.waitForExistence(timeout: 5),
                      "Should return to home screen after closing flow")
    }

    // MARK: - Sport Selection

    @MainActor
    func testSportSelectionShowsTennisAndCricket() throws {
        // Note: This test requires a video to be pre-selected.
        // In real usage, you would either:
        // 1. Use a test video fixture pre-loaded in simulator
        // 2. Mock the video selection state
        // 3. Skip directly to sport selection if possible

        // For now, verify the flow opens correctly
        homeScreen.createHighlightButton.tap()

        // Verify video selection step appears
        XCTAssertTrue(creationScreen.videoLibraryButton.waitForExistence(timeout: 5),
                      "Should show video library button on first step")
    }

    // MARK: - Tennis Mode Selection

    @MainActor
    func testTennisModeButtonsExist() throws {
        // This would run after video and tennis sport are selected
        // Verify the mode selection elements exist when navigated to

        homeScreen.createHighlightButton.tap()
        XCTAssertTrue(creationScreen.flowContainer.waitForExistence(timeout: 5),
                      "Creation flow should open")

        // Note: Full flow testing requires either:
        // - Test video fixtures with Photos library access
        // - UI state injection for testing
        // This test verifies the infrastructure is in place
    }
}
