//
//  DebugReportService.swift
//  SportCrunch
//
//  Generates comprehensive debug reports for comparing processing runs
//  between simulator and device to identify platform-specific differences.
//

import Foundation
import UIKit
import CryptoKit
import AVFoundation

// MARK: - Debug Report

/// Comprehensive debug report for a video processing run.
/// Contains all information needed to compare simulator vs device behavior.
struct DebugReport: Codable {
    
    // MARK: - Report Metadata
    
    let reportId: String
    let generatedAt: Date
    let reportVersion: String
    
    // MARK: - Platform Information
    
    let platform: PlatformInfo
    
    // MARK: - Input File Information
    
    let inputFile: InputFileInfo
    
    // MARK: - Processing Configuration
    
    let configuration: ProcessingConfiguration
    
    // MARK: - Audio Analysis Details
    
    var audioAnalysis: AudioAnalysisDetails?
    
    // MARK: - Visual Validation Details
    
    var visualValidation: VisualValidationDetails?
    
    // MARK: - Export Details
    
    var exportDetails: ExportDetails?
    
    // MARK: - Timing Information
    
    var timing: TimingInfo?
    
    // MARK: - Processing Logs
    
    var logs: [LogEntry]
    
    // MARK: - Final Results
    
    var results: ProcessingResults?
    
    init(inputFileURL: URL, sport: Sport, sportMode: SportMode?) {
        self.reportId = UUID().uuidString
        self.generatedAt = Date()
        self.reportVersion = "1.0"
        self.platform = PlatformInfo()
        self.inputFile = InputFileInfo(url: inputFileURL)
        self.configuration = ProcessingConfiguration(sport: sport, sportMode: sportMode)
        self.logs = []
    }
}

// MARK: - Platform Information

struct PlatformInfo: Codable {
    let isSimulator: Bool
    let architecture: String
    let osVersion: String
    let deviceModel: String
    let deviceName: String
    let processorCount: Int
    let physicalMemory: UInt64
    let thermalState: String
    let lowPowerMode: Bool
    
    init() {
        #if targetEnvironment(simulator)
        self.isSimulator = true
        self.architecture = "x86_64"
        #else
        self.isSimulator = false
        self.architecture = "arm64"
        #endif
        
        self.osVersion = UIDevice.current.systemVersion
        self.deviceModel = Self.getDeviceModel()
        self.deviceName = UIDevice.current.name
        self.processorCount = ProcessInfo.processInfo.processorCount
        self.physicalMemory = ProcessInfo.processInfo.physicalMemory
        self.thermalState = Self.getThermalState()
        self.lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    }
    
    private static func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
    
    private static func getThermalState() -> String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }
}

// MARK: - Input File Information

struct InputFileInfo: Codable {
    let fileName: String
    let filePath: String
    let fileSizeBytes: Int64
    let fileSizeMB: Double
    let sha256Hash: String
    let duration: Double?
    let videoCodec: String?
    let audioCodec: String?
    let videoResolution: String?
    let frameRate: Double?
    let audiaSampleRate: Double?
    let audioChannels: Int?
    
    init(url: URL) {
        self.fileName = url.lastPathComponent
        self.filePath = url.path
        
        // File size
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64 {
            self.fileSizeBytes = size
            self.fileSizeMB = Double(size) / 1024 / 1024
        } else {
            self.fileSizeBytes = 0
            self.fileSizeMB = 0
        }
        
        // SHA256 hash of file
        self.sha256Hash = Self.computeSHA256(for: url)
        
        // Media properties (computed asynchronously but we need sync init)
        // These will be populated separately
        self.duration = nil
        self.videoCodec = nil
        self.audioCodec = nil
        self.videoResolution = nil
        self.frameRate = nil
        self.audiaSampleRate = nil
        self.audioChannels = nil
    }
    
