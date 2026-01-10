# Codebase Concerns

**Analysis Date:** 2026-01-10

## Tech Debt

**Missing Test Coverage:**
- Issue: Core video processing algorithms have zero test coverage
- Files affected: `AudioAnalyzer.swift` (724 lines), `VisualValidator.swift` (653 lines), `VideoExporter.swift` (849 lines), `VideoProcessingService.swift` (884 lines)
- Why: Development focused on feature implementation first
- Impact: No regression protection, difficult to refactor safely, no validation of algorithm correctness
- Fix approach: Add unit tests for signal processing functions, integration tests for pipeline, mock AVFoundation dependencies

**Unsafe Force Unwraps in Signal Processing:**
- Issue: Force unwrapping of `baseAddress` in FFT buffer allocation
- Files: `AudioAnalyzer.swift` (lines 537-538)
- Code: `realp: UnsafeMutablePointer(mutating: realPtr.baseAddress!)`
- Why: Assuming buffer allocation always succeeds
- Impact: Potential crash if memory allocation fails
- Fix approach: Use guard statements with proper error handling, throw `AudioAnalyzerError.memoryAllocationFailed`

**Silent Error Swallowing:**
- Issue: `try?` used for file operations without logging failures
- Files: `ProjectStorageService.swift` (line 110)
- Code: `try? FileManager.default.removeItem(at: highlightURL)`
- Why: Simplified cleanup code
- Impact: Orphaned files accumulate on disk, storage fills up over time
- Fix approach: Log deletion failures, implement periodic cleanup routine

## Known Bugs

**None explicitly documented in TODO/FIXME comments**

## Security Considerations

**Local File Access Only:**
- Risk: App has access to user's photo library
- Current mitigation: iOS sandbox restrictions, permission prompts
- Recommendations: Document data access in privacy policy, minimize data retention

**No User Authentication:**
- Risk: All data stored locally without encryption
- Current mitigation: iOS device encryption (FileVault/FileProtection)
- Recommendations: Consider encryption for sensitive debug reports if they contain user content

## Performance Bottlenecks

**Frame Extraction in Visual Validation:**
- Problem: Extracting 100+ frames from video for motion detection
- Files: `VisualValidator.swift` (lines 500-548)
- Measurement: Depends on video length and frame rate
- Cause: Synchronous `generateCGImagesAsynchronously` extracts all frames into memory
- Improvement path: Stream frames instead of buffering, process in batches, skip frames for long segments

**Large File Processing:**
- Problem: Processing high-resolution 4K videos
- Files: All processing services
- Measurement: Processing time scales with resolution
- Cause: No resolution downscaling for analysis
- Improvement path: Downsample video to 1080p or 720p for analysis, preserve original for export

**Memory Usage During FFT:**
- Problem: FFT operations allocate large temporary buffers
- Files: `AudioAnalyzer.swift` (lines 490-570)
- Measurement: Depends on audio duration
- Cause: Full audio loaded into memory for processing
- Improvement path: Process audio in chunks, release buffers aggressively

## Fragile Areas

**Video Timing Calculations:**
- Files: `VideoExporter.swift` (lines 600-700)
- Why fragile: Complex `CMTime` arithmetic with frame rates
- Common failures: Timing mismatches between tracks, frame drops
- Safe modification: Extensive testing with various frame rates, verify with different video formats
- Test coverage: None currently

**Onset Detection Threshold Tuning:**
- Files: `AudioAnalyzer.swift` (lines 600+), `Sport.swift` (preset parameters)
- Why fragile: 22 tunable parameters per sport/mode, interdependent effects
- Common failures: False positives (too sensitive), false negatives (too conservative)
- Safe modification: Change one parameter at a time, test with reference videos, compare with Python prototype
- Test coverage: None currently

**Concurrent State Updates:**
- Files: `BackgroundProcessingManager.swift` (lines 146-149)
- Why fragile: Multiple state dictionaries updated from async contexts
- Common failures: Race conditions in status/progress updates
- Safe modification: Ensure `@MainActor` consistency, add synchronization if needed
- Test coverage: None currently

