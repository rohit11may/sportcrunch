# External Integrations

**Analysis Date:** 2026-01-10

## APIs & External Services

**None detected** - This is a fully local, on-device iOS application with no cloud backend or external API integrations.

## Data Storage

**Databases:**
- Not applicable - No database used

**File Storage:**
- Local file system - `Documents/Highlights/` directory for video files
- Location: App sandbox (user-inaccessible externally)
- Format: Standard iOS file system via FileManager
- Persistence: `ProjectStorageService.swift`

**Caching:**
- UserDefaults - Project metadata storage (`ProjectStorageService.swift`)
- Connection: Native iOS UserDefaults API
- Format: JSON-encoded `Project` objects
- No external caching service

## Authentication & Identity

**Auth Provider:**
- None - No user authentication system
- No login/signup functionality
- All data stored locally on device

**OAuth Integrations:**
- None

## Monitoring & Observability

**Error Tracking:**
- In-app debug reports only (`DebugReportService.swift`)
- No external error tracking service (no Sentry, Crashlytics, etc.)
- Debug reports saved to `Documents/DebugReports/` directory

**Analytics:**
- None - No analytics integration
- No user behavior tracking
- No crash reporting service

**Logs:**
- Console logs via `print()` statements
- `ProcessingLogger.swift` - In-app logging system for UI display
- No external log aggregation service

## CI/CD & Deployment

**Hosting:**
- App Store (intended deployment target)
- No web hosting or server infrastructure

**CI Pipeline:**
- Not detected - No `.github/workflows/`, CircleCI, or similar config files
- Manual builds via Xcode or `launch.sh` script

## Environment Configuration

**Development:**
- No environment variables required
- All configuration in code or UserDefaults
- Xcode scheme-based configuration
- `launch.sh` - Local build automation

**Staging:**
- Not applicable - Single production configuration

**Production:**
- App Store distribution
- All secrets/configuration embedded in app
- No remote configuration service

## Webhooks & Callbacks

**Incoming:**
- None

**Outgoing:**
- None

## System Integrations

**iOS Photos Library:**
- Integration: PhotosUI and Photos frameworks
- Access: `VideoSelectionView.swift`, `HighlightCreationFlow.swift`
- Permissions required:
  - Photo Library Read: `NSPhotoLibraryUsageDescription`
  - Photo Library Write: `NSPhotoLibraryAddUsageDescription`
- Purpose: Video import and highlight export

**Apple Frameworks (On-Device Processing):**
- AVFoundation - Native media handling
- Accelerate - Vectorized signal processing (DSP operations)
- All processing happens locally on-device
- No data sent to external services

## Research & Prototyping Infrastructure

**Python Prototype** (`prototype/` directory):
- Streamlit dashboard for algorithm tuning (`prototype/app.py`)
- Reference implementation of audio analysis (`prototype/src/audio_analyzer.py`)
- Parameter exploration tool (not deployed; development-only)
- No runtime dependency on Python code

---

*Integration audit: 2026-01-10*
*Update when adding/removing external services*
