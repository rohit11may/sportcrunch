# Codebase Structure

**Analysis Date:** 2026-01-14

## Directory Layout

```
SportCrunch/
├── SportCrunchApp.swift          # App entry point, @main, AppState provider
├── ContentView.swift              # Root navigation (Onboarding ↔ Home)
├── Assets.xcassets/               # App icons, colors, images
│   ├── AccentColor.colorset
│   ├── AppIcon.appiconset
│   ├── SCPrimary.colorset
│   └── SCPrimaryLight.colorset
├── Core/                          # Domain logic & infrastructure
│   ├── Models/                    # Domain models
│   │   ├── Project.swift         # Main data model (~12KB)
│   │   └── Sport.swift           # Sport types, modes, presets (~13KB)
│   └── Services/                  # Core business logic
│       ├── AppState.swift        # Central app state singleton
│       ├── VideoProcessingService.swift  # Main pipeline orchestrator (~30KB)
│       ├── AudioAnalyzer.swift   # Audio signal processing actor (~30KB)
│       ├── VisualValidator.swift # Motion detection actor (~28KB)
│       ├── VideoExporter.swift   # Video composition (~37KB)
│       ├── ProjectStorageService.swift  # Persistence layer
│       ├── BackgroundProcessingManager.swift  # Async job queue
│       ├── DebugReportService.swift  # Diagnostic data capture (~42KB)
│       ├── ProcessingLogger.swift     # Structured logging
│       ├── ProcessingReportManager.swift  # Debug report orchestration (~18KB)
│       ├── ThumbnailService.swift     # Video thumbnail generation
│       └── VideoLoaderService.swift   # Photos library video loading (~15KB)
├── Features/                      # User-facing features (MVVM)
│   ├── Home/
│   │   ├── HomeView.swift        # Project list and creation entry
│   │   ├── CompletedProjectSheet.swift  # Project detail/editing (~32KB)
│   │   └── CompletedProjectViewModel.swift  # Project sheet logic
│   ├── HighlightCreation/
│   │   ├── HighlightCreationFlow.swift  # Multi-step wizard (~17KB)
│   │   ├── VideoSelectionView.swift     # PhotosPicker integration
│   │   ├── SportSelectionView.swift     # Sport selection
│   │   └── TennisModeSelectionView.swift  # Mode selection
│   ├── Settings/
│   │   ├── SettingsView.swift          # User preferences
│   │   └── DebugReportsListView.swift  # Debug report viewer (~21KB)
│   └── Onboarding/
│       └── OnboardingView.swift        # First-run experience
└── Shared/                        # Reusable components
    ├── AccessibilityIdentifiers.swift  # Shared accessibility IDs for UI testing
    ├── Components/
    │   ├── ProjectCard.swift           # Project grid cell
    │   ├── ControllableVideoPlayer.swift  # Video playback
    │   ├── SegmentNavigator.swift      # Segment selection UI with star toggle
    │   ├── HighlightProgressBar.swift  # Processing progress
    │   ├── OriginalTimelineBar.swift   # Timeline reference
    │   ├── PrimaryButton.swift         # Branded button
    │   └── AnimatedBackground.swift    # Background animations
    └── Theme/
        └── AppTheme.swift              # Design system
```

## Test Directory Layout

```
SportCrunchTests/
├── SportCrunchTests.swift         # Unit tests (Swift Testing placeholder)
├── TEST_RESOURCES.md              # Documentation for test resources
├── E2E/                           # End-to-end tests
│   └── SegmentDetectionTests.swift  # Detection accuracy tests (~9KB)
├── Helpers/                       # Test utilities
│   ├── SegmentEvaluator.swift    # IoU-based fuzzy matching (~6KB)
│   └── TestResourceLoader.swift  # Bundle resource loading (~4KB)
├── Models/                        # Test data models
│   └── GroundTruth.swift         # Ground truth segment format
└── TestResources/                 # Test assets (not in git)
    ├── Videos/                    # Test video files (MP4)
    └── GroundTruth/               # Segment annotations (JSON)

SportCrunchUITests/
├── SportCrunchUITests.swift       # UI tests (XCTest placeholder)
├── SportCrunchUITestsLaunchTests.swift  # Launch performance tests
├── E2E/                           # End-to-end UI tests
│   ├── HighlightCreationFlowTests.swift  # Creation wizard tests (~10KB)
│   └── ExportFlowTests.swift     # Export flow tests (~4KB)
├── Helpers/                       # UI test utilities
│   ├── AccessibilityIdentifiers.swift  # Re-export for test target
│   ├── AppScreen.swift           # Screen object patterns (~4KB)
│   └── TestHelpers.swift         # XCTestCase extensions
└── Samples/                       # Sample test videos
```

