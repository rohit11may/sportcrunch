//
//  AccessibilityIdentifiers.swift
//  SportCrunch
//
//  Shared accessibility identifiers used by both app views and UI tests.
//  Single source of truth - no string duplication between targets.
//

import Foundation

/// Shared accessibility identifiers used by both app views and UI tests.
/// Single source of truth - no string duplication between targets.
enum AccessibilityID {

    // MARK: - Home Screen

    enum Home {
        static let createHighlightButton = "home_createHighlight"
        static let settingsButton = "home_settings"
        static let emptyStateView = "home_emptyState"

        /// Dynamic identifier for project cards: "home_projectCard_{uuid}"
        static func projectCard(id: String) -> String {
            "home_projectCard_\(id)"
        }

        /// Prefix for matching any project card
        static let projectCardPrefix = "home_projectCard_"
    }

    // MARK: - Highlight Creation Flow

    enum Creation {
        static let flowContainer = "creation_flow"
        static let backButton = "creation_back"
        static let closeButton = "creation_close"

        // Video selection step
        static let videoLibraryButton = "creation_videoLibrary"

        // Sport selection step
        static let sportTennisButton = "creation_sport_tennis"
        static let sportCricketButton = "creation_sport_cricket"
        static let videoPreview = "creation_videoPreview"

        // Tennis mode selection step
        static let modeRallyButton = "creation_mode_rally"
        static let modeShotButton = "creation_mode_shot"
        static let crunchButton = "creation_crunch"
    }

    // MARK: - Completed Project Sheet

    enum Project {
        static let sheet = "project_sheet"
        static let videoPlayer = "project_videoPlayer"
        static let progressBar = "project_progressBar"
        static let segmentNavigator = "project_segmentNavigator"
        static let filterToggle = "project_filterToggle"
        static let exportButton = "project_export"
    }

    // MARK: - Export Sheet

    enum Export {
        static let sheet = "export_sheet"
        static let onlyStarredToggle = "export_onlyStarred"
        static let saveCameraRollButton = "export_saveCameraRoll"
        static let shareButton = "export_share"
        static let doneButton = "export_done"
    }
}
