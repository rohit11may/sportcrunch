//
//  DebugReportsListView.swift
//  SportCrunch
//
//  View for browsing, viewing, and sharing debug reports.
//

import SwiftUI

struct DebugReportsListView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var reports: [DebugReportFile] = []
  @State private var selectedReport: DebugReportFile?
  @State private var showingShareSheet = false
  @State private var shareURL: URL?
  @State private var isLoading = true

  var body: some View {
    NavigationStack {
      ZStack {
        Color.scBackground.ignoresSafeArea()

        if isLoading {
          ProgressView()
            .tint(Color.scGradientStart)
        } else if reports.isEmpty {
          emptyState
        } else {
          reportsList
        }
      }
      .navigationTitle("Debug Reports")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Close") {
            dismiss()
          }
        }

        ToolbarItem(placement: .topBarTrailing) {
          if !reports.isEmpty {
            Button(role: .destructive) {
              deleteAllReports()
            } label: {
              Image(systemName: "trash")
            }
          }
        }
      }
      .sheet(item: $selectedReport) { report in
        DebugReportDetailView(reportFile: report)
      }
      .sheet(isPresented: $showingShareSheet) {
        if let url = shareURL {
          ShareSheet(items: [url])
        }
      }
      .onAppear {
        loadReports()
      }
    }
  }

  // MARK: - Empty State

  private var emptyState: some View {
    VStack(spacing: Spacing.md) {
      Image(systemName: "doc.text.magnifyingglass")
        .font(.system(size: 48))
        .foregroundStyle(Color.scTextTertiary)

      Text("No Debug Reports")
        .font(AppFont.headline())
        .foregroundStyle(Color.scTextPrimary)

      Text("Debug reports are generated automatically\nwhen processing videos.")
        .font(AppFont.body())
        .foregroundStyle(Color.scTextSecondary)
        .multilineTextAlignment(.center)
    }
    .padding()
  }

  // MARK: - Reports List

  private var reportsList: some View {
    List {
      ForEach(reports) { report in
        reportRow(report)
          .listRowBackground(Color.scSurface)
          .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
              deleteReport(report)
            } label: {
              Label("Delete", systemImage: "trash")
            }

            Button {
              shareURL = report.url
              showingShareSheet = true
            } label: {
              Label("Share", systemImage: "square.and.arrow.up")
            }
            .tint(Color.scGradientStart)
          }
      }
    }
    .listStyle(.insetGrouped)
    .scrollContentBackground(.hidden)
  }

  private func reportRow(_ report: DebugReportFile) -> some View {
    Button {
      selectedReport = report
    } label: {
      HStack(spacing: Spacing.md) {
        // Platform indicator
        VStack {
          Image(systemName: report.isSimulator ? "desktopcomputer" : "iphone")
            .font(.system(size: 20))
            .foregroundStyle(report.isSimulator ? Color.blue : Color.green)
        }
        .frame(width: 32)

        VStack(alignment: .leading, spacing: 4) {
          Text(report.displayName)
            .font(AppFont.bodyBold())
            .foregroundStyle(Color.scTextPrimary)

          Text(report.formattedDate)
            .font(AppFont.caption())
            .foregroundStyle(Color.scTextSecondary)
        }

        Spacer()

        VStack(alignment: .trailing, spacing: 4) {
          Text(report.formattedSize)
            .font(AppFont.caption())
            .foregroundStyle(Color.scTextSecondary)

          Text(report.isSimulator ? "Simulator" : "Device")
            .font(AppFont.caption())
            .foregroundStyle(report.isSimulator ? Color.blue : Color.green)
        }

        Image(systemName: "chevron.right")
          .font(.system(size: 14))
          .foregroundStyle(Color.scTextTertiary)
      }
      .padding(.vertical, Spacing.xs)
    }
    .buttonStyle(.plain)
  }

  // MARK: - Actions

  private func loadReports() {
    isLoading = true

    DispatchQueue.global(qos: .userInitiated).async {
      let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        .first!
      let reportsDir = documentsURL.appendingPathComponent("DebugReports", isDirectory: true)

      var loadedReports: [DebugReportFile] = []

      if let files = try? FileManager.default.contentsOfDirectory(atPath: reportsDir.path) {
        for file in files where file.hasSuffix(".json") {
          let fileURL = reportsDir.appendingPathComponent(file)

          if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
            let modDate = attrs[.modificationDate] as? Date,
            let size = attrs[.size] as? Int64
          {

            let isSimulator = file.contains("simulator")

            loadedReports.append(
              DebugReportFile(
                id: file,
                fileName: file,
                url: fileURL,
                date: modDate,
                sizeBytes: size,
                isSimulator: isSimulator
              ))
          }
        }
      }

      // Sort by date, newest first
      loadedReports.sort { $0.date > $1.date }

      DispatchQueue.main.async {
        self.reports = loadedReports
        self.isLoading = false
      }
    }
  }

  private func deleteReport(_ report: DebugReportFile) {
    try? FileManager.default.removeItem(at: report.url)
    reports.removeAll { $0.id == report.id }
  }

  private func deleteAllReports() {
    for report in reports {
      try? FileManager.default.removeItem(at: report.url)
    }
    reports.removeAll()
  }
}

