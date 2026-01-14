import XCTest

final class HighlightCreationFlowTests: XCTestCase {
    var app: XCUIApplication!
    var homeScreen: HomeScreen!
    var creationScreen: HighlightCreationScreen!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()

        // Enable test mode to inject sample video instead of using PhotosPicker
        app.launchArguments.append("-isTestingVideoFlow")

        // Copy sample video from test bundle to a location the app can access
        let testBundle = Bundle(for: type(of: self))
        if let sampleURL = testBundle.url(forResource: "sample", withExtension: "mp4") {
            let sharedURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("test_sample.mp4")
            try? FileManager.default.removeItem(at: sharedURL)
            try? FileManager.default.copyItem(at: sampleURL, to: sharedURL)
            app.launchEnvironment["TEST_VIDEO_PATH"] = sharedURL.path
        }

        app.launch()

        // Force portrait orientation
        XCUIDevice.shared.orientation = .portrait

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
        // First verify the flow container appears
        let flowContainer = app.descendants(matching: .any)[AccessibilityID.Creation.flowContainer]
        XCTAssertTrue(flowContainer.waitForExistence(timeout: 10),
                      "Creation flow container should appear")

        // Then check for the video library button
        let videoLibraryButton = app.descendants(matching: .any)[AccessibilityID.Creation.videoLibraryButton]

        // Debug: Print the element hierarchy if button doesn't exist
        if !videoLibraryButton.exists {
            print("=== DEBUG: Video library button not found ===")
            print("Flow container exists: \(flowContainer.exists)")
            print("App hierarchy: \(app.debugDescription)")
        }

