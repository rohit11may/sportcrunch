//
//  AudioAnalyzer.swift
//  SportCrunch
//
//  Detects racket-ball impacts using audio signal processing.
//  Port of Python prototype's audio_analyzer.py using Accelerate framework.
//

import Foundation
import AVFoundation
import Accelerate

// MARK: - Audio Analysis Result

struct AudioAnalysisResult {
    let duration: TimeInterval
    let peakTimes: [TimeInterval]
    let candidateIntervals: [(start: TimeInterval, end: TimeInterval)]
}

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
actor AudioAnalyzer {
    
    // MARK: - Fixed Constants (not sport-specific)
    
    private let hopLength: Int = 512
    private let fftSize: Int = 1024
    
    // MARK: - Public API
    
    /// Analyze audio from a video file to detect action segments.
    /// - Parameters:
    ///   - videoURL: URL to the video file
    ///   - sport: Sport type for detection tuning
    ///   - sportMode: Optional sport-specific mode (e.g., TennisMode.rally)
    /// - Returns: Analysis result with detected peaks and candidate intervals
    func analyze(videoURL: URL, sport: Sport, sportMode: SportMode? = nil) async throws -> AudioAnalysisResult {
        let preset = sport.preset(for: sportMode)
        let startTime = Date()
        let logger = ProcessingLogger.shared
        let modeDescription = (sportMode as? TennisMode)?.displayName ?? "Default"
        
        print("🎵 [AudioAnalyzer] ═══════════════════════════════════════════")
        print("🎵 [AudioAnalyzer] Starting audio analysis for \(sport.displayName) (\(modeDescription))")
        print("🎵 [AudioAnalyzer] Source: \(videoURL.lastPathComponent)")
        print("🎵 [AudioAnalyzer] ───────────────────────────────────────────")
        print("🎵 [AudioAnalyzer] Preset Configuration:")
        print("🎵 [AudioAnalyzer]   • Sample rate: \(Int(preset.sampleRate)) Hz")
        print("🎵 [AudioAnalyzer]   • Bandpass: \(Int(preset.bandpassLow))-\(Int(preset.bandpassHigh)) Hz")
        print("🎵 [AudioAnalyzer]   • Threshold λ: \(preset.onsetThresholdLambda) (lower = more sensitive)")
        print("🎵 [AudioAnalyzer]   • Min peak distance: \(preset.peakMinDistanceSec)s")
        print("🎵 [AudioAnalyzer]   • Cluster max gap: \(preset.clusterMaxGapSec)s")
        print("🎵 [AudioAnalyzer]   • Cluster min hits: \(preset.clusterMinHits)")
        print("🎵 [AudioAnalyzer]   • Padding: \(preset.paddingPreSec)s before, \(preset.paddingPostSec)s after")
        print("🎵 [AudioAnalyzer] ───────────────────────────────────────────")
        
        logger.audioAsync("Starting audio analysis for \(sport.displayName) (\(modeDescription))...")
        
        // Step 1: Extract audio samples
        print("🎵 [AudioAnalyzer] Step 1/5: Extracting audio at \(Int(preset.sampleRate)) Hz...")
        logger.audioAsync("Extracting audio at \(Int(preset.sampleRate)) Hz...")
        let (samples, duration) = try await extractAudio(from: videoURL, sampleRate: preset.sampleRate)
        
        guard !samples.isEmpty else {
            print("🎵 [AudioAnalyzer] ❌ ERROR: No audio samples extracted")
            logger.errorAsync("No audio samples extracted")
            throw AudioAnalyzerError.audioExtractionFailed
        }
        
        let sampleCount = samples.count
        print("🎵 [AudioAnalyzer] ✓ Extracted \(formatNumber(sampleCount)) samples")
        print("🎵 [AudioAnalyzer] ✓ Duration: \(formatTime(duration))")
        logger.audioAsync("Extracted \(formatNumber(sampleCount)) samples (\(formatTime(duration)))")
        
        // DEBUG: Compute audio fingerprint to detect extraction differences between simulator and device
        // This helps identify if the discrepancy starts at audio extraction or later processing
        let fingerprint = computeAudioFingerprint(samples)
        print("🎵 [AudioAnalyzer] 🔍 DEBUG: Audio fingerprint: \(fingerprint)")
        print("🎵 [AudioAnalyzer] 🔍 DEBUG: First 10 samples: \(samples.prefix(10).map { String(format: "%.6f", $0) }.joined(separator: ", "))")
        print("🎵 [AudioAnalyzer] 🔍 DEBUG: Samples at 1s: \(samples.dropFirst(Int(preset.sampleRate)).prefix(5).map { String(format: "%.6f", $0) }.joined(separator: ", "))")
        
        // Step 2: Apply bandpass filter
        print("🎵 [AudioAnalyzer] Step 2/5: Applying bandpass filter (\(Int(preset.bandpassLow))-\(Int(preset.bandpassHigh)) Hz)...")
        logger.audioAsync("Applying bandpass filter (\(Int(preset.bandpassLow))-\(Int(preset.bandpassHigh)) Hz)...")
        let filteredSamples = applyBandpassFilter(
            samples,
            lowCutoff: Float(preset.bandpassLow),
            highCutoff: Float(preset.bandpassHigh),
            sampleRate: Float(preset.sampleRate)
        )
        print("🎵 [AudioAnalyzer] ✓ Bandpass filter applied")
        
        // DEBUG: Fingerprint after filtering to isolate where divergence occurs
        let filteredFingerprint = computeAudioFingerprint(filteredSamples)
        print("🎵 [AudioAnalyzer] 🔍 DEBUG: Filtered audio fingerprint: \(filteredFingerprint)")
        
        // Step 3: Compute onset strength (spectral flux)
        print("🎵 [AudioAnalyzer] Step 3/5: Computing spectral flux (FFT)...")
        logger.audioAsync("Computing spectral flux (FFT analysis)...")
        let onsetStrength = computeOnsetStrength(filteredSamples)
        print("🎵 [AudioAnalyzer] ✓ Computed \(formatNumber(onsetStrength.count)) onset frames")
        
        // Log detailed stats about onset strength for debugging simulator vs device differences
        if !onsetStrength.isEmpty {
            let maxOnset = onsetStrength.max() ?? 0
            let avgOnset = onsetStrength.reduce(0, +) / Float(onsetStrength.count)
            let sortedOnsets = onsetStrength.sorted(by: >)
            let top10 = sortedOnsets.prefix(10)
            let median = onsetStrength.count > 0 ? sortedOnsets[onsetStrength.count / 2] : 0
            
            print("🎵 [AudioAnalyzer]   Onset stats - Max: \(String(format: "%.1f", maxOnset)), Avg: \(String(format: "%.3f", avgOnset)), Median: \(String(format: "%.3f", median))")
            print("🎵 [AudioAnalyzer]   Top 10 onset values: \(top10.map { String(format: "%.1f", $0) }.joined(separator: ", "))")
            
            #if targetEnvironment(simulator)
            print("🎵 [AudioAnalyzer]   ⚡ RUNNING ON SIMULATOR (x86_64)")
            #else
            print("🎵 [AudioAnalyzer]   📱 RUNNING ON DEVICE (ARM)")
            #endif
        }
        
        // Step 4: Compute adaptive threshold and find peaks
        print("🎵 [AudioAnalyzer] Step 4/5: Finding peaks with adaptive threshold (λ=\(preset.onsetThresholdLambda))...")
        logger.audioAsync("Detecting impact sounds...")
        let peakIndices = findPeaks(
            onsetStrength: onsetStrength,
            sampleRate: preset.sampleRate,
            thresholdLambda: preset.onsetThresholdLambda,
            minDistanceSec: preset.peakMinDistanceSec
        )
        
        // Convert peak indices to timestamps
        let framesPerSecond = preset.sampleRate / Double(hopLength)
        let peakTimes = peakIndices.map { Double($0) / framesPerSecond }
        print("🎵 [AudioAnalyzer] ✓ Detected \(peakTimes.count) potential hits")
        logger.audioAsync("Detected \(peakTimes.count) potential \(sport.displayName.lowercased()) hits")
        
        // DEBUG: Log peak onset strengths for comparison between simulator and device
        print("🎵 [AudioAnalyzer] 🔍 DEBUG: Peak indices and their onset strengths:")
        for (i, peakIdx) in peakIndices.prefix(20).enumerated() {
            let peakStrength = onsetStrength[peakIdx]
            let peakTime = Double(peakIdx) / framesPerSecond
            print("🎵 [AudioAnalyzer]   Peak \(i+1): t=\(String(format: "%.3f", peakTime))s, idx=\(peakIdx), strength=\(String(format: "%.2f", peakStrength))")
        }
        if peakIndices.count > 20 {
            print("🎵 [AudioAnalyzer]   ... and \(peakIndices.count - 20) more peaks")
        }
        
        if !peakTimes.isEmpty {
            let firstFew = peakTimes.prefix(5).map { formatTime($0) }.joined(separator: ", ")
            print("🎵 [AudioAnalyzer]   First hits at: \(firstFew)\(peakTimes.count > 5 ? "..." : "")")
        }
        
        // Step 5: Cluster peaks into intervals
        print("🎵 [AudioAnalyzer] Step 5/5: Clustering peaks (max gap: \(preset.clusterMaxGapSec)s, min hits: \(preset.clusterMinHits))...")
        logger.audioAsync("Clustering hits into action segments...")
        let candidateIntervals = clusterPeaks(
            peakTimes: peakTimes,
            maxGapSeconds: preset.clusterMaxGapSec,
            minHitsPerSegment: preset.clusterMinHits,
            paddingPre: preset.paddingPreSec,
            paddingPost: preset.paddingPostSec,
            videoDuration: duration
        )
        
        let elapsed = Date().timeIntervalSince(startTime)
        print("🎵 [AudioAnalyzer] ═══════════════════════════════════════════")
        print("🎵 [AudioAnalyzer] ✅ ANALYSIS COMPLETE in \(String(format: "%.2f", elapsed))s")
        print("🎵 [AudioAnalyzer] 📊 Results:")
        print("🎵 [AudioAnalyzer]    • Video duration: \(formatTime(duration))")
        print("🎵 [AudioAnalyzer]    • Hits detected: \(peakTimes.count)")
        print("🎵 [AudioAnalyzer]    • Candidate segments: \(candidateIntervals.count)")
        
        for (i, interval) in candidateIntervals.enumerated() {
            let segDuration = interval.end - interval.start
            print("🎵 [AudioAnalyzer]    Segment \(i+1): \(formatTime(interval.start)) → \(formatTime(interval.end)) (\(String(format: "%.1f", segDuration))s)")
        }
        print("🎵 [AudioAnalyzer] ═══════════════════════════════════════════")
        
        logger.successAsync("Audio analysis complete: \(candidateIntervals.count) segments found in \(String(format: "%.1f", elapsed))s")
        
        return AudioAnalysisResult(
            duration: duration,
            peakTimes: peakTimes,
            candidateIntervals: candidateIntervals
        )
    }
    
    // MARK: - Formatting Helpers
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let ms = Int((seconds.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", mins, secs, ms)
    }
    
    private func formatNumber(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }
    
    // MARK: - Debug Helpers
    
    /// Computes a simple fingerprint of audio samples for comparing between simulator and device.
    /// Uses sum, sum of squares, min, max, and count to create a reproducible hash.
    private func computeAudioFingerprint(_ samples: [Float]) -> String {
        guard !samples.isEmpty else { return "empty" }
        
        var sum: Float = 0
        var sumSq: Float = 0
        vDSP_sve(samples, 1, &sum, vDSP_Length(samples.count))
        vDSP_svesq(samples, 1, &sumSq, vDSP_Length(samples.count))
        
        let min = samples.min() ?? 0
        let max = samples.max() ?? 0
        
        // Create a fingerprint string that's easy to compare
        return String(format: "n=%d sum=%.4f ssq=%.4f min=%.6f max=%.6f", 
                      samples.count, sum, sumSq, min, max)
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
            
            onsetStrength[frame] = flux
            prevMagnitudes = magnitudes
        }
        
        return onsetStrength
    }
    
    // MARK: - Peak Detection
    
    /// Find peaks in onset strength using adaptive thresholding.
    private func findPeaks(
        onsetStrength: [Float],
        sampleRate: Double,
        thresholdLambda: Float,
        minDistanceSec: Double
    ) -> [Int] {
        guard onsetStrength.count > 0 else { return [] }
        
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
        
        return peaks
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
            
            threshold[i] = mean + lambda * std
        }
        
        // DEBUG: Log threshold stats for simulator vs device comparison
        if !threshold.isEmpty {
            let minThresh = threshold.min() ?? 0
            let maxThresh = threshold.max() ?? 0
            let avgThresh = threshold.reduce(0, +) / Float(threshold.count)
            print("🎵 [AudioAnalyzer] 🔍 DEBUG: Adaptive threshold stats - Min: \(String(format: "%.3f", minThresh)), Max: \(String(format: "%.3f", maxThresh)), Avg: \(String(format: "%.3f", avgThresh))")
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

