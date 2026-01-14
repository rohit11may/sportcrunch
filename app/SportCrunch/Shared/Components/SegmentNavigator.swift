//
//  SegmentNavigator.swift
//  SportCrunch
//
//  A horizontal scrollable segment navigator that allows users to tap on
//  individual segments to jump to them in the highlight video.
//

import SwiftUI

struct SegmentNavigator: View {
  let segments: [ActionSegment]
  let accentColor: Color
  @Binding var currentSegmentIndex: Int?
  var onSegmentTap: (Int, ActionSegment) -> Void
  var onStarToggle: ((Int, ActionSegment) -> Void)?

  /// Optional display indices for each segment (1-based).
  /// When provided, these are used for "Segment X" labels instead of the enumeration index.
  /// Useful when showing a filtered subset of segments but wanting to preserve original numbers.
  var displayIndices: [Int]?

  @State private var scrollProxy: ScrollViewProxy?
  @Namespace private var segmentNamespace

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(spacing: Spacing.sm) {
          ForEach(segments.indices, id: \.self) { index in
            let segment = segments[index]
            // Use provided display index if available, otherwise use enumeration index + 1
            let displayNumber = displayIndices?[safe: index] ?? (index + 1)

            SegmentChip(
              index: displayNumber,
              duration: segment.duration,
              isActive: currentSegmentIndex == index,
              isStarred: segment.isStarred,
              accentColor: accentColor,
              onChipTap: {
                withAnimation(.spring(response: 0.3)) {
                  currentSegmentIndex = index
                }
                onSegmentTap(index, segment)

                // Haptic feedback
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
              },
              onStarTap: onStarToggle != nil
                ? {
                  onStarToggle?(index, segment)

                  // Haptic feedback for star toggle
                  let impact = UIImpactFeedbackGenerator(style: .light)
                  impact.impactOccurred()
                } : nil
            )
            // Use stable ID for correct scrolling and animation
            .id(segment.id)
          }
        }
        .padding(.horizontal, Spacing.lg)
      }
      .onAppear {
        scrollProxy = proxy
      }
      .onChange(of: currentSegmentIndex) { _, newIndex in
        guard let index = newIndex, index < segments.count else { return }
        withAnimation(.spring(response: 0.3)) {
          proxy.scrollTo(segments[index].id, anchor: .center)
        }
      }
    }
  }
}

// MARK: - Safe Array Subscript

extension Array {
  fileprivate subscript(safe index: Int) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}

// MARK: - Segment Chip

struct SegmentChip: View {
  let index: Int
  let duration: TimeInterval
  let isActive: Bool
  let isStarred: Bool
  let accentColor: Color
  var onChipTap: (() -> Void)?
  var onStarTap: (() -> Void)?

  @State private var starGlowPhase: CGFloat = 0

  var body: some View {
    HStack(spacing: Spacing.xs) {
      // Chip body - tappable area for segment selection
      VStack(spacing: 2) {
        Text("\(index)")
          .font(AppFont.captionBold())
          .foregroundStyle(isActive ? .black : Color.scTextPrimary)

        Text(formatDuration(duration))
          .font(.system(size: 11, weight: .medium, design: .monospaced))
          .foregroundStyle(isActive ? .black.opacity(0.7) : Color.scTextSecondary)
      }
      .contentShape(Rectangle())
      .onTapGesture {
        onChipTap?()
      }

      // Star toggle button - separate tap target
      if onStarTap != nil {
        Button {
          onStarTap?()
        } label: {
          ZStack {
            // Glow effect for starred segments
            if isStarred {
              Image(systemName: "star.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color.yellow)
                .blur(radius: 2)  // Reduced blur for sharper appearance
                .opacity(0.4 + 0.4 * starGlowPhase)  // Animate opacity instead
            }

            Image(systemName: isStarred ? "star.fill" : "star")
              .font(.system(size: 16, weight: .medium))
              .foregroundStyle(
                isStarred
                  ? Color.yellow
                  : (isActive ? .black.opacity(0.5) : Color.scTextTertiary)
              )
          }
          .frame(width: 32, height: 32)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, Spacing.md)
    .padding(.vertical, Spacing.sm)
    .background(
      ZStack {
        RoundedRectangle(cornerRadius: CornerRadius.medium)
          .fill(isActive ? accentColor : Color.scSurfaceElevated)

        // Golden shimmer overlay for starred segments
        if isStarred && !isActive {
          RoundedRectangle(cornerRadius: CornerRadius.medium)
            .fill(
              LinearGradient(
                colors: [
                  Color.yellow.opacity(0.08),
                  Color.orange.opacity(0.04),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
        }
      }
    )
    .overlay(
      RoundedRectangle(cornerRadius: CornerRadius.medium)
        .stroke(
          isStarred
            ? Color.yellow.opacity(0.5)
            : (isActive ? accentColor.opacity(0.5) : Color.clear),
          lineWidth: isStarred ? 1.5 : 2
        )
    )
    .shadow(
      color: isStarred
        ? Color.yellow.opacity(0.2)  // Reduced shadow opacity
        : (isActive ? accentColor.opacity(0.3) : .clear),
      radius: (isActive || isStarred) ? 8 : 0,
      y: (isActive || isStarred) ? 2 : 0
    )
    .scaleEffect(isActive ? 1.05 : 1.0)
    .animation(.spring(response: 0.25), value: isActive)
    .animation(.spring(response: 0.25), value: isStarred)
    .onAppear {
      if isStarred {
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
          starGlowPhase = 1
        }
      }
    }
    .onChange(of: isStarred) { _, newValue in
      if newValue {
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
          starGlowPhase = 1
        }
      } else {
        starGlowPhase = 0
      }
    }
  }

  private func formatDuration(_ duration: TimeInterval) -> String {
    let totalSeconds = Int(duration)
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60
    return String(format: "%d:%02d", minutes, seconds)
  }
}

// MARK: - Preview

#Preview {
  struct PreviewWrapper: View {
    @State private var currentIndex: Int? = 1
    @State private var segments = [
      ActionSegment(startTime: 0, endTime: 45, isStarred: true),
      ActionSegment(startTime: 45, endTime: 120),
      ActionSegment(startTime: 120, endTime: 180, isStarred: true),
      ActionSegment(startTime: 180, endTime: 240),
      ActionSegment(startTime: 240, endTime: 300),
    ]

    var body: some View {
      VStack(spacing: Spacing.lg) {
        Text("Current: \(currentIndex ?? -1)")
          .foregroundStyle(.white)

        Text("Starred: \(segments.filter { $0.isStarred }.count)")
          .foregroundStyle(.yellow)

        SegmentNavigator(
          segments: segments,
          accentColor: .scTennis,
          currentSegmentIndex: $currentIndex,
          onSegmentTap: { index, _ in
            print("Tapped segment \(index)")
          },
          onStarToggle: { index, _ in
            segments[index].isStarred.toggle()
            print("Toggled star on segment \(index): \(segments[index].isStarred)")
          }
        )
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.scBackground)
    }
  }

  return PreviewWrapper()
}