    private static func computeSHA256(for url: URL) -> String {
        guard let data = try? Data(contentsOf: url) else {
            return "ERROR: Could not read file"
        }
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Processing Configuration

struct ProcessingConfiguration: Codable {
    let sport: String
    let sportMode: String?
    
    // Audio Processing
    let sampleRate: Double
    let bandpassLow: Double
    let bandpassHigh: Double
    
    // Onset Detection
    let onsetThresholdLambda: Float
    let peakMinDistanceSec: Double
    
    // Clustering
    let clusterMaxGapSec: Double
    let clusterMinHits: Int
    
    // Padding
    let paddingPreSec: Double
    let paddingPostSec: Double
    
    // Visual Validation
    let skipVisualValidation: Bool
    let videoSampleStride: Int
    let videoThumbWidth: Int
    let videoThumbHeight: Int
    let motionPixelThreshold: Int
    let motionAreaThreshold: Double
    
    init(sport: Sport, sportMode: SportMode?) {
        self.sport = sport.displayName
        self.sportMode = (sportMode as? TennisMode)?.displayName
        
        let preset = sport.preset(for: sportMode)
        self.sampleRate = preset.sampleRate
        self.bandpassLow = preset.bandpassLow
        self.bandpassHigh = preset.bandpassHigh
        self.onsetThresholdLambda = preset.onsetThresholdLambda
        self.peakMinDistanceSec = preset.peakMinDistanceSec
        self.clusterMaxGapSec = preset.clusterMaxGapSec
        self.clusterMinHits = preset.clusterMinHits
        self.paddingPreSec = preset.paddingPreSec
        self.paddingPostSec = preset.paddingPostSec
        self.skipVisualValidation = preset.skipVisualValidation
        self.videoSampleStride = preset.videoSampleStride
        self.videoThumbWidth = preset.videoThumbSize.width
        self.videoThumbHeight = preset.videoThumbSize.height
        self.motionPixelThreshold = preset.motionPixelThreshold
        self.motionAreaThreshold = preset.motionAreaThreshold
    }
}

// MARK: - Audio Analysis Details

struct AudioAnalysisDetails: Codable {
    // Raw audio extraction
    let extractedSampleCount: Int
    let extractedDuration: Double
    let rawAudioFingerprint: AudioFingerprint
    
    // Filtered audio
    let filteredAudioFingerprint: AudioFingerprint
    
    // First N samples for direct comparison
    let first100RawSamples: [Float]
    let first100FilteredSamples: [Float]
    
    // Onset strength
    let onsetFrameCount: Int
    let onsetStrengthFingerprint: AudioFingerprint
    let onsetStrengthStats: StatisticalSummary
    let top20OnsetStrengths: [IndexedValue]
    let first50OnsetStrengths: [Float]
    
    // Adaptive threshold
    let thresholdStats: StatisticalSummary
    let first50Thresholds: [Float]
    
    // Peak detection
    let detectedPeakCount: Int
    let peakDetails: [PeakDetail]
    
    // Clustering
    let clusterCount: Int
    let clusters: [ClusterDetail]
    
    // Final candidate intervals
    let candidateIntervals: [IntervalDetail]
}

struct AudioFingerprint: Codable {
    let count: Int
    let sum: Float
    let sumOfSquares: Float
    let min: Float
    let max: Float
    let mean: Float
    let variance: Float
    let stdDev: Float
    
    init(samples: [Float]) {
        self.count = samples.count
        guard !samples.isEmpty else {
            self.sum = 0
            self.sumOfSquares = 0
            self.min = 0
            self.max = 0
            self.mean = 0
            self.variance = 0
            self.stdDev = 0
            return
        }
        
        let computedSum = samples.reduce(0, +)
        let computedMean = computedSum / Float(samples.count)
        
        self.sum = computedSum
        self.sumOfSquares = samples.reduce(0) { $0 + $1 * $1 }
        self.min = samples.min() ?? 0
        self.max = samples.max() ?? 0
        self.mean = computedMean
        
        var varianceSum: Float = 0
        for sample in samples {
            let diff = sample - computedMean
            varianceSum += diff * diff
        }
        self.variance = varianceSum / Float(samples.count)
        self.stdDev = sqrt(self.variance)
    }
}

struct StatisticalSummary: Codable {
    let count: Int
    let min: Float
    let max: Float
    let mean: Float
    let median: Float
    let stdDev: Float
    let p25: Float
    let p75: Float
    let p90: Float
    let p95: Float
    let p99: Float
    
    init(values: [Float]) {
        self.count = values.count
        guard !values.isEmpty else {
            self.min = 0
            self.max = 0
            self.mean = 0
            self.median = 0
            self.stdDev = 0
            self.p25 = 0
            self.p75 = 0
            self.p90 = 0
            self.p95 = 0
            self.p99 = 0
            return
        }
        
        let sorted = values.sorted()
        let computedMean = values.reduce(0, +) / Float(values.count)
        
        self.min = sorted.first!
        self.max = sorted.last!
        self.mean = computedMean
        self.median = sorted[sorted.count / 2]
        
        var varianceSum: Float = 0
        for value in values {
            let diff = value - computedMean
            varianceSum += diff * diff
        }
        self.stdDev = sqrt(varianceSum / Float(values.count))
        
        self.p25 = sorted[Int(Double(sorted.count) * 0.25)]
        self.p75 = sorted[Int(Double(sorted.count) * 0.75)]
        self.p90 = sorted[Int(Double(sorted.count) * 0.90)]
        self.p95 = sorted[Int(Double(sorted.count) * 0.95)]
        self.p99 = sorted[Swift.min(sorted.count - 1, Int(Double(sorted.count) * 0.99))]
    }
}

struct IndexedValue: Codable {
    let index: Int
    let value: Float
    let timeSeconds: Double
}

struct PeakDetail: Codable {
    let index: Int
    let peakIndex: Int
    let timeSeconds: Double
    let onsetStrength: Float
    let threshold: Float
    let margin: Float  // How much above threshold
}

struct ClusterDetail: Codable {
    let clusterIndex: Int
    let hitCount: Int
    let firstHitTime: Double
    let lastHitTime: Double
    let duration: Double
    let hitTimes: [Double]
}

struct IntervalDetail: Codable {
    let index: Int
    let startTime: Double
    let endTime: Double
    let duration: Double
    let hitCount: Int
}

// MARK: - Visual Validation Details (Enhanced)

struct VisualValidationDetails: Codable {
    let segmentsValidated: Int
    let segmentsApproved: Int
    let segmentsRejected: Int
    let validationResults: [SegmentValidationDetail]
    
    // Platform-specific frame processing info
    let frameProcessingInfo: FrameProcessingInfo?
    
    // Aggregated statistics across all segments
    let aggregateStats: VisualValidationStats?
}

struct FrameProcessingInfo: Codable {
    let thumbnailWidth: Int
    let thumbnailHeight: Int
    let pixelCount: Int
    let frameStride: Int
    let motionPixelThreshold: Int
    let motionAreaThreshold: Double
    let sourceVideoFPS: Double
    let sourceVideoResolution: String
}

struct VisualValidationStats: Codable {
    let totalFramesRequested: Int
    let totalFramesExtracted: Int
    let frameExtractionSuccessRate: Double
    let averageMotionScore: Double
    let medianMotionScore: Double
    let minMotionScore: Double
    let maxMotionScore: Double
    let stdDevMotionScore: Double
    let approvalRate: Double
}

struct SegmentValidationDetail: Codable {
    let segmentIndex: Int
    let startTime: Double
    let endTime: Double
    let duration: Double
    
    // Frame extraction details
    let framesRequested: Int
    let framesExtracted: Int
    let frameExtractionRate: Double
    
    // Motion analysis details
    let motionScore: Double
    let threshold: Double
    let isValid: Bool
    let usedEarlyExit: Bool
    let framesProcessedBeforeDecision: Int
    
    // Per-frame motion scores (all of them for comparison)
    let allFrameScores: [Double]
    
    // Frame pair analysis for first N pairs (detailed debugging)
    let framePairDetails: [FramePairDetail]?
    
    // Errors encountered during frame extraction (for debugging device issues)
    let extractionErrors: [String]?
}

/// Detailed info about a single frame pair comparison for motion detection
struct FramePairDetail: Codable {
    let pairIndex: Int
    let frameATime: Double
    let frameBTime: Double
    
    // Frame dimensions (to detect resizing issues)
    let frameAWidth: Int
    let frameAHeight: Int
    let frameBWidth: Int
    let frameBHeight: Int
    
    // Grayscale conversion stats
    let frameAGrayscaleMean: Float
    let frameAGrayscaleStdDev: Float
    let frameBGrayscaleMean: Float
    let frameBGrayscaleStdDev: Float
    
    // Motion computation intermediates
    let rawDiffSum: Float           // Sum of absolute differences before threshold
    let rawDiffMean: Float          // Mean of absolute differences
    let rawDiffMax: Float           // Max absolute difference
    let pixelsAboveThreshold: Int   // Count of pixels exceeding threshold
    let motionScore: Double         // Final motion score for this pair
}

// MARK: - Export Details (Enhanced for timing/slow-mo diagnosis)

struct ExportDetails: Codable {
    let outputFileName: String
    let outputFilePath: String
    let outputFileSizeBytes: Int64
    let outputFileSizeMB: Double
    let outputDuration: Double
    let segmentsExported: Int
    let compressionRatio: Double
    
    // Enhanced: Source video properties (critical for slow-mo diagnosis)
    let sourceVideoProperties: SourceVideoProperties?
    
    // Enhanced: Composition configuration
    let compositionConfig: CompositionConfig?
    
    // Enhanced: Per-segment timing details
    let segmentTimingDetails: [SegmentTimingDetail]?
    
    // Enhanced: Output video verification
    let outputVideoVerification: OutputVideoVerification?
}

/// Source video timing and format properties - critical for diagnosing slow-mo
struct SourceVideoProperties: Codable {
    // Basic timing
    let duration: Double
    let durationCMTime: String              // CMTime as string for exact comparison
    let nominalFrameRate: Float
    let minFrameDuration: String            // CMTime as string
    let naturalTimeScale: Int32
    
    // Track info
    let videoTrackCount: Int
    let audioTrackCount: Int
    
    // Video format
    let naturalSize: String                 // "WIDTHxHEIGHT"
    let preferredTransform: String          // Transform matrix as string
    let isVideoPortrait: Bool
    
    // Color space (for color issues)
    let colorPrimaries: String?
    let transferFunction: String?
    let ycbcrMatrix: String?
    
    // Codec info
    let videoCodecType: String?
    let videoCodecName: String?
    
    // For detecting variable frame rate videos (VFR) which can cause issues
    let hasVariableFrameRate: Bool?
}

/// Composition configuration used during export
struct CompositionConfig: Codable {
    let exportPreset: String
    let outputFileType: String
    let shouldOptimizeForNetworkUse: Bool
    
    // Video composition settings
    let usedVideoComposition: Bool
    let renderSize: String?                 // "WIDTHxHEIGHT"
    let frameDuration: String?              // CMTime as string
    let frameRate: Double?
    
    // Color settings applied
    let colorPrimariesApplied: String?
    let transferFunctionApplied: String?
    let ycbcrMatrixApplied: String?
    
    // Transform handling
    let appliedTransform: String?
}

/// Per-segment timing details for diagnosing timing issues
struct SegmentTimingDetail: Codable {
    let segmentIndex: Int
    
    // Requested times
    let requestedStartTime: Double
    let requestedEndTime: Double
    let requestedDuration: Double
    
    // CMTime values used (exact representation)
    let startCMTime: String                 // e.g., "12345/600"
    let endCMTime: String
    let durationCMTime: String
    
    // Insertion position
    let insertionPosition: String           // CMTime at which segment was inserted
    
    // Success/failure
    let insertedSuccessfully: Bool
    let errorMessage: String?
    
    // Time range validation
    let timeRangeValid: Bool
    let clampedToVideoBounds: Bool
}

/// Verification of output video properties (to compare with input)
struct OutputVideoVerification: Codable {
    let duration: Double
    let durationCMTime: String
    let expectedDuration: Double            // Sum of segment durations
    let durationMismatch: Double            // Difference from expected
    let durationMismatchPercent: Double
    
    // Frame rate verification (critical for slow-mo)
    let nominalFrameRate: Float?
    let frameRateMismatch: Bool
    let sourceFrameRate: Float
    
    // Output format
    let naturalSize: String?
    let videoCodecType: String?
    
    // Timing accuracy
    let timingAccurate: Bool                // true if duration matches expected within tolerance
    let timingIssueDescription: String?
}

// MARK: - Timing Information

struct TimingInfo: Codable {
    let totalProcessingTime: Double
    let audioExtractionTime: Double
    let audioFilteringTime: Double
    let onsetDetectionTime: Double
    let peakDetectionTime: Double
    let clusteringTime: Double
    let visualValidationTime: Double
    let exportTime: Double
    
    var breakdown: [String: Double] {
        [
            "Audio Extraction": audioExtractionTime,
            "Audio Filtering": audioFilteringTime,
            "Onset Detection": onsetDetectionTime,
            "Peak Detection": peakDetectionTime,
            "Clustering": clusteringTime,
            "Visual Validation": visualValidationTime,
            "Export": exportTime
        ]
    }
}

// MARK: - Processing Results

struct ProcessingResults: Codable {
    let success: Bool
    let errorMessage: String?
    let inputDuration: Double
    let outputDuration: Double
    let reductionPercent: Double
    let segmentCount: Int
    let segments: [SegmentResult]
}

struct SegmentResult: Codable {
    let index: Int
    let startTime: Double
    let endTime: Double
    let duration: Double
    let confidence: Double
}

// MARK: - Log Entry

struct LogEntry: Codable {
    let timestamp: Date
    let level: String  // "debug", "info", "warning", "error"
    let component: String  // "AudioAnalyzer", "VisualValidator", etc.
    let message: String
    let data: [String: String]?
}

// MARK: - Debug Report Service

actor DebugReportService {
    
    static let shared = DebugReportService()
    
    private var currentReport: DebugReport?
    private var isEnabled: Bool = true
    
    // MARK: - Report Lifecycle
    
    /// Start a new debug report for a processing run.
    func startReport(inputFileURL: URL, sport: Sport, sportMode: SportMode?) {
        guard isEnabled else { return }
        currentReport = DebugReport(inputFileURL: inputFileURL, sport: sport, sportMode: sportMode)
        log(level: "info", component: "DebugReport", message: "Started new debug report", data: [
            "reportId": currentReport?.reportId ?? "unknown",
            "file": inputFileURL.lastPathComponent
        ])
    }
    
    /// Enable or disable debug reporting.
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }
    
    // MARK: - Logging
    
    /// Add a log entry to the current report.
    func log(level: String, component: String, message: String, data: [String: String]? = nil) {
        guard isEnabled, currentReport != nil else { return }
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            component: component,
            message: message,
            data: data
        )
        currentReport?.logs.append(entry)
    }
    
