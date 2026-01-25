//
//  HighlightProgressBar.swift
//  SportCrunch
//
//  A simple progress bar for scrubbing through the highlight video,
//  with segment markers to show boundaries between segments.
//

import SwiftUI

struct HighlightProgressBar: View {
  let totalDuration: TimeInterval
  let segments: [ActionSegment]
  let accentColor: Color
  @Binding var currentTime: TimeInterval
  var onSeek: (TimeInterval) -> Void

  @State private var isDragging = false
  @State private var dragTime: TimeInterval = 0

  private let barHeight: CGFloat = 6
  private let expandedHeight: CGFloat = 10

  // Calculate segment offsets within the highlight (concatenated segments)
  private var segmentOffsets: [(segment: ActionSegment, startOffset: TimeInterval)] {
    var offset: TimeInterval = 0
    return segments.map { segment in
      let result = (segment: segment, startOffset: offset)
      offset += segment.duration
      return result
    }
  }

  var body: some View {
    VStack(spacing: Spacing.xxs) {
      // Time labels
      HStack {
        Text(formatTime(isDragging ? dragTime : currentTime))
          .font(.system(size: 12, weight: .medium, design: .monospaced))
          .foregroundStyle(Color.scTextSecondary)

        Spacer()

        Text("-\(formatTime(max(0, totalDuration - (isDragging ? dragTime : currentTime))))")
          .font(.system(size: 12, weight: .medium, design: .monospaced))
          .foregroundStyle(Color.scTextTertiary)
      }

      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          // Background track
          RoundedRectangle(cornerRadius: barHeight / 2)
            .fill(Color.scSurfaceElevated)

          // Starred segment glowing overlays (behind progress)
          ForEach(Array(segmentOffsets.enumerated()), id: \.offset) { _, offsetInfo in
            if offsetInfo.segment.isStarred {
              let startX = (offsetInfo.startOffset / totalDuration) * geometry.size.width
              let width = (offsetInfo.segment.duration / totalDuration) * geometry.size.width

              // Glowing starred segment indicator
              StarredSegmentGlow(
                width: max(width, 4),
                height: isDragging ? expandedHeight : barHeight
              )
              .offset(x: startX)
            }
          }

          // Progress fill
          let displayTime = isDragging ? dragTime : currentTime
          let progress = totalDuration > 0 ? displayTime / totalDuration : 0

          RoundedRectangle(cornerRadius: barHeight / 2)
            .fill(
              LinearGradient(
                colors: [accentColor, accentColor.opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
              )
            )
            .frame(width: geometry.size.width * progress)

          // Starred segment indicators on top of progress (visible part)
          ForEach(Array(segmentOffsets.enumerated()), id: \.offset) { _, offsetInfo in
            if offsetInfo.segment.isStarred {
              let startX = (offsetInfo.startOffset / totalDuration) * geometry.size.width
              let width = (offsetInfo.segment.duration / totalDuration) * geometry.size.width
              let displayTime = isDragging ? dragTime : currentTime
              let progressX = (displayTime / totalDuration) * geometry.size.width

              // Only show the golden overlay on the played portion
              if progressX > startX {
                let visibleWidth = min(width, progressX - startX)

                RoundedRectangle(cornerRadius: barHeight / 2)
                  .fill(
                    LinearGradient(
                      colors: [
                        Color.yellow.opacity(0.6),
                        Color.orange.opacity(0.4)
                      ],
                      startPoint: .leading,
                      endPoint: .trailing
                    )
                  )
                  .frame(width: max(visibleWidth, 0))
                  .offset(x: startX)
              }
            }
          }

          // Segment boundary markers (subtle dividers)
          ForEach(Array(segmentOffsets.dropFirst().enumerated()), id: \.offset) { _, offsetInfo in
            let markerX = (offsetInfo.startOffset / totalDuration) * geometry.size.width

            Rectangle()
              .fill(Color.scTextTertiary.opacity(0.3))
              .frame(width: 1)
              .offset(x: markerX - 0.5)
          }

          // Playhead handle (only visible when dragging)
          if isDragging {
            Circle()
              .fill(Color.white)
              .frame(width: 16, height: 16)
              .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
              .offset(x: geometry.size.width * progress - 8)
          }
        }
        .frame(height: isDragging ? expandedHeight : barHeight)
        .animation(.spring(response: 0.2), value: isDragging)
        .contentShape(Rectangle())
        .gesture(
          DragGesture(minimumDistance: 0)
            .onChanged { value in
              handleDrag(value: value, in: geometry)
            }
            .onEnded { value in
              handleDragEnd(value: value, in: geometry)
            }
        )
      }
      .frame(height: isDragging ? expandedHeight : barHeight)
    }
    .animation(.spring(response: 0.2), value: isDragging)
  }

  // MARK: - Gesture Handlers

  private func handleDrag(value: DragGesture.Value, in geometry: GeometryProxy) {
    if !isDragging {
      isDragging = true
      let impact = UIImpactFeedbackGenerator(style: .light)
      impact.impactOccurred()
    }

    let x = max(0, min(value.location.x, geometry.size.width))
    dragTime = (x / geometry.size.width) * totalDuration
  }

  private func handleDragEnd(value: DragGesture.Value, in geometry: GeometryProxy) {
    let x = max(0, min(value.location.x, geometry.size.width))
    let finalTime = (x / geometry.size.width) * totalDuration

    onSeek(finalTime)
    isDragging = false
  }

  // MARK: - Helpers

  private func formatTime(_ time: TimeInterval) -> String {
    let totalSeconds = Int(time)
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let seconds = totalSeconds % 60

    if hours > 0 {
      return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    } else {
      return String(format: "%d:%02d", minutes, seconds)
    }
  }
}

// MARK: - Starred Segment Glow

struct StarredSegmentGlow: View {
  let width: CGFloat
  let height: CGFloat

  var body: some View {
    ZStack {
      // Static yellow background
      RoundedRectangle(cornerRadius: height / 2)
        .fill(Color.yellow.opacity(0.5))
        .frame(width: width, height: height)

      // Star icon at the center (only if wide enough)
      if width > 20 {
        Image(systemName: "star.fill")
          .font(.system(size: 8))
          .foregroundStyle(Color.yellow)
      }
    }
  }
}

// MARK: - Preview

#Preview {
  struct PreviewWrapper: View {
    @State private var currentTime: TimeInterval = 90

    let segments = [
      ActionSegment(startTime: 0, endTime: 60, isStarred: true),
      ActionSegment(startTime: 60, endTime: 120),
      ActionSegment(startTime: 120, endTime: 180, isStarred: true),
      ActionSegment(startTime: 180, endTime: 224)
    ]

    var body: some View {
      VStack(spacing: Spacing.xl) {
        Text("Current: \(Int(currentTime))s")
          .font(AppFont.headline())
          .foregroundStyle(.white)

        HighlightProgressBar(
          totalDuration: 224,
          segments: segments,
          accentColor: .scTennis,
          currentTime: $currentTime,
          onSeek: { time in
            currentTime = time
          }
        )
        .padding(.horizontal, Spacing.lg)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.scBackground)
    }
  }

  return PreviewWrapper()
}
