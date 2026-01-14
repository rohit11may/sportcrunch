//
//  ProcessingReportManager.swift
//  SportCrunch
//
//  Manages debug report orchestration during video processing.
//  Separates debug reporting concerns from core processing logic.
//

import Foundation

// MARK: - Debug Report Builder

/// Builder for constructing a debug report during processing.
struct DebugReportBuilder {
    let reportId: String
    var audioAnalysisRecorded: Bool = false
    var visualValidationRecorded: Bool = false
    var exportRecorded: Bool = false
}

// MARK: - Processing Report Manager Protocol

/// Protocol defining the interface for managing debug reports during video processing.
protocol ProcessingReportManagerProtocol {
    /// Start a new debug report for a processing run.
    /// Returns a builder that tracks what has been recorded.
    func startReport(for project: Project?, sourceURL: URL, sport: Sport, sportMode: SportMode?) async -> DebugReportBuilder

    /// Record audio analysis results to the debug report.
    func recordAudioAnalysis(_ result: AudioAnalysisResult, to builder: inout DebugReportBuilder) async

    /// Record visual validation results to the debug report.
    func recordVisualValidation(_ result: VisualValidationResult, to builder: inout DebugReportBuilder) async

    /// Record export results to the debug report.
    func recordExport(_ result: ExportResult, originalFileSize: Int64, to builder: inout DebugReportBuilder) async

    /// Record timing information for the processing run.
    func recordTiming(
        totalTime: Double,
        audioTime: Double,
        visualTime: Double,
        exportTime: Double,
        to builder: inout DebugReportBuilder
    ) async

    /// Record final processing results and finalize the report.
    func finalizeReport(
        _ builder: DebugReportBuilder,
        segments: [ActionSegment],
        inputDuration: Double,
        outputDuration: Double
    ) async throws

    /// Log a message to the debug report.
    func log(level: String, component: String, message: String, data: [String: String]?) async
}

// MARK: - Visual Validation Result

/// Result of visual validation for reporting purposes.
struct VisualValidationResult {
    let validations: [SegmentValidation]
    let preset: AnalysisPreset
}

// MARK: - Real Implementation

