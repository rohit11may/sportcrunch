//
//  HoughDebugRenderer.swift
//  SportCrunch
//
//  Renders debug overlay frames with motion points and detected line streaks.
//

import CoreGraphics
import CoreVideo
import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// Renders debug overlay frames showing motion points and detected line streaks.
/// Used for algorithm validation and debugging.
final class HoughDebugRenderer {

    /// Maximum motion points to render (downsample if exceeded for performance).
    private let maxRenderPoints = 5000

    /// Render an annotated debug frame.
    /// - Parameters:
    ///   - pixelBuffer: The source video frame (Y'CbCr or BGRA)
    ///   - motionPoints: Detected motion pixel locations
    ///   - lines: Detected line streaks
    /// - Returns: JPEG data of the annotated frame, or nil on failure
    func render(
        pixelBuffer: CVPixelBuffer,
        motionPoints: [MotionPoint],
        lines: [LineSegment]
    ) -> Data? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        // Create CGImage from pixel buffer
        guard let baseImage = createCGImage(from: pixelBuffer) else {
            return nil
        }

        // Create drawing context
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        // Draw base frame
        context.draw(baseImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Downsample motion points if needed
        let pointsToRender: [MotionPoint]
        if motionPoints.count > maxRenderPoints {
            let step = motionPoints.count / maxRenderPoints
            pointsToRender = stride(from: 0, to: motionPoints.count, by: step)
                .prefix(maxRenderPoints)
                .map { motionPoints[$0] }
        } else {
            pointsToRender = motionPoints
        }

        // Draw motion points as green dots (3px, 50% opacity)
        context.setFillColor(CGColor(red: 0, green: 1, blue: 0, alpha: 0.5))
        for point in pointsToRender {
            let rect = CGRect(
                x: point.x - 1.5,
                y: Double(height) - point.y - 1.5,  // Flip Y for Core Graphics
                width: 3,
                height: 3
            )
            context.fillEllipse(in: rect)
        }

        // Draw line streaks as red lines (2px) with endpoint markers
        context.setStrokeColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1.0))
        context.setLineWidth(2.0)

        for line in lines {
            // Draw line
            context.move(to: CGPoint(x: line.start.x, y: Double(height) - line.start.y))
            context.addLine(to: CGPoint(x: line.end.x, y: Double(height) - line.end.y))
            context.strokePath()

            // Draw endpoint markers (small circles)
            context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1.0))
            let startRect = CGRect(
                x: line.start.x - 3,
                y: Double(height) - line.start.y - 3,
                width: 6,
                height: 6
            )
            let endRect = CGRect(
                x: line.end.x - 3,
                y: Double(height) - line.end.y - 3,
                width: 6,
                height: 6
            )
            context.fillEllipse(in: startRect)
            context.fillEllipse(in: endRect)
        }

        // Create final image
        guard let outputImage = context.makeImage() else {
            return nil
        }

        // Convert to JPEG
        #if canImport(UIKit)
        let uiImage = UIImage(cgImage: outputImage)
        return uiImage.jpegData(compressionQuality: 0.7)
        #else
        // macOS fallback
        let bitmapRep = NSBitmapImageRep(cgImage: outputImage)
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.7])
        #endif
    }

    /// Create CGImage from CVPixelBuffer.
    private func createCGImage(from pixelBuffer: CVPixelBuffer) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: nil)
        return context.createCGImage(ciImage, from: ciImage.extent)
    }
}
