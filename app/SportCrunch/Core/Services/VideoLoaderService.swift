//
//  VideoLoaderService.swift
//  SportCrunch
//
//  Service for loading videos from the Photos library. Extracted from HighlightCreationViewModel
//  to improve testability and follow single-responsibility principle.
//
//  Implements a fallback chain: PHAssetResourceManager → PHImageManager → Transferable
//  to handle various video types (standard, slow-mo, edited, iCloud).
//

import Foundation
import Photos
import PhotosUI
import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

// MARK: - Errors

/// Errors that can occur during video loading
enum VideoLoaderError: LocalizedError {
    case noAssetIdentifier
    case fetchFailed
    case loadFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .noAssetIdentifier:
            return "No asset identifier available for the selected video"
        case .fetchFailed:
            return "Failed to fetch video from Photos library"
        case .loadFailed(let message):
            return "Failed to load video: \(message)"
        case .cancelled:
            return "Video loading was cancelled"
        }
    }
}

// MARK: - Protocol

/// Protocol for loading videos from the Photos library
protocol VideoLoaderServiceProtocol {
    /// Load video from a PhotosPickerItem to a local URL
    /// - Parameters:
    ///   - item: The PhotosPickerItem to load
    /// - Returns: URL to the loaded video file
    func loadVideo(
        from item: PhotosPickerItem
    ) async throws -> URL
}

// MARK: - Real Implementation

/// Production implementation that uses PHAssetResourceManager, PHImageManager, and Transferable
/// with a fallback chain to handle all video types reliably.
final class RealVideoLoaderService: VideoLoaderServiceProtocol {

    // MARK: - VideoLoaderServiceProtocol

    func loadVideo(
        from item: PhotosPickerItem
    ) async throws -> URL {
        // Get the asset identifier from PhotosPickerItem
        guard let assetIdentifier = item.itemIdentifier else {
            print("SportCrunch: [VideoLoaderService] No asset identifier, falling back to Transferable...")
            return try await loadVideoViaTransferable(item: item)
        }

        print("SportCrunch: [VideoLoaderService] Loading video with asset ID: \(assetIdentifier)")

        // Fetch the PHAsset from Photos library
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
        guard let asset = fetchResult.firstObject else {
            print("SportCrunch: [VideoLoaderService] Could not fetch PHAsset, falling back to Transferable...")
            await MainActor.run {
            }
            return try await loadVideoViaTransferable(item: item)
        }

        // Check if this is a slow-mo or edited video (mediaSubtypes contains .videoHighFrameRate)
        let isSlowMo = asset.mediaSubtypes.contains(.videoHighFrameRate)
        if isSlowMo {
            print("SportCrunch: [VideoLoaderService] Video is slow-mo, using PHImageManager fallback...")
            await MainActor.run {
            }
            return try await loadVideoViaPHImageManager(asset: asset, item: item)
        }

        // Use PHAssetResourceManager for byte-for-byte original access (no transcoding)
        print("SportCrunch: [VideoLoaderService] Using PHAssetResourceManager for original video access...")
        await MainActor.run {
        }

        return try await loadVideoViaPHAssetResourceManager(asset: asset, item: item)
    }

    // MARK: - Private Methods

    /// Primary method: Uses PHAssetResourceManager to copy the original video bytes without transcoding.
    /// This is critical for reliable frame extraction on physical devices.
    private func loadVideoViaPHAssetResourceManager(
        asset: PHAsset,
        item: PhotosPickerItem
    ) async throws -> URL {
        // Find the video resource (prefer fullSizeVideo for edited videos, fall back to video)
        let resources = PHAssetResource.assetResources(for: asset)

        // Log available resources for debugging
        print("SportCrunch: [VideoLoaderService] Available resources: \(resources.map { "\($0.type.rawValue):\($0.originalFilename)" })")

        // Priority: fullSizeVideo > video (fullSizeVideo is the original for edited assets)
        guard let videoResource = resources.first(where: { $0.type == .fullSizeVideo })
                ?? resources.first(where: { $0.type == .video }) else {
            print("SportCrunch: [VideoLoaderService] No video resource found, falling back to PHImageManager...")
            await MainActor.run {
            }
            return try await loadVideoViaPHImageManager(asset: asset, item: item)
        }

        print("SportCrunch: [VideoLoaderService] Using resource type \(videoResource.type.rawValue): \(videoResource.originalFilename)")
        await MainActor.run {
        }

        // Create destination URL with original filename extension
        let originalExtension = (videoResource.originalFilename as NSString).pathExtension
        let fileExtension = originalExtension.isEmpty ? "mov" : originalExtension
        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)