/// Real implementation that delegates to DebugReportService.
actor RealProcessingReportManager: ProcessingReportManagerProtocol {

    // MARK: - Dependencies

    private let debugReportService: DebugReportService

    // MARK: - Initialization

    init(debugReportService: DebugReportService = .shared) {
        self.debugReportService = debugReportService
    }

    // MARK: - Report Lifecycle

    func startReport(for project: Project?, sourceURL: URL, sport: Sport, sportMode: SportMode?) async -> DebugReportBuilder {
        await debugReportService.startReport(inputFileURL: sourceURL, sport: sport, sportMode: sportMode)

        let report = await debugReportService.getCurrentReport()
        let reportId = report?.reportId ?? "unknown"

        return DebugReportBuilder(reportId: reportId)
    }

    // MARK: - Audio Analysis Recording

    func recordAudioAnalysis(_ result: AudioAnalysisResult, to builder: inout DebugReportBuilder) async {
        guard let debugData = result.debugData else {
            await debugReportService.log(
                level: "warning",
                component: "ProcessingReportManager",
                message: "No audio debug data available",
                data: nil
            )
            return
        }

        let audioDetails = debugReportService.createAudioAnalysisDetails(
            rawSamples: debugData.rawSamples,
            filteredSamples: debugData.filteredSamples,
            onsetStrength: debugData.onsetStrength,
            thresholds: debugData.thresholds,
            peakIndices: debugData.peakIndices,
            peakTimes: result.peakTimes,
            clusters: debugData.clusters,
            candidateIntervals: result.candidateIntervals,
            duration: result.duration,
            framesPerSecond: debugData.framesPerSecond
        )

        await debugReportService.recordAudioAnalysis(audioDetails)
        builder.audioAnalysisRecorded = true
    }

    // MARK: - Visual Validation Recording

    func recordVisualValidation(_ result: VisualValidationResult, to builder: inout DebugReportBuilder) async {
        // Build frame processing info
        let frameProcessingInfo = FrameProcessingInfo(
            thumbnailWidth: result.preset.videoThumbSize.width,
            thumbnailHeight: result.preset.videoThumbSize.height,
            pixelCount: result.preset.videoThumbSize.width * result.preset.videoThumbSize.height,
            frameStride: result.preset.videoSampleStride,
            motionPixelThreshold: result.preset.motionPixelThreshold,
            motionAreaThreshold: result.preset.motionAreaThreshold,
            sourceVideoFPS: 0, // Will be updated from actual video if available
            sourceVideoResolution: "unknown"
        )

        // Build segment validation details from the debug data
        var segmentDetails: [SegmentValidationDetail] = []
        var allMotionScores: [Double] = []

        for (index, validation) in result.validations.enumerated() {
            // Collect all motion scores for aggregate stats
            if let debugData = validation.debugData {
                allMotionScores.append(contentsOf: debugData.allFrameScores)

                // Convert frame pair debug data to the report format
                var framePairDetails: [FramePairDetail]? = nil
                if !debugData.framePairDetails.isEmpty {
                    framePairDetails = debugData.framePairDetails.map { pair in
                        FramePairDetail(
                            pairIndex: pair.pairIndex,
                            frameATime: pair.frameATime,
                            frameBTime: pair.frameBTime,
                            frameAWidth: pair.frameAWidth,
                            frameAHeight: pair.frameAHeight,
                            frameBWidth: pair.frameBWidth,
                            frameBHeight: pair.frameBHeight,
                            frameAGrayscaleMean: pair.frameAGrayscaleMean,
                            frameAGrayscaleStdDev: pair.frameAGrayscaleStdDev,
                            frameBGrayscaleMean: pair.frameBGrayscaleMean,
                            frameBGrayscaleStdDev: pair.frameBGrayscaleStdDev,
                            rawDiffSum: pair.rawDiffSum,
                            rawDiffMean: pair.rawDiffMean,
                            rawDiffMax: pair.rawDiffMax,
                            pixelsAboveThreshold: pair.pixelsAboveThreshold,
                            motionScore: pair.motionScore
                        )
                    }
                }

                let detail = debugReportService.createSegmentValidationDetail(
                    segmentIndex: index,
                    startTime: validation.start,
                    endTime: validation.end,
                    framesRequested: debugData.framesRequested,
                    framesExtracted: debugData.framesExtracted,
                    motionScore: validation.motionScore,
                    threshold: result.preset.motionAreaThreshold,
                    isValid: validation.isValid,
                    usedEarlyExit: debugData.usedEarlyExit,
                    framesProcessedBeforeDecision: debugData.framesProcessedBeforeDecision,
                    allFrameScores: debugData.allFrameScores,
                    framePairDetails: framePairDetails,
                    extractionErrors: debugData.extractionErrors.isEmpty ? nil : debugData.extractionErrors
                )
                segmentDetails.append(detail)
            } else {
                // No debug data available - create minimal entry
                let detail = debugReportService.createSegmentValidationDetail(
                    segmentIndex: index,
                    startTime: validation.start,
                    endTime: validation.end,
                    framesRequested: 0,
                    framesExtracted: 0,
                    motionScore: validation.motionScore,
                    threshold: result.preset.motionAreaThreshold,
                    isValid: validation.isValid,
                    usedEarlyExit: false,
                    framesProcessedBeforeDecision: 0,
                    allFrameScores: [],
                    framePairDetails: nil,
                    extractionErrors: nil
                )
                segmentDetails.append(detail)
            }
        }

        // Create and record the visual validation details
        let visualDetails = debugReportService.createVisualValidationDetails(
            segmentResults: segmentDetails,
            frameProcessingInfo: frameProcessingInfo,
            allMotionScores: allMotionScores
        )

        await debugReportService.recordVisualValidation(visualDetails)
        builder.visualValidationRecorded = true
    }

    // MARK: - Export Recording

    func recordExport(_ result: ExportResult, originalFileSize: Int64, to builder: inout DebugReportBuilder) async {
        // Get highlight file size
        var highlightFileSize: Int64 = 0
        if let attrs = try? FileManager.default.attributesOfItem(atPath: result.outputURL.path),
           let size = attrs[.size] as? Int64 {
            highlightFileSize = size
        }

        // Convert export debug data to report format
        let exportDetails: ExportDetails
        if let debugData = result.debugData {
            // Convert debug data to the report format
            let sourceProps: SourceVideoProperties? = {
                let src = debugData.sourceVideoProperties
                return SourceVideoProperties(
                    duration: src.duration,
                    durationCMTime: src.durationCMTime.debugString,
                    nominalFrameRate: src.nominalFrameRate,
                    minFrameDuration: src.minFrameDuration.debugString,
                    naturalTimeScale: src.naturalTimeScale,
                    videoTrackCount: src.videoTrackCount,
                    audioTrackCount: src.audioTrackCount,
                    naturalSize: "\(Int(src.naturalSize.width))x\(Int(src.naturalSize.height))",
                    preferredTransform: "a=\(src.preferredTransform.a),b=\(src.preferredTransform.b),c=\(src.preferredTransform.c),d=\(src.preferredTransform.d)",
                    isVideoPortrait: src.isVideoPortrait,
                    colorPrimaries: src.colorPrimaries,
                    transferFunction: src.transferFunction,
                    ycbcrMatrix: src.ycbcrMatrix,
                    videoCodecType: src.videoCodecType,
                    videoCodecName: src.videoCodecType,
                    hasVariableFrameRate: src.hasVariableFrameRate
                )
            }()

            let compConfig: CompositionConfig? = {
                let cfg = debugData.compositionConfig
                return CompositionConfig(
                    exportPreset: cfg.exportPreset,
                    outputFileType: cfg.outputFileType,
                    shouldOptimizeForNetworkUse: cfg.shouldOptimizeForNetworkUse,
                    usedVideoComposition: cfg.usedVideoComposition,
                    renderSize: cfg.renderSize != nil ? "\(Int(cfg.renderSize!.width))x\(Int(cfg.renderSize!.height))" : nil,
                    frameDuration: cfg.frameDuration?.debugString,
                    frameRate: cfg.frameRate,
                    colorPrimariesApplied: cfg.colorPrimariesApplied,
                    transferFunctionApplied: cfg.transferFunctionApplied,
                    ycbcrMatrixApplied: cfg.ycbcrMatrixApplied,
                    appliedTransform: cfg.appliedTransform != nil ? "a=\(cfg.appliedTransform!.a),b=\(cfg.appliedTransform!.b),c=\(cfg.appliedTransform!.c),d=\(cfg.appliedTransform!.d)" : nil
                )
            }()

            let segmentTimings: [SegmentTimingDetail]? = debugData.segmentTimingDetails.map { detail in
                SegmentTimingDetail(
                    segmentIndex: detail.segmentIndex,
                    requestedStartTime: detail.requestedStartTime,
                    requestedEndTime: detail.requestedEndTime,
                    requestedDuration: detail.requestedDuration,
                    startCMTime: detail.startCMTime.debugString,
                    endCMTime: detail.endCMTime.debugString,
                    durationCMTime: detail.durationCMTime.debugString,
                    insertionPosition: detail.insertionPosition.debugString,
                    insertedSuccessfully: detail.insertedSuccessfully,
                    errorMessage: detail.errorMessage,
                    timeRangeValid: detail.timeRangeValid,
                    clampedToVideoBounds: detail.clampedToVideoBounds
                )
            }

            let outputVerification: OutputVideoVerification? = {
                guard let ver = debugData.outputVerification else { return nil }
                return OutputVideoVerification(
                    duration: ver.duration,
                    durationCMTime: ver.durationCMTime.debugString,
                    expectedDuration: ver.expectedDuration,
                    durationMismatch: ver.durationMismatch,
                    durationMismatchPercent: ver.durationMismatchPercent,
                    nominalFrameRate: ver.nominalFrameRate,
                    frameRateMismatch: ver.frameRateMismatch,
                    sourceFrameRate: ver.sourceFrameRate,
                    naturalSize: ver.naturalSize != nil ? "\(Int(ver.naturalSize!.width))x\(Int(ver.naturalSize!.height))" : nil,
                    videoCodecType: ver.videoCodecType,
                    timingAccurate: ver.timingAccurate,
                    timingIssueDescription: ver.timingIssueDescription
                )
            }()

            exportDetails = debugReportService.createExportDetails(
                outputFileName: result.outputURL.lastPathComponent,
                outputFilePath: result.outputURL.path,
                outputFileSizeBytes: highlightFileSize,
                outputDuration: result.outputDuration,
                segmentsExported: debugData.segmentTimingDetails.count,
                inputDuration: result.inputDuration,
                sourceVideoProperties: sourceProps,
                compositionConfig: compConfig,
                segmentTimingDetails: segmentTimings,
                outputVideoVerification: outputVerification
            )
        } else {
            // No debug data - use basic export details
            exportDetails = ExportDetails(
                outputFileName: result.outputURL.lastPathComponent,
                outputFilePath: result.outputURL.path,
                outputFileSizeBytes: highlightFileSize,
                outputFileSizeMB: Double(highlightFileSize) / 1024 / 1024,
                outputDuration: result.outputDuration,
                segmentsExported: 0,
                compressionRatio: result.compressionRatio,
                sourceVideoProperties: nil,
                compositionConfig: nil,
                segmentTimingDetails: nil,
                outputVideoVerification: nil
            )
        }

        await debugReportService.recordExport(exportDetails)
        builder.exportRecorded = true
    }

    // MARK: - Timing Recording

    func recordTiming(
        totalTime: Double,
        audioTime: Double,
        visualTime: Double,
        exportTime: Double,
        to builder: inout DebugReportBuilder
    ) async {
        let timing = TimingInfo(
            totalProcessingTime: totalTime,
            audioExtractionTime: audioTime,
            audioFilteringTime: 0,  // Included in audioExtractionTime
            onsetDetectionTime: 0,  // Included in audioExtractionTime
            peakDetectionTime: 0,   // Included in audioExtractionTime
            clusteringTime: 0,      // Included in audioExtractionTime
            visualValidationTime: visualTime,
            exportTime: exportTime
        )
        await debugReportService.recordTiming(timing)
    }

    // MARK: - Finalization

    func finalizeReport(
        _ builder: DebugReportBuilder,
        segments: [ActionSegment],
        inputDuration: Double,
        outputDuration: Double
    ) async throws {
        // Calculate compression ratio
        let compressionRatio = inputDuration > 0 ? (1 - outputDuration / inputDuration) * 100 : 0

        // Record final results
        let processingResults = ProcessingResults(
            success: true,
            errorMessage: nil,
            inputDuration: inputDuration,
            outputDuration: outputDuration,
            reductionPercent: compressionRatio,
            segmentCount: segments.count,
            segments: segments.enumerated().map { index, segment in
                SegmentResult(
                    index: index,
                    startTime: segment.startTime,
                    endTime: segment.endTime,
                    duration: segment.duration,
                    confidence: segment.confidence
                )
            }
        )
        await debugReportService.recordResults(processingResults)

        // Finalize and save the report
        if let reportURL = try? await debugReportService.finalizeReport() {
            print("📊 [ProcessingReportManager] Debug report saved: \(reportURL.lastPathComponent)")
        }
    }

    // MARK: - Logging

    func log(level: String, component: String, message: String, data: [String: String]?) async {
        await debugReportService.log(level: level, component: component, message: message, data: data)
    }
}
