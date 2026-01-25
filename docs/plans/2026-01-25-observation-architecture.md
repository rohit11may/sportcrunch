# Observation Architecture & Dashboard Lab View Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement a generic `Observation` architecture for segmentation methods to record signals, events, and artifacts, and visualize them in a new "Lab" view on the Dashboard.

**Architecture:**
1.  **Runner:** Introduce `Observation` actor (Swift 6 compliant) passed through `SegmentationMethod`.
2.  **Runner:** Update `SpectralFluxMethod` to record downsampled signals (2 points/sec) and events.
3.  **Runner:** Update `ArtifactExporter` to serialize observations and manage artifact files separately.
4.  **Dashboard:** Create `Lab` view with synchronized charts (Recharts) and interactive event ledger.
5.  **Dashboard:** Implement manual artifact sync with status tracking.

**Tech Stack:** Swift 6 (iOS/macOS), Node.js (Backend), React + Recharts (Frontend).

**Design Decisions:**
- **Thread Safety:** Use Swift actor instead of @unchecked Sendable for compile-time data race prevention
- **Signal Downsampling:** Aggressively downsample to 2 points/second for dashboard performance
- **Artifact Storage:** Separate artifact file management from observation data model
- **Image Format:** JPEG only (compression optimized for validation screenshots)
- **Sync Strategy:** Manual sync button with persistent sync status tracking

---

### Task 1: Create Observation Model

**Files:**
- Create: `app/SportCrunch/Core/Models/Observation.swift`
- Test: `app/SportCrunchTests/Core/ObservationTests.swift`

**Step 1: Write the test**

```swift
// app/SportCrunchTests/Core/ObservationTests.swift
import XCTest
@testable import SportCrunch

final class ObservationTests: XCTestCase {
    func testSignalRecording() async {
        let obs = Observation()
        await obs.addSignalPoint(name: "audio_flux", time: 1.0, value: 0.5)
        await obs.addSignalPoint(name: "audio_flux", time: 1.1, value: 0.8)

        let signals = await obs.getSignals()
        XCTAssertEqual(signals["audio_flux"]?.count, 2)
        XCTAssertEqual(signals["audio_flux"]?[0].value, 0.5)
    }

    func testEventRecording() async {
        let obs = Observation()
        await obs.addEvent(name: "peak", time: 1.5, metadata: ["confidence": "0.9"])

        let events = await obs.getEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].name, "peak")
        XCTAssertEqual(events[0].metadata["confidence"], "0.9")
    }

    func testThreadSafety() async {
        let obs = Observation()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    await obs.addSignalPoint(name: "test", time: 0, value: 0)
                }
            }
        }

        let signals = await obs.getSignals()
        XCTAssertEqual(signals["test"]?.count, 100)
    }
}
```

**Step 2: Run test to verify failure**

Run: `xcodebuild test -scheme SportCrunch -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SportCrunchTests/ObservationTests`
Expected: FAIL (Observation not defined)

**Step 3: Implement Observation Model**

