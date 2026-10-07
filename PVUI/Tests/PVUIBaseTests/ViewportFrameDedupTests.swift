//
//  ViewportFrameDedupTests.swift
//  PVUIBaseTests
//

import CoreGraphics
import Testing
@testable import PVUIBase

@Suite("ViewportFrameDedup")
struct ViewportFrameDedupTests {
    let frame = CGRect(x: 0, y: 60, width: 390, height: 292)

    @Test("An unchanged frame is skipped unless forced")
    func unchanged() {
        #expect(!ViewportFrameDedup.shouldApply(new: frame, current: frame, force: false))
        #expect(ViewportFrameDedup.shouldApply(new: frame, current: frame, force: true))
    }

    @Test("Differences under the tolerance count as unchanged; larger ones apply")
    func tolerance() {
        #expect(!ViewportFrameDedup.shouldApply(new: frame.offsetBy(dx: 0.4, dy: -0.4), current: frame, force: false))
        #expect(ViewportFrameDedup.shouldApply(new: frame.offsetBy(dx: 0.6, dy: 0), current: frame, force: false))
        #expect(ViewportFrameDedup.shouldApply(new: frame.insetBy(dx: 1, dy: 0), current: frame, force: false))
    }

    @Test("With no current frame (e.g. right after rotation) the new frame applies")
    func noCurrent() {
        #expect(ViewportFrameDedup.shouldApply(new: frame, current: nil, force: false))
    }
}