## Directory Purposes

**Core/**
- Purpose: Domain logic, business rules, infrastructure
- Contains: Models (data structures) and Services (business logic)
- Key files: `AppState.swift` (central state), video processing pipeline services
- Subdirectories: `Models/`, `Services/`
- No UI dependencies (pure Swift/Foundation)

**Core/Models/**
- Purpose: Domain data structures
- Contains: `Codable` structs/enums for domain concepts
- Key files:
  - `Project.swift` - Highlight project with metadata, status, segments
  - `Sport.swift` - Sport types, modes, and detection presets
- No external dependencies

**Core/Services/**
- Purpose: Business logic and data access
- Contains: Service protocols and implementations
- Key services:
  - `VideoProcessingService.swift` - Main orchestrator (~30KB)
  - `AudioAnalyzer.swift` - Audio onset detection (~30KB)
  - `VisualValidator.swift` - Motion validation (~28KB)
  - `VideoExporter.swift` - Video composition (~37KB)
  - `ProjectStorageService.swift` - UserDefaults persistence
  - `BackgroundProcessingManager.swift` - Async job queue
  - `ThumbnailService.swift` - Video thumbnail generation (new)
  - `VideoLoaderService.swift` - Photos library loading with fallback chain (new)
  - `ProcessingReportManager.swift` - Debug report orchestration (new)
- Pattern: Protocol + Real implementation + Mock/Dummy variants

**Features/**
- Purpose: User-facing feature modules
- Contains: Views, ViewModels, and feature-specific logic
- Subdirectories: `Home/`, `HighlightCreation/`, `Settings/`, `Onboarding/`
- Pattern: Each feature is semi-independent with own views/viewmodels

**Features/Home/**
- Purpose: Project list and management
- Key files:
  - `HomeView.swift` - Main project grid
  - `CompletedProjectSheet.swift` - Project detail/editing (significantly expanded)
  - `CompletedProjectViewModel.swift` - Sheet state management (new)

**Features/HighlightCreation/**
- Purpose: Multi-step highlight creation wizard
- Key files:
  - `HighlightCreationFlow.swift` - Step orchestration
  - `VideoSelectionView.swift` - PhotosPicker integration
  - `SportSelectionView.swift` - Sport selection
  - `TennisModeSelectionView.swift` - Mode selection
- Flow: Video → Sport → Mode → Background processing
- Note: `HighlightCreationViewModel` removed; logic moved to Flow

**Features/Settings/**
- Purpose: App settings and developer tools
- Key files:
  - `SettingsView.swift` - Settings screen
  - `DebugReportsListView.swift` - Debug report viewer (significantly expanded)

**Features/Onboarding/**
- Purpose: First-run experience
- Key files: `OnboardingView.swift`

**Shared/**
- Purpose: Reusable UI components and design system
- Contains: Components, theme definitions, and accessibility identifiers
- Subdirectories: `Components/`, `Theme/`
- Pattern: Stateless components, theme constants
- New: `AccessibilityIdentifiers.swift` - Shared enum for UI testing

**Shared/Components/**
- Purpose: Reusable UI building blocks
- Examples:
  - `ProjectCard.swift` - Project grid cell
  - `ControllableVideoPlayer.swift` - Full-screen video player
  - `SegmentNavigator.swift` - Segment chips with star toggle functionality
  - `PrimaryButton.swift` - Branded button style
  - `HighlightProgressBar.swift` - Processing progress indicator

**Shared/Theme/**
- Purpose: Design system constants
- Key file: `AppTheme.swift`
- Contains: Colors, typography, spacing, gradients, corner radii

## Key File Locations

**Entry Points:**
- App entry: `SportCrunchApp.swift`
- Root view: `ContentView.swift`
- Feature roots: `HomeView.swift`, `HighlightCreationFlow.swift`

**Configuration:**
- Xcode project: `SportCrunch.xcodeproj/project.pbxproj`
- Asset catalog: `Assets.xcassets/`
- Build script: `launch.sh`
- Git ignore: `.gitignore`

**Core Logic:**
- Video processing: `Core/Services/VideoProcessingService.swift`
- Audio analysis: `Core/Services/AudioAnalyzer.swift`
- Visual validation: `Core/Services/VisualValidator.swift`
- Video export: `Core/Services/VideoExporter.swift`
- Persistence: `Core/Services/ProjectStorageService.swift`
- Video loading: `Core/Services/VideoLoaderService.swift`
- Thumbnails: `Core/Services/ThumbnailService.swift`

**Testing:**
- Unit tests: `SportCrunchTests/`
  - E2E detection: `E2E/SegmentDetectionTests.swift`
  - Test helpers: `Helpers/SegmentEvaluator.swift`, `TestResourceLoader.swift`
  - Test models: `Models/GroundTruth.swift`
- UI tests: `SportCrunchUITests/`
  - E2E flows: `E2E/HighlightCreationFlowTests.swift`, `ExportFlowTests.swift`
  - Screen objects: `Helpers/AppScreen.swift`
  - Test helpers: `Helpers/TestHelpers.swift`

**Accessibility:**
- Shared identifiers: `Shared/AccessibilityIdentifiers.swift`
- Test re-export: `SportCrunchUITests/Helpers/AccessibilityIdentifiers.swift`

**Documentation:**
- Test resources guide: `SportCrunchTests/TEST_RESOURCES.md`

## Naming Conventions

**Files:**
- PascalCase for all Swift files
- Pattern: `{Name}{Type}.swift`
- Examples: `HomeView.swift`, `ProjectStorageService.swift`, `CompletedProjectViewModel.swift`
- Suffixes: `View`, `ViewModel`, `Service`, `Sheet`, `Flow`

**Directories:**
- PascalCase for feature directories: `Home`, `Settings`, `HighlightCreation`
- PascalCase for semantic groupings: `Core`, `Models`, `Services`, `Shared`, `Components`, `Theme`
- Test directories: `E2E`, `Helpers`, `Models`, `TestResources`, `Samples`

**Special Patterns:**
- `*App.swift` - Application entry point
- `*Service.swift` - Service implementations
- `*Protocol` suffix - Protocol definitions (implied in service files)
- `Mock*` / `Dummy*` prefix - Test/preview implementations
- `*Tests.swift` - Test files
- `*Screen.swift` - Screen object patterns for UI testing

## Where to Add New Code

**New Feature:**
- Primary code: `SportCrunch/Features/{FeatureName}/`
- ViewModel: `Features/{FeatureName}/{FeatureName}ViewModel.swift`
- Views: `Features/{FeatureName}/*.swift`
- UI tests: `SportCrunchUITests/E2E/{FeatureName}Tests.swift`

**New Service:**
- Implementation: `Core/Services/{Name}Service.swift`
- Protocol: Define in same file as implementation
- Mock: Include mock implementation in same file or separate for complex services
- Unit tests: `SportCrunchTests/{Name}ServiceTests.swift`

**New Model:**
- Implementation: `Core/Models/{Name}.swift`
- Make `Codable` if needs persistence
- Add sample data for previews

**New UI Component:**
- Implementation: `Shared/Components/{Name}.swift`
- Make reusable and stateless if possible
- Support both light/dark mode
- Add accessibility identifiers in `AccessibilityIdentifiers.swift`

**New Sport:**
- Extend `Sport` enum in `Core/Models/Sport.swift`
- Add `AnalysisPreset` configuration
- Update sport selection UI in `SportSelectionView.swift`

**New UI Test:**
- Create screen object in `SportCrunchUITests/Helpers/AppScreen.swift`
- Add accessibility IDs to `Shared/AccessibilityIdentifiers.swift`
- Create test file in `SportCrunchUITests/E2E/`

**New E2E Detection Test:**
- Add test video to `SportCrunchTests/TestResources/Videos/`
- Add ground truth JSON to `SportCrunchTests/TestResources/GroundTruth/`
- Create test in `SportCrunchTests/E2E/`

## Special Directories

**Assets.xcassets/**
- Purpose: Asset catalog for images, colors, icons
- Source: Managed by Xcode
- Committed: Yes (part of project)

**build/**
- Purpose: Xcode build artifacts
- Source: Generated by xcodebuild
- Committed: No (in `.gitignore`)

**TestResources/**
- Purpose: Test video files and ground truth annotations
- Location: `SportCrunchTests/TestResources/`
- Committed: Selective (large videos excluded)

**Samples/**
- Purpose: Sample videos for UI testing
- Location: `SportCrunchUITests/Samples/`
- Committed: Selective

**Documents/** (Runtime, not in repo)
- Purpose: App sandbox directory (runtime only)
- Contains: `Highlights/` (video files), `DebugReports/` (JSON files)
- Location: iOS app sandbox on device
- Not in version control

---

*Structure analysis: 2026-01-14*
*Update when directory structure changes*