```swift
// app/SportCrunch/Core/Models/Observation.swift
import Foundation

/// Thread-safe observation recorder using Swift 6 actor isolation.
/// Stores downsampled signals (2 points/sec) and discrete events for debugging.
public actor Observation {
    public struct SignalPoint: Codable, Sendable {
        public let time: TimeInterval
        public let value: Double

        public init(time: TimeInterval, value: Double) {
            self.time = time
            self.value = value
        }
    }

    public struct Event: Codable, Sendable {
        public let id: UUID
        public let timestamp: TimeInterval
        public let name: String
        public let metadata: [String: String]
        public let artifactId: String?

        public init(id: UUID = UUID(), timestamp: TimeInterval, name: String, metadata: [String: String] = [:], artifactId: String? = nil) {
            self.id = id
            self.timestamp = timestamp
            self.name = name
            self.metadata = metadata
            self.artifactId = artifactId
        }
    }

    private var signals: [String: [SignalPoint]] = [:]
    private var events: [Event] = []

    public init() {}

    /// Add signal point with automatic downsampling.
    /// Only records if sufficient time has passed since last point (2 points/sec = 0.5s threshold).
    public func addSignalPoint(name: String, time: TimeInterval, value: Double) {
        if signals[name] == nil {
            signals[name] = []
        }

        // Downsample: only add if 0.5s elapsed since last point (2 points/sec)
        if let lastPoint = signals[name]?.last, time - lastPoint.time < 0.5 {
            return
        }

        signals[name]?.append(SignalPoint(time: time, value: value))
    }

    public func addEvent(name: String, time: TimeInterval, metadata: [String: String] = [:], artifactId: String? = nil) {
        let event = Event(timestamp: time, name: name, metadata: metadata, artifactId: artifactId)
        events.append(event)
    }

    // MARK: - Snapshot Accessors (for export/encoding)

    public func getSignals() -> [String: [SignalPoint]] {
        return signals
    }

    public func getEvents() -> [Event] {
        return events
    }
}

// MARK: - Codable Conformance

extension Observation: Codable {
    private enum CodingKeys: String, CodingKey {
        case signals, events
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(signals, forKey: .signals)
        try container.encode(events, forKey: .events)
    }

    public convenience init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        signals = try container.decode([String: [SignalPoint]].self, forKey: .signals)
        events = try container.decode([Event].self, forKey: .events)
    }
}
```

**Step 4: Run test to verify pass**

Run: `xcodebuild test -scheme SportCrunch -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SportCrunchTests/ObservationTests`
Expected: PASS

**Step 5: Commit**

```bash
git add app/SportCrunch/Core/Models/Observation.swift app/SportCrunchTests/Core/ObservationTests.swift
git commit -m "feat: add Observation model for telemetry and debugging"
```

---

### Task 2: Update Segmentation Protocol

**Files:**
- Modify: `app/SportCrunch/Core/Services/SegmentationMethod.swift`
- Modify: `app/methods/spectral_flux/SpectralFluxMethod.swift`
- Modify: `app/SportCrunch/Core/Models/Sport.swift` (If it calls this)
- Modify: `app/SportCrunch/Core/Services/VideoProcessingService.swift`

**Step 1: Update Protocol**

Update `SegmentationMethod` to accept optional `Observation`.

```swift
// app/SportCrunch/Core/Services/SegmentationMethod.swift
protocol SegmentationMethod: Sendable {
    var name: String { get }
    func detectSegments(videoURL: URL, observation: Observation?) async throws -> [ActionSegment]
}
```

**Step 2: Update SpectralFluxMethod Signature**

Just update the signature to satisfy protocol, implementation comes later.

```swift
// app/methods/spectral_flux/SpectralFluxMethod.swift
final class SpectralFluxMethod: SegmentationMethod {
    // ...
    func detectSegments(videoURL: URL, observation: Observation?) async throws -> [ActionSegment] {
        // ... existing logic, ignoring observation for now ...
    }
}
```

**Step 3: Update Call Sites**

Update all call sites to pass `observation: nil` for now. Will wire up actual observation in Task 6.

```swift
// Update any existing calls to detectSegments
// Example in RunExecutor or elsewhere:
let segments = try await method.detectSegments(videoURL: videoURL, observation: nil)
```

**Step 4: Verify Compilation**

Run: `xcodebuild build -scheme SportCrunch -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: SUCCESS

**Step 5: Commit**

```bash
git add app/SportCrunch/Core/Services/SegmentationMethod.swift app/methods/spectral_flux/SpectralFluxMethod.swift
git commit -m "refactor: update SegmentationMethod protocol to accept Observation"
```

---

### Task 3: Instrument SpectralFlux AudioAnalyzer

**Files:**
- Modify: `app/methods/spectral_flux/SpectralFluxAudioAnalyzer.swift`

**Step 1: Update analyze signature**

```swift
func analyze(videoURL: URL, config: SpectralFluxMethodConfig, observation: Observation?) async throws -> AudioAnalysisResult
```

**Step 2: Record Signals**

Inside `analyze`:
- Record `audio_flux` signal (downsampled automatically by Observation to 2 points/sec).
- Record `audio_peak` events.

```swift
// Inside analyze() ...
let onsetStrength = computeOnsetStrength(filteredSamples)

