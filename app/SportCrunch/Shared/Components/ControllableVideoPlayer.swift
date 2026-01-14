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
    ZStack {
      if let player = player {
        VideoPlayerView(player: player)
          .onAppear {
            setupTimeObserver()
          }
      } else {
        Rectangle()
          .fill(Color.scSurfaceElevated)
          .overlay(
            ProgressView()
              .tint(.white)
          )
      }
    }
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
      // Detect external changes by checking if the difference is significant
      // and we're not currently seeking
      let timeDiff = abs(newValue - lastReportedTime)
      if timeDiff > 0.5 && !isSeeking {
        performSeek(to: newValue)
      }
    }
  }

  // MARK: - Setup

  private func setupPlayer() {
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
    NotificationCenter.default.addObserver(
      forName: .AVPlayerItemFailedToPlayToEndTime,
      object: playerItem,
      queue: .main
    ) { notification in
      if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
        print("⚠️ [ControllableVideoPlayer] Playback error: \(error.localizedDescription)")
      }
    }

    // Loop playback
    NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: playerItem,
      queue: .main
    ) { _ in
      newPlayer.seek(to: .zero)
      if isPlaying {
        newPlayer.play()
      }
    }
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
    if let token = timeObserverToken, let player = player {
      player.removeTimeObserver(token)
      timeObserverToken = nil
    }
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
    controller.videoGravity = .resizeAspect
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
