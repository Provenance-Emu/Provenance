//
//  PauseToggleCoalescerTests.swift
//  PVUI
//

import Testing
@testable import PVUIBase

@Suite("PauseToggleCoalescer")
struct PauseToggleCoalescerTests {

    /// Feeds `times` to a fresh 0.4 s coalescer and returns each verdict.
    /// `shouldAccept` is mutating, and `#expect` evaluates its argument in a
    /// closure that can't mutate captured state, so the calls happen here.
    private func verdicts(_ times: Double...) -> [Bool] {
        var coalescer = PauseToggleCoalescer(window: 0.4)
        return times.map { coalescer.shouldAccept(at: $0) }
    }

    @Test("First toggle is always accepted")
    func firstToggleAccepted() {
        #expect(verdicts(100) == [true])
    }

    @Test("Duplicate signals for one press collapse into one toggle",
          arguments: [0.0, 0.016, 0.15, 0.399])
    func duplicateWithinWindowRejected(gap: Double) {
        #expect(verdicts(100, 100 + gap) == [true, false])
    }

    @Test("A deliberate second press still toggles", arguments: [0.4, 0.75, 30.0])
    func pressAfterWindowAccepted(gap: Double) {
        #expect(verdicts(100, 100 + gap) == [true, true])
    }

    @Test("Rejected duplicates do not extend the window")
    func rejectedDuplicateDoesNotSlideWindow() {
        #expect(verdicts(100, 100.3, 100.45) == [true, false, true])
    }

    @Test("A clock that moves backwards never wedges the toggle")
    func backwardsClockAccepted() {
        #expect(verdicts(100, 50) == [true, true])
    }
}
