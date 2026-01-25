//
//  SpectralFluxAudioAnalyzer.swift
//  SportCrunch
//
//  Detects racket-ball impacts using audio signal processing.
//  Port of Python prototype's audio_analyzer.py using Accelerate framework.
//  Spectral flux method-specific implementation.
//

import Foundation
import AVFoundation
import Accelerate

// MARK: - Audio Analysis Result

struct AudioAnalysisResult {
    let candidateIntervals: [(start: TimeInterval, end: TimeInterval)]
}

// MARK: - Audio Analysis Debug Data

/// All intermediate values captured during audio analysis for debug comparison.

// MARK: - Audio Analyzer Errors

enum AudioAnalyzerError: Error, LocalizedError {
    case cannotAccessFile
    case noAudioTrack
    case audioExtractionFailed
    case processingFailed(String)

    var errorDescription: String? {
        switch self {
        case .cannotAccessFile:
            return "Cannot access the video file."
        case .noAudioTrack:
            return "No audio track found in video."
        case .audioExtractionFailed:
            return "Failed to extract audio from video."
        case .processingFailed(let reason):
            return "Audio processing failed: \(reason)"
        }
    }
}

// MARK: - Audio Analyzer

/// Analyzes audio to detect sports action sounds (racket hits, bat contacts).
///
/// Pipeline:
/// 1. Extract audio at target sample rate (mono)
/// 2. Apply bandpass filter to isolate hit frequencies
/// 3. Compute onset strength (spectral flux)
/// 4. Apply adaptive threshold to find peaks
/// 5. Cluster peaks into action intervals
///
/// This analyzer is specific to the spectral flux method family.
actor SpectralFluxAudioAnalyzer {

    // MARK: - Fixed Constants (not sport-specific)

    private let hopLength: Int = 512
    private let fftSize: Int = 1024

    // MARK: - Public API

    /// Analyze audio from a video file to detect action segments.
    /// - Parameters:
    ///   - videoURL: URL to the video file
    ///   - config: Spectral flux method configuration parameters
    ///   - observation: Optional observation recorder for telemetry
    /// - Returns: Analysis result with detected peaks and candidate intervals
    func analyze(videoURL: URL, config: SpectralFluxMethodConfig, observation: RunObservation?) async throws -> AudioAnalysisResult {
        // Audio processing constants (not tunable parameters)
        let sampleRate: Double = 16000
        let bandpassLow: Double = 200
        let bandpassHigh: Double = 3000

        let startTime = Date()

        print("🎵 [SpectralFluxAudioAnalyzer] ═══════════════════════════════════════════")
        print("🎵 [SpectralFluxAudioAnalyzer] Starting audio analysis")
        print("🎵 [SpectralFluxAudioAnalyzer] Source: \(videoURL.lastPathComponent)")
        print("🎵 [SpectralFluxAudioAnalyzer] ───────────────────────────────────────────")
        print("🎵 [SpectralFluxAudioAnalyzer] Configuration:")
        print("🎵 [SpectralFluxAudioAnalyzer]   • Sample rate: \(Int(sampleRate)) Hz")
        print("🎵 [SpectralFluxAudioAnalyzer]   • Bandpass: \(Int(bandpassLow))-\(Int(bandpassHigh)) Hz")
        print("🎵 [SpectralFluxAudioAnalyzer]   • Threshold λ: \(config.audioThresholdMultiplier) (lower = more sensitive)")
        print("🎵 [SpectralFluxAudioAnalyzer]   • Min peak distance: \(config.peakMinDistance)s")
        print("🎵 [SpectralFluxAudioAnalyzer]   • Cluster max gap: \(config.clusterMaxGapSec)s")
        print("🎵 [SpectralFluxAudioAnalyzer]   • Cluster min hits: \(config.clusterMinHits)")
        print("🎵 [SpectralFluxAudioAnalyzer]   • Padding: \(config.paddingPreSec)s before, \(config.paddingPostSec)s after")
        print("🎵 [SpectralFluxAudioAnalyzer] ───────────────────────────────────────────")

        // Step 1: Extract audio samples
        print("🎵 [SpectralFluxAudioAnalyzer] Step 1/5: Extracting audio at \(Int(sampleRate)) Hz...")
        let (samples, duration) = try await extractAudio(from: videoURL, sampleRate: sampleRate)

        guard !samples.isEmpty else {
            print("🎵 [SpectralFluxAudioAnalyzer] ❌ ERROR: No audio samples extracted")
                throw AudioAnalyzerError.audioExtractionFailed
        }

        let sampleCount = samples.count
        print("🎵 [SpectralFluxAudioAnalyzer] ✓ Extracted \(sampleCount) samples")
        print("🎵 [SpectralFluxAudioAnalyzer] ✓ Duration: \(String(format: "%d:%02d", Int(duration) / 60, Int(duration) % 60))")

        // Step 2: Apply bandpass filter
        print("🎵 [SpectralFluxAudioAnalyzer] Step 2/5: Applying bandpass filter (\(Int(bandpassLow))-\(Int(bandpassHigh)) Hz)...")
        let filteredSamples = applyBandpassFilter(
            samples,
            lowCutoff: Float(bandpassLow),
            highCutoff: Float(bandpassHigh),
            sampleRate: Float(sampleRate)
        )
        print("🎵 [SpectralFluxAudioAnalyzer] ✓ Bandpass filter applied")

        // Step 3: Compute onset strength (spectral flux)
        print("🎵 [SpectralFluxAudioAnalyzer] Step 3/5: Computing spectral flux (FFT)...")
        let onsetStrength = computeOnsetStrength(filteredSamples)
        print("🎵 [SpectralFluxAudioAnalyzer] ✓ Computed \(onsetStrength.count) onset frames")

        // Log detailed stats about onset strength for debugging simulator vs device differences
        if !onsetStrength.isEmpty {
            let maxOnset = onsetStrength.max() ?? 0
            let avgOnset = onsetStrength.reduce(0, +) / Float(onsetStrength.count)
            let sortedOnsets = onsetStrength.sorted(by: >)
            let top10 = sortedOnsets.prefix(10)
            let median = onsetStrength.count > 0 ? sortedOnsets[onsetStrength.count / 2] : 0

            print("🎵 [SpectralFluxAudioAnalyzer]   Onset stats - Max: \(String(format: "%.1f", maxOnset)), Avg: \(String(format: "%.3f", avgOnset)), Median: \(String(format: "%.3f", median))")
            print("🎵 [SpectralFluxAudioAnalyzer]   Top 10 onset values: \(top10.map { String(format: "%.1f", $0) }.joined(separator: ", "))")

            #if targetEnvironment(simulator)
            print("🎵 [SpectralFluxAudioAnalyzer]   ⚡ RUNNING ON SIMULATOR (x86_64)")
            #else
            print("🎵 [SpectralFluxAudioAnalyzer]   📱 RUNNING ON DEVICE (ARM)")
            #endif
        }

        // Step 4: Compute adaptive threshold and find peaks
        print("🎵 [SpectralFluxAudioAnalyzer] Step 4/5: Finding peaks with adaptive threshold (λ=\(config.audioThresholdMultiplier))...")
        let (peakIndices, thresholds) = findPeaksWithThresholds(
            onsetStrength: onsetStrength,
            sampleRate: sampleRate,
            thresholdLambda: Float(config.audioThresholdMultiplier),
            minDistanceSec: config.peakMinDistance
        )

        // Convert peak indices to timestamps
        let framesPerSecond = sampleRate / Double(hopLength)
        let peakTimes = peakIndices.map { Double($0) / framesPerSecond }
        print("🎵 [SpectralFluxAudioAnalyzer] ✓ Detected \(peakTimes.count) potential hits")

        // Record observation data if provided
        if let obs = observation {
            // Record onset strength signal (downsampled automatically by Observation to 2 points/sec)
            let frameDuration = Double(hopLength) / sampleRate
            for (i, val) in onsetStrength.enumerated() {
                await obs.addSignalPoint(name: "audio_flux", time: Double(i) * frameDuration, value: Double(val))
            }

            // Record peak events
            for (i, peakIdx) in peakIndices.enumerated() {
                let peakTime = Double(peakIdx) / framesPerSecond
                let peakStrength = onsetStrength[peakIdx]
                await obs.addEvent(
                    name: "audio_peak",
                    time: peakTime,
                    metadata: ["strength": String(format: "%.2f", peakStrength)]
                )
            }
        }

        // DEBUG: Log peak onset strengths for comparison between simulator and device
        print("🎵 [SpectralFluxAudioAnalyzer] 🔍 DEBUG: Peak indices and their onset strengths:")
        for (i, peakIdx) in peakIndices.prefix(20).enumerated() {
            let peakStrength = onsetStrength[peakIdx]
            let threshold = peakIdx < thresholds.count ? thresholds[peakIdx] : 0
            let peakTime = Double(peakIdx) / framesPerSecond
            print("🎵 [SpectralFluxAudioAnalyzer]   Peak \(i+1): t=\(String(format: "%.3f", peakTime))s, idx=\(peakIdx), strength=\(String(format: "%.2f", peakStrength)), threshold=\(String(format: "%.2f", threshold))")
        }
        if peakIndices.count > 20 {
            print("🎵 [SpectralFluxAudioAnalyzer]   ... and \(peakIndices.count - 20) more peaks")
        }

        if !peakTimes.isEmpty {
            let firstFew = peakTimes.prefix(5).map { String(format: "%.3f", $0) }.joined(separator: ", ")
            print("🎵 [SpectralFluxAudioAnalyzer]   First hits at: \(firstFew)\(peakTimes.count > 5 ? "..." : "")")
        }

        // Step 5: Cluster peaks into intervals
        print("🎵 [SpectralFluxAudioAnalyzer] Step 5/5: Clustering peaks (max gap: \(config.clusterMaxGapSec)s, min hits: \(config.clusterMinHits))...")
        let candidateIntervals = clusterPeaks(
            peakTimes: peakTimes,
            maxGapSeconds: config.clusterMaxGapSec,
            minHitsPerSegment: config.clusterMinHits,
            paddingPre: config.paddingPreSec,
            paddingPost: config.paddingPostSec,
            videoDuration: duration
        )

        let elapsed = Date().timeIntervalSince(startTime)
        let durationStr = String(format: "%d:%02d", Int(duration) / 60, Int(duration) % 60)
        print("🎵 [SpectralFluxAudioAnalyzer] ═══════════════════════════════════════════")
        print("🎵 [SpectralFluxAudioAnalyzer] ✅ ANALYSIS COMPLETE in \(String(format: "%.2f", elapsed))s")
        print("🎵 [SpectralFluxAudioAnalyzer] 📊 Results:")
        print("🎵 [SpectralFluxAudioAnalyzer]    • Video duration: \(durationStr)")
        print("🎵 [SpectralFluxAudioAnalyzer]    • Hits detected: \(peakTimes.count)")
        print("🎵 [SpectralFluxAudioAnalyzer]    • Candidate segments: \(candidateIntervals.count)")

        for (i, interval) in candidateIntervals.enumerated() {
            let segDuration = interval.end - interval.start
            let startStr = String(format: "%d:%02d", Int(interval.start) / 60, Int(interval.start) % 60)
            let endStr = String(format: "%d:%02d", Int(interval.end) / 60, Int(interval.end) % 60)
            print("🎵 [SpectralFluxAudioAnalyzer]    Segment \(i+1): \(startStr) → \(endStr) (\(String(format: "%.1f", segDuration))s)")
        }
        print("🎵 [SpectralFluxAudioAnalyzer] ═══════════════════════════════════════════")

        return AudioAnalysisResult(
            candidateIntervals: candidateIntervals
        )
    }

    // MARK: - Audio Extraction

    private func extractAudio(from videoURL: URL, sampleRate: Double) async throws -> (samples: [Float], duration: TimeInterval) {
        let asset = AVURLAsset(url: videoURL)

        // Get audio track
        guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw AudioAnalyzerError.noAudioTrack
        }

        let duration = try await asset.load(.duration).seconds

        // Configure reader output for target sample rate mono float
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        let reader: AVAssetReader
        do {
            reader = try AVAssetReader(asset: asset)
        } catch {
            throw AudioAnalyzerError.cannotAccessFile
        }

        let output = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
        output.alwaysCopiesSampleData = false

        guard reader.canAdd(output) else {
            throw AudioAnalyzerError.audioExtractionFailed
        }
        reader.add(output)

        guard reader.startReading() else {
            throw AudioAnalyzerError.audioExtractionFailed
        }

        // Read all samples
        var allSamples: [Float] = []
        allSamples.reserveCapacity(Int(duration * sampleRate))

        while let sampleBuffer = output.copyNextSampleBuffer() {
            guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
                continue
            }

            var lengthAtOffset: Int = 0
            var totalLength: Int = 0
            var dataPointer: UnsafeMutablePointer<Int8>?

            let status = CMBlockBufferGetDataPointer(
                blockBuffer,
                atOffset: 0,
                lengthAtOffsetOut: &lengthAtOffset,
                totalLengthOut: &totalLength,
                dataPointerOut: &dataPointer
            )

            guard status == kCMBlockBufferNoErr, let data = dataPointer else {
                continue
            }

            let floatCount = totalLength / MemoryLayout<Float>.size
            let floatPointer = UnsafeRawPointer(data).bindMemory(to: Float.self, capacity: floatCount)
            let buffer = UnsafeBufferPointer(start: floatPointer, count: floatCount)
            allSamples.append(contentsOf: buffer)
        }

        return (allSamples, duration)
    }

    // MARK: - Bandpass Filter

    /// Apply a 4th-order Butterworth bandpass filter using cascaded biquads.
    private func applyBandpassFilter(
        _ samples: [Float],
        lowCutoff: Float,
        highCutoff: Float,
        sampleRate: Float
    ) -> [Float] {
        guard samples.count > 0 else { return [] }

        // Compute normalized frequencies
        let nyquist = sampleRate / 2.0
        let lowNorm = lowCutoff / nyquist
        let highNorm = highCutoff / nyquist

        // Compute biquad coefficients for bandpass
        // Using 2 cascaded 2nd-order sections for 4th-order filter
        let coefficients = computeBandpassCoefficients(
            lowNorm: lowNorm,
            highNorm: highNorm
        )

        var output = samples

        // Apply each biquad section
        for section in coefficients {
            output = applyBiquad(output, coefficients: section)
        }

        return output
    }

    /// Compute biquad coefficients for bandpass filter.
    /// Returns array of coefficient arrays for cascaded sections.
    private func computeBandpassCoefficients(
        lowNorm: Float,
        highNorm: Float
    ) -> [[Float]] {
        // Simplified bandpass using cascaded high-pass and low-pass
        // Each is a 2nd-order Butterworth

        let highPassCoeffs = computeHighPassCoefficients(cutoff: lowNorm)
        let lowPassCoeffs = computeLowPassCoefficients(cutoff: highNorm)

        return [highPassCoeffs, lowPassCoeffs]
    }

    /// 2nd-order Butterworth high-pass filter coefficients
    private func computeHighPassCoefficients(cutoff: Float) -> [Float] {
        let omega = tan(Float.pi * cutoff)
        let omega2 = omega * omega
        let sqrt2 = Float(sqrt(2.0))

        let n = 1.0 + sqrt2 * omega + omega2

        let b0 = 1.0 / n
        let b1 = -2.0 / n
        let b2 = 1.0 / n
        let a1 = 2.0 * (omega2 - 1.0) / n
        let a2 = (1.0 - sqrt2 * omega + omega2) / n

        return [b0, b1, b2, a1, a2]
    }

    /// 2nd-order Butterworth low-pass filter coefficients
    private func computeLowPassCoefficients(cutoff: Float) -> [Float] {
        let omega = tan(Float.pi * cutoff)
        let omega2 = omega * omega
        let sqrt2 = Float(sqrt(2.0))

        let n = 1.0 + sqrt2 * omega + omega2

        let b0 = omega2 / n
        let b1 = 2.0 * omega2 / n
        let b2 = omega2 / n
        let a1 = 2.0 * (omega2 - 1.0) / n
        let a2 = (1.0 - sqrt2 * omega + omega2) / n

        return [b0, b1, b2, a1, a2]
    }

    /// Apply a single biquad filter section
    private func applyBiquad(_ input: [Float], coefficients: [Float]) -> [Float] {
        guard input.count > 0, coefficients.count == 5 else { return input }

        let b0 = coefficients[0]
        let b1 = coefficients[1]
        let b2 = coefficients[2]
        let a1 = coefficients[3]
        let a2 = coefficients[4]

        var output = [Float](repeating: 0, count: input.count)

        // State variables
        var x1: Float = 0, x2: Float = 0
        var y1: Float = 0, y2: Float = 0

        for i in 0..<input.count {
            let x0 = input[i]
            let y0 = b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2

            output[i] = y0

            x2 = x1
            x1 = x0
            y2 = y1
            y1 = y0
        }

        return output
    }

    // MARK: - Onset Strength (Spectral Flux)

    /// Compute onset strength using spectral flux.
    private func computeOnsetStrength(_ samples: [Float]) -> [Float] {
        guard samples.count > fftSize else { return [] }

        // Setup FFT
        let log2n = vDSP_Length(log2(Float(fftSize)))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return []
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        // Calculate number of frames
        let numFrames = (samples.count - fftSize) / hopLength + 1
        guard numFrames > 1 else { return [] }

        var onsetStrength = [Float](repeating: 0, count: numFrames)
        var prevMagnitudes = [Float](repeating: 0, count: fftSize / 2)

        // Hann window
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        // Buffers for FFT
        var realPart = [Float](repeating: 0, count: fftSize / 2)
        var imagPart = [Float](repeating: 0, count: fftSize / 2)
        var magnitudes = [Float](repeating: 0, count: fftSize / 2)

        for frame in 0..<numFrames {
            let startIdx = frame * hopLength

            // Extract and window the frame
            var windowedFrame = [Float](repeating: 0, count: fftSize)
            for i in 0..<fftSize {
                if startIdx + i < samples.count {
                    windowedFrame[i] = samples[startIdx + i] * window[i]
                }
            }

            // Perform FFT
            windowedFrame.withUnsafeMutableBufferPointer { framePtr in
                realPart.withUnsafeMutableBufferPointer { realPtr in
                    imagPart.withUnsafeMutableBufferPointer { imagPtr in
                        var splitComplex = DSPSplitComplex(
                            realp: realPtr.baseAddress!,
                            imagp: imagPtr.baseAddress!
                        )

                        // Convert to split complex
                        framePtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftSize / 2) { complexPtr in
                            vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(fftSize / 2))
                        }

                        // Forward FFT
                        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
                    }
                }
            }

            // Compute magnitudes
            realPart.withUnsafeBufferPointer { realPtr in
                imagPart.withUnsafeBufferPointer { imagPtr in
                    magnitudes.withUnsafeMutableBufferPointer { magPtr in
                        var splitComplex = DSPSplitComplex(
                            realp: UnsafeMutablePointer(mutating: realPtr.baseAddress!),
                            imagp: UnsafeMutablePointer(mutating: imagPtr.baseAddress!)
                        )
                        vDSP_zvabs(&splitComplex, 1, magPtr.baseAddress!, 1, vDSP_Length(fftSize / 2))
                    }
                }
            }

            // Compute spectral flux (sum of positive differences)
            var flux: Float = 0
            for i in 0..<(fftSize / 2) {
                let diff = magnitudes[i] - prevMagnitudes[i]
                if diff > 0 {
                    flux += diff
                }
            }

            // QUANTIZE: Round to 2 decimal places to reduce architecture-specific
            // floating-point drift between x86_64 (simulator) and ARM64 (device).
            // This ensures consistent peak detection across platforms.
            onsetStrength[frame] = (flux * 100).rounded() / 100
            prevMagnitudes = magnitudes
        }

        return onsetStrength
    }

    // MARK: - Peak Detection

    /// Find peaks in onset strength using adaptive thresholding.
    /// Returns tuple of (peakIndices, thresholds) for debug reporting.
    private func findPeaksWithThresholds(
        onsetStrength: [Float],
        sampleRate: Double,
        thresholdLambda: Float,
        minDistanceSec: Double
    ) -> (peaks: [Int], thresholds: [Float]) {
        guard onsetStrength.count > 0 else { return ([], []) }

        // Calculate window size for adaptive threshold (5 seconds)
        let framesPerSecond = sampleRate / Double(hopLength)
        var windowSize = Int(5.0 * framesPerSecond)
        if windowSize < 3 { windowSize = 3 }
        if windowSize % 2 == 0 { windowSize += 1 }

        // Compute adaptive threshold: local_mean + lambda * local_std
        let threshold = computeAdaptiveThreshold(
            onsetStrength,
            windowSize: windowSize,
            lambda: thresholdLambda
        )

        // Minimum distance between peaks in frames
        let minDistance = Int(minDistanceSec * framesPerSecond)

        // Find local maxima above threshold
        var peaks: [Int] = []
        let halfWindow = minDistance / 2

        for i in halfWindow..<(onsetStrength.count - halfWindow) {
            // Check if above threshold
            guard onsetStrength[i] > threshold[i] else { continue }

            // Check if local maximum
            var isMax = true
            for j in (i - halfWindow)...(i + halfWindow) {
                if j != i && onsetStrength[j] >= onsetStrength[i] {
                    isMax = false
                    break
                }
            }

            if isMax {
                // Ensure minimum distance from last peak
                if let lastPeak = peaks.last, i - lastPeak < minDistance {
                    // Keep the higher peak
                    if onsetStrength[i] > onsetStrength[lastPeak] {
                        peaks[peaks.count - 1] = i
                    }
                } else {
                    peaks.append(i)
                }
            }
        }

        return (peaks, threshold)
    }

    /// Compute adaptive threshold: rolling_mean + lambda * rolling_std
    private func computeAdaptiveThreshold(
        _ values: [Float],
        windowSize: Int,
        lambda: Float
    ) -> [Float] {
        guard values.count > 0 else { return [] }

        var threshold = [Float](repeating: 0, count: values.count)
        let halfWindow = windowSize / 2

        for i in 0..<values.count {
            let start = max(0, i - halfWindow)
            let end = min(values.count - 1, i + halfWindow)
            let windowLength = end - start + 1

            // Compute mean
            var sum: Float = 0
            vDSP_sve(Array(values[start...end]), 1, &sum, vDSP_Length(windowLength))
            let mean = sum / Float(windowLength)

            // Compute std deviation
            var sumSq: Float = 0
            for j in start...end {
                let diff = values[j] - mean
                sumSq += diff * diff
            }
            let std = sqrt(sumSq / Float(windowLength))

            // QUANTIZE: Round to 2 decimal places to reduce architecture-specific
            // floating-point drift between x86_64 (simulator) and ARM64 (device).
            let rawThreshold = mean + lambda * std
            threshold[i] = (rawThreshold * 100).rounded() / 100
        }

        // DEBUG: Log threshold stats for simulator vs device comparison
        if !threshold.isEmpty {
            let minThresh = threshold.min() ?? 0
            let maxThresh = threshold.max() ?? 0
            let avgThresh = threshold.reduce(0, +) / Float(threshold.count)
            print("🎵 [SpectralFluxAudioAnalyzer] 🔍 DEBUG: Adaptive threshold stats - Min: \(String(format: "%.3f", minThresh)), Max: \(String(format: "%.3f", maxThresh)), Avg: \(String(format: "%.3f", avgThresh))")
        }

        return threshold
    }

    // MARK: - Peak Clustering

    /// Cluster detected peaks into action intervals.
    private func clusterPeaks(
        peakTimes: [TimeInterval],
        maxGapSeconds: Double,
        minHitsPerSegment: Int,
        paddingPre: Double,
        paddingPost: Double,
        videoDuration: TimeInterval
    ) -> [(start: TimeInterval, end: TimeInterval)] {
        guard !peakTimes.isEmpty else { return [] }

        let sortedPeaks = peakTimes.sorted()

        var clusters: [[TimeInterval]] = []
        var currentCluster: [TimeInterval] = [sortedPeaks[0]]

        for i in 1..<sortedPeaks.count {
            let gap = sortedPeaks[i] - sortedPeaks[i - 1]

            if gap <= maxGapSeconds {
                currentCluster.append(sortedPeaks[i])
            } else {
                // Save current cluster if valid
                if currentCluster.count >= minHitsPerSegment {
                    clusters.append(currentCluster)
                }
                currentCluster = [sortedPeaks[i]]
            }
        }

        // Don't forget the last cluster
        if currentCluster.count >= minHitsPerSegment {
            clusters.append(currentCluster)
        }

        // Convert clusters to intervals with padding
        var intervals: [(start: TimeInterval, end: TimeInterval)] = []

        for cluster in clusters {
            guard let first = cluster.first, let last = cluster.last else { continue }

            let start = max(0, first - paddingPre)
            let end = min(videoDuration, last + paddingPost)

            intervals.append((start: start, end: end))
        }

        return intervals
    }
}