    // MARK: - Audio Analysis Data
    
    /// Record audio analysis details.
    func recordAudioAnalysis(_ details: AudioAnalysisDetails) {
        guard isEnabled else { return }
        currentReport?.audioAnalysis = details
    }
    
    // MARK: - Visual Validation Data
    
    /// Record visual validation details.
    func recordVisualValidation(_ details: VisualValidationDetails) {
        guard isEnabled else { return }
        currentReport?.visualValidation = details
    }
    
    // MARK: - Export Data
    
    /// Record export details.
    func recordExport(_ details: ExportDetails) {
        guard isEnabled else { return }
        currentReport?.exportDetails = details
    }
    
    // MARK: - Timing Data
    
    /// Record timing information.
    func recordTiming(_ timing: TimingInfo) {
        guard isEnabled else { return }
        currentReport?.timing = timing
    }
    
    // MARK: - Results
    
    /// Record final processing results.
    func recordResults(_ results: ProcessingResults) {
        guard isEnabled else { return }
        currentReport?.results = results
    }
    
    // MARK: - Export Report
    
    /// Finalize and save the debug report.
    /// Returns the URL where the report was saved.
    func finalizeReport() throws -> URL? {
        guard isEnabled, let report = currentReport else { return nil }
        
        // Create debug reports directory
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let reportsDir = documentsURL.appendingPathComponent("DebugReports", isDirectory: true)
        try FileManager.default.createDirectory(at: reportsDir, withIntermediateDirectories: true)
        
        // Generate filename with timestamp and platform
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: report.generatedAt)
        let platform = report.platform.isSimulator ? "simulator" : "device"
        let fileName = "debug_report_\(timestamp)_\(platform).json"
        
