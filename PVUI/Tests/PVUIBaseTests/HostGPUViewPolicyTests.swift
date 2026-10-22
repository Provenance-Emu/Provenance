//
//  HostGPUViewPolicyTests.swift
//  PVUIBaseTests
//

import Testing
@testable import PVUIBase

@Suite("HostGPUViewPolicy")
struct HostGPUViewPolicyTests {
    @Test func ownSurfaceCoreHidesTheHostView() {
        #expect(!HostGPUViewPolicy.drawsGame(skipLayout: true, positionsOwnRenderView: true))
    }

    @Test func frontendPresentedCoreShowsTheHostView() {
        #expect(HostGPUViewPolicy.drawsGame(skipLayout: false, positionsOwnRenderView: false))
    }

    /// Thin libretro cores position their viewport but still present through the host view.
    @Test func viewportPositioningAloneKeepsTheHostView() {
        #expect(HostGPUViewPolicy.drawsGame(skipLayout: false, positionsOwnRenderView: true))
    }

    @Test func skipLayoutAloneKeepsTheHostView() {
        #expect(HostGPUViewPolicy.drawsGame(skipLayout: true, positionsOwnRenderView: false))
    }
}
