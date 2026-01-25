# Observation Architecture & Dashboard Lab View Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement a generic `Observation` architecture for segmentation methods to record signals, events, and artifacts, and visualize them in a new "Lab" view on the Dashboard.

**Architecture:**
1.  **Runner:** Introduce `Observation` class (thread-safe) passed through `SegmentationMethod`.
2.  **Runner:** Update `SpectralFluxMethod` to record signals (audio flux, motion score) and events (peaks, validation).
3.  **Runner:** Update `ArtifactExporter` to serialize observations and save image artifacts.
4.  **Dashboard:** Create `Lab` view with synchronized charts (Recharts) and interactive event ledger.
5.  **Dashboard:** Implement background artifact pulling logic.

**Tech Stack:** Swift (iOS/macOS), Node.js (Backend), React + Recharts (Frontend).

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
    func testSignalRecording() {
        let obs = Observation()
        obs.addSignalPoint(name: "audio_flux", time: 1.0, value: 0.5)
        obs.addSignalPoint(name: "audio_flux", time: 1.1, value: 0.8)
        
        let signals = obs.signals["audio_flux"]
        XCTAssertEqual(signals?.count, 2)
        XCTAssertEqual(signals?[0].value, 0.5)
    }
    
    func testEventRecording() {
        let obs = Observation()
        obs.addEvent(name: "peak", time: 1.5, metadata: ["confidence": "0.9"])
        
        XCTAssertEqual(obs.events.count, 1)
        XCTAssertEqual(obs.events[0].name, "peak")
        XCTAssertEqual(obs.events[0].metadata["confidence"], "0.9")
    }
    
    func testThreadSafety() {
        let obs = Observation()
        let group = DispatchGroup()
        
        for _ in 0..<100 {
            group.enter()
            DispatchQueue.global().async {
                obs.addSignalPoint(name: "test", time: 0, value: 0)
                group.leave()
            }
        }
        
        group.wait()
        XCTAssertEqual(obs.signals["test"]?.count, 100)
    }
}
```

**Step 2: Run test to verify failure**

Run: `xcodebuild test -scheme SportCrunch -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SportCrunchTests/ObservationTests`
Expected: FAIL (Observation not defined)

**Step 3: Implement Observation Model**

```swift
// app/SportCrunch/Core/Models/Observation.swift
import Foundation

public final class Observation: @unchecked Sendable, Codable {
    private let lock = NSLock()
    
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
    
    public private(set) var signals: [String: [SignalPoint]] = [:]
    public private(set) var events: [Event] = []
    public private(set) var artifactPaths: [String: URL] = [:] // Local paths, not codified directly usually, but we need to export them.
    // We will custom encode artifactPaths as relative paths or ignore them during standard codable if needed, 
    // but for export we likely want to just move files. 
    // Let's make artifactPaths Codable for simplicity but exclude from JSON if needed? 
    // Actually, for the JSON export, we only need signals and events. Artifact paths are local temp.
    
    enum CodingKeys: String, CodingKey {
        case signals, events
    }
    
    public init() {}
    
    public func addSignalPoint(name: String, time: TimeInterval, value: Double) {
        lock.lock()
        defer { lock.unlock() }
        
        if signals[name] == nil {
            signals[name] = []
        }
        signals[name]?.append(SignalPoint(time: time, value: value))
    }
    
    public func addEvent(name: String, time: TimeInterval, metadata: [String: String] = [:], artifactId: String? = nil) {
        lock.lock()
        defer { lock.unlock() }
        
        let event = Event(timestamp: time, name: name, metadata: metadata, artifactId: artifactId)
        events.append(event)
    }
    
