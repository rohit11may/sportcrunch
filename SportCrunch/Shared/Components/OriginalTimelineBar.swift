//
//  OriginalTimelineBar.swift
//  SportCrunch
//
//  A thin static visualization showing what was kept vs removed
//  from the original source video. This is purely informational.
//

import SwiftUI

struct OriginalTimelineBar: View {
    let segments: [ActionSegment]
    let totalDuration: TimeInterval
    let accentColor: Color
    
    private let barHeight: CGFloat = 8
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background (removed time)
                RoundedRectangle(cornerRadius: barHeight / 2)
                    .fill(Color.scSurfaceElevated.opacity(0.5))
                
                // Kept segments
                ForEach(segments) { segment in
                    let startX = (segment.startTime / totalDuration) * geometry.size.width
                    let width = max((segment.duration / totalDuration) * geometry.size.width, 2)
                    
                    RoundedRectangle(cornerRadius: barHeight / 2)
                        .fill(accentColor)
                        .frame(width: width)
                        .offset(x: startX)
                }
            }
        }
        .frame(height: barHeight)
        .clipShape(RoundedRectangle(cornerRadius: barHeight / 2))
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: Spacing.lg) {
        // Sparse segments
        OriginalTimelineBar(
            segments: [
                ActionSegment(startTime: 120, endTime: 180),
                ActionSegment(startTime: 300, endTime: 420),
                ActionSegment(startTime: 600, endTime: 720),
            ],
            totalDuration: 1200,
            accentColor: .scTennis
        )
        
        // Dense segments
        OriginalTimelineBar(
            segments: [
                ActionSegment(startTime: 0, endTime: 60),
                ActionSegment(startTime: 80, endTime: 150),
                ActionSegment(startTime: 160, endTime: 220),
                ActionSegment(startTime: 250, endTime: 320),
                ActionSegment(startTime: 340, endTime: 400),
            ],
            totalDuration: 450,
            accentColor: .scCricket
        )
    }
    .padding(Spacing.lg)
    .background(Color.scBackground)
}