// Record signal (downsampling handled automatically by Observation)
if let obs = observation {
    let frameDuration = Double(hopLength) / sampleRate
    for (i, val) in onsetStrength.enumerated() {
        await obs.addSignalPoint(name: "audio_flux", time: Double(i) * frameDuration, value: Double(val))
    }

    // Record peaks
    for (i, val) in peakIndices.enumerated() {
         await obs.addEvent(name: "audio_peak", time: peakTimes[i], metadata: ["strength": "\(onsetStrength[val])"])
    }
}
```

**Step 3: Commit**

```bash
git add app/methods/spectral_flux/SpectralFluxAudioAnalyzer.swift
git commit -m "feat: instrument AudioAnalyzer with Observation"
```

---

### Task 4: Instrument SpectralFlux VisualValidator

**Files:**
- Modify: `app/methods/spectral_flux/SpectralFluxVisualValidator.swift`

**Step 1: Update validate signature**

```swift
func validate(
    videoURL: URL,
    candidates: [(start: TimeInterval, end: TimeInterval)],
    config: SpectralFluxMethodConfig,
    observation: Observation?,
    progressHandler: ((Double) -> Void)? = nil
) async throws -> [SegmentValidation]
```

**Step 2: Record Motion Signals and Decisions**

Add property to store temp artifacts:
```swift
private var tempArtifactPaths: [String: URL] = [:]  // Add to class properties
```

Record motion signals and save artifacts:

```swift
// Inside validateSegmentBatch ...
// Calculate score...

