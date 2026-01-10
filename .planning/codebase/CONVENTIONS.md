# Coding Conventions

**Analysis Date:** 2026-01-10

## Naming Patterns

**Files:**
- PascalCase for all files: `HomeView.swift`, `VideoProcessingService.swift`
- Pattern suffixes: `*View.swift`, `*ViewModel.swift`, `*Service.swift`, `*Sheet.swift`, `*Flow.swift`
- Test files: `SportCrunchTests.swift` (not co-located with source)

**Functions:**
- camelCase for all functions
- Verb-first naming: `processVideo()`, `loadProjects()`, `completeOnboarding()`
- Async functions: No special prefix (rely on `async` keyword)
- Event handlers: `handleEventName` pattern not strictly followed

**Variables:**
- camelCase for variables and properties
- Private properties: `private(set)` or `private` access control (no underscore prefix)
- Constants: UPPER_SNAKE_CASE for magic values, camelCase for computed constants
- Boolean flags: `isProcessing`, `showCreateFlow`, `hasCompletedOnboarding`

**Types:**
- Interfaces/Protocols: PascalCase with `Protocol` suffix - `VideoProcessingServiceProtocol`
- Classes/Structs: PascalCase - `Project`, `AppState`, `AudioAnalyzer`
- Enums: PascalCase for type, camelCase for cases - `ProcessingStatus.analyzingAudio`
- Type aliases: PascalCase

## Code Style

**Formatting:**
- Indentation: 4 spaces (Swift standard)
- Line length: ~100-120 character soft limit (not strictly enforced)
- Quotes: Double quotes `"` for all strings
- Semicolons: Not used (Swift convention)
- Braces: Opening brace on same line

**Linting:**
- No SwiftLint configuration detected
- Relies on Xcode's built-in formatting
- No automated linting tools

**Spacing:**
- Defined in `AppTheme.swift`:
  - `xxs: 4`, `xs: 8`, `sm: 12`, `md: 16`, `lg: 24`, `xl: 32`, `xxl: 48`
- Used via `Spacing.md`, `Spacing.lg`, etc.
- Consistent throughout UI code

## Import Organization

**Order:**
1. System frameworks (SwiftUI, AVFoundation, etc.)
2. No internal grouping (single block of imports)
3. No explicit import sorting

**Grouping:**
- No blank lines between groups
- Imports listed at top of file
- No path aliases (Swift uses module-based imports)

**Path References:**
- Module-based imports: `import SwiftUI`, `import AVFoundation`
- Internal imports: Implicit (same module)

## Error Handling

**Patterns:**
- Throw errors from services, catch at ViewModel/UI boundaries
- Custom error enums: `ProcessingError`, `AudioAnalyzerError`, `VideoExporterError`
- Async functions use `throws` for expected failures
- `try?` used for non-critical failures (e.g., file deletion cleanup)

**Error Types:**
- Custom errors extend `Error` protocol
- Enum-based error types with associated values
- Example:
  ```swift
  enum ProcessingError: Error {
      case invalidVideoURL
      case audioExtractionFailed
      case noActionDetected
      case cancelled
  }
  ```

**Logging:**
- Errors logged with context before throwing
- Example: `print("⚙️ [VideoProcessor] ❌ Audio analysis failed: \(error)")`

## Logging

**Framework:**
- `print()` for console logging
- `ProcessingLogger` for observable UI logging
- Emoji prefixes for categories: `⚙️` (pipeline), `🎵` (audio), `👁️` (visual), `📼` (export)

**Patterns:**
- Format: `print("⚙️ [Component] Message")`
- Structured logging via `ProcessingLogger`:
  ```swift
  logger.pipeline("Starting highlight creation...")
  logger.audio("Extracting audio waveform...")
  logger.success("Processing complete!")
  logger.error("Failed to process video")
  ```

**When to Log:**
- Phase transitions in processing pipeline
- External operations (file I/O, AVFoundation calls)
- Errors and warnings
- Progress milestones

## Comments

**When to Comment:**
- Explain "why" not "what" (algorithm rationale, workarounds)
- Document complex signal processing logic
- Explain non-obvious business rules
- Mark major sections with `// MARK:`

**MARK Comments:**
- Consistent use of `// MARK: - Section Name`
- Examples: `// MARK: - Properties`, `// MARK: - Processing`, `// MARK: - Real Implementation`
- Used to organize long files (services, views)

**Doc Comments:**
- Triple-slash `///` for public APIs
- Examples:
  ```swift
  /// Analyzes audio to detect sports action sounds (racket hits, bat contacts).
  ///
  /// Pipeline:
  /// 1. Extract audio at target sample rate (mono)
  /// 2. Apply bandpass filter to isolate hit frequencies
  /// 3. Compute onset strength (spectral flux)
  ```

**TODO Comments:**
- Format: `// TODO: Description` (no username or issue link)
- Used sparingly in codebase

## Function Design

**Size:**
- Large functions common (200+ lines in services)
- Complex processing pipelines kept in single function
- Helper functions extracted when logic is reusable

**Parameters:**
- Named parameters for clarity
- Use default values where appropriate
- Example: `func validate(videoURL: URL, candidates: [(start: TimeInterval, end: TimeInterval)], sport: Sport, sportMode: SportMode?, progressHandler: @escaping (Double) -> Void)`

**Return Values:**
- Explicit return types
- Return early for guard clauses
- Async functions return or throw (no Result type)
- Example:
  ```swift
  func processVideo(sourceURL: URL, sport: Sport, sportMode: SportMode?) async throws -> ProcessingResult
  ```

## Module Design

**Exports:**
- Internal by default (Swift's default access)
- Public marked explicitly for cross-module access
- No default exports (Swift doesn't support)

**File Organization:**
- One primary type per file
- Related types grouped in same file (e.g., protocol + implementations)
- Example: `VideoProcessingService.swift` contains protocol, Real, and Dummy implementations

**Property Wrappers:**
- `@Published` for observable properties
- `@MainActor` for UI-safe classes
- `@Observable` for ViewModels (iOS 17+)
- `@State`, `@Binding`, `@EnvironmentObject` for SwiftUI

**Actors:**
- Used for thread-safe services: `actor AudioAnalyzer`, `actor VisualValidator`
- All actor functions are `async`

---

*Convention analysis: 2026-01-10*
*Update when patterns change*
