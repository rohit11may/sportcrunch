//
//  AppScreen.swift
//  SportCrunchUITests
//
//  Screen object helpers for E2E tests using accessibility identifiers.
//

import XCTest

// MARK: - XCUIElement Extensions

extension XCUIElement {
  /// Waits for the element to no longer exist in the hierarchy
  /// - Parameter timeout: Maximum time to wait
  /// - Returns: true if the element no longer exists within the timeout
  func waitForNonExistence(timeout: TimeInterval) -> Bool {
    let predicate = NSPredicate(format: "exists == false")
    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
    let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
    return result == .completed
  }
}

/// Base protocol for screen objects providing semantic element access
protocol AppScreen {
  var app: XCUIApplication { get }
}

extension AppScreen {
  /// Find element by accessibility identifier with wait
  func element(_ identifier: String, timeout: TimeInterval = 5) -> XCUIElement {
    let element = app.descendants(matching: .any)[identifier]
    _ = element.waitForExistence(timeout: timeout)
    return element
  }
}

// MARK: - Home Screen

struct HomeScreen: AppScreen {
  let app: XCUIApplication

  var createHighlightButton: XCUIElement {
    element(AccessibilityID.Home.createHighlightButton)
  }
}

// MARK: - Highlight Creation Flow

struct HighlightCreationScreen: AppScreen {
  let app: XCUIApplication

  var flowContainer: XCUIElement { element(AccessibilityID.Creation.flowContainer) }

  // Video selection
  var videoLibraryButton: XCUIElement { element(AccessibilityID.Creation.videoLibraryButton) }

  // Sport selection
  var tennisButton: XCUIElement { element(AccessibilityID.Creation.sportTennisButton) }
  var cricketButton: XCUIElement { element(AccessibilityID.Creation.sportCricketButton) }
  var videoPreview: XCUIElement { element(AccessibilityID.Creation.videoPreview) }

  // Tennis mode selection
  var rallyModeButton: XCUIElement { element(AccessibilityID.Creation.modeRallyButton) }
  var shotModeButton: XCUIElement { element(AccessibilityID.Creation.modeShotButton) }
  var crunchButton: XCUIElement { element(AccessibilityID.Creation.crunchButton) }
}

// MARK: - Completed Project Sheet

struct CompletedProjectScreen: AppScreen {
  let app: XCUIApplication

  var sheet: XCUIElement { element(AccessibilityID.Project.sheet) }
  var exportButton: XCUIElement {
    // Toolbar items are best found via .buttons query
    let button = app.buttons[AccessibilityID.Project.exportButton]
    return button.waitForExistence(timeout: 2)
      ? button : element(AccessibilityID.Project.exportButton)
  }
}

// MARK: - Export Sheet

struct ExportScreen: AppScreen {
  let app: XCUIApplication

  var sheet: XCUIElement { element(AccessibilityID.Export.sheet) }
  var onlyStarredToggle: XCUIElement { element(AccessibilityID.Export.onlyStarredToggle) }
  var saveCameraRollButton: XCUIElement { element(AccessibilityID.Export.saveCameraRollButton) }
  var shareButton: XCUIElement { element(AccessibilityID.Export.shareButton) }
}