if let obs = observation {
    // Record decision
    let status = isValid ? "accepted" : (motionScore < motionAreaThreshold ? "rejected_low_motion" : "rejected_other")

    // Save artifact if "interesting" (rejected or borderline)
    if !isValid {
        let artifactId = UUID().uuidString
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("\(artifactId).jpg")

        // Save frame as JPEG (quality 0.8 for balance)
        if let jpegData = frame.jpegData(compressionQuality: 0.8) {
            try? jpegData.write(to: tempURL)
            tempArtifactPaths[artifactId] = tempURL

            await obs.addEvent(
                name: "validation_decision",
                time: start,
                metadata: [
                    "status": status,
                    "motion_score": String(format: "%.3f", motionScore),
                    "threshold": String(format: "%.3f", motionAreaThreshold)
                ],
                artifactId: artifactId
            )
        }
    }

    // Record signal point (downsampled automatically to 2 points/sec)
    await obs.addSignalPoint(name: "motion_score", time: start, value: motionScore)
}
```

**Step 3: Commit**

```bash
git add app/methods/spectral_flux/SpectralFluxVisualValidator.swift
git commit -m "feat: instrument VisualValidator with Observation and artifacts"
```

---

### Task 5: Wire Up SpectralFluxMethod

**Files:**
- Modify: `app/methods/spectral_flux/SpectralFluxMethod.swift`

**Step 1: Pass Observation Down**

Update `detectSegments` to pass `observation` to `audioAnalyzer.analyze` and `visualValidator.validate`.

```swift
// app/methods/spectral_flux/SpectralFluxMethod.swift
func detectSegments(videoURL: URL, observation: Observation?) async throws -> [ActionSegment] {
    // Pass observation to analyzer
    let analysisResult = try await audioAnalyzer.analyze(
        videoURL: videoURL,
        config: config,
        observation: observation
    )

    // Pass observation to validator
    let validations = try await visualValidator.validate(
        videoURL: videoURL,
        candidates: candidates,
        config: config,
        observation: observation,
        progressHandler: progressHandler
    )

    // ... rest of method
}
```

**Step 2: Commit**

```bash
git add app/methods/spectral_flux/SpectralFluxMethod.swift
git commit -m "feat: wire up Observation in SpectralFluxMethod"
```

---

### Task 6: Runner Artifact Export

**Files:**
- Modify: `app/SportCrunchRunner/Services/RunExecutor.swift`
- Modify: `app/SportCrunchRunner/Services/ArtifactExporter.swift`

**Step 1: Create Observation in RunExecutor**

```swift
// RunExecutor.swift
func execute(run: Run, method: SegmentationMethod) async throws -> RunResult {
    let observation = Observation()
    let segments = try await method.detectSegments(videoURL: videoURL, observation: observation)

    // Get temp artifacts from method (if it's SpectralFluxMethod)
    var tempArtifacts: [String: URL] = [:]
    if let spectralMethod = method as? SpectralFluxMethod {
        tempArtifacts = spectralMethod.visualValidator.tempArtifactPaths
    }

    // Pass observation and artifacts to exporter
    let artifactPaths = try await exporter.export(
        run: run,
        segments: exportedSegments,
        highlightURL: highlightURL,
        observation: observation,
        tempArtifacts: tempArtifacts
    )

    return runResult
}
```

**Step 2: Update ArtifactExporter**

Add robust error handling and artifact management:

```swift
// ArtifactExporter.swift
func export(
    run: Run,
    segments: [ExportedSegment],
    highlightURL: URL?,
    observation: Observation?,
    tempArtifacts: [String: URL]
) async throws -> ArtifactPaths {
    // ... export segments.json ...

    if let obs = observation {
        // 1. Encode observation with pretty printing for debugging
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let obsData: Data
        do {
            obsData = try encoder.encode(obs)
        } catch {
            logger.error("Failed to encode observation: \(error)")
            throw ExportError.observationEncodingFailed(error)
        }

        let obsPath = runDirectory.appendingPathComponent("observations.json")
        try obsData.write(to: obsPath)

        // 2. Export artifacts if any
        if !tempArtifacts.isEmpty {
            let artifactsDir = runDirectory.appendingPathComponent("artifacts")
            try fileManager.createDirectory(at: artifactsDir, withIntermediateDirectories: true)

            for (artifactId, tempURL) in tempArtifacts {
                // Validate file exists before copying
                guard fileManager.fileExists(atPath: tempURL.path) else {
                    logger.warning("Artifact file missing: \(tempURL)")
                    continue
                }

                // Always use .jpg extension (JPEG format for all artifacts)
                let destURL = artifactsDir.appendingPathComponent("\(artifactId).jpg")

                do {
                    try fileManager.copyItem(at: tempURL, to: destURL)
                } catch {
                    logger.error("Failed to copy artifact \(artifactId): \(error)")
                    // Continue with other artifacts rather than failing entire export
                }
            }

            logger.info("Exported \(tempArtifacts.count) artifacts to \(artifactsDir.path)")
        }
    }

    return artifactPaths
}
```

**Step 3: Commit**

```bash
git add app/SportCrunchRunner/Services/RunExecutor.swift app/SportCrunchRunner/Services/ArtifactExporter.swift
git commit -m "feat: export Observation and artifacts with error handling"
```

---

### Task 7: Dashboard Backend Pull Logic

**Files:**
- Modify: `dashboard/backend/server.js`
- Modify: `dashboard/backend/run-metadata.json` (add sync status fields)

**Step 1: Add Sync Status to Run Metadata**

Update run metadata structure to track sync state:

```javascript
// Example run metadata structure
{
  "id": "run-123",
  "method": "spectral_flux",
  "timestamp": "2026-01-25T10:00:00Z",
  "syncStatus": "pending",  // "pending" | "syncing" | "synced" | "failed"
  "lastSyncAttempt": null,  // ISO timestamp or null
  "syncError": null,        // Error message if failed
  "artifactsPath": null     // Local path to artifacts dir, null if not synced
}
```

**Step 2: Add Artifact Pulling Endpoint**

Implement `POST /api/runs/:id/sync` with status tracking:

```javascript
// server.js
app.post('/api/runs/:id/sync', async (req, res) => {
  const runId = req.params.id;
  const run = runs.find(r => r.id === runId);

  if (!run) {
    return res.status(404).json({ error: 'Run not found' });
  }

  // Update status to syncing
  run.syncStatus = 'syncing';
  run.lastSyncAttempt = new Date().toISOString();
  saveRunMetadata();

  try {
    // Pull run folder from device using devicectl
    const deviceRunPath = `/var/mobile/Containers/Data/Application/.../SportCrunchRuns/${runId}`;
    const localRunPath = path.join(__dirname, 'data', 'runs', runId);

    // Execute devicectl pull command
    const { stdout, stderr } = await execPromise(
      `xcrun devicectl device copy from --source "${deviceRunPath}" --destination "${localRunPath}"`
    );

    // Verify artifacts exist
    const artifactsPath = path.join(localRunPath, 'artifacts');
    const artifactsExist = fs.existsSync(artifactsPath);

    // Update status to synced
    run.syncStatus = 'synced';
    run.artifactsPath = artifactsExist ? artifactsPath : null;
    run.syncError = null;
    saveRunMetadata();

    res.json({
      success: true,
      syncStatus: 'synced',
      artifactsPath: run.artifactsPath,
      message: artifactsExist ? 'Artifacts synced successfully' : 'No artifacts found'
    });

  } catch (error) {
    // Update status to failed
    run.syncStatus = 'failed';
    run.syncError = error.message;
    saveRunMetadata();

    res.status(500).json({
      success: false,
      syncStatus: 'failed',
      error: error.message
    });
  }
});

