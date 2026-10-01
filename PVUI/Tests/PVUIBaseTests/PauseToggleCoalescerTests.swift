//
//  PauseToggleCoalescerTests.swift
//  PVUI
//

import Testing
@testable import PVUIBase

@Suite("PauseToggleCoalescer")
struct PauseToggleCoalescerTests {

    @Test("First toggle is always accepted")
    func firstToggleAccepted() {
        var coalescer = PauseToggleCoalescer(window: 0.4)
        #expect(coalescer.shouldAccept(at: 100))
    }

    @Test("Duplicate signals for one press collapse into one toggle",
          arguments: [0.0, 0.016, 0.15, 0.399])
    func duplicateWithinWindowRejected(gap: Double) {
        var coalescer = PauseToggleCoalescer(window: 0.4)
        #expect(coalescer.shouldAccept(at: 100))
        #expect(!coalescer.shouldAccept(at: 100 + gap))
    }

    @Test("A deliberate second press still toggles", arguments: [0.4, 0.75, 30.0])
    func pressAfterWindowAccepted(gap: Double) {
        var coalescer = PauseToggleCoalescer(window: 0.4)
        #expect(coalescer.shouldAccept(at: 100))
        #expect(coalescer.shouldAccept(at: 100 + gap))
    }

    @Test("Rejected duplicates do not extend the window")
    func rejectedDuplicateDoesNotSlideWindow() {
        var coalescer = PauseToggleCoalescer(window: 0.4)
        #expect(coalescer.shouldAccept(at: 100))
        #expect(!coalescer.shouldAccept(at: 100.3))
        #expect(coalescer.shouldAccept(at: 100.45))
    }

    @Test("A clock that moves backwards never wedges the toggle")
    func backwardsClockAccepted() {
        var coalescer = PauseToggleCoalescer(window: 0.4)
        #expect(coalescer.shouldAccept(at: 100))
        #expect(coalescer.shouldAccept(at: 50))
    }
}
