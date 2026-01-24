# Performance Profiling System Design

**Date:** 2026-01-24
**Purpose:** Capture memory and resource footprint of on-device video segmentation algorithm to determine headroom and guide optimization decisions

## Problem Statement

Need to understand how the video segmentation algorithm affects device resources (RAM, CPU, thermal state, GPU) to answer:
- Are we over-optimized (significant headroom available)?
- Are we hitting device limits (need to optimize)?
- Can we use more accurate/intensive techniques?

## Requirements

- Post-processing analysis (not real-time monitoring)
- JSON output for custom analysis
- Easy to understand (plain English recommendations)
- Target devices: iPhone 15+ (A17+ chipset, 6GB+ RAM)
- Metrics: Memory peaks/average, CPU utilization, thermal throttling, GPU usage
- On-demand via Settings toggle (not always-on)
- Minimal overhead when enabled (~1-2%)

## Architecture Overview

Three-layer architecture:

### 1. Capture Layer - PerformanceProfiler
- Samples metrics at 100ms intervals during processing
- Collects: Memory (current/peak), CPU%, thermal state, GPU memory
- Overhead: ~1% CPU, ~1MB RAM for 300 samples (30-second video)

### 2. Analysis Layer - ProfileAnalyzer
- Post-processes samples into insights
- Calculates: Peak/average metrics, headroom percentages
- Detects: Thermal throttling, memory pressure
- Generates: Plain English recommendations

### 3. Storage Layer - ProfilingReportWriter
- Binary timeline format (3KB for 300 samples)
- JSON summary format (5KB with metadata and analysis)
- Total: 8KB per report (92% smaller than pure JSON)

## Data Formats

### Binary Timeline (.bin)

Fixed-size struct (10 bytes per sample):

```swift
struct PerformanceSample {
    var timestamp: Float32        // 4 bytes - seconds since start
    var memoryMB: UInt16          // 2 bytes - 0-65535 MB
    var cpuPercent: UInt8         // 1 byte - 0-100%
    var thermalState: UInt8       // 1 byte - 0=nominal, 1=fair, 2=serious, 3=critical
    var gpuMemoryMB: UInt16       // 2 bytes - 0-65535 MB
}
```

**Storage:** 300 samples × 10 bytes = 3KB

### JSON Summary (.json)

```json
{
  "reportMetadata": {
    "reportId": "uuid",
    "timestamp": "2026-01-24T14:30:45Z",
    "sport": "Tennis",
    "sportMode": "Rally",
    "method": "SpectralFlux"
  },

  "deviceInfo": {
    "model": "iPhone15,2",
    "modelName": "iPhone 15 Pro",
    "chipset": "A17 Pro",
    "totalRAM": 8192,
    "osVersion": "iOS 18.2"
  },

  "memorySummary": {
    "peakUsageMB": 450,
    "averageUsageMB": 380,
    "headroomPercent": 89.1,
    "recommendation": "Excellent headroom. You can use more memory-intensive techniques..."
  },

  "cpuSummary": {
    "peakUtilization": 78.5,
    "averageUtilization": 62.3,
    "headroomPercent": 21.5,
    "recommendation": "Moderate CPU usage. Some room for optimization."
  },

  "thermalSummary": {
    "throttlingDetected": false,
    "stateChanges": [
      {"timestamp": 0.0, "state": "nominal"},
      {"timestamp": 18.5, "state": "fair"}
    ],
    "recommendation": "No thermal issues. Device stayed cool."
  },

  "gpuSummary": {
    "peakMemoryMB": 85,
    "averageMemoryMB": 65,
    "recommendation": "Minimal GPU usage. Could leverage GPU for frame analysis."
  },

  "overallAssessment": {
    "performanceCategory": "under_optimized",
    "recommendation": "Your algorithm is NOT hitting device limits. Significant headroom:\n- 89% memory available\n- 21% CPU headroom\n- No thermal throttling\n\nYou can use more accurate techniques."
  },

  "binaryTimelineFile": "profile_2026-01-24_14-30-45.bin",
  "sampleCount": 300
}
```

**Storage:** ~5KB

## File Structure

```
Documents/ProfilingReports/
├─ profile_2026-01-24_14-30-45.json  (5KB - summary + recommendations)
└─ profile_2026-01-24_14-30-45.bin   (3KB - timeline samples)
```

## Implementation Components

### 1. PerformanceProfiler (actor)

**Responsibilities:**
- Start/stop profiling lifecycle
- Sample metrics every 100ms in background loop
- Collect memory, CPU, thermal, GPU metrics
- Return samples array on stop

**Key Methods:**
```swift
func startProfiling()
func stopProfiling() -> [PerformanceSample]
private func recordSample()
private func currentMemoryUsage() -> UInt16      // via mach_task_basic_info
private func currentCPUUsage() -> UInt8          // via thread_info
private func currentThermalState() -> UInt8      // via ProcessInfo
private func currentGPUMemory() -> UInt16        // via Metal
```

