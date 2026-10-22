//
//  HostGPUViewPolicyTests.swift
//  PVUIBaseTests
//

import Testing
@testable import PVUIBase

@Suite("HostGPUViewPolicy")
struct HostGPUViewPolicyTests {
    /// Azahar and Dolphin: their render view sits next to the GPU view.
    @Test func ownSurfaceCoreHidesTheHostView() {
        #expect(!HostGPUViewPolicy.drawsGame(skipLayout: true, positionsOwnRenderView: true, rendersInsideHostView: false))
    }

    /// Native PPSSPP under a skin has no host view and draws inside the GPU view.
    @Test func ownSurfaceInsideTheHostViewKeepsItShown() {
        #expect(HostGPUViewPolicy.drawsGame(skipLayout: true, positionsOwnRenderView: true, rendersInsideHostView: true))
    }

    @Test func frontendPresentedCoreShowsTheHostView() {
        #expect(HostGPUViewPolicy.drawsGame(skipLayout: false, positionsOwnRenderView: false, rendersInsideHostView: false))
    }

    /// Thin libretro cores position their viewport but still present through the host view.
    @Test func viewportPositioningAloneKeepsTheHostView() {
        #expect(HostGPUViewPolicy.drawsGame(skipLayout: false, positionsOwnRenderView: true, rendersInsideHostView: true))
    }

    @Test func skipLayoutAloneKeepsTheHostView() {
        #expect(HostGPUViewPolicy.drawsGame(skipLayout: true, positionsOwnRenderView: false, rendersInsideHostView: false))
    }
}
