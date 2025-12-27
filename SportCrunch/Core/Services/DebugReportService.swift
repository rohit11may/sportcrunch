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

// MARK: - Visual Validation Details

struct VisualValidationDetails: Codable {
    let segmentsValidated: Int
    let segmentsApproved: Int
    let segmentsRejected: Int
    let validationResults: [SegmentValidationDetail]
}

struct SegmentValidationDetail: Codable {
    let segmentIndex: Int
    let startTime: Double
    let endTime: Double
    let framesExtracted: Int
    let motionScore: Double
    let threshold: Double
    let isValid: Bool
    let frameScores: [Double]?  // First N frame scores for comparison
}

// MARK: - Export Details

struct ExportDetails: Codable {
    let outputFileName: String
    let outputFilePath: String
    let outputFileSizeBytes: Int64
    let outputFileSizeMB: Double
    let outputDuration: Double
    let segmentsExported: Int
    let compressionRatio: Double
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
}

