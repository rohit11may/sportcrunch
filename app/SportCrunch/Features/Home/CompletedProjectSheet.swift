//
//  CompletedProjectSheet.swift
//  SportCrunch
//
//  Sheet view for viewing and playing a completed highlight project.
//

import AVKit
import SwiftUI

struct CompletedProjectSheet: View {
  @Bindable var viewModel: CompletedProjectViewModel
  @Environment(\.dismiss) private var dismiss
  @State private var isPlaying = false
  @State private var currentTime: TimeInterval = 0
  @State private var currentSegmentIndex: Int?
  @State private var showShareSheet = false
  @State private var isSavedToCameraRoll = false
  @State private var showExportSheet = false

  var body: some View {
    NavigationStack {
      ZStack {
        Color.scBackground.ignoresSafeArea()

        VStack(spacing: 0) {
          // Video player area
          videoPlayerArea
            .accessibilityIdentifier(AccessibilityID.Project.videoPlayer)

          // Original video summary (static visualization)
          originalVideoSummarySection

          // Segment navigator
          segmentNavigatorSection
            .accessibilityIdentifier(AccessibilityID.Project.segmentNavigator)

          Spacer(minLength: 0)
        }
        .accessibilityIdentifier(AccessibilityID.Project.sheet)
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) {
          VStack(spacing: 2) {
            // Title with highlight duration
            HStack(spacing: Spacing.xs) {
              Text(viewModel.project.title ?? "Highlight")
                .font(AppFont.subheadline())
                .foregroundStyle(Color.scTextPrimary)

              Text("•")
                .font(AppFont.caption())
                .foregroundStyle(Color.scTextTertiary)

              Text(viewModel.project.formattedHighlightDuration ?? "—")
                .font(AppFont.subheadline())
                .foregroundStyle(viewModel.project.sport.accentColor)
            }

            HStack(spacing: Spacing.xxs) {
              Text(viewModel.project.sport.emoji)
                .font(.system(size: 10))
              Text(viewModel.project.sport.displayName)
                .font(AppFont.caption())
                .foregroundStyle(Color.scTextSecondary)
            }
          }
          .frame(maxWidth: .infinity)
        }

        ToolbarItem(placement: .navigationBarLeading) {
          // Export button
          Button {
            showExportSheet = true
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
          } label: {
            Image(systemName: "square.and.arrow.up")
              .font(.system(size: 14, weight: .medium))
              .foregroundStyle(.black)
              .frame(width: 32, height: 32)
              .background(AppGradient.primary)
              .clipShape(Circle())
          }
          .accessibilityLabel("Export")
          .accessibilityIdentifier(AccessibilityID.Project.exportButton)
        }

        ToolbarItem(placement: .navigationBarTrailing) {
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark")
              .font(.system(size: 14, weight: .semibold))
              .foregroundStyle(Color.scTextSecondary)
              .frame(width: 32, height: 32)
              .background(Color.scSurface)
              .clipShape(Circle())
          }
        }
      }
      .toolbarBackground(Color.scBackground, for: .navigationBar)
    }
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
    .sheet(isPresented: $showShareSheet) {
      if let url = viewModel.project.highlightVideoURL {
        ShareSheet(items: [url])
      }
    }
    .sheet(isPresented: $showExportSheet) {
      CompletedProjectExportSheet(
        project: viewModel.project,
        starredSegments: viewModel.starredSegments
      )
      .presentationDetents([.medium])
      .presentationDragIndicator(.visible)
    }
    .onChange(of: currentTime) { _, newTime in
      if let newIndex = viewModel.segmentIndex(for: newTime), newIndex != currentSegmentIndex {
        currentSegmentIndex = newIndex
      }
    }
  }

  // MARK: - Video Player Area

  private var videoPlayerArea: some View {
    GeometryReader { geometry in
      ZStack {
        // Dark background to avoid any white showing through
        Color.black

        if let url = viewModel.project.highlightVideoURL,
          FileManager.default.fileExists(atPath: url.path)
        {
          ControllableVideoPlayer(
            url: url,
            currentTime: $currentTime,
            isPlaying: $isPlaying
          )
          .onAppear {
            // Auto-play when view appears
            isPlaying = true
          }
        } else {
          // Placeholder gradient background
          Rectangle()
            .fill(
              LinearGradient(
                colors: [
                  viewModel.project.sport.accentColor.opacity(0.3),
                  viewModel.project.sport.accentColor.opacity(0.1),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
            .overlay(
              VStack(spacing: Spacing.sm) {
                Image(systemName: "exclamationmark.triangle")
                  .font(.system(size: 32))
                  .foregroundStyle(Color.scTextTertiary)
                Text("Video unavailable")
                  .font(AppFont.caption())
                  .foregroundStyle(Color.scTextSecondary)
              }
            )
        }
      }
    }
    .frame(height: UIScreen.main.bounds.height * 0.55)
  }

  // MARK: - Original Video Summary Section

  private var originalVideoSummarySection: some View {
    VStack(alignment: .leading, spacing: Spacing.xs) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text("Original Video Summary")
            .font(AppFont.caption())
            .foregroundStyle(Color.scTextSecondary)

          Text(
            "\(viewModel.project.formattedOriginalDuration) total • \(viewModel.project.segments.count) segments kept"
          )
          .font(.system(size: 11))
          .foregroundStyle(Color.scTextTertiary)
        }

        Spacer()

        // Legend
        HStack(spacing: Spacing.sm) {
          legendItem(color: viewModel.project.sport.accentColor, label: "Kept")
          legendItem(color: .scSurfaceElevated, label: "Removed")
        }
      }

      // Static original timeline visualization
      OriginalTimelineBar(
        segments: viewModel.project.segments,
        totalDuration: viewModel.project.originalDuration,
        accentColor: viewModel.project.sport.accentColor
      )
    }
    .padding(.horizontal, Spacing.lg)
    .padding(.vertical, Spacing.md)
  }

  private func legendItem(color: Color, label: String) -> some View {
    HStack(spacing: Spacing.xxs) {
      RoundedRectangle(cornerRadius: 2)
        .fill(color)
        .frame(width: 10, height: 10)

      Text(label)
        .font(.system(size: 11))
        .foregroundStyle(Color.scTextTertiary)
    }
  }

  // MARK: - Segment Navigator Section

  private var segmentNavigatorSection: some View {
    VStack(alignment: .leading, spacing: Spacing.xs) {
      HStack {
        HStack(spacing: Spacing.xs) {
          Text(
            viewModel.showOnlyStarred
              ? "\(viewModel.starredCount) Starred" : "\(viewModel.project.segments.count) Segments"
          )
          .font(AppFont.caption())
          .foregroundStyle(Color.scTextSecondary)

          if viewModel.hasStarredSegments && !viewModel.showOnlyStarred {
            Text("•")
              .foregroundStyle(Color.scTextTertiary)

            HStack(spacing: 2) {
              Image(systemName: "star.fill")
                .font(.system(size: 10))
                .foregroundStyle(Color.yellow)
              Text("\(viewModel.starredCount) starred")
                .font(AppFont.caption())
                .foregroundStyle(Color.yellow)
            }
          }
        }

        Spacer()

        // Filter toggle button (only show if there are starred segments)
        if viewModel.hasStarredSegments {
          Button {
            withAnimation(.spring(response: 0.3)) {
              viewModel.showOnlyStarred.toggle()
            }
          } label: {
            HStack(spacing: 4) {
              Image(systemName: viewModel.showOnlyStarred ? "star.fill" : "star")
                .font(.system(size: 12, weight: .medium))
              Text(viewModel.showOnlyStarred ? "All" : "Starred")
                .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(viewModel.showOnlyStarred ? Color.yellow : Color.scTextSecondary)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xxs)
            .background(
              Capsule()
                .fill(
                  viewModel.showOnlyStarred ? Color.yellow.opacity(0.15) : Color.scSurfaceElevated)
            )
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier(AccessibilityID.Project.filterToggle)
        } else {
          Text("Tap ★ to star segments")
            .font(.system(size: 11))
            .foregroundStyle(Color.scTextTertiary)
        }
      }
      .padding(.horizontal, Spacing.lg)

      // Segment navigator - shows filtered or all segments
      SegmentNavigator(
        segments: viewModel.displayedSegments,
        accentColor: viewModel.project.sport.accentColor,
        currentSegmentIndex: Binding(
          get: {
            // Map the current segment index to the displayed segments
            guard let index = currentSegmentIndex else { return nil }
            let allSegs = viewModel.allSegments
            guard index < allSegs.count else { return nil }
            let segmentId = allSegs[index].id
            return viewModel.displayedSegments.firstIndex(where: { $0.id == segmentId })
          },
          set: { newIndex in
            // Map displayed index back to all segments index
            guard let idx = newIndex, idx < viewModel.displayedSegments.count else {
              currentSegmentIndex = nil
              return
            }
            let segmentId = viewModel.displayedSegments[idx].id
            currentSegmentIndex = viewModel.allSegments.firstIndex(where: { $0.id == segmentId })
          }
        ),
        onSegmentTap: { _, segment in
          // Jump to the segment using its actual position in all segments
          if let allIndex = viewModel.allSegments.firstIndex(where: { $0.id == segment.id }),
            let seekTime = viewModel.seekTime(for: allIndex)
          {
            currentTime = seekTime
          }
        },
        onStarToggle: { _, segment in
          withAnimation(.spring(response: 0.3)) {
            viewModel.toggleStarred(segment: segment)
          }
        },
        showDuration: shouldShowSegmentDuration,
        displayIndices: viewModel.displayedSegmentIndices
      )
    }
    .padding(.vertical, Spacing.sm)
  }

  private var shouldShowSegmentDuration: Bool {
    // Hide duration for Tennis Shot Mode (Individual)
    if let mode = viewModel.project.sportMode, case .tennis(.individual) = mode {
      return false
    }
    return true
  }

}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
  let items: [Any]

  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: items, applicationActivities: nil)
  }

  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Completed Project Export Sheet