        XCTAssertTrue(videoLibraryButton.waitForExistence(timeout: 5),
                      "Video library button should appear in creation flow")
    }

    @MainActor
    func testCreationFlowCanBeClosed() throws {
        // Given: Creation flow is open
        homeScreen.createHighlightButton.tap()
        XCTAssertTrue(creationScreen.flowContainer.waitForExistence(timeout: 10))

        // When: Tap close button (use firstMatch to handle potential duplicates)
        let closeButton = app.buttons[AccessibilityID.Creation.closeButton].firstMatch
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5), "Close button should exist")
        closeButton.tap()

        // Then: Flow closes, back to home
        XCTAssertTrue(homeScreen.createHighlightButton.waitForExistence(timeout: 5),
                      "Should return to home screen after closing flow")
    }

    // MARK: - Sport Selection

    @MainActor
    func testSportSelectionShowsTennisAndCricket() throws {
        // Given: App is on home screen
        XCTAssertTrue(homeScreen.createHighlightButton.waitForExistence(timeout: 5),
                      "Create Highlight button should be visible")

        // When: Open creation flow and inject test video
        homeScreen.createHighlightButton.tap()
        XCTAssertTrue(creationScreen.flowContainer.waitForExistence(timeout: 10),
                      "Creation flow should open")

        // Then check for the video library button
        XCTAssertTrue(creationScreen.videoLibraryButton.waitForExistence(timeout: 5),
                      "Video library button should appear")
        
        // Tap the test video button (which will inject the sample video)
        creationScreen.videoLibraryButton.tap()

        // Then: Sport selection screen appears with Tennis and Cricket buttons
        XCTAssertTrue(creationScreen.videoPreview.waitForExistence(timeout: 10),
                      "Video preview should appear after video injection")

        XCTAssertTrue(creationScreen.tennisButton.waitForExistence(timeout: 5),
                      "Tennis button should be visible on sport selection screen")

        XCTAssertTrue(creationScreen.cricketButton.waitForExistence(timeout: 5),
                      "Cricket button should be visible on sport selection screen")
    }

    // MARK: - Tennis Mode Selection

    @MainActor
    func testTennisModeButtonsExist() throws {
        // Given: App is on home screen
        XCTAssertTrue(homeScreen.createHighlightButton.waitForExistence(timeout: 5),
                      "Create Highlight button should be visible")

        // When: Open creation flow, inject test video, and select Tennis
        homeScreen.createHighlightButton.tap()
        XCTAssertTrue(creationScreen.flowContainer.waitForExistence(timeout: 10),
                      "Creation flow should open")

        // Inject test video
        XCTAssertTrue(creationScreen.videoLibraryButton.waitForExistence(timeout: 5),
                      "Video library button should appear")
        creationScreen.videoLibraryButton.tap()

        // Wait for sport selection to appear and select Tennis
        XCTAssertTrue(creationScreen.tennisButton.waitForExistence(timeout: 10),
                      "Tennis button should appear after video injection")
        creationScreen.tennisButton.tap()

        // Then: Tennis mode selection screen appears with Rally and Shot mode buttons
        XCTAssertTrue(creationScreen.rallyModeButton.waitForExistence(timeout: 5),
                      "Rally mode button should appear on tennis mode selection screen")

        XCTAssertTrue(creationScreen.shotModeButton.waitForExistence(timeout: 5),
                      "Shot mode button should appear on tennis mode selection screen")
        
        // Verify Crunch button does not appear until a mode is selected
        XCTAssertFalse(creationScreen.crunchButton.exists,
                       "Crunch button should not appear until a mode is selected")
        
        
        creationScreen.shotModeButton.tap()
        
        XCTAssertTrue(creationScreen.crunchButton.waitForExistence(timeout: 3),
                      "Crunch button should appear after a mode is selected")
    }
    
    @MainActor
    func testHighlightCreationIsTriggered() throws {
        // Given: App is on home screen
        XCTAssertTrue(homeScreen.createHighlightButton.waitForExistence(timeout: 5),
                      "Create Highlight button should be visible")

        // When: Open creation flow, inject test video, and select Tennis
        homeScreen.createHighlightButton.tap()
        XCTAssertTrue(creationScreen.flowContainer.waitForExistence(timeout: 10),
                      "Creation flow should open")

        // Inject test video
        XCTAssertTrue(creationScreen.videoLibraryButton.waitForExistence(timeout: 5),
                      "Video library button should appear")
        creationScreen.videoLibraryButton.tap()

        // Wait for sport selection to appear and select Tennis
        XCTAssertTrue(creationScreen.tennisButton.waitForExistence(timeout: 10),
                      "Tennis button should appear after video injection")
        creationScreen.tennisButton.tap()

        // Then: Tennis mode selection screen appears with Rally and Shot mode buttons
        XCTAssertTrue(creationScreen.rallyModeButton.waitForExistence(timeout: 5),
                      "Rally mode button should appear on tennis mode selection screen")

        XCTAssertTrue(creationScreen.shotModeButton.waitForExistence(timeout: 5),
                      "Shot mode button should appear on tennis mode selection screen")
        
        // Verify Crunch button does not appear until a mode is selected
        XCTAssertFalse(creationScreen.crunchButton.exists,
                       "Crunch button should not appear until a mode is selected")
        
        
        creationScreen.shotModeButton.tap()
        
        XCTAssertTrue(creationScreen.crunchButton.waitForExistence(timeout: 3),
                      "Crunch button should appear after a mode is selected")
        
        creationScreen.crunchButton.tap()

        // Wait for the creation flow to dismiss (flow container should disappear)
        let flowDismissed = creationScreen.flowContainer.waitForNonExistence(timeout: 10)
        XCTAssertTrue(flowDismissed, "Creation flow should dismiss after tapping Crunch")

        // Verify that we're back on the home screen
        XCTAssertTrue(homeScreen.createHighlightButton.waitForExistence(timeout: 5),
                      "Should return to home screen after triggering highlight creation")

        // Verify that a project card is created on the home screen
        let projectCardPredicate = NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Home.projectCardPrefix)
        let projectCards = app.descendants(matching: .any).matching(projectCardPredicate)

        // Wait for the project card to appear (may take a moment for storage to save)
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "count > 0"),
            object: projectCards
        )

        let result = XCTWaiter.wait(for: [expectation], timeout: 10)
        XCTAssertEqual(result, .completed, "A project card should be created after triggering highlight creation")

        // Verify the project card is visible
        XCTAssertTrue(projectCards.firstMatch.exists,
                      "Project card should be visible on home screen after highlight creation is triggered")
    }
}
