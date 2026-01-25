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
  var showDuration: Bool = true

  /// Optional display indices for each segment (1-based).
  /// When provided, these are used for "Segment X" labels instead of the enumeration index.
  /// Useful when showing a filtered subset of segments but wanting to preserve original numbers.
  var displayIndices: [Int]?

  @State private var scrollProxy: ScrollViewProxy?
  @Namespace private var segmentNamespace

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(spacing: Spacing.xs) {
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
              showDuration: showDuration,
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
  let showDuration: Bool
  var onChipTap: (() -> Void)?
  var onStarTap: (() -> Void)?

  @State private var starGlowPhase: CGFloat = 0

  var body: some View {
    VStack(spacing: 0) {
      // Top part: Number and optional Duration
      VStack(spacing: 2) {
        Text("\(index)")
          .font(AppFont.captionBold())
          .foregroundStyle(isActive ? .black : Color.scTextPrimary)
          .frame(height: 24)

        if showDuration {
          Text(formatDuration(duration))
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(isActive ? .black.opacity(0.7) : Color.scTextSecondary)
            .frame(height: 14)
        }
      }
      .padding(.horizontal, Spacing.md)
      .padding(.top, Spacing.sm)
      .padding(.bottom, onStarTap != nil ? 4 : Spacing.sm)
      .contentShape(Rectangle())
      .onTapGesture {
        onChipTap?()
      }

      // Divider if we have a star button
      if onStarTap != nil {
        // Tiny spacer or divider logic could go here, but padding handles it well
      }

      // Bottom part: Star Button (if enabled)
      if onStarTap != nil {
        Button {
          onStarTap?()
        } label: {
          ZStack {
            // Glow effect for starred segments
            if isStarred {
              Image(systemName: "star.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.yellow)
                .blur(radius: 1.5)
                .opacity(0.4 + 0.4 * starGlowPhase)
            }

            Image(systemName: isStarred ? "star.fill" : "star")
              .font(.system(size: 14, weight: .medium))
              .foregroundStyle(
                isStarred
                  ? Color.yellow
                  : (isActive ? .black.opacity(0.5) : Color.scTextTertiary)
              )
          }
          .frame(width: 36, height: 28)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.bottom, 4)
      }
    }
    .frame(minWidth: isActive ? 72 : 48)  // Expands when active
    .background(
      ZStack {
        RoundedRectangle(cornerRadius: CornerRadius.small)
          .fill(isActive ? accentColor : Color.scSurfaceElevated)

        // Golden shimmer overlay for starred segments
        if isStarred && !isActive {
          RoundedRectangle(cornerRadius: CornerRadius.small)
            .fill(
              LinearGradient(
                colors: [
                  Color.yellow.opacity(0.08),
                  Color.orange.opacity(0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
        }
      }
    )
    .overlay(
      RoundedRectangle(cornerRadius: CornerRadius.small)
        .stroke(
          isStarred
            ? Color.yellow.opacity(0.5)
            : (isActive ? accentColor.opacity(0.5) : Color.clear),
          lineWidth: isStarred ? 1.5 : 2
        )
    )
    .shadow(
      color: isStarred
        ? Color.yellow.opacity(0.2)
        : (isActive ? accentColor.opacity(0.3) : .clear),
      radius: (isActive || isStarred) ? 4 : 0,
      y: (isActive || isStarred) ? 1 : 0
    )
    .scaleEffect(isActive ? 1.05 : 1.0)  // Scale boost
    .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isActive)
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
    // For very short clips (shot mode), maybe just show seconds if < 60?
    // But keeping MM:SS is consistent.
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
      ActionSegment(startTime: 240, endTime: 300)
    ]

    var body: some View {
      VStack(spacing: Spacing.lg) {
        Text("Current: \(currentIndex ?? -1)")
          .foregroundStyle(.white)

        Text("Starred: \(segments.filter { $0.isStarred }.count)")
          .foregroundStyle(.yellow)

        Text("With Duration")
          .foregroundStyle(.white)
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
          },
          showDuration: true
        )
        .frame(height: 80)

        Text("Without Duration")
          .foregroundStyle(.white)
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
          },
          showDuration: false
        )
        .frame(height: 80)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.scBackground)
    }
  }

  return PreviewWrapper()
}