// MARK: - Debug Report File

struct DebugReportFile: Identifiable {
  let id: String
  let fileName: String
  let url: URL
  let date: Date
  let sizeBytes: Int64
  let isSimulator: Bool

  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
  }()

  var displayName: String {
    // Extract timestamp from filename: debug_report_2025-01-15_14-30-45_simulator.json
    if let range = fileName.range(of: "debug_report_") {
      let afterPrefix = String(fileName[range.upperBound...])
      if let endRange = afterPrefix.range(of: "_") {
        return String(afterPrefix[..<endRange.lowerBound])
      }
    }
    return fileName
  }

  var formattedDate: String {
    Self.dateFormatter.string(from: date)
  }

  var formattedSize: String {
    let kb = Double(sizeBytes) / 1024
    if kb < 1024 {
      return String(format: "%.1f KB", kb)
    } else {
      return String(format: "%.1f MB", kb / 1024)
    }
  }
}

// MARK: - Debug Report Detail View

struct DebugReportDetailView: View {
  let reportFile: DebugReportFile
  @Environment(\.dismiss) private var dismiss
  @State private var report: DebugReport?
  @State private var rawJSON: String = ""
  @State private var isLoading = true
  @State private var showRawJSON = false
  @State private var showingShareSheet = false

  var body: some View {
    NavigationStack {
      ZStack {
        Color.scBackground.ignoresSafeArea()

        if isLoading {
          ProgressView()
            .tint(Color.scGradientStart)
        } else if let report = report {
          reportContent(report)
        } else {
          Text("Failed to load report")
            .foregroundStyle(Color.scError)
        }
      }
      .navigationTitle("Report Details")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Close") {
            dismiss()
          }
        }

