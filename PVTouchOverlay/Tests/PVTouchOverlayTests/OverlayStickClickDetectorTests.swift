import Foundation
import Testing
@testable import PVTouchOverlay

@Suite("OverlayStickClickDetector")
struct OverlayStickClickDetectorTests {
    /// A 120pt stick: 60pt radius, so a click allows under 6pt of travel.
    static let radius: CGFloat = 60
    static let centre = CGPoint(x: 60, y: 60)

    private func gesture(moves: [CGPoint] = [], duration: TimeInterval) -> Bool {
        var detector = OverlayStickClickDetector(radius: Self.radius)
        detector.began(at: Self.centre, time: 10)
        for point in moves { detector.moved(to: point) }
        return detector.ended(at: 10 + duration)
    }

    @Test("A quick tap that barely moves is a click")
    func tap() {
        #expect(gesture(duration: 0.1))
        #expect(gesture(moves: [CGPoint(x: 63, y: 62)], duration: 0.2))
    }

    @Test("A drag is not a click, even when it returns to where it started")
    func drag() {
        #expect(!gesture(moves: [CGPoint(x: 90, y: 60)], duration: 0.1))
        #expect(!gesture(moves: [CGPoint(x: 90, y: 60), Self.centre], duration: 0.1))
    }

    @Test("A long hold is not a click")
    func longHold() {
        #expect(!gesture(duration: 0.5))
        #expect(!gesture(duration: OverlayStickClickDetector.maxTapDuration + 0.01))
    }

    @Test("Ending without a begin is not a click, and each gesture starts fresh")
    func reset() {
        var detector = OverlayStickClickDetector(radius: Self.radius)
        let orphanEnd = detector.ended(at: 1)
        #expect(!orphanEnd)
        detector.began(at: Self.centre, time: 1)
        detector.moved(to: CGPoint(x: 100, y: 60))
        let dragEnd = detector.ended(at: 1.1)
        #expect(!dragEnd)
        detector.began(at: Self.centre, time: 2)
        let tapEnd = detector.ended(at: 2.1)
        #expect(tapEnd)
        let repeatedEnd = detector.ended(at: 2.15)
        #expect(!repeatedEnd)
    }
}