        let reportURL = reportsDir.appendingPathComponent(fileName)
        
        // Encode and save
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(report)
        try data.write(to: reportURL)
        
        print("📊 [DebugReport] Saved report to: \(reportURL.path)")
        
        // Also print a summary to console
        printReportSummary(report)
        
        // Clear current report
        currentReport = nil
        
        return reportURL
    }
    
    /// Get the current report without finalizing.
    func getCurrentReport() -> DebugReport? {
        return currentReport
    }
    
    // MARK: - Console Summary
    
    private nonisolated func printReportSummary(_ report: DebugReport) {
        print("")
        print("📊 ═══════════════════════════════════════════════════════════════")
        print("📊  DEBUG REPORT SUMMARY")
        print("📊 ═══════════════════════════════════════════════════════════════")
        print("📊  Report ID: \(report.reportId)")
        print("📊  Generated: \(report.generatedAt)")
        print("📊 ───────────────────────────────────────────────────────────────")
        print("📊  PLATFORM:")
        print("📊    • Type: \(report.platform.isSimulator ? "SIMULATOR (x86_64)" : "DEVICE (ARM64)")")
        print("📊    • Model: \(report.platform.deviceModel)")
        print("📊    • OS: iOS \(report.platform.osVersion)")
        print("📊    • CPUs: \(report.platform.processorCount)")
        print("📊    • RAM: \(report.platform.physicalMemory / 1024 / 1024 / 1024) GB")
        print("📊    • Thermal: \(report.platform.thermalState)")
        print("📊    • Low Power: \(report.platform.lowPowerMode)")
        print("📊 ───────────────────────────────────────────────────────────────")
        print("📊  INPUT FILE:")
        print("📊    • Name: \(report.inputFile.fileName)")
        print("📊    • Size: \(String(format: "%.2f", report.inputFile.fileSizeMB)) MB")
        print("📊    • SHA256: \(report.inputFile.sha256Hash.prefix(16))...")
        print("📊 ───────────────────────────────────────────────────────────────")
        
        if let audio = report.audioAnalysis {
            print("📊  AUDIO ANALYSIS:")
            print("📊    • Samples: \(audio.extractedSampleCount)")
            print("📊    • Duration: \(String(format: "%.2f", audio.extractedDuration))s")
            print("📊    • Raw fingerprint sum: \(String(format: "%.4f", audio.rawAudioFingerprint.sum))")
            print("📊    • Filtered fingerprint sum: \(String(format: "%.4f", audio.filteredAudioFingerprint.sum))")
            print("📊    • Onset frames: \(audio.onsetFrameCount)")
            print("📊    • Onset mean: \(String(format: "%.4f", audio.onsetStrengthStats.mean))")
            print("📊    • Onset p95: \(String(format: "%.4f", audio.onsetStrengthStats.p95))")
            print("📊    • Peaks detected: \(audio.detectedPeakCount)")
            print("📊    • Clusters: \(audio.clusterCount)")
            print("📊    • Candidate intervals: \(audio.candidateIntervals.count)")
        }
        
        if let visual = report.visualValidation {
            print("📊 ───────────────────────────────────────────────────────────────")
            print("📊  VISUAL VALIDATION:")
            print("📊    • Validated: \(visual.segmentsValidated)")
            print("📊    • Approved: \(visual.segmentsApproved)")
            print("📊    • Rejected: \(visual.segmentsRejected)")
            
            if let frameInfo = visual.frameProcessingInfo {
                print("📊    • Thumbnail: \(frameInfo.thumbnailWidth)x\(frameInfo.thumbnailHeight) (\(frameInfo.pixelCount) pixels)")
                print("📊    • Frame stride: \(frameInfo.frameStride)")
                print("📊    • Pixel threshold: \(frameInfo.motionPixelThreshold)")
                print("📊    • Area threshold: \(Int(frameInfo.motionAreaThreshold))")
            }
            
            if let stats = visual.aggregateStats {
                print("📊    • Frame extraction rate: \(String(format: "%.1f", stats.frameExtractionSuccessRate * 100))%")
                print("📊    • Motion scores: avg=\(String(format: "%.1f", stats.averageMotionScore)), median=\(String(format: "%.1f", stats.medianMotionScore))")
                print("📊    • Motion range: \(String(format: "%.1f", stats.minMotionScore)) - \(String(format: "%.1f", stats.maxMotionScore))")
                print("📊    • Motion stdDev: \(String(format: "%.1f", stats.stdDevMotionScore))")
                print("📊    • Approval rate: \(String(format: "%.1f", stats.approvalRate * 100))%")
            }
            
            // Print details for rejected segments to help diagnose
            let rejectedSegments = visual.validationResults.filter { !$0.isValid }
            if !rejectedSegments.isEmpty {
                print("📊    • REJECTED SEGMENTS (motion below threshold):")
                for seg in rejectedSegments.prefix(5) {
                    print("📊      - Seg \(seg.segmentIndex): score=\(String(format: "%.1f", seg.motionScore)) (threshold=\(String(format: "%.1f", seg.threshold))), frames=\(seg.framesExtracted)/\(seg.framesRequested)")
                }
                if rejectedSegments.count > 5 {
                    print("📊      ... and \(rejectedSegments.count - 5) more")
                }
            }
        }
        
        if let results = report.results {
            print("📊 ───────────────────────────────────────────────────────────────")
            print("📊  RESULTS:")
            print("📊    • Success: \(results.success)")
            print("📊    • Input duration: \(String(format: "%.2f", results.inputDuration))s")
            print("📊    • Output duration: \(String(format: "%.2f", results.outputDuration))s")
            print("📊    • Reduction: \(String(format: "%.1f", results.reductionPercent))%")
            print("📊    • Segments: \(results.segmentCount)")
        }
        
        // Print export verification details (critical for slow-mo diagnosis)
        if let exportDetails = report.exportDetails {
            if let sourceProps = exportDetails.sourceVideoProperties {
                print("📊 ───────────────────────────────────────────────────────────────")
                print("📊  SOURCE VIDEO (for timing comparison):")
                print("📊    • Duration CMTime: \(sourceProps.durationCMTime)")
                print("📊    • Frame rate: \(sourceProps.nominalFrameRate) fps")
                print("📊    • Time scale: \(sourceProps.naturalTimeScale)")
                print("📊    • Size: \(sourceProps.naturalSize)")
                print("📊    • Codec: \(sourceProps.videoCodecType ?? "unknown")")
                if sourceProps.hasVariableFrameRate == true {
                    print("📊    ⚠️ VARIABLE FRAME RATE detected!")
                }
            }
            
            if let verification = exportDetails.outputVideoVerification {
                print("📊 ───────────────────────────────────────────────────────────────")
                print("📊  OUTPUT VERIFICATION:")
                print("📊    • Actual duration: \(String(format: "%.3f", verification.duration))s")
                print("📊    • Expected: \(String(format: "%.3f", verification.expectedDuration))s")
                print("📊    • Mismatch: \(String(format: "%.3f", verification.durationMismatch))s (\(String(format: "%.1f", verification.durationMismatchPercent))%)")
                if let fps = verification.nominalFrameRate {
                    print("📊    • Output FPS: \(String(format: "%.2f", fps)) (source: \(String(format: "%.2f", verification.sourceFrameRate)))")
                }
                if verification.frameRateMismatch {
                    print("📊    ⚠️ FRAME RATE MISMATCH detected!")
                }
                if !verification.timingAccurate {
                    print("📊    ⚠️ TIMING ISSUE: \(verification.timingIssueDescription ?? "Unknown")")
                }
            }
        }
        
        if let timing = report.timing {
            print("📊 ───────────────────────────────────────────────────────────────")
            print("📊  TIMING:")
            print("📊    • Total: \(String(format: "%.2f", timing.totalProcessingTime))s")
            for (name, time) in timing.breakdown.sorted(by: { $0.value > $1.value }) {
                if time > 0 {
                    print("📊    • \(name): \(String(format: "%.2f", time))s")
                }
            }
        }
        
        print("📊 ═══════════════════════════════════════════════════════════════")
        print("")
    }
}