struct CompletedProjectExportSheet: View {
  let project: Project
  let starredSegments: Set<UUID>

  @Environment(\.dismiss) private var dismiss
  @State private var onlyStarred = false
  @State private var isExporting = false
  @State private var showSavedConfirmation = false
  @State private var showShareSheet = false
  @State private var exportedVideoURL: URL?
  @State private var exportError: String?
  @State private var showError = false

  private var starredCount: Int {
    starredSegments.count
  }

  private var hasStarredSegments: Bool {
    !starredSegments.isEmpty
  }

  private var exportDescription: String {
    if onlyStarred && hasStarredSegments {
      return "Export \(starredCount) starred segment\(starredCount == 1 ? "" : "s")"
    } else {
      return "Export all \(project.segments.count) segments"
    }
  }

  /// Calculate segment offsets within the highlight video
  /// Since the highlight is a concatenation of segments, we need to map
  /// each segment to its position within the highlight
  private var segmentOffsets:
    [(segment: ActionSegment, startOffset: TimeInterval, endOffset: TimeInterval)]
  {
    var offset: TimeInterval = 0
    return project.segments.map { segment in
      let start = offset
      offset += segment.duration
      return (segment: segment, startOffset: start, endOffset: offset)
    }
  }

  /// Get intervals for starred segments only (positions within the highlight video)
  private var starredIntervals: [(start: TimeInterval, end: TimeInterval)] {
    segmentOffsets
      .filter { starredSegments.contains($0.segment.id) }
      .map { (start: $0.startOffset, end: $0.endOffset) }
  }

