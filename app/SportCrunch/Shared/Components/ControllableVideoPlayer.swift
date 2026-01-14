//
//  ControllableVideoPlayer.swift
//  SportCrunch
//
//  A custom video player wrapper that exposes time binding for synchronization
//  with the interactive timeline.
//

import AVKit
import SwiftUI

struct ControllableVideoPlayer: View {
  let url: URL
  @Binding var currentTime: TimeInterval
  @Binding var isPlaying: Bool
  var onSegmentChange: ((UUID?) -> Void)?

  @State private var player: AVPlayer?
  @State private var timeObserverToken: Any?
  @State private var isSeeking = false
  @State private var duration: TimeInterval = 0
  @State private var lastReportedTime: TimeInterval = 0

  var body: some View {
    // Container ensuring player state stability across gesture changes
    ZStack {
      if finalScale > 1.0 {
        playerView
          .simultaneousGesture(magnificationGesture)
          .highPriorityGesture(dragGesture)
      } else {
        playerView
          .highPriorityGesture(magnificationGesture)
      }
    }
    .scaleEffect(currentScale * finalScale)
    .offset(
      x: currentOffset.width + finalOffset.width,
      y: currentOffset.height + finalOffset.height
    )
    .clipShape(Rectangle())
    .onAppear {
      setupPlayer()
    }
    .onDisappear {
      cleanupPlayer()
    }
    .onChange(of: isPlaying) { _, playing in
      if playing {
        player?.play()
      } else {
        player?.pause()
      }
    }
    .onChange(of: currentTime) { oldValue, newValue in
      // Only seek if the change was external (not from our observer)
      let timeDiff = abs(newValue - lastReportedTime)
      if timeDiff > 0.5 && !isSeeking {
        performSeek(to: newValue)
      }
    }
  }

  private var playerView: some View {
    ZStack {
      if let player = player {
        VideoPlayerView(player: player)
      } else {
        Rectangle()
          .fill(Color.scSurfaceElevated)
          .overlay(
            ProgressView()
              .tint(.white)
          )
      }
    }
  }

  // MARK: - Gestures

  private var magnificationGesture: some Gesture {
    MagnificationGesture()
      .onChanged { scale in
        currentScale = scale
      }
      .onEnded { scale in
        let newScale = finalScale * scale
        // Clamp scale between 1.0 (original size) and 5.0
        finalScale = max(1.0, min(newScale, 5.0))
        currentScale = 1.0

        // If we zoomed back out to 1.0, reset offset
        if finalScale == 1.0 {
          withAnimation(.spring()) {
            finalOffset = .zero
          }
        }
      }
  }

  private var dragGesture: some Gesture {
    DragGesture()
      .onChanged { value in
        // Only allow panning if zoomed in
        if finalScale > 1.0 {
          currentOffset = value.translation
        }
      }
      .onEnded { value in
        if finalScale > 1.0 {
          finalOffset = CGSize(
            width: finalOffset.width + value.translation.width,
            height: finalOffset.height + value.translation.height
          )
          currentOffset = .zero
        }
      }
  }

  // MARK: - Gesture State

  @State private var currentScale: CGFloat = 1.0
  @State private var finalScale: CGFloat = 1.0
  @State private var currentOffset: CGSize = .zero
  @State private var finalOffset: CGSize = .zero

  // MARK: - Setup

  @State private var notificationObservers: [NSObjectProtocol] = []

  private func setupPlayer() {
    // Ensure we clean up any existing player/observers before creating a new one
    // This is critical to avoid "AVPlayer cannot remove a time observer..." crash
    if player != nil || timeObserverToken != nil {
      cleanupPlayer()
    }

    // Configure Audio Session
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      print("⚠️ [ControllableVideoPlayer] Failed to set audio session category: \(error)")
    }
    guard FileManager.default.fileExists(atPath: url.path) else {
      print("⚠️ [ControllableVideoPlayer] Video file not found at: \(url.path)")
      return
    }

    let playerItem = AVPlayerItem(url: url)
    let newPlayer = AVPlayer(playerItem: playerItem)

    // Get duration
    Task {
      if let durationValue = try? await AVURLAsset(url: url).load(.duration) {
        await MainActor.run {
          self.duration = CMTimeGetSeconds(durationValue)
        }
      }
    }

    player = newPlayer

    // Observe playback errors
    let errorObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemFailedToPlayToEndTime,
      object: playerItem,
      queue: .main
    ) { notification in
      if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
        print("⚠️ [ControllableVideoPlayer] Playback error: \(error.localizedDescription)")
      }
    }
    notificationObservers.append(errorObserver)

    // Loop playback
    let loopObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: playerItem,
      queue: .main
    ) { _ in
      newPlayer.seek(to: .zero)
      if isPlaying {
        newPlayer.play()
      }
    }
    notificationObservers.append(loopObserver)

    // Start time observation
    setupTimeObserver()
  }

  private func setupTimeObserver() {
    guard let player = player else { return }

    // Remove existing observer if any
    if let token = timeObserverToken {
      player.removeTimeObserver(token)
      timeObserverToken = nil
    }

    // Add periodic time observer (every 0.1 seconds for smooth updates)
    let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
    timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) {
      time in
      guard !isSeeking else { return }

      let newTime = CMTimeGetSeconds(time)
      if abs(newTime - currentTime) > 0.05 {
        lastReportedTime = newTime
        currentTime = newTime
      }
    }
  }

  private func cleanupPlayer() {
    // Remove time observer
    if let token = timeObserverToken {
      // Only attempt to remove from player if it exists
      if let player = player {
        player.removeTimeObserver(token)
      }
      // Always clear the token to prevent stale references
      timeObserverToken = nil
    }

    // Remove notification observers
    notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
    notificationObservers.removeAll()

    player?.pause()
    player = nil
  }

  // MARK: - Seeking

  private func seek(by seconds: TimeInterval) {
    let newTime = max(0, min(duration, currentTime + seconds))
    performSeek(to: newTime)
  }

  private func performSeek(to time: TimeInterval) {
    guard let player = player else { return }

    isSeeking = true
    let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))

    player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { finished in
      DispatchQueue.main.async {
        if finished {
          self.lastReportedTime = time
          self.currentTime = time
        }
        self.isSeeking = false
      }
    }
  }
}

// MARK: - Video Player UIViewControllerRepresentable

private struct VideoPlayerView: UIViewControllerRepresentable {
  let player: AVPlayer

  func makeUIViewController(context: Context) -> AVPlayerViewController {
    let controller = AVPlayerViewController()
    controller.player = player
    controller.showsPlaybackControls = true
    controller.videoGravity = .resizeAspectFill
    return controller
  }

  func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
    uiViewController.player = player
    uiViewController.showsPlaybackControls = true
  }
}

// MARK: - Preview

#Preview {
  ControllableVideoPlayer(
    url: URL(fileURLWithPath: "/sample/video.mp4"),
    currentTime: .constant(30),
    isPlaying: .constant(false)
  )
  .frame(height: 300)
  .background(Color.scBackground)
}
