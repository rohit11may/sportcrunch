# Architecture

**Analysis Date:** 2026-01-10

## Pattern Overview

**Overall:** Clean MVVM Architecture with Protocol-Oriented Service Layer

**Key Characteristics:**
- Feature-based SwiftUI application
- MVVM pattern with `@Observable` ViewModels
- Protocol-based dependency injection for testability
- Actor-based concurrency for thread safety
- Background processing with async/await

## Layers

**Presentation Layer (SwiftUI Views):**
- Purpose: User interface and interaction handling
- Contains: View structs, UI components, navigation flows
- Location: `SportCrunch/Features/`, `SportCrunch/Shared/Components/`
- Depends on: ViewModels, AppState (via environment objects)
- Used by: iOS runtime (SwiftUI)

**ViewModel Layer:**
- Purpose: Business logic and presentation state management
- Contains: `@Observable` classes with UI state and event handlers
- Examples: `HomeViewModel`, `HighlightCreationViewModel`
- Depends on: Services (via protocols)
- Used by: Views (observation)

**Service Layer:**
- Purpose: Core business logic and data access
- Contains: Protocol definitions and implementations
- Location: `SportCrunch/Core/Services/`
- Depends on: Models, system frameworks (AVFoundation, Accelerate)
- Used by: ViewModels, AppState
- Key services:
  - `VideoProcessingServiceProtocol` → `RealVideoProcessingService` / `DummyVideoProcessingService`
  - `ProjectStorageServiceProtocol` → `UserDefaultsProjectStorageService` / `MockProjectStorageService`
  - `AudioAnalyzer` (actor) - Thread-safe audio processing
  - `VisualValidator` (actor) - Thread-safe video validation
  - `VideoExporter` - AVFoundation video composition
  - `BackgroundProcessingManager` - Async job orchestration

**Domain Layer (Models):**
- Purpose: Data structures and domain logic
- Contains: Codable structs/enums representing domain concepts
- Location: `SportCrunch/Core/Models/`
- Examples: `Project`, `Sport`, `ActionSegment`, `ProcessingStatus`, `AnalysisPreset`
- Depends on: Foundation only
- Used by: All layers

**Shared Layer:**
- Purpose: Reusable UI components and design system
- Contains: Stateless/stateful UI components, theme definitions
- Location: `SportCrunch/Shared/`
- Examples: `PrimaryButton`, `ProjectCard`, `ControllableVideoPlayer`, `AppTheme`
- Depends on: Models for display
- Used by: Feature views

## Data Flow

**Highlight Creation Flow:**

1. User taps "Create Highlight" in `HomeView`
2. `HighlightCreationFlow` presented as full-screen cover
3. Multi-step wizard:
   - Step 1: `VideoSelectionView` → PhotosPicker → User selects video
   - Step 2: `SportSelectionView` → User chooses sport (Tennis/Cricket)
   - Step 3: `TennisModeSelectionView` → User selects mode (Rally/Shot)
4. `HighlightCreationViewModel.startProcessing()` called:
   - Creates `Project` with `.pending` status
   - Saves to `ProjectStorageService`
   - Queues with `BackgroundProcessingManager`
5. Background processing pipeline:
   - `BackgroundProcessingManager.queueProcessing()` spawns async Task
   - Task calls `VideoProcessingService.processVideo()`
   - Progress/status updates via Combine publishers
6. Processing stages (orchestrated by `VideoProcessingService`):
   - `.loadingVideo` → Load asset metadata
   - `.analyzingAudio` → `AudioAnalyzer.analyze()` detects racket/bat hits (0-50% progress)
   - `.detectingAction` → `VisualValidator.validate()` confirms motion (50-75% progress)
   - `.creatingClips` → `VideoExporter` composes segments (75-90% progress)
   - `.exporting` → Final export (90-100% progress)