// MARK: - Debug Report Builder Helpers

extension DebugReportService {
    
    /// Create audio analysis details from processing data.
    nonisolated func createAudioAnalysisDetails(
        rawSamples: [Float],
        filteredSamples: [Float],
        onsetStrength: [Float],
        thresholds: [Float],
        peakIndices: [Int],
        peakTimes: [TimeInterval],
        clusters: [[TimeInterval]],
        candidateIntervals: [(start: TimeInterval, end: TimeInterval)],
        duration: TimeInterval,
        framesPerSecond: Double
    ) -> AudioAnalysisDetails {
        
        // Build peak details
        var peakDetails: [PeakDetail] = []
        for (i, peakIdx) in peakIndices.enumerated() {
            let strength = peakIdx < onsetStrength.count ? onsetStrength[peakIdx] : 0
            let threshold = peakIdx < thresholds.count ? thresholds[peakIdx] : 0
            peakDetails.append(PeakDetail(
                index: i,
                peakIndex: peakIdx,
                timeSeconds: peakTimes[i],
                onsetStrength: strength,
                threshold: threshold,
                margin: strength - threshold
            ))
        }
        
        // Build cluster details
        var clusterDetails: [ClusterDetail] = []
        for (i, cluster) in clusters.enumerated() {
            guard !cluster.isEmpty else { continue }
            clusterDetails.append(ClusterDetail(
                clusterIndex: i,
                hitCount: cluster.count,
                firstHitTime: cluster.first ?? 0,
                lastHitTime: cluster.last ?? 0,
                duration: (cluster.last ?? 0) - (cluster.first ?? 0),
                hitTimes: cluster
            ))
        }
        
        // Build interval details
        var intervalDetails: [IntervalDetail] = []
        for (i, interval) in candidateIntervals.enumerated() {
            // Count hits in this interval
            let hitsInInterval = peakTimes.filter { $0 >= interval.start && $0 <= interval.end }.count
            intervalDetails.append(IntervalDetail(
                index: i,
                startTime: interval.start,
                endTime: interval.end,
                duration: interval.end - interval.start,
                hitCount: hitsInInterval
            ))
        }
        
        // Build top 20 onset strengths
        let indexedOnsets = onsetStrength.enumerated().map { (index, value) in
            IndexedValue(index: index, value: value, timeSeconds: Double(index) / framesPerSecond)
        }
        let top20 = indexedOnsets.sorted { $0.value > $1.value }.prefix(20)
        
        return AudioAnalysisDetails(
            extractedSampleCount: rawSamples.count,
            extractedDuration: duration,
            rawAudioFingerprint: AudioFingerprint(samples: rawSamples),
            filteredAudioFingerprint: AudioFingerprint(samples: filteredSamples),
            first100RawSamples: Array(rawSamples.prefix(100)),
            first100FilteredSamples: Array(filteredSamples.prefix(100)),
            onsetFrameCount: onsetStrength.count,
            onsetStrengthFingerprint: AudioFingerprint(samples: onsetStrength),
            onsetStrengthStats: StatisticalSummary(values: onsetStrength),
            top20OnsetStrengths: Array(top20),
            first50OnsetStrengths: Array(onsetStrength.prefix(50)),
            thresholdStats: StatisticalSummary(values: thresholds),
            first50Thresholds: Array(thresholds.prefix(50)),
            detectedPeakCount: peakIndices.count,
            peakDetails: peakDetails,
            clusterCount: clusters.count,
            clusters: clusterDetails,
            candidateIntervals: intervalDetails
        )
    }
    