  /// Calculate total duration of starred segments
  private var starredDuration: TimeInterval {
    starredIntervals.reduce(0) { $0 + ($1.end - $1.start) }
  }

  /// Formatted duration for starred segments
  private var formattedStarredDuration: String {
    let totalSeconds = Int(starredDuration)
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60
    if minutes > 0 {
      return "\(minutes)m \(seconds)s"
    } else {
      return "\(seconds)s"
    }
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: Spacing.xl) {
        // Preview info card
        exportInfoCard

        // Only starred toggle
        if hasStarredSegments {
          onlyStarredToggle
        }

        Spacer()

        // Export options
        VStack(spacing: Spacing.sm) {
          if isExporting {
            exportingIndicator
          } else if showSavedConfirmation {
            savedConfirmationView
          } else {
            // Save to Camera Roll button
            Button {
              performSaveToCameraRoll()
            } label: {
              HStack(spacing: Spacing.sm) {
                Image(systemName: "arrow.down.to.line")
                  .font(.system(size: 18, weight: .semibold))
                Text("Save to Camera Roll")
                  .font(AppFont.bodyBold())
              }
              .foregroundStyle(.black)
              .frame(maxWidth: .infinity)
              .frame(height: 56)
              .background(AppGradient.primary)
              .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            }
            .accessibilityIdentifier(AccessibilityID.Export.saveCameraRollButton)

            // Share button
            Button {
              performShare()
            } label: {
              HStack(spacing: Spacing.sm) {
                Image(systemName: "square.and.arrow.up")
                  .font(.system(size: 18, weight: .semibold))
                Text("Share Highlight")
                  .font(AppFont.bodyBold())
              }
              .foregroundStyle(Color.scTextPrimary)
              .frame(maxWidth: .infinity)
              .frame(height: 56)
              .background(Color.scSurfaceElevated)
              .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            }
            .accessibilityIdentifier(AccessibilityID.Export.shareButton)
          }
        }
      }
      .padding(.horizontal, Spacing.lg)
      .padding(.vertical, Spacing.md)
      .background(Color.scBackground)
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier(AccessibilityID.Export.sheet)
      .navigationTitle("Export")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark")
              .font(.system(size: 14, weight: .semibold))
              .foregroundStyle(Color.scTextSecondary)
              .frame(width: 32, height: 32)
              .background(Color.scSurface)
              .clipShape(Circle())
          }
        }
      }
      .toolbarBackground(Color.scBackground, for: .navigationBar)
    }
    .sheet(isPresented: $showShareSheet) {
      if let url = exportedVideoURL ?? project.highlightVideoURL {
        ShareSheet(items: [url])
      }
    }
    .alert("Export Error", isPresented: $showError) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(exportError ?? "An unknown error occurred.")
    }
  }

  // MARK: - Export Info Card

  private var exportInfoCard: some View {
    HStack(spacing: Spacing.md) {
      // Sport icon
      ZStack {
        Circle()
          .fill(project.sport.accentColor.opacity(0.2))
          .frame(width: 50, height: 50)

        Text(project.sport.emoji)
          .font(.system(size: 24))
      }

      // Info
      VStack(alignment: .leading, spacing: 4) {
        Text(project.title ?? "Highlight")
          .font(AppFont.headline())
          .foregroundStyle(Color.scTextPrimary)

        Text(exportDescription)
          .font(AppFont.caption())
          .foregroundStyle(Color.scTextSecondary)
      }

      Spacer()

      // Duration badge - shows starred duration when onlyStarred is enabled
      VStack(alignment: .trailing, spacing: 2) {
        Text(
          onlyStarred && hasStarredSegments
            ? formattedStarredDuration : (project.formattedHighlightDuration ?? "—")
        )
        .font(AppFont.captionBold())
        .foregroundStyle(onlyStarred && hasStarredSegments ? Color.yellow : Color.scTextPrimary)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs)
        .background(Color.scSurfaceElevated)
        .clipShape(Capsule())
        .animation(.spring(response: 0.3), value: onlyStarred)
      }
    }
    .padding(Spacing.md)
    .background(Color.scSurface)
    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
  }

  // MARK: - Only Starred Toggle

  private var onlyStarredToggle: some View {
    HStack(spacing: Spacing.md) {
      // Star icon with glow
      ZStack {
        Image(systemName: "star.fill")
          .font(.system(size: 20))
          .foregroundStyle(Color.yellow)
          .blur(radius: onlyStarred ? 2 : 0)
          .opacity(onlyStarred ? 0.6 : 0)

        Image(systemName: "star.fill")
          .font(.system(size: 20))
          .foregroundStyle(Color.yellow)
      }

      // Label
      VStack(alignment: .leading, spacing: 2) {
        Text("Only Starred")
          .font(AppFont.bodyBold())
          .foregroundStyle(Color.scTextPrimary)

        Text("\(starredCount) segment\(starredCount == 1 ? "" : "s") selected")
          .font(AppFont.caption())
          .foregroundStyle(Color.scTextSecondary)
      }

      Spacer()

      // Toggle
      Toggle("", isOn: $onlyStarred)
        .tint(Color.yellow)
        .labelsHidden()
    }
    .padding(Spacing.md)
    .background(
      RoundedRectangle(cornerRadius: CornerRadius.medium)
        .fill(Color.scSurface)
        .overlay(
          RoundedRectangle(cornerRadius: CornerRadius.medium)
            .stroke(onlyStarred ? Color.yellow.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    )
    .animation(.spring(response: 0.3), value: onlyStarred)
    .accessibilityIdentifier(AccessibilityID.Export.onlyStarredToggle)
  }

  // MARK: - Exporting Indicator

  private var exportingIndicator: some View {
    HStack(spacing: Spacing.md) {
      ProgressView()
        .progressViewStyle(CircularProgressViewStyle(tint: .scGradientStart))

      Text(onlyStarred ? "Stitching starred segments..." : "Saving to Camera Roll...")
        .font(AppFont.body())
        .foregroundStyle(Color.scTextSecondary)
    }
    .frame(maxWidth: .infinity)
    .frame(height: 56)
    .background(Color.scSurface)
    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
  }

  // MARK: - Saved Confirmation View

  private var savedConfirmationView: some View {
    VStack(spacing: Spacing.sm) {
      HStack(spacing: Spacing.xs) {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 20, weight: .semibold))
          .foregroundStyle(Color.scSuccess)
        Text("Saved to Camera Roll")
          .font(AppFont.bodyBold())
          .foregroundStyle(Color.scTextPrimary)
      }
      .frame(maxWidth: .infinity)
      .frame(height: 56)
      .background(Color.scSurfaceElevated.opacity(0.6))
      .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))

      // Done button
      Button {
        dismiss()
      } label: {
        Text("Done")
          .font(AppFont.bodyBold())
          .foregroundStyle(Color.scTextPrimary)
          .frame(maxWidth: .infinity)
          .frame(height: 56)
          .background(Color.scSurfaceElevated)
          .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
      }
      .accessibilityIdentifier(AccessibilityID.Export.doneButton)
    }
  }

  // MARK: - Actions

  private func performSaveToCameraRoll() {
    isExporting = true

    Task {
      do {
        let urlToSave: URL

        if onlyStarred && hasStarredSegments {
          // Export only starred segments
          urlToSave = try await exportStarredSegments()
        } else {
          // Use the full highlight video
          guard let url = project.highlightVideoURL else {
            throw ExportError.noHighlightVideo
          }
          urlToSave = url
        }

        // Save to camera roll
        await MainActor.run {
          UISaveVideoAtPathToSavedPhotosAlbum(urlToSave.path, nil, nil, nil)

          withAnimation(.spring(response: 0.5)) {
            isExporting = false
            showSavedConfirmation = true
          }
        }
      } catch {
        await MainActor.run {
          exportError = error.localizedDescription
          isExporting = false
          showError = true
        }
      }
    }
  }

  private func performShare() {
    if onlyStarred && hasStarredSegments {
      // Export starred segments first, then share
      isExporting = true

      Task {
        do {
          let exportedURL = try await exportStarredSegments()

          await MainActor.run {
            exportedVideoURL = exportedURL
            isExporting = false
            showShareSheet = true
          }
        } catch {
          await MainActor.run {
            exportError = error.localizedDescription
            isExporting = false
            showError = true
          }
        }
      }
    } else {
      // Share the full highlight video directly
      exportedVideoURL = project.highlightVideoURL
      showShareSheet = true
    }
  }

  /// Export only the starred segments from the highlight video
  private func exportStarredSegments() async throws -> URL {
    guard let highlightURL = project.highlightVideoURL else {
      throw ExportError.noHighlightVideo
    }

    guard FileManager.default.fileExists(atPath: highlightURL.path) else {
      throw ExportError.highlightNotFound
    }

    guard !starredIntervals.isEmpty else {
      throw ExportError.noStarredSegments
    }

    // Create output URL in temp directory
    let outputURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("SportCrunch_Starred_\(UUID().uuidString)")
      .appendingPathExtension("mp4")

    // Use VideoExporter to stitch only the starred segments
    let exporter = VideoExporter()
    let _ = try await exporter.export(
      sourceURL: highlightURL,
      intervals: starredIntervals,
      outputURL: outputURL,
      preset: .fast
    )

    return outputURL
  }
}

// MARK: - Export Error

enum ExportError: Error, LocalizedError {
  case noHighlightVideo
  case highlightNotFound
  case noStarredSegments

  var errorDescription: String? {
    switch self {
    case .noHighlightVideo:
      return "No highlight video available."
    case .highlightNotFound:
      return "The highlight video file was not found."
    case .noStarredSegments:
      return "No segments are starred for export."
    }
  }
}

// MARK: - Preview

#Preview {
  let viewModel = CompletedProjectViewModel(
    project: .sampleCompleted,
    storageService: MockProjectStorageService(withSampleData: true)
  )
  CompletedProjectSheet(viewModel: viewModel)
}

#Preview("Export Sheet") {
  CompletedProjectExportSheet(
    project: .sampleCompleted,
    starredSegments: Set([UUID(), UUID()])
  )
}