        ToolbarItem(placement: .topBarTrailing) {
          Menu {
            Button {
              showingShareSheet = true
            } label: {
              Label("Share Report", systemImage: "square.and.arrow.up")
            }

            Button {
              showRawJSON.toggle()
            } label: {
              Label(showRawJSON ? "Show Summary" : "Show Raw JSON", systemImage: "doc.text")
            }
          } label: {
            Image(systemName: "ellipsis.circle")
          }
        }
      }
      .sheet(isPresented: $showingShareSheet) {
        ShareSheet(items: [reportFile.url])
      }
      .onAppear {
        loadReport()
      }
    }
  }

  private func reportContent(_ report: DebugReport) -> some View {
    ScrollView {
      if showRawJSON {
        rawJSONView
      } else {
        VStack(alignment: .leading, spacing: Spacing.lg) {
          platformSection(report)
          inputFileSection(report)
          configurationSection(report)

          if let audio = report.audioAnalysis {
            audioAnalysisSection(audio)
          }

          if let results = report.results {
            resultsSection(results)
          }

          if let timing = report.timing {
            timingSection(timing)
          }
        }
        .padding()
      }
    }
  }

  private var rawJSONView: some View {
    ScrollView(.horizontal, showsIndicators: true) {
      Text(rawJSON)
        .font(.system(.caption, design: .monospaced))
        .foregroundStyle(Color.scTextSecondary)
        .padding()
    }
  }

  // MARK: - Sections

  private func platformSection(_ report: DebugReport) -> some View {
    sectionCard(title: "Platform", icon: "cpu") {
      infoRow("Type", report.platform.isSimulator ? "Simulator (x86_64)" : "Device (ARM64)")
      infoRow("Model", report.platform.deviceModel)
      infoRow("OS", "iOS \(report.platform.osVersion)")
      infoRow("CPUs", "\(report.platform.processorCount)")
      infoRow("RAM", "\(report.platform.physicalMemory / 1024 / 1024 / 1024) GB")
      infoRow("Thermal", report.platform.thermalState.capitalized)
      infoRow("Low Power", report.platform.lowPowerMode ? "Yes" : "No")
    }
  }

  private func inputFileSection(_ report: DebugReport) -> some View {
    sectionCard(title: "Input File", icon: "doc.fill") {
      infoRow("Name", report.inputFile.fileName)
      infoRow("Size", String(format: "%.2f MB", report.inputFile.fileSizeMB))

    }
  }

  private func configurationSection(_ report: DebugReport) -> some View {
    sectionCard(title: "Configuration", icon: "gearshape.fill") {
      infoRow("Sport", report.configuration.sport)
      if let mode = report.configuration.sportMode {
        infoRow("Mode", mode)
      }
      infoRow("Sample Rate", "\(Int(report.configuration.sampleRate)) Hz")
      infoRow(
        "Bandpass",
        "\(Int(report.configuration.bandpassLow))-\(Int(report.configuration.bandpassHigh)) Hz")
      infoRow("Threshold λ", String(format: "%.1f", report.configuration.onsetThresholdLambda))
      infoRow("Min Peak Distance", String(format: "%.2fs", report.configuration.peakMinDistanceSec))
      infoRow("Cluster Max Gap", String(format: "%.1fs", report.configuration.clusterMaxGapSec))
      infoRow("Cluster Min Hits", "\(report.configuration.clusterMinHits)")
    }
  }

  private func audioAnalysisSection(_ audio: AudioAnalysisDetails) -> some View {
    sectionCard(title: "Audio Analysis", icon: "waveform") {
      infoRow("Samples", "\(audio.extractedSampleCount)")
      infoRow("Duration", String(format: "%.2fs", audio.extractedDuration))
      infoRow("Onset Frames", "\(audio.onsetFrameCount)")

      Divider().background(Color.scTextTertiary.opacity(0.3))

      Text("Raw Audio Fingerprint")
        .font(AppFont.captionBold())
        .foregroundStyle(Color.scTextSecondary)

      fingerprintView(audio.rawAudioFingerprint)

      Divider().background(Color.scTextTertiary.opacity(0.3))

      Text("Filtered Audio Fingerprint")
        .font(AppFont.captionBold())
        .foregroundStyle(Color.scTextSecondary)

      fingerprintView(audio.filteredAudioFingerprint)

      Divider().background(Color.scTextTertiary.opacity(0.3))

      Text("Onset Strength Stats")
        .font(AppFont.captionBold())
        .foregroundStyle(Color.scTextSecondary)

      statsView(audio.onsetStrengthStats)

      Divider().background(Color.scTextTertiary.opacity(0.3))

      infoRow("Peaks Detected", "\(audio.detectedPeakCount)")
      infoRow("Clusters", "\(audio.clusterCount)")
      infoRow("Candidate Intervals", "\(audio.candidateIntervals.count)")
    }
  }

  private func resultsSection(_ results: ProcessingResults) -> some View {
    sectionCard(title: "Results", icon: "checkmark.circle.fill") {
      infoRow("Success", results.success ? "✅ Yes" : "❌ No")
      infoRow("Input Duration", String(format: "%.2fs", results.inputDuration))
      infoRow("Output Duration", String(format: "%.2fs", results.outputDuration))
      infoRow("Reduction", String(format: "%.1f%%", results.reductionPercent))
      infoRow("Segments", "\(results.segmentCount)")
    }
  }

  private func timingSection(_ timing: TimingInfo) -> some View {
    sectionCard(title: "Timing", icon: "clock.fill") {
      infoRow("Total", String(format: "%.2fs", timing.totalProcessingTime))
      infoRow("Audio Analysis", String(format: "%.2fs", timing.audioExtractionTime))
      infoRow("Visual Validation", String(format: "%.2fs", timing.visualValidationTime))
      infoRow("Export", String(format: "%.2fs", timing.exportTime))
    }
  }

  // MARK: - Helper Views

  private func sectionCard<Content: View>(
    title: String,
    icon: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: Spacing.sm) {
      HStack(spacing: Spacing.sm) {
        Image(systemName: icon)
          .foregroundStyle(Color.scGradientStart)
        Text(title)
          .font(AppFont.headline())
          .foregroundStyle(Color.scTextPrimary)
      }

      VStack(alignment: .leading, spacing: Spacing.xs) {
        content()
      }
      .padding()
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.scSurface)
      .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }
  }

  private func infoRow(_ label: String, _ value: String) -> some View {
    HStack {
      Text(label)
        .font(AppFont.body())
        .foregroundStyle(Color.scTextSecondary)
      Spacer()
      Text(value)
        .font(AppFont.body())
        .foregroundStyle(Color.scTextPrimary)
        .textSelection(.enabled)
    }
  }

  private func fingerprintView(_ fp: AudioFingerprint) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack {
        Text("Count: \(fp.count)")
        Spacer()
        Text("Sum: \(String(format: "%.4f", fp.sum))")
      }
      HStack {
        Text("Min: \(String(format: "%.6f", fp.min))")
        Spacer()
        Text("Max: \(String(format: "%.6f", fp.max))")
      }
      HStack {
        Text("Mean: \(String(format: "%.6f", fp.mean))")
        Spacer()
        Text("StdDev: \(String(format: "%.6f", fp.stdDev))")
      }
    }
    .font(.system(.caption, design: .monospaced))
    .foregroundStyle(Color.scTextSecondary)
  }

  private func statsView(_ stats: StatisticalSummary) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack {
        Text("Min: \(String(format: "%.2f", stats.min))")
        Spacer()
        Text("Max: \(String(format: "%.2f", stats.max))")
      }
      HStack {
        Text("Mean: \(String(format: "%.4f", stats.mean))")
        Spacer()
        Text("Median: \(String(format: "%.4f", stats.median))")
      }
      HStack {
        Text("P95: \(String(format: "%.2f", stats.p95))")
        Spacer()
        Text("P99: \(String(format: "%.2f", stats.p99))")
      }
    }
    .font(.system(.caption, design: .monospaced))
    .foregroundStyle(Color.scTextSecondary)
  }

  // MARK: - Load Report

  private func loadReport() {
    isLoading = true

    DispatchQueue.global(qos: .userInitiated).async {
      do {
        let data = try Data(contentsOf: reportFile.url)
        rawJSON = String(data: data, encoding: .utf8) ?? "Could not decode JSON"

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let loadedReport = try decoder.decode(DebugReport.self, from: data)

        DispatchQueue.main.async {
          self.report = loadedReport
          self.isLoading = false
        }
      } catch {
        print("Failed to load report: \(error)")
        DispatchQueue.main.async {
          self.isLoading = false
        }
      }
    }
  }
}

// MARK: - Preview

#Preview {
  DebugReportsListView()
}