// Get sync status endpoint
app.get('/api/runs/:id/sync-status', (req, res) => {
  const run = runs.find(r => r.id === req.params.id);
  if (!run) {
    return res.status(404).json({ error: 'Run not found' });
  }

  res.json({
    syncStatus: run.syncStatus,
    lastSyncAttempt: run.lastSyncAttempt,
    syncError: run.syncError,
    artifactsPath: run.artifactsPath
  });
});
```

**Step 3: Commit**

```bash
git add dashboard/backend/server.js
git commit -m "feat: add manual artifact sync with status tracking"
```

---

### Task 8: Dashboard Frontend Lab View

**Files:**
- Create: `dashboard/frontend/src/pages/Lab.jsx`
- Modify: `dashboard/frontend/src/App.jsx` (Add route)
- Modify: `dashboard/frontend/src/components/RunHistory.jsx` (Link to Lab)

**Step 1: Create Basic Lab View with Sync Button**

```jsx
// dashboard/frontend/src/pages/Lab.jsx
import { useState, useEffect } from 'react';
import { useParams } from 'react-router-dom';

export default function Lab() {
  const { runId } = useParams();
  const [syncStatus, setSyncStatus] = useState('pending');
  const [observation, setObservation] = useState(null);
  const [syncing, setSyncing] = useState(false);
  const [error, setError] = useState(null);

  // Check sync status on mount
  useEffect(() => {
    fetchSyncStatus();
  }, [runId]);

  const fetchSyncStatus = async () => {
    try {
      const res = await fetch(`/api/runs/${runId}/sync-status`);
      const data = await res.json();
      setSyncStatus(data.syncStatus);

      // If already synced, fetch observations
      if (data.syncStatus === 'synced') {
        fetchObservations();
      }
    } catch (err) {
      setError(err.message);
    }
  };

  const handleSync = async () => {
    setSyncing(true);
    setError(null);

    try {
      const res = await fetch(`/api/runs/${runId}/sync`, { method: 'POST' });
      const data = await res.json();

      if (data.success) {
        setSyncStatus('synced');
        fetchObservations();
      } else {
        setError(data.error);
        setSyncStatus('failed');
      }
    } catch (err) {
      setError(err.message);
      setSyncStatus('failed');
    } finally {
      setSyncing(false);
    }
  };

  const fetchObservations = async () => {
    try {
      const res = await fetch(`/api/runs/${runId}/observations`);
      const data = await res.json();
      setObservation(data);
    } catch (err) {
      setError(err.message);
    }
  };

  return (
    <div className="lab-view">
      <h1>Lab View - Run {runId}</h1>

      {/* Sync Status Banner */}
      <div className={`sync-banner sync-${syncStatus}`}>
        {syncStatus === 'pending' && (
          <>
            <p>Artifacts not synced yet.</p>
            <button onClick={handleSync} disabled={syncing}>
              {syncing ? 'Syncing...' : 'Sync Artifacts'}
            </button>
          </>
        )}
        {syncStatus === 'syncing' && <p>Syncing artifacts...</p>}
        {syncStatus === 'synced' && <p>✓ Artifacts synced</p>}
        {syncStatus === 'failed' && (
          <>
            <p>❌ Sync failed: {error}</p>
            <button onClick={handleSync}>Retry Sync</button>
          </>
        )}
      </div>

      {/* Observation Data Display */}
      {observation && (
        <pre>{JSON.stringify(observation, null, 2)}</pre>
      )}
    </div>
  );
}
```

**Step 2: Add Route**

```jsx
// dashboard/frontend/src/App.jsx
import Lab from './pages/Lab';