    // MARK: - Visual Validation Helpers
    
    /// Create comprehensive visual validation details.
    nonisolated func createVisualValidationDetails(
        segmentResults: [SegmentValidationDetail],
        frameProcessingInfo: FrameProcessingInfo?,
        allMotionScores: [Double]
    ) -> VisualValidationDetails {
        let approved = segmentResults.filter { $0.isValid }.count
        let rejected = segmentResults.count - approved
        
        // Calculate aggregate stats
        var aggregateStats: VisualValidationStats? = nil
        if !allMotionScores.isEmpty {
            let sorted = allMotionScores.sorted()
            let sum = allMotionScores.reduce(0, +)
            let mean = sum / Double(allMotionScores.count)
            let variance = allMotionScores.reduce(0) { $0 + pow($1 - mean, 2) } / Double(allMotionScores.count)
            let stdDev = sqrt(variance)
            
            let totalRequested = segmentResults.reduce(0) { $0 + $1.framesRequested }
            let totalExtracted = segmentResults.reduce(0) { $0 + $1.framesExtracted }
            
            aggregateStats = VisualValidationStats(
                totalFramesRequested: totalRequested,
                totalFramesExtracted: totalExtracted,
                frameExtractionSuccessRate: totalRequested > 0 ? Double(totalExtracted) / Double(totalRequested) : 0,
                averageMotionScore: mean,
                medianMotionScore: sorted[sorted.count / 2],
                minMotionScore: sorted.first ?? 0,
                maxMotionScore: sorted.last ?? 0,
                stdDevMotionScore: stdDev,
                approvalRate: segmentResults.isEmpty ? 0 : Double(approved) / Double(segmentResults.count)
            )
        }
        
        return VisualValidationDetails(
            segmentsValidated: segmentResults.count,
            segmentsApproved: approved,
            segmentsRejected: rejected,
            validationResults: segmentResults,
            frameProcessingInfo: frameProcessingInfo,
            aggregateStats: aggregateStats
        )
    }
    