## Scaling Limits

**Memory for Long Videos:**
- Current capacity: Tested with videos up to ~30 minutes
- Limit: Audio extraction loads full waveform into memory
- Symptoms at limit: Memory warnings, app termination
- Scaling path: Stream audio processing, chunk large files

**Storage for Multiple Projects:**
- Current capacity: Unlimited project storage
- Limit: iOS device storage
- Symptoms at limit: Export failures, slow file operations
- Scaling path: Implement storage limits, auto-delete old projects, compress thumbnails

**Concurrent Processing:**
- Current capacity: One video at a time (by design)
- Limit: Single `processingTask` variable in `VideoProcessingService.swift` (line 215)
- Symptoms at limit: Subsequent requests overwrite previous task
- Scaling path: Queue multiple tasks, enforce serial processing explicitly

## Dependencies at Risk

**None** - All dependencies are first-party Apple frameworks with long-term support

## Missing Critical Features

**No Error Recovery:**
- Problem: Processing failures leave projects in `.pending` state
- Current workaround: Delete failed project and retry
- Blocks: Cannot resume failed processing, no partial results saved
- Implementation complexity: Medium (save intermediate results, resume from checkpoint)

**No Background App Refresh:**
- Problem: Processing pauses when app is backgrounded
- Current workaround: Keep app in foreground during processing
- Blocks: Cannot process while using other apps
- Implementation complexity: High (background tasks have strict time limits, need to break into chunks)

**No Video Trimming Before Processing:**
- Problem: Must process entire video even if only part is relevant
- Current workaround: Process full video, manually select segments after
- Blocks: Cannot preprocess to reduce processing time
- Implementation complexity: Medium (add trimming UI before processing step)

## Test Coverage Gaps

**Critical Algorithms Untested:**
- What's not tested: Audio onset detection, FFT operations, bandpass filtering, motion detection, video composition
- Risk: Algorithm bugs go unnoticed, refactoring breaks functionality silently
- Priority: **HIGH**
- Difficulty to test: Medium (need mock AVFoundation, test video fixtures)

**Error Handling Paths:**
- What's not tested: File not found, corrupted video, memory allocation failures, permission denials
- Risk: App crashes on edge cases
- Priority: **HIGH**
- Difficulty to test: Low (can inject errors via mocks)

**Concurrent State Management:**
- What's not tested: Multiple simultaneous processing requests, rapid status updates, cancellation during processing
- Risk: Race conditions, UI showing incorrect state
- Priority: **MEDIUM**
- Difficulty to test: Medium (need concurrency testing tools)

**UI Flows:**
- What's not tested: Complete highlight creation flow, project deletion, settings changes
- Risk: UI regressions break user experience
- Priority: **MEDIUM**
- Difficulty to test: Low (XCUITest supports this)

## Additional Concerns

**Complex Files Without Documentation:**
- Files: `DebugReportService.swift` (1142 lines), `VideoProcessingService.swift` (884 lines), `VideoExporter.swift` (849 lines), `AudioAnalyzer.swift` (724 lines), `VisualValidator.swift` (653 lines)
- Issue: Large service files with minimal inline documentation of algorithms
- Impact: High maintenance burden, difficult for new contributors
- Fix approach: Add algorithmic explanations, document assumptions, reference Python prototype

**No Production Logging:**
- Issue: `ProcessingLogger` only prints to console, no persistent logs
- Files: `ProcessingLogger.swift`
- Impact: Cannot debug issues on user devices
- Fix approach: Write logs to file in Documents/Logs/, implement rotation, add export feature

**Hardcoded Configuration Values:**
- Issue: FFT size (1024), hop length (512), frame extraction limits (10 frames for debug) scattered throughout code
- Files: `AudioAnalyzer.swift` (lines 73-74), `VisualValidator.swift` (lines 390, 395, 413, 520)
- Impact: Difficult to tune, no centralized configuration
- Fix approach: Move to `AnalysisPreset` or separate configuration struct

---

*Concerns audit: 2026-01-10*
*Update as issues are fixed or new ones discovered*
