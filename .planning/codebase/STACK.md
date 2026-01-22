# Technology Stack

**Analysis Date:** 2026-01-10

## Languages

**Primary:**
- Swift 5+ - All application code (`SportCrunch/**/*.swift`)

**Secondary:**
- Python - Prototype research and algorithm development (`prototype/`)
- JavaScript/Node.js - Development tooling (package.json for Claude Code CLI)

## Runtime

**Environment:**
- iOS 17+ (target deployment)
- Apple Silicon / Intel x86_64 (macOS development)

**Package Manager:**
- Xcode / Swift Package Manager (no external dependencies)
- npm for development tools (Claude Code CLI)

## Frameworks

**Core:**
- SwiftUI - UI framework (`SportCrunch/Features/**/*.swift`, `SportCrunch/Shared/Components/*.swift`)
- AVFoundation - Video/audio processing (`SportCrunch/Core/Services/VideoProcessingService.swift`, `AudioAnalyzer.swift`, `VideoExporter.swift`)
- Accelerate - High-performance signal processing (`AudioAnalyzer.swift`, `VisualValidator.swift`)

**Media & Device Integration:**
- AVKit - Video playback (`ControllableVideoPlayer.swift`)
- PhotosUI - Photo library picker (`VideoSelectionView.swift`)
- Photos - Photo library access (`HighlightCreationFlow.swift`)
- CoreMedia - Media timing and composition (`VideoExporter.swift`)

**System & Graphics:**
- Combine - Reactive programming (`AppState.swift`, `VideoProcessingService.swift`)
- Foundation - Core utilities (all files)
- CoreGraphics - Graphics operations (`VisualValidator.swift`)
- UIKit - iOS UI foundation (`ProjectCard.swift`, `DebugReportService.swift`)
- CryptoKit - Cryptographic hashing (`DebugReportService.swift`)
- UniformTypeIdentifiers - File type handling (`HighlightCreationFlow.swift`)

**Testing:**
- XCTest - Unit and UI testing (standard iOS testing)

**Build/Dev:**
- Xcode 17.6+ - Build system (`SportCrunch.xcodeproj/project.pbxproj`)
- xcodebuild - Command-line compilation (`launch.sh`)

## Key Dependencies

**Critical:**
- Accelerate vDSP - FFT, filtering, vectorized operations for audio onset detection
- AVFoundation AVAsset/AVAssetReader - Video decoding and audio extraction
- AVFoundation AVMutableComposition - Video segment composition and export
- Combine Publishers - Async status/progress updates

**Infrastructure:**
- SwiftUI @Observable - Reactive state management (iOS 17+)
- Swift Concurrency - async/await, actors for thread safety
- UserDefaults - Project metadata persistence (`ProjectStorageService.swift`)

## Configuration

**Environment:**
- No environment variables required
- All configuration via in-app settings
- UserDefaults for persistent preferences

**Build:**
- `SportCrunch.xcodeproj/project.pbxproj` - Xcode project configuration
- `Assets.xcassets/` - Asset catalog (images, colors)
- `launch.sh` - Build and launch automation script

## Platform Requirements

**Development:**
- macOS 14+ (for Xcode 17.6+)
- Xcode 17.6 or later
- No external dependencies

**Production:**
- iOS 17.0+ (target minimum)
- iPhone and iPad compatible
- ~100-200 MB app size
- Local processing only (no cloud backend)

---

*Stack analysis: 2026-01-10*
*Update after major dependency changes*