**Sampling Strategy:**
- 100ms intervals (fast enough for spikes, slow enough for low overhead)
- Background Task loop (doesn't block processing)
- Runs only when ProfilingConfig.isEnabled = true

### 2. ProfileAnalyzer (struct)

**Responsibilities:**
- Analyze samples array to generate summary
- Calculate peak/average metrics
- Compute headroom percentages
- Generate plain English recommendations
- Detect thermal state changes

**Key Methods:**
```swift
func generateSummary(sport: Sport, processingDuration: Double, deviceInfo: DeviceInfo) -> ProfilingSummary
private func memoryRecommendation(headroomPercent: Double) -> String
private func cpuRecommendation(peakCPU: Double) -> String
private func thermalRecommendation(throttlingDetected: Bool) -> String
private func generateOverallAssessment(...) -> OverallAssessment
private func detectThermalChanges() -> [ThermalStateChange]
```

**Recommendation Logic:**

Memory Headroom:
- 80%+: "Excellent. Use more memory-intensive techniques."
- 50-80%: "Good. Room for moderate increases."
- 20-50%: "Moderate. Be cautious."
- <20%: "Low. Optimize or risk crashes."

CPU Headroom:
- <60% peak: "Low usage. Room for compute-intensive features."
- 60-80%: "Moderate. Some room for optimization."
- 80-95%: "High. Near device limits."
- 95%+: "Saturated. Optimize or offload to GPU."

Thermal:
- No throttling: "No thermal issues."
- Throttling detected: "Device reduced performance to cool down."

Overall Assessment:
- `under_optimized`: >70% memory headroom, >30% CPU headroom, no throttling
- `at_limits`: Throttling OR <10% CPU headroom
- `balanced`: Everything else

### 3. ProfilingReportWriter (class)

**Responsibilities:**
- Write binary timeline to .bin file
- Write JSON summary to .json file
- Create ProfilingReports directory if needed
- Generate timestamped filenames

**Key Methods:**
```swift
func writeReport(samples: [PerformanceSample], summary: ProfilingSummary) throws -> URL
```

**Implementation:**
```swift
// Binary timeline
var data = Data(capacity: samples.count * 10)
for sample in samples {
    withUnsafeBytes(of: sample) { data.append(contentsOf: $0) }
}
try data.write(to: timelineURL)

// JSON summary
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
try encoder.encode(summary).write(to: summaryURL)
```

### 4. ProfilingConfig (enum)

**Responsibilities:**
- Global toggle state via UserDefaults
- Single source of truth for profiling enabled/disabled

**Implementation:**
```swift
enum ProfilingConfig {
    private static let key = "com.sportcrunch.profiling.enabled"

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}
```

### 5. Integration with VideoProcessingService

**Modifications to RealVideoProcessingService:**

```swift
final class RealVideoProcessingService: VideoProcessingServiceProtocol {

    private let profiler = PerformanceProfiler()

    func processVideo(sourceURL: URL, sport: Sport, sportMode: SportMode?) async throws -> ProcessingResult {

        // Start profiling if enabled
        let shouldProfile = ProfilingConfig.isEnabled
        if shouldProfile {
            await profiler.startProfiling()
        }

        // ... existing processing code ...
        let pipelineStart = Date()
        let segments = try await algorithm.detectSegments(videoURL: sourceURL)
        let result = try await exportSegments(...)
        let totalElapsed = Date().timeIntervalSince(pipelineStart)

        // Stop profiling and generate report
        if shouldProfile {
            let samples = await profiler.stopProfiling()
            try? await generateProfilingReport(
                samples: samples,
                result: result,
                sport: sport,
                processingDuration: totalElapsed
            )
        }

        return result
    }

    private func generateProfilingReport(
        samples: [PerformanceSample],
        result: ProcessingResult,
        sport: Sport,
        processingDuration: Double
    ) async throws {

        let analyzer = ProfileAnalyzer(samples: samples)
        let summary = analyzer.generateSummary(
            sport: sport,
            processingDuration: processingDuration,
            deviceInfo: DeviceInfo.current()
        )

        let writer = ProfilingReportWriter()
        let reportURL = try writer.writeReport(samples: samples, summary: summary)

        print("📊 [Profiling] Report saved: \(reportURL.lastPathComponent)")
    }
}
```

### 6. Settings UI Toggle

**Addition to SettingsView.swift:**

```swift
struct SettingsView: View {
    @State private var profilingEnabled = ProfilingConfig.isEnabled

    var body: some View {
        Form {
            // ... existing settings sections ...

            Section(header: Text("Performance Profiling")) {
                Toggle("Enable Profiling", isOn: $profilingEnabled)
                    .onChange(of: profilingEnabled) { newValue in
                        ProfilingConfig.isEnabled = newValue
                    }

                if profilingEnabled {
                    Text("Captures memory, CPU, and thermal metrics during processing. Reports saved to Documents/ProfilingReports/")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
```

## Performance Overhead Analysis

### When Profiling is Disabled
- Zero overhead (ProfilingConfig.isEnabled = false, no profiler created)
- No sampling loop started
- No disk writes

### When Profiling is Enabled

**Per-sample overhead:**
- Memory check: ~0.1ms (mach_task_basic_info)
- CPU check: ~0.5ms (thread_info iteration)
- Thermal check: <0.1ms (ProcessInfo property)
- GPU check: ~0.2ms (Metal query)
- **Total: ~0.9ms per sample**

**For 30-second processing run:**
- 300 samples × 0.9ms = 270ms total overhead
- 270ms / 30,000ms = 0.9% of processing time
- **Acceptable for profiling purposes**

**Memory overhead:**
- 300 samples × 10 bytes = 3KB in memory
- Plus overhead for Task and profiler state: ~100KB
- **Total: ~1MB RAM**

## Usage Workflow

### 1. Enable Profiling
- Open Settings
- Toggle "Enable Profiling" ON
- See confirmation message

### 2. Process a Video
- Select sport and video as normal
- Processing runs with profiling active
- No visible UI changes (happens in background)

### 3. Check Report
- After processing completes
- Navigate to Files app → On My iPhone → SportCrunch → ProfilingReports
- Open latest .json file
- Read `overallAssessment.recommendation` for plain English guidance

### 4. Analyze Timeline (Optional)
- Use custom tools to parse .bin file
- Plot memory/CPU over time
- Correlate with specific algorithm phases

### 5. Disable Profiling
- Return to Settings
- Toggle "Enable Profiling" OFF
- Zero overhead for future processing runs

## Example Report Output

### Scenario: Under-Optimized Algorithm

```json
{
  "memorySummary": {
    "peakUsageMB": 380,
    "headroomPercent": 91.2,
    "recommendation": "Excellent headroom. You can use more memory-intensive techniques (higher resolution, ML models)."
  },

  "cpuSummary": {
    "peakUtilization": 45.3,
    "headroomPercent": 54.7,
    "recommendation": "Low CPU usage. Significant room for more compute-intensive features."
  },

  "overallAssessment": {
    "performanceCategory": "under_optimized",
    "recommendation": "Your algorithm is NOT hitting device limits. Significant headroom available:\n- 91% memory headroom\n- 55% CPU headroom\n- No thermal throttling\n\nYou can confidently use more accurate/intensive techniques."
  }
}
```

**Interpretation:** Algorithm is over-optimized. Safe to add ML-based segmentation, higher-resolution frame analysis, or real-time visual validation.

### Scenario: At Device Limits

```json
{
  "memorySummary": {
    "peakUsageMB": 5800,
    "headroomPercent": 8.2,
    "recommendation": "Low headroom. Optimize memory usage or risk crashes."
  },

  "cpuSummary": {
    "peakUtilization": 96.5,
    "headroomPercent": 3.5,
    "recommendation": "CPU saturated. Optimize algorithms or offload to GPU."
  },

  "thermalSummary": {
    "throttlingDetected": true,
    "recommendation": "Thermal throttling detected. Device reduced performance to cool down."
  },

  "overallAssessment": {
    "performanceCategory": "at_limits",
    "recommendation": "Device is at or near limits. Optimize before adding features."
  }
}
```

**Interpretation:** Algorithm is hitting device limits. Optimize existing code before adding features. Consider GPU offloading or reducing resolution.

## Benefits

1. **Data-Driven Decisions:** Know exactly how much headroom exists
2. **Plain English Guidance:** No need to interpret raw metrics
3. **Efficient Storage:** 8KB per report (vs 95KB for pure JSON)
4. **Zero Production Overhead:** Disabled by default, no performance impact
5. **Easy Analysis:** JSON summary + optional binary timeline for deep analysis
6. **Device-Accurate:** Real on-device metrics, not simulator estimates

## Future Enhancements (Not in Scope)

- Export reports via Share sheet
- Real-time profiling UI (live charts)
- Automatic comparison between runs
- Integration with Xcode Instruments
- Cloud upload for cross-device comparison

## Testing Strategy

1. **Unit Tests:** ProfileAnalyzer recommendation logic
2. **Integration Tests:** Full profiling workflow (start → sample → stop → write)
3. **Manual Testing:** Enable toggle, process video, verify report generation
4. **Performance Testing:** Measure overhead with/without profiling enabled
5. **Device Testing:** iPhone 15 Pro (primary), iPhone 14 (compatibility check)

## Implementation Order

1. PerformanceSample struct + binary encoding
2. PerformanceProfiler actor (metric collection)
3. ProfileAnalyzer (summary generation)
4. ProfilingReportWriter (file I/O)
5. ProfilingConfig (toggle state)
6. VideoProcessingService integration
7. SettingsView UI toggle
8. Testing and validation

## Success Criteria

- Toggle in Settings controls profiling on/off
- Reports written to Documents/ProfilingReports/ after processing
- Summary JSON contains plain English recommendations
- Binary timeline is <5KB for typical 30-second processing run
- Overhead is <2% when profiling enabled
- Recommendations accurately reflect device headroom (validated manually)
