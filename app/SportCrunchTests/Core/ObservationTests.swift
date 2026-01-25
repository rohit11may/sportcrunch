//
//  ObservationTests.swift
//  SportCrunchTests
//
//  Tests for thread-safe Observation actor with signal and event recording.
//

import XCTest
@testable import SportCrunch

final class ObservationTests: XCTestCase {
    func testSignalRecording() async {
        let obs = RunObservation()
        // Add points spaced > 0.5s apart to avoid downsampling
        await obs.addSignalPoint(name: "audio_flux", time: 1.0, value: 0.5)
        await obs.addSignalPoint(name: "audio_flux", time: 1.6, value: 0.8)

        let signals = await obs.getSignals()
        XCTAssertEqual(signals["audio_flux"]?.count, 2)
        XCTAssertEqual(signals["audio_flux"]?[0].value, 0.5)
        XCTAssertEqual(signals["audio_flux"]?[1].value, 0.8)
    }

    func testEventRecording() async {
        let obs = RunObservation()
        await obs.addEvent(name: "peak", time: 1.5, metadata: ["confidence": "0.9"])

        let events = await obs.getEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].name, "peak")
        XCTAssertEqual(events[0].metadata["confidence"], "0.9")
    }

    func testThreadSafety() async {
        let obs = RunObservation()

        // Test concurrent access doesn't cause crashes or data races
        // Use sequential timestamps to ensure all points are recorded
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                let timestamp = Double(i) * 0.6  // Capture timestamp
                group.addTask {
                    await obs.addSignalPoint(name: "test_\(i)", time: timestamp, value: Double(i))
                }
            }
        }

        let signals = await obs.getSignals()
        // Each signal name is unique, so we should have 100 signals with 1 point each
        XCTAssertEqual(signals.count, 100)
    }
}