7. Completion:
   - `ProcessingResult` with highlight URL and segments returned
   - `BackgroundProcessingManager` updates project status to `.completed`
   - `ProjectStorageService.updateProject()` persists changes
8. UI updates:
   - `HomeView` observes `appState.backgroundProcessingManager.statusByProject`
   - Progress bar updates in real-time
   - Completed project shows in "Recent" section

**State Management:**
- Central `AppState: ObservableObject` injected as environment object
- `@Published` properties for reactive updates
- Services publish status/progress via Combine
- ViewModels subscribe and transform for UI

## Key Abstractions

**Protocol-Based Services:**
- Purpose: Enable dependency injection and testing
- Examples: `VideoProcessingServiceProtocol`, `ProjectStorageServiceProtocol`
- Pattern: Protocol defines interface, multiple implementations (Real/Mock/Dummy)
- Location: Service files contain both protocol and implementations

**Sport-Specific Presets:**
- Purpose: Configurable detection parameters per sport
- Location: `Sport.swift` → `AnalysisPreset` struct
- Pattern: `Sport.preset(for: SportMode?)` returns tuned parameters
- Examples:
  - Tennis Rally mode: 3s gap clustering, audio-only validation
  - Tennis Shot mode: 1s gap clustering, snappy clips
  - Cricket: 6s gap clustering, longer segments

**Actor-Based Concurrency:**
- Purpose: Thread-safe processing of media data
- Examples: `actor AudioAnalyzer`, `actor VisualValidator`
- Pattern: Actors ensure serial access to mutable state
- Usage: Async functions called from service layer

**Observable State:**
- Purpose: Reactive UI updates
- Pattern: `@Observable` macro (iOS 17+) for ViewModels
- Examples: `HomeViewModel`, `HighlightCreationViewModel`
- Replaces: `@StateObject` + `@Published` pattern

## Entry Points

**Application Entry:**
- Location: `SportCrunchApp.swift`
- Triggers: App launch
- Responsibilities: Initialize `AppState`, inject environment object, set up window

**Root View:**
- Location: `ContentView.swift`
- Triggers: First view displayed
- Responsibilities: Route between Onboarding ↔ Home based on `hasCompletedOnboarding`

**Feature Entry Points:**
- `HomeView.swift` - Home tab, project list, create button
- `HighlightCreationFlow.swift` - Multi-step creation wizard
- `SettingsView.swift` - Settings tab, debug reports
- `OnboardingView.swift` - First-run experience

## Error Handling

**Strategy:** Throw errors from services, catch at ViewModel/UI boundary

**Patterns:**
- Services throw typed errors: `ProcessingError`, `AudioAnalyzerError`, etc.
- ViewModels catch and transform to user-friendly messages
- UI displays errors in alerts or inline messages
- Background processing continues on failure (doesn't crash app)

**Error Types:**
- `ProcessingError` - Video processing failures
- `AudioAnalyzerError` - Audio extraction/analysis failures
- `VideoExporterError` - Export failures
- Codable errors - Data persistence failures

## Cross-Cutting Concerns

**Logging:**
- `ProcessingLogger` - Observable logging for UI display
- `print()` statements with emoji prefixes for console debugging
- Structured log entries with categories (audio, visual, export, pipeline)

**Progress Tracking:**
- Combine publishers for progress updates (0.0 to 1.0)
- `BackgroundProcessingManager` aggregates progress from services
- UI subscribes to `progressByProject` dictionary

**Debug Reporting:**
- `DebugReportService` - Comprehensive diagnostic data capture
- Exports JSON reports with audio/video analysis data
- Comparison with Python prototype for validation
- Accessible in Settings → Developer Mode

**Concurrency:**
- Async/await throughout for asynchronous operations
- Actors for thread-safe mutable state
- `@MainActor` for UI updates
- Task cancellation support via `isCancelled` flags

---

*Architecture analysis: 2026-01-10*
*Update when major patterns change*
