//
//  RenderTargetBudgetTests.swift
//  PVShadersTests
//
//  A preset's render targets are sized from the picture it filters, and nothing
//  bounded their total. In iCube, which filters a display-sized frame, one bundled
//  preset asked for 3.8 GB on an iPad Pro and iOS killed the app for memory
//  (2026-11-25). Same chain here, same budget.
//

import CoreGraphics
import Foundation
import Testing
@testable import PVSlangRuntime

@Suite("FilterChain render target budget")
struct RenderTargetBudgetTests {
    private typealias Request = FilterChain.RenderTargetRequest
    private let mib = 1_048_576.0

    private func bytes(_ requests: [Request], _ sizes: [CGSize]) -> Double {
        zip(requests, sizes).reduce(0) { $0 + $1.0.bytes(at: $1.1) }
    }

    @Test("the budget is an eighth of memory, between 256 MB and 2 GB")
    func budgetBounds() {
        let gib: UInt64 = 1_073_741_824
        #expect(FilterChain.renderTargetBudget(physicalMemory: 6 * gib) == 768 * 1_048_576)
        #expect(FilterChain.renderTargetBudget(physicalMemory: 1 * gib) == 256 * 1_048_576)
        #expect(FilterChain.renderTargetBudget(physicalMemory: 96 * gib) == 2048 * 1_048_576)
    }

    @Test("a chain inside the budget is left alone")
    func insideBudgetUntouched() {
        let requests = [
            Request(size: CGSize(width: 640, height: 480), bytesPerPixel: 4, copies: 1, canShrink: true),
            Request(size: CGSize(width: 1280, height: 960), bytesPerPixel: 8, copies: 2, canShrink: true),
            Request(size: CGSize(width: 2732, height: 2048), bytesPerPixel: 4, copies: 0, canShrink: false)
        ]
        #expect(FilterChain.fitRenderTargets(requests, fixedBytes: 0, budget: 708 * mib) == requests.map(\.size))
    }

    @Test("4x passes over a display-sized source shrink under the budget and keep their ratios")
    func oversizedChainShrinks() throws {
        let source = CGSize(width: 2732, height: 2048)
        let fourTimes = CGSize(width: source.width * 4, height: source.height * 4)
        let requests = [
            Request(size: source, bytesPerPixel: 8, copies: 1, canShrink: true),
            Request(size: fourTimes, bytesPerPixel: 4, copies: 1, canShrink: true),
            Request(size: fourTimes, bytesPerPixel: 8, copies: 2, canShrink: true),
            Request(size: source, bytesPerPixel: 4, copies: 0, canShrink: false)
        ]
        let budget = 708 * mib
        #expect(bytes(requests, requests.map(\.size)) > 1700 * mib)

        let sizes = try #require(FilterChain.fitRenderTargets(requests, fixedBytes: 0, budget: budget))

        #expect(bytes(requests, sizes) <= budget)
        #expect(bytes(requests, sizes) > budget * 0.95)
        #expect(abs(sizes[1].width / sizes[0].width - 4) < 0.01)
        #expect(abs(sizes[1].height / sizes[0].height - 4) < 0.01)
        #expect(abs(sizes[0].width / sizes[0].height - source.width / source.height) < 0.01)
        #expect(sizes[3] == source)
    }

    @Test("fixed targets and history count but do not shrink")
    func fixedTargetsCount() throws {
        let lut = Request(size: CGSize(width: 1024, height: 1024), bytesPerPixel: 4, copies: 1, canShrink: false)
        let big = Request(size: CGSize(width: 8192, height: 8192), bytesPerPixel: 4, copies: 1, canShrink: true)
        let history = 100 * mib
        let budget = 300 * mib

        let sizes = try #require(FilterChain.fitRenderTargets([lut, big], fixedBytes: history, budget: budget))

        #expect(sizes[0] == lut.size)
        #expect(sizes[1].width < big.size.width)
        #expect(bytes([lut, big], sizes) + history <= budget)
    }

    @Test("a chain that cannot fit is refused")
    func cannotFit() {
        let fixed = Request(size: CGSize(width: 16384, height: 16384), bytesPerPixel: 4, copies: 1, canShrink: false)
        #expect(FilterChain.fitRenderTargets([fixed], fixedBytes: 0, budget: 708 * mib) == nil)
        let small = Request(size: CGSize(width: 64, height: 64), bytesPerPixel: 4, copies: 1, canShrink: true)
        #expect(FilterChain.fitRenderTargets([small], fixedBytes: 800 * mib, budget: 708 * mib) == nil)
        #expect(FilterChain.fitRenderTargets([small], fixedBytes: .infinity, budget: 708 * mib) == nil)
    }

    @Test("a shrunk target never reaches zero")
    func neverZero() throws {
        let wide = Request(size: CGSize(width: 16000, height: 1), bytesPerPixel: 16, copies: 2, canShrink: true)
        let sizes = try #require(FilterChain.fitRenderTargets([wide], fixedBytes: 0, budget: 1024))
        #expect(sizes[0].width >= 1)
        #expect(sizes[0].height == 1)
        // The height cannot go below one pixel, so the width has to make up for it.
        #expect(bytes([wide], sizes) <= 1024)
    }

    @Test("a chain over budget with every target at one pixel is refused")
    func cannotFitAtOnePixel() {
        let wide = Request(size: CGSize(width: 16000, height: 1), bytesPerPixel: 16, copies: 2, canShrink: true)
        #expect(FilterChain.fitRenderTargets([wide], fixedBytes: 0, budget: 16) == nil)
    }
}