    /// Create a segment validation detail with frame pair analysis.
    nonisolated func createSegmentValidationDetail(
        segmentIndex: Int,
        startTime: Double,
        endTime: Double,
        framesRequested: Int,
        framesExtracted: Int,
        motionScore: Double,
        threshold: Double,
        isValid: Bool,
        usedEarlyExit: Bool,
        framesProcessedBeforeDecision: Int,
        allFrameScores: [Double],
        framePairDetails: [FramePairDetail]?,
        extractionErrors: [String]? = nil
    ) -> SegmentValidationDetail {
        return SegmentValidationDetail(
            segmentIndex: segmentIndex,
            startTime: startTime,
            endTime: endTime,
            duration: endTime - startTime,
            framesRequested: framesRequested,
            framesExtracted: framesExtracted,
            frameExtractionRate: framesRequested > 0 ? Double(framesExtracted) / Double(framesRequested) : 0,
            motionScore: motionScore,
            threshold: threshold,
            isValid: isValid,
            usedEarlyExit: usedEarlyExit,
            framesProcessedBeforeDecision: framesProcessedBeforeDecision,
            allFrameScores: allFrameScores,
            framePairDetails: framePairDetails,
            extractionErrors: extractionErrors
        )
    }
    
    // MARK: - Export Helpers
    