    public func registerArtifact(id: String, fileURL: URL) {
        lock.lock()
        defer { lock.unlock() }
        artifactPaths[id] = fileURL
    }
}
```

**Step 4: Run test to verify pass**

Run: `xcodebuild test -scheme SportCrunch -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SportCrunchTests/ObservationTests`
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
    // Update signature
    func detectSegments(videoURL: URL, observation: Observation?) async throws -> [ActionSegment]
}

// Add default extension for backward compatibility if needed, OR just update calls.
extension SegmentationMethod {
    func detectSegments(videoURL: URL) async throws -> [ActionSegment] {
        return try await detectSegments(videoURL: videoURL, observation: nil)
    }
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

**Step 3: Update Call Sites (Runner)**

We need to pass the observation in `RunExecutor.swift` later, but for now we ensure compilation works.
We added a default extension, so main app shouldn't break.

**Step 4: Verify Compilation**

Run: `xcodebuild build -scheme SportCrunch -destination 'platform=iOS Simulator,name=iPhone 16'`
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
- Record `audio_flux` signal (downsample if necessary, or full resolution).
- Record `audio_peak` events.

```swift
// Inside analyze() ...
let onsetStrength = computeOnsetStrength(filteredSamples)

// Record signal
if let obs = observation {
    let frameDuration = Double(hopLength) / sampleRate
    for (i, val) in onsetStrength.enumerated() {
        obs.addSignalPoint(name: "audio_flux", time: Double(i) * frameDuration, value: Double(val))
    }
    
    // Record peaks
    for (i, val) in peakIndices.enumerated() {
         obs.addEvent(name: "audio_peak", time: peakTimes[i], metadata: ["strength": "\(onsetStrength[val])"])
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

- Save images to temporary directory.
- Register artifacts in `Observation`.

```swift
// Inside validateSegmentBatch ...
// Calculate score...

if let obs = observation {
    // Record decision
    let status = isValid ? "accepted" : (motionScore < motionAreaThreshold ? "rejected_low_motion" : "rejected_other")
    let eventId = UUID()
    
    // Save artifact if "interesting" (rejected or borderline)
    // ... logic to save image ...
    // obs.registerArtifact(id: artifactId, fileURL: tempURL)
    // obs.addEvent(name: "validation_decision", time: start, metadata: [...], artifactId: artifactId)
    
    // Record signal point (sparse)
    obs.addSignalPoint(name: "motion_score", time: start, value: motionScore)
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
// ...
let observation = Observation()
let segments = try await method.detectSegments(videoURL: videoURL, observation: observation)
// ...
// Pass observation to exporter
let artifactPaths = try exporter.export(..., observation: observation)
```

**Step 2: Update ArtifactExporter**

```swift
// ArtifactExporter.swift
func export(run: Run, segments: [ExportedSegment], highlightURL: URL?, observation: Observation?) throws -> ArtifactPaths {
    // ... export segments.json ...
    
    if let obs = observation {
        // 1. Write observations.json
        let obsData = try JSONEncoder().encode(obs)
        try obsData.write(to: runDirectory.appendingPathComponent("observations.json"))
        
        // 2. Move artifacts
        let artifactsDir = runDirectory.appendingPathComponent("artifacts")
        try fileManager.createDirectory(at: artifactsDir, withIntermediateDirectories: true)
        
        for (id, tempURL) in obs.artifactPaths {
            let destURL = artifactsDir.appendingPathComponent("\(id).jpg") // Assuming jpg
            try fileManager.copyItem(at: tempURL, to: destURL)
        }
    }
    // ...
}
```

**Step 3: Commit**

```bash
git add app/SportCrunchRunner/Services/RunExecutor.swift app/SportCrunchRunner/Services/ArtifactExporter.swift
git commit -m "feat: export Observation and artifacts in Runner"
```

---

### Task 7: Dashboard Backend Pull Logic

**Files:**
- Modify: `dashboard/backend/server.js`

**Step 1: Add Artifact Pulling Endpoint**

Implement `POST /api/runs/:id/sync` that calls `xcrun devicectl` to pull the specific run folder.

**Step 2: Commit**

```bash
git add dashboard/backend/server.js
git commit -m "feat: add artifact sync endpoint"
```

---

### Task 8: Dashboard Frontend Lab View

**Files:**
- Create: `dashboard/frontend/src/pages/Lab.jsx`
- Modify: `dashboard/frontend/src/App.jsx` (Add route)
- Modify: `dashboard/frontend/src/components/RunHistory.jsx` (Link to Lab)

**Step 1: Create Basic Lab View**

Just fetch `observations.json` and dump it to verify data flow.

**Step 2: Commit**

```bash
git add dashboard/frontend/src/pages/Lab.jsx dashboard/frontend/src/App.jsx
git commit -m "feat: add basic Lab view scaffold"
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
