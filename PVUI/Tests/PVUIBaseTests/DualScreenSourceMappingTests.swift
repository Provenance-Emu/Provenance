//
//  DualScreenSourceMappingTests.swift
//  PVUIBaseTests
//
//  Validates how the Metal dual-screen renderer picks and normalises each DS
//  screen's source region inside the core's framebuffer texture.
//

@testable import PVUIBase
import PVCoreBridge
import CoreGraphics
import XCTest

final class DualScreenSourceMappingTests: XCTestCase {

    private let deltaTop = CGRect(x: 0, y: 0, width: 256, height: 192)
    private let deltaBottom = CGRect(x: 0, y: 192, width: 256, height: 192)

    // MARK: - Source rect resolution

    func testDeltaInputFramesOnDefaultLayoutAreUnchanged() {
        let layout = NDSScreenLayout.default
        XCTAssertEqual(DualScreenSourceMapping.sourceRect(skinInputFrame: deltaTop, defaultScreen: .bottom,
                                                          swapped: false, layout: layout), deltaTop)
        XCTAssertEqual(DualScreenSourceMapping.sourceRect(skinInputFrame: deltaBottom, defaultScreen: .top,
                                                          swapped: false, layout: layout), deltaBottom)
    }

    func testDeltaInputFramesAreRebasedOntoGappedLayout() {
        let layout = NDSScreenLayout(arrangement: .topBottom, gap: 20)
        XCTAssertEqual(DualScreenSourceMapping.sourceRect(skinInputFrame: deltaBottom, defaultScreen: .top,
                                                          swapped: false, layout: layout),
                       CGRect(x: 0, y: 212, width: 256, height: 192))
    }

    func testDeltaInputFramesAreRebasedOntoSideBySideLayout() {
        let layout = NDSScreenLayout(arrangement: .leftRight, gap: 0)
        XCTAssertEqual(DualScreenSourceMapping.sourceRect(skinInputFrame: deltaTop, defaultScreen: .bottom,
                                                          swapped: false, layout: layout), deltaTop)
        XCTAssertEqual(DualScreenSourceMapping.sourceRect(skinInputFrame: deltaBottom, defaultScreen: .top,
                                                          swapped: false, layout: layout),
                       CGRect(x: 256, y: 0, width: 256, height: 192))
    }

    func testCroppedInputFrameKeepsItsCropWithinTheScreen() {
        let layout = NDSScreenLayout(arrangement: .bottomTop, gap: 0)
        let crop = CGRect(x: 8, y: 200, width: 240, height: 176) // inside the Delta bottom screen
        XCTAssertEqual(DualScreenSourceMapping.sourceRect(skinInputFrame: crop, defaultScreen: .top,
                                                          swapped: false, layout: layout),
                       CGRect(x: 8, y: 8, width: 240, height: 176))
    }

    func testMissingInputFrameUsesDefaultScreen() {
        let layout = NDSScreenLayout(arrangement: .topBottom, gap: 10)
        XCTAssertEqual(DualScreenSourceMapping.sourceRect(skinInputFrame: nil, defaultScreen: .bottom,
                                                          swapped: false, layout: layout),
                       CGRect(x: 0, y: 202, width: 256, height: 192))
        XCTAssertEqual(DualScreenSourceMapping.sourceRect(skinInputFrame: .zero, defaultScreen: .top,
                                                          swapped: false, layout: layout), deltaTop)
    }

    func testSwapExchangesScreens() {
        let layout = NDSScreenLayout.default
        XCTAssertEqual(DualScreenSourceMapping.sourceRect(skinInputFrame: deltaTop, defaultScreen: .top,
                                                          swapped: true, layout: layout), deltaBottom)
        XCTAssertEqual(DualScreenSourceMapping.sourceRect(skinInputFrame: nil, defaultScreen: .bottom,
                                                          swapped: true, layout: layout), deltaTop)
    }

    func testHiddenScreenHasNoSource() {
        let layout = NDSScreenLayout(arrangement: .topOnly, gap: 0)
        XCTAssertNil(DualScreenSourceMapping.sourceRect(skinInputFrame: deltaBottom, defaultScreen: .bottom,
                                                        swapped: false, layout: layout))
    }

    // MARK: - Normalisation against the bound texture

    func testNormalisesAgainstNativeSizedTexture() throws {
        let rect = try XCTUnwrap(DualScreenSourceMapping.normalizedSourceRect(
            deltaBottom, framebufferSize: CGSize(width: 256, height: 384), textureSize: CGSize(width: 256, height: 384)))
        XCTAssertEqual(rect, CGRect(x: 0, y: 0.5, width: 1, height: 0.5))
    }

    func testNormalisationIsResolutionScaleIndependent() throws {
        // A core rendering at 2x native fills a 512x768 texture.
        let rect = try XCTUnwrap(DualScreenSourceMapping.normalizedSourceRect(
            deltaBottom, framebufferSize: CGSize(width: 256, height: 384), textureSize: CGSize(width: 512, height: 768)))
        XCTAssertEqual(rect, CGRect(x: 0, y: 0.5, width: 1, height: 0.5))
    }

    func testRejectsTextureWhoseProportionsDisagreeWithLayout() {
        // Thin cores start on a 256x240 fallback texture until the real geometry arrives,
        // and a side-by-side core produces 512x192: neither can be split as 256x384.
        let layoutSize = CGSize(width: 256, height: 384)
        XCTAssertNil(DualScreenSourceMapping.normalizedSourceRect(
            deltaTop, framebufferSize: layoutSize, textureSize: CGSize(width: 256, height: 240)))
        XCTAssertNil(DualScreenSourceMapping.normalizedSourceRect(
            deltaTop, framebufferSize: layoutSize, textureSize: CGSize(width: 512, height: 192)))
        XCTAssertNil(DualScreenSourceMapping.normalizedSourceRect(
            deltaTop, framebufferSize: layoutSize, textureSize: .zero))
    }

    func testPaddedBufferSizeNoLongerShrinksUVs() throws {
        // Regression: the UVs were divided by core.bufferSize, which native DeSmuME
        // reports as 2048x2048 while its texture is the 256x384 screen rect.
        let rect = try XCTUnwrap(DualScreenSourceMapping.normalizedSourceRect(
            deltaTop, framebufferSize: CGSize(width: 256, height: 384), textureSize: CGSize(width: 256, height: 384)))
        XCTAssertEqual(rect.width, 1)
        XCTAssertEqual(rect.height, 0.5)
    }

    // MARK: - Texture coordinates

    func testTopLeftOriginTextureSamplesRectUpright() {
        let coords = DualScreenSourceMapping.textureCoordinates(
            for: CGRect(x: 0, y: 0.5, width: 1, height: 0.5), sourceIsBottomUp: false)
        XCTAssertEqual(coords, DualScreenTextureCoordinates(u0: 0, u1: 1, vTop: 0.5, vBottom: 1))
    }

    func testBottomUpTextureMirrorsTheRect() {
        // In a bottom-up (OpenGL) texture the framebuffer's top half lives at v 0.5…1.
        let coords = DualScreenSourceMapping.textureCoordinates(
            for: CGRect(x: 0, y: 0, width: 1, height: 0.5), sourceIsBottomUp: true)
        XCTAssertEqual(coords, DualScreenTextureCoordinates(u0: 0, u1: 1, vTop: 1, vBottom: 0.5))
    }
}