    /// Create comprehensive export details with timing verification.
    nonisolated func createExportDetails(
        outputFileName: String,
        outputFilePath: String,
        outputFileSizeBytes: Int64,
        outputDuration: Double,
        segmentsExported: Int,
        inputDuration: Double,
        sourceVideoProperties: SourceVideoProperties?,
        compositionConfig: CompositionConfig?,
        segmentTimingDetails: [SegmentTimingDetail]?,
        outputVideoVerification: OutputVideoVerification?
    ) -> ExportDetails {
        let compressionRatio = inputDuration > 0 ? (1 - outputDuration / inputDuration) * 100 : 0
        
        return ExportDetails(
            outputFileName: outputFileName,
            outputFilePath: outputFilePath,
            outputFileSizeBytes: outputFileSizeBytes,
            outputFileSizeMB: Double(outputFileSizeBytes) / 1024 / 1024,
            outputDuration: outputDuration,
            segmentsExported: segmentsExported,
            compressionRatio: compressionRatio,
            sourceVideoProperties: sourceVideoProperties,
            compositionConfig: compositionConfig,
            segmentTimingDetails: segmentTimingDetails,
            outputVideoVerification: outputVideoVerification
        )
    }
}

// MARK: - CMTime String Helpers

extension CMTime {
    /// Format CMTime as a debug string showing exact representation.
    var debugString: String {
        if isIndefinite { return "indefinite" }
        if isNegativeInfinity { return "-infinity" }
        if isPositiveInfinity { return "+infinity" }
        if !flags.contains(.valid) { return "invalid" }
        return "\(value)/\(timescale) (\(String(format: "%.4f", seconds))s)"
    }
}