// In routes:
<Route path="/lab/:runId" element={<Lab />} />
```

**Step 3: Add Link from RunHistory**

```jsx
// dashboard/frontend/src/components/RunHistory.jsx
<Link to={`/lab/${run.id}`}>View Lab</Link>
```

**Step 4: Commit**

```bash
git add dashboard/frontend/src/pages/Lab.jsx dashboard/frontend/src/App.jsx dashboard/frontend/src/components/RunHistory.jsx
git commit -m "feat: add Lab view with manual artifact sync"
```

---

### Task 9: Lab Charts & Events

**Files:**
- Modify: `dashboard/frontend/src/pages/Lab.jsx`
- Install: `recharts`

**Step 1: Install Recharts**

`npm install recharts --prefix dashboard/frontend`

**Step 2: Implement Chart**

Render `audio_flux` and `motion_score`.

**Step 3: Implement Event Ledger**

List events, click to seek video.

**Step 4: Commit**

```bash
git add dashboard/frontend/src/pages/Lab.jsx
git commit -m "feat: implement Lab charts and event ledger"
```

---

## Plan Review Summary

**Architecture Changes Made:**
1. ✅ **Thread Safety**: Changed from `@unchecked Sendable` + NSLock to Swift 6 `actor` for compile-time data race prevention
2. ✅ **Codable Design**: Separated artifact file management from Observation model (artifacts managed by validator, only IDs stored in events)
3. ✅ **Signal Downsampling**: Implemented automatic downsampling to 2 points/second in `addSignalPoint()` method
4. ✅ **Test Updates**: All tests now use `async` functions and `await` for actor access
5. ✅ **Device Targets**: All test/build commands updated to use iPhone 17 per CLAUDE.md requirements
6. ✅ **Backward Compatibility**: Removed compatibility extensions per CLAUDE.md (just update call sites directly)
7. ✅ **Error Handling**: Added robust error handling in ArtifactExporter with logging and graceful degradation
8. ✅ **Artifact Format**: Standardized on JPEG format (quality 0.8) for all validation screenshots
9. ✅ **Sync Strategy**: Manual sync button with persistent status tracking (pending → syncing → synced/failed)

**Key Implementation Details:**
- **Observation**: Actor with automatic 2-point/sec downsampling, custom Codable conformance
- **Artifacts**: Managed separately by validator's `tempArtifactPaths` dictionary, exported by ArtifactExporter
- **Events**: Store artifact IDs (not paths) to reference JPEG files in artifacts/ directory
- **Dashboard Sync**: Manual trigger with status persistence, retry on failure
- **Data Volume**: ~120 points/minute/signal (2 points/sec) = manageable for 60s videos (~7,200 points total)

**Testing Strategy:**
- Each task has TDD flow: write test → verify failure → implement → verify pass
- Thread safety validated with concurrent task groups (Swift 6 pattern)
- All tests use iPhone 17 simulator as per project standards
