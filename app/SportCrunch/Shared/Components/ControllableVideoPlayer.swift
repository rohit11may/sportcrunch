//
//  ControllableVideoPlayer.swift
//  SportCrunch
//
//  A custom video player wrapper that exposes time binding for synchronization
//  with the interactive timeline.
//

import AVKit
import Combine
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

  // MARK: - Setup State
  @State private var notificationObservers: [NSObjectProtocol] = []

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      if let player = player {
        ZoomableVideoPlayerView(player: player)
      } else {
        Rectangle()
          .fill(Color.scSurfaceElevated)
          .overlay(
            ProgressView()
              .tint(.white)
          )
      }

      // Controls Overlay - always visible
      if player != nil {
        controlsOverlay
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
      let timeDiff = abs(newValue - lastReportedTime)
      if timeDiff > 0.5 && !isSeeking {
        performSeek(to: newValue)
      }
    }
  }

  // MARK: - Controls Overlay

  private var controlsOverlay: some View {
    VStack {
      Spacer()

      // Bottom Bar with scrubber and play/pause
      HStack(spacing: 12) {
        Text(formatTime(currentTime))
          .font(.caption)
          .monospacedDigit()
          .foregroundStyle(.white)

        // Custom Slider
        GeometryReader { geo in
          ZStack(alignment: .leading) {
            // Track
            Capsule()
              .fill(Color.white.opacity(0.3))
              .frame(height: 4)

            // Progress
            let percent = duration > 0 ? CGFloat(currentTime / duration) : 0
            Capsule()
              .fill(Color.yellow)
              .frame(width: max(0, geo.size.width * percent), height: 4)
          }
          .frame(height: 20)
          .contentShape(Rectangle())
          .gesture(
            DragGesture(minimumDistance: 0)
              .onChanged { value in
                isSeeking = true
                let pct = min(max(value.location.x / geo.size.width, 0), 1)
                let newTime = duration * Double(pct)
                currentTime = newTime
              }
              .onEnded { value in
                let pct = min(max(value.location.x / geo.size.width, 0), 1)
                let newTime = duration * Double(pct)
                performSeek(to: newTime)
              }
          )
        }
        .frame(height: 20)

        Text(formatTime(duration))
          .font(.caption)
          .monospacedDigit()
          .foregroundStyle(.white.opacity(0.7))

        // Play/Pause button - bottom right, thumb-friendly
        Button {
          isPlaying.toggle()
        } label: {
          Image(systemName: isPlaying ? "pause.fill" : "play.fill")
            .contentTransition(.identity)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(.black)
            .frame(width: 44, height: 44)
            .background(Color.yellow)
            .clipShape(Circle())
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(
        LinearGradient(
          colors: [.clear, .black.opacity(0.7)],
          startPoint: .top,
          endPoint: .bottom
        )
        .allowsHitTesting(false)
      )
    }
  }

  private func formatTime(_ seconds: TimeInterval) -> String {
    let m = Int(seconds) / 60
    let s = Int(seconds) % 60
    return String(format: "%d:%02d", m, s)
  }

  // MARK: - Setup

  private func setupPlayer() {
    if player != nil || timeObserverToken != nil {
      cleanupPlayer()
    }

    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      print("⚠️ [ControllableVideoPlayer] Failed to set audio session category: \(error)")
    }

    guard FileManager.default.fileExists(atPath: url.path) else { return }

    let playerItem = AVPlayerItem(url: url)
    let newPlayer = AVPlayer(playerItem: playerItem)

    Task {
      if let durationValue = try? await AVURLAsset(url: url).load(.duration) {
        await MainActor.run {
          self.duration = CMTimeGetSeconds(durationValue)
        }
      }
    }

    player = newPlayer

    let errorObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemFailedToPlayToEndTime,
      object: playerItem,
      queue: .main
    ) { notification in
      if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
        print("⚠️ Playback error: \(error.localizedDescription)")
      }
    }
    notificationObservers.append(errorObserver)

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

    setupTimeObserver()
  }

  private func setupTimeObserver() {
    guard let player = player else { return }
    if let token = timeObserverToken {
      player.removeTimeObserver(token)
      timeObserverToken = nil
    }

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
    if let token = timeObserverToken {
      player?.removeTimeObserver(token)
      timeObserverToken = nil
    }
    notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
    notificationObservers.removeAll()
    player?.pause()
    player = nil
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

// MARK: - Zoomable Video Player Implementation (AVPlayerLayer)

private struct ZoomableVideoPlayerView: UIViewControllerRepresentable {
  let player: AVPlayer

  func makeUIViewController(context: Context) -> ZoomableVideoViewController {
    let controller = ZoomableVideoViewController()
    controller.setPlayer(player)
    return controller
  }

  func updateUIViewController(_ uiViewController: ZoomableVideoViewController, context: Context) {
    uiViewController.setPlayer(player)
  }
}

private class ZoomableVideoViewController: UIViewController, UIScrollViewDelegate {
  private let scrollView = UIScrollView()
  private let containerView = UIView()
  private let playerView = PlayerView()

  override func viewDidLoad() {
    super.viewDidLoad()

    view.backgroundColor = .black

    // Setup ScrollView
    view.addSubview(scrollView)
    scrollView.delegate = self
    scrollView.minimumZoomScale = 1.0
    scrollView.maximumZoomScale = 5.0
    scrollView.showsHorizontalScrollIndicator = false
    scrollView.showsVerticalScrollIndicator = false
    scrollView.bouncesZoom = true
    scrollView.backgroundColor = .black
    scrollView.contentInsetAdjustmentBehavior = .never

    scrollView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: view.topAnchor),
      scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
    ])

    // Setup Container View
    scrollView.addSubview(containerView)
    containerView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      containerView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
      containerView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
      containerView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
      containerView.trailingAnchor.constraint(
        equalTo: scrollView.contentLayoutGuide.trailingAnchor),
      containerView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
      containerView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
    ])

    // Setup Player View
    containerView.addSubview(playerView)
    playerView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      playerView.topAnchor.constraint(equalTo: containerView.topAnchor),
      playerView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
      playerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
      playerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
    ])
  }

  func setPlayer(_ player: AVPlayer) {
    playerView.player = player
  }

  func viewForZooming(in scrollView: UIScrollView) -> UIView? {
    return containerView
  }
}

// Custom UIView backed by AVPlayerLayer
private class PlayerView: UIView {
  var player: AVPlayer? {
    get { playerLayer.player }
    set { playerLayer.player = newValue }
  }

  var playerLayer: AVPlayerLayer {
    return layer as! AVPlayerLayer
  }

  override class var layerClass: AnyClass {
    return AVPlayerLayer.self
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    playerLayer.videoGravity = .resizeAspectFill
    backgroundColor = .black
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
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
