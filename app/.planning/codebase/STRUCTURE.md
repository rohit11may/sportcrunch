# Codebase Structure

**Analysis Date:** 2026-01-10

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
│   │   ├── Project.swift         # Main data model (346 lines)
│   │   └── Sport.swift           # Sport types, modes, presets (386 lines)
│   └── Services/                  # Core business logic
│       ├── AppState.swift        # Central app state singleton
│       ├── VideoProcessingService.swift  # Main pipeline orchestrator (884 lines)
│       ├── AudioAnalyzer.swift   # Audio signal processing actor (724 lines)
│       ├── VisualValidator.swift # Motion detection actor (653 lines)
│       ├── VideoExporter.swift   # Video composition (849 lines)
│       ├── ProjectStorageService.swift  # Persistence layer
│       ├── BackgroundProcessingManager.swift  # Async job queue
│       ├── DebugReportService.swift  # Diagnostic data capture (1142 lines)
│       └── ProcessingLogger.swift     # Structured logging
├── Features/                      # User-facing features (MVVM)
│   ├── Home/
│   │   ├── HomeView.swift        # Project list and creation entry
│   │   ├── HomeViewModel.swift   # Home screen logic
│   │   └── CompletedProjectSheet.swift  # Project detail view
│   ├── HighlightCreation/
│   │   ├── HighlightCreationFlow.swift  # Multi-step wizard
│   │   ├── HighlightCreationViewModel.swift
│   │   ├── VideoSelectionView.swift     # PhotosPicker integration
│   │   ├── SportSelectionView.swift     # Sport selection
│   │   └── TennisModeSelectionView.swift  # Mode selection
│   ├── Settings/
│   │   ├── SettingsView.swift          # User preferences
│   │   └── DebugReportsListView.swift  # Debug report viewer
│   └── Onboarding/
│       └── OnboardingView.swift        # First-run experience
└── Shared/                        # Reusable components
    ├── Components/
    │   ├── ProjectCard.swift           # Project grid cell
    │   ├── ControllableVideoPlayer.swift  # Video playback
    │   ├── SegmentNavigator.swift      # Segment selection UI
    │   ├── HighlightProgressBar.swift  # Processing progress
    │   ├── OriginalTimelineBar.swift   # Timeline reference
    │   ├── PrimaryButton.swift         # Branded button
    │   └── AnimatedBackground.swift    # Background animations
    └── Theme/
        └── AppTheme.swift              # Design system
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
  - `VideoProcessingService.swift` - Main orchestrator (884 lines)
  - `AudioAnalyzer.swift` - Audio onset detection (724 lines)
  - `VisualValidator.swift` - Motion validation (653 lines)
  - `VideoExporter.swift` - Video composition (849 lines)
  - `ProjectStorageService.swift` - UserDefaults persistence
  - `BackgroundProcessingManager.swift` - Async job queue
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
  - `HomeViewModel.swift` - State management
  - `CompletedProjectSheet.swift` - Project detail/editing

**Features/HighlightCreation/**
- Purpose: Multi-step highlight creation wizard
- Key files:
  - `HighlightCreationFlow.swift` - Step orchestration
  - `VideoSelectionView.swift` - PhotosPicker integration
  - `SportSelectionView.swift` - Sport selection
  - `TennisModeSelectionView.swift` - Mode selection
- Flow: Video → Sport → Mode → Background processing

**Features/Settings/**
- Purpose: App settings and developer tools
- Key files:
  - `SettingsView.swift` - Settings screen
  - `DebugReportsListView.swift` - Debug report viewer

**Features/Onboarding/**
- Purpose: First-run experience
- Key files: `OnboardingView.swift`

**Shared/**
- Purpose: Reusable UI components and design system
- Contains: Components and theme definitions
- Subdirectories: `Components/`, `Theme/`
- Pattern: Stateless components, theme constants

**Shared/Components/**
- Purpose: Reusable UI building blocks
- Examples:
  - `ProjectCard.swift` - Project grid cell
  - `ControllableVideoPlayer.swift` - Full-screen video player
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

**Testing:**
- Unit tests: `SportCrunchTests/SportCrunchTests.swift`
- UI tests: `SportCrunchUITests/SportCrunchUITests.swift`

**Documentation:**
- Technical deep dive: `prototype/TECHNICAL.md`
- Prototype README: `prototype/README.md`

## Naming Conventions

**Files:**
- PascalCase for all Swift files
- Pattern: `{Name}{Type}.swift`
- Examples: `HomeView.swift`, `ProjectStorageService.swift`, `HighlightCreationViewModel.swift`
- Suffixes: `View`, `ViewModel`, `Service`, `Sheet`, `Flow`

**Directories:**
- PascalCase for feature directories: `Home`, `Settings`, `HighlightCreation`
- PascalCase for semantic groupings: `Core`, `Models`, `Services`, `Shared`, `Components`, `Theme`

**Special Patterns:**
- `*App.swift` - Application entry point
- `*Service.swift` - Service implementations
- `*Protocol` suffix - Protocol definitions (implied in service files)
- `Mock*` / `Dummy*` prefix - Test/preview implementations

## Where to Add New Code

**New Feature:**
- Primary code: `SportCrunch/Features/{FeatureName}/`
- ViewModel: `Features/{FeatureName}/{FeatureName}ViewModel.swift`
- Views: `Features/{FeatureName}/*.swift`
- Tests: `SportCrunchTests/{FeatureName}Tests.swift`

**New Service:**
- Implementation: `Core/Services/{Name}Service.swift`
- Protocol: Define in same file as implementation
- Mock: Include mock implementation in same file or separate for complex services
- Tests: `SportCrunchTests/{Name}ServiceTests.swift`

**New Model:**
- Implementation: `Core/Models/{Name}.swift`
- Make `Codable` if needs persistence
- Add sample data for previews

**New UI Component:**
- Implementation: `Shared/Components/{Name}.swift`
- Make reusable and stateless if possible
- Support both light/dark mode

**New Sport:**
- Extend `Sport` enum in `Core/Models/Sport.swift`
- Add `AnalysisPreset` configuration
- Update sport selection UI in `SportSelectionView.swift`

## Special Directories

**Assets.xcassets/**
- Purpose: Asset catalog for images, colors, icons
- Source: Managed by Xcode
- Committed: Yes (part of project)

**prototype/**
- Purpose: Python research prototype for algorithm development
- Source: Separate Python project
- Committed: Yes (for reference)
- Not part of iOS build

**build/**
- Purpose: Xcode build artifacts
- Source: Generated by xcodebuild
- Committed: No (in `.gitignore`)

**Documents/** (Runtime, not in repo)
- Purpose: App sandbox directory (runtime only)
- Contains: `Highlights/` (video files), `DebugReports/` (JSON files)
- Location: iOS app sandbox on device
- Not in version control

---

*Structure analysis: 2026-01-10*
*Update when directory structure changes*
