---
phase: 02-core-e2e-test-coverage
plan: 01
subsystem: testing, ui
tags: [accessibility, xcuitest, swiftui, e2e]

# Dependency graph
requires:
  - phase: 01-test-infrastructure
    provides: XCTest framework patterns
provides:
  - Shared AccessibilityIdentifiers.swift constants
  - Screen object pattern for E2E tests
  - Semantic element discovery via accessibility IDs
affects: [02-02, 02-03, e2e-tests, ui-refactoring]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Enum-based shared constants for accessibility identifiers
    - Screen object pattern with AppScreen protocol
    - Symlinked files for cross-target sharing

key-files:
  created:
    - SportCrunch/Shared/AccessibilityIdentifiers.swift
    - SportCrunchUITests/Helpers/AppScreen.swift
    - SportCrunchUITests/Helpers/TestHelpers.swift
  modified:
    - SportCrunch/Features/Home/HomeView.swift
    - SportCrunch/Features/HighlightCreation/HighlightCreationFlow.swift
    - SportCrunch/Features/HighlightCreation/VideoSelectionView.swift
    - SportCrunch/Features/HighlightCreation/SportSelectionView.swift
    - SportCrunch/Features/HighlightCreation/TennisModeSelectionView.swift
    - SportCrunch/Features/Home/CompletedProjectSheet.swift

key-decisions:
  - "Symlink AccessibilityIdentifiers.swift to UITests instead of duplicating"
  - "Screen object pattern with typed properties for each element"

patterns-established:
  - "AccessibilityID.{Screen}.{element} naming convention"
  - "AppScreen protocol with element() and exists() helpers"

issues-created: []

# Metrics
duration: 5min
completed: 2026-01-13
---

# Phase 2 Plan 1: Accessibility Infrastructure Summary

**Shared AccessibilityIdentifiers.swift with enum-based constants for all critical UI elements, plus screen object helpers for E2E test element discovery**

## Performance

- **Duration:** 5 min
- **Started:** 2026-01-13T12:03:59Z
- **Completed:** 2026-01-13T12:09:18Z
- **Tasks:** 3
- **Files modified:** 9

## Accomplishments

- Created single-source-of-truth AccessibilityIdentifiers.swift with nested enums for Home, Creation, Project, and Export screens
- Added .accessibilityIdentifier() modifiers to all critical interactive elements across 6 SwiftUI view files
- Created AppScreen protocol with screen objects (HomeScreen, HighlightCreationScreen, etc.) for semantic E2E element access
- Symlinked constants file to UITests target to avoid code duplication

## Task Commits

Each task was committed atomically:

1. **Task 1: Create shared AccessibilityIdentifiers constants** - `66d5109` (feat)
2. **Task 2: Add accessibility identifiers to views** - `c6b1d3c` (feat)
3. **Task 3: Create E2E test helpers** - `e655dd3` (feat)

**Plan metadata:** (pending)

## Files Created/Modified

- `SportCrunch/Shared/AccessibilityIdentifiers.swift` - Enum-based shared constants for accessibility IDs
- `SportCrunchUITests/Helpers/AppScreen.swift` - Screen object protocol and implementations
- `SportCrunchUITests/Helpers/TestHelpers.swift` - XCTestCase extensions for waitForHittable/waitForDisappear
- `SportCrunchUITests/Helpers/AccessibilityIdentifiers.swift` - Symlink to shared constants
- `HomeView.swift` - Added IDs for createHighlightButton, settingsButton, emptyStateView, projectCard
- `HighlightCreationFlow.swift` - Added IDs for flowContainer, backButton, closeButton
- `VideoSelectionView.swift` - Added ID for videoLibraryButton
- `SportSelectionView.swift` - Added IDs for sportTennisButton, sportCricketButton, videoPreview
- `TennisModeSelectionView.swift` - Added IDs for modeRallyButton, modeShotButton, crunchButton
- `CompletedProjectSheet.swift` - Added IDs for sheet, videoPlayer, progressBar, segmentNavigator, filterToggle, exportButton, and export sheet elements

## Decisions Made

- Used symlink instead of file duplication for sharing AccessibilityIdentifiers.swift between app and UITests targets - keeps single source of truth while avoiding manual Xcode project file modifications
- Adopted screen object pattern with typed properties - tests read naturally (e.g., `homeScreen.createHighlightButton.tap()`)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## Next Step

Ready for 02-02-PLAN.md: E2E Test Implementation
