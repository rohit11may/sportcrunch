//
//  ThumbnailService.swift
//  SportCrunch
//
//  Service for generating video thumbnails. Extracted from BackgroundProcessingManager
//  to improve testability and follow single-responsibility principle.
//

import Foundation
import AVFoundation
import UIKit

// MARK: - Protocol

/// Protocol for thumbnail generation from video files
protocol ThumbnailServiceProtocol {
    /// Generates a thumbnail image from a video file
    /// - Parameters:
    ///   - videoURL: URL to the video file
    ///   - maxSize: Maximum size for the thumbnail. Defaults to 400x400 if nil.
    /// - Returns: JPEG data of the thumbnail, or nil if generation fails
    func generateThumbnail(from videoURL: URL, maxSize: CGSize?) async -> Data?
}

// MARK: - Real Implementation

/// Production implementation that uses AVAssetImageGenerator to extract frames
final class RealThumbnailService: ThumbnailServiceProtocol {

    // MARK: - Constants

    private let defaultMaxSize = CGSize(width: 400, height: 400)
    private let compressionQuality: CGFloat = 0.7

    // MARK: - ThumbnailServiceProtocol

    func generateThumbnail(from videoURL: URL, maxSize: CGSize?) async -> Data? {
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = maxSize ?? defaultMaxSize

        // Get video duration to find the middle
        guard let duration = try? await asset.load(.duration) else {
            print("⚙️ [ThumbnailService] Failed to load video duration for thumbnail")
            return nil
        }

        // Use the middle of the video for the thumbnail
        let middleTime = CMTime(seconds: CMTimeGetSeconds(duration) / 2, preferredTimescale: 600)

        do {
            let cgImage = try await imageGenerator.image(at: middleTime).image
            let uiImage = UIImage(cgImage: cgImage)
            print("⚙️ [ThumbnailService] Thumbnail generated from middle of video")
            return uiImage.jpegData(compressionQuality: compressionQuality)
        } catch {
            print("⚙️ [ThumbnailService] Failed to generate thumbnail: \(error.localizedDescription)")
            return nil
        }
    }
}
