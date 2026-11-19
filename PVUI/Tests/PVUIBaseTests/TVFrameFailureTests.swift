//
//  TVFrameFailureTests.swift
//  PVUIBaseTests
//
//  What to do when the GPU rejects a frame drawn through a TV.
//

import Foundation
import Metal
import Testing
@testable import PVUIBase

@Suite("TVFrameFailure")
struct TVFrameFailureTests {

    private func metalError(_ code: Int) -> NSError {
        NSError(domain: MTLCommandBufferErrorDomain, code: code)
    }

    @Test("Access revoked means nothing can draw until the app is reopened")
    func accessRevoked() {
        #expect(TVFrameFailure.action(for: metalError(4)) == .accessRevoked)
        #expect(MTLCommandBufferError.Code.accessRevoked.rawValue == 4)
    }

    @Test("A timeout or a page fault drops the TV", arguments: [2, 3])
    func dropsTV(code: Int) {
        #expect(TVFrameFailure.action(for: metalError(code)) == .dropTV)
    }

    @Test("Other Metal errors, and errors that are not Metal's, are only logged")
    func logOnly() {
        #expect(TVFrameFailure.action(for: metalError(1)) == .logOnly)
        #expect(TVFrameFailure.action(for: metalError(9)) == .logOnly)
        #expect(TVFrameFailure.action(for: URLError(.timedOut)) == .logOnly)
        #expect(TVFrameFailure.action(for: NSError(domain: "other", code: 4)) == .logOnly)
    }
}