        // Configure options for the copy
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true // For iCloud videos

        // Copy the original video bytes to our temp location
        return try await withCheckedThrowingContinuation { continuation in
            PHAssetResourceManager.default().writeData(
                for: videoResource,
                toFile: destinationURL,
                options: options
            ) { error in
                if let error = error {
                    print("SportCrunch: [VideoLoaderService] PHAssetResourceManager error: \(error.localizedDescription)")
                    Task { @MainActor in
                    }

                    // Fall back to PHImageManager on error
                    Task {
                        do {
                            let url = try await self.loadVideoViaPHImageManager(
                                asset: asset,
                                item: item
                            )
                            continuation.resume(returning: url)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                    return
                }

                print("SportCrunch: [VideoLoaderService] Successfully copied original video to: \(destinationURL)")
                Task { @MainActor in
                }
                continuation.resume(returning: destinationURL)
            }
        }
    }

    /// Secondary fallback: Uses PHImageManager for slow-mo and edited videos that need composition.
    /// These videos return AVComposition and need to be exported via Transferable.
    private func loadVideoViaPHImageManager(
        asset: PHAsset,
        item: PhotosPickerItem
    ) async throws -> URL {
        print("SportCrunch: [VideoLoaderService] Using PHImageManager for video asset...")
        await MainActor.run {
        }

        return try await withCheckedThrowingContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.version = .current
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, info in
                // Check for errors
                if let error = info?[PHImageErrorKey] as? Error {
                    Task { @MainActor in
                    }
                    continuation.resume(throwing: error)
                    return
                }

                // Check if request was cancelled
                if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled {
                    continuation.resume(throwing: VideoLoaderError.cancelled)
                    return
                }

                if let urlAsset = avAsset as? AVURLAsset {
                    print("SportCrunch: [VideoLoaderService] Got video URL from PHImageManager: \(urlAsset.url)")
                    Task { @MainActor in
                    }
                    continuation.resume(returning: urlAsset.url)
                } else if avAsset is AVComposition {
                    // Slow-mo or heavily edited video - need Transferable export
                    print("SportCrunch: [VideoLoaderService] Video is AVComposition, falling back to Transferable export...")
                    Task { @MainActor in
                    }
                    Task {
                        do {
                            let url = try await self.loadVideoViaTransferable(item: item)
                            continuation.resume(returning: url)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                } else {
                    // Unexpected type - fall back to Transferable
                    print("SportCrunch: [VideoLoaderService] Unexpected AVAsset type: \(type(of: avAsset)), falling back to Transferable...")
                    Task {
                        do {
                            let url = try await self.loadVideoViaTransferable(item: item)
                            continuation.resume(returning: url)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
            }
        }
    }

    /// Fallback method using Transferable for edge cases (slow-mo, edited videos, non-Photos sources)
    private func loadVideoViaTransferable(
        item: PhotosPickerItem
    ) async throws -> URL {
        print("SportCrunch: [VideoLoaderService] Loading video via Transferable...")
        await MainActor.run {
        }

        guard let movie = try await item.loadTransferable(type: VideoTransferable.self) else {
            print("SportCrunch: [VideoLoaderService] Failed to load video - loadTransferable returned nil")
            print("SportCrunch: [VideoLoaderService] Item supported types: \(item.supportedContentTypes)")
            await MainActor.run {
            }
            throw VideoLoaderError.loadFailed("Transferable returned nil")
        }

        print("SportCrunch: [VideoLoaderService] Successfully loaded video at: \(movie.url)")
        await MainActor.run {
        }
        return movie.url
    }
}

// MARK: - Video Transferable

/// Transferable wrapper for video files that handles multiple video formats
struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        // Support multiple video formats that may come from the Photos library
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            // Copy to a temporary location preserving the original extension
            let originalExtension = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(originalExtension)

            try FileManager.default.copyItem(at: received.file, to: tempURL)
            return Self(url: tempURL)
        }

        // Also support QuickTime movies specifically
        FileRepresentation(contentType: .quickTimeMovie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let originalExtension = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(originalExtension)

            try FileManager.default.copyItem(at: received.file, to: tempURL)
            return Self(url: tempURL)
        }

        // Also support MPEG-4 movies
        FileRepresentation(contentType: .mpeg4Movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let originalExtension = received.file.pathExtension.isEmpty ? "mp4" : received.file.pathExtension
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(originalExtension)

            try FileManager.default.copyItem(at: received.file, to: tempURL)
            return Self(url: tempURL)
        }
    }
}
