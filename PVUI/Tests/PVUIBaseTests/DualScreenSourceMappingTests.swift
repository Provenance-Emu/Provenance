//
//  DualScreenSourceMappingTests.swift
//  PVUIBaseTests
//
//  Validates how the Metal dual-screen renderer picks and normalises each DS
//  screen's source region inside the core's framebuffer texture.
//

@testable import PVUIBase
import PVCoreBridge
import PVShaders
import CoreGraphics
import CoreImage
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

    // MARK: - LCD look placements

    private func info(_ source: CGRect, skinFilter: Bool = false) -> DualScreenRenderInfo {
        DualScreenRenderInfo(sourceRect: source, framebufferSize: CGSize(width: 256, height: 384),
                             viewDestRect: CGRect(x: 10, y: 20, width: 300, height: 225),
                             skinFilterInfos: skinFilter ? [DeltaSkin.FilterInfo(name: "CIColorInvert")] : [])
    }

    func testLCDPlacementUsesTexturePixelsAndDrawablePixels() throws {
        // A 2x internal resolution texture of the stacked layout.
        let textureSize = CGSize(width: 512, height: 768)
        let layout = [info(deltaTop), info(deltaBottom)]
        let coords = try XCTUnwrap(DualScreenSourceMapping.textureCoordinates(for: layout, textureSize: textureSize,
                                                                              sourceIsBottomUp: false))
        let bottom = DualScreenSourceMapping.lcdPlacement(for: layout[1], coordinates: coords[1],
                                                          textureSize: textureSize, contentScale: 3, lcdLook: true)
        XCTAssertEqual(bottom.sourceRect, CGRect(x: 0, y: 384, width: 512, height: 384))
        XCTAssertFalse(bottom.sourceIsFlipped)
        XCTAssertEqual(bottom.destinationRect, CGRect(x: 30, y: 60, width: 900, height: 675))
        // The grid follows the DS's own pixels, not the upscaled texture's.
        XCTAssertEqual(bottom.nativeSize, CGSize(width: 256, height: 192))
        XCTAssertTrue(bottom.appliesLCD)
    }

    func testLCDPlacementOfBottomUpTextureIsFlipped() throws {
        let textureSize = CGSize(width: 256, height: 384)
        let layout = [info(deltaTop)]
        let coords = try XCTUnwrap(DualScreenSourceMapping.textureCoordinates(for: layout, textureSize: textureSize,
                                                                              sourceIsBottomUp: true))
        let top = DualScreenSourceMapping.lcdPlacement(for: layout[0], coordinates: coords[0],
                                                       textureSize: textureSize, contentScale: 1, lcdLook: true)
        // The top screen is stored bottom row first in the texture's lower half.
        XCTAssertEqual(top.sourceRect, CGRect(x: 0, y: 192, width: 256, height: 192))
        XCTAssertTrue(top.sourceIsFlipped)
    }

    func testSkinFilterKeepsItsScreenPlain() throws {
        let textureSize = CGSize(width: 256, height: 384)
        let layout = [info(deltaTop, skinFilter: true)]
        let coords = try XCTUnwrap(DualScreenSourceMapping.textureCoordinates(for: layout, textureSize: textureSize,
                                                                              sourceIsBottomUp: false))
        XCTAssertFalse(DualScreenSourceMapping.lcdPlacement(for: layout[0], coordinates: coords[0],
                                                            textureSize: textureSize, contentScale: 2,
                                                            lcdLook: true).appliesLCD)
    }

    func testLCDLookOffKeepsScreensPlain() throws {
        let textureSize = CGSize(width: 256, height: 384)
        let layout = [info(deltaTop)]
        let coords = try XCTUnwrap(DualScreenSourceMapping.textureCoordinates(for: layout, textureSize: textureSize,
                                                                              sourceIsBottomUp: false))
        XCTAssertFalse(DualScreenSourceMapping.lcdPlacement(for: layout[0], coordinates: coords[0],
                                                            textureSize: textureSize, contentScale: 2,
                                                            lcdLook: false).appliesLCD)
    }

    // MARK: - Skin filter chains

    func testChainsFollowEachScreensFilters() {
        let chains = DeltaSkinScreenFilter.chains(for: [info(deltaTop, skinFilter: true), info(deltaBottom)])
        XCTAssertEqual(chains.map { $0.map(\.filter.name) }, [["CIColorInvert"], []])
    }

    func testRunAppliesFiltersInOrderAndReleasesInputs() throws {
        let brighten = try XCTUnwrap(DeltaSkinScreenFilter(filterInfo: DeltaSkin.FilterInfo(
            name: "CIColorControls", parameters: ["inputBrightness": .number(0.5)])))
        let invert = try XCTUnwrap(DeltaSkinScreenFilter(filterInfo: DeltaSkin.FilterInfo(name: "CIColorInvert")))
        let red = CIImage(color: .red).cropped(to: CGRect(x: 0, y: 0, width: 4, height: 4))
        let output = DeltaSkinScreenFilter.run([brighten, invert], on: red)
        var pixel = [UInt8](repeating: 0, count: 4)
        CIContext(options: [.workingColorSpace: NSNull()])
            .render(output, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 1, y: 1, width: 1, height: 1),
                    format: .RGBA8, colorSpace: nil)
        // Brightened red (1, .5, .5) inverts to (0, .5, .5); the other order gives (.5, 1, 1).
        XCTAssertLessThan(pixel[0], 20)
        XCTAssertTrue((100...160).contains(pixel[1]), "green \(pixel[1])")
        XCTAssertNil(brighten.filter.value(forKey: kCIInputImageKey))
        XCTAssertNil(invert.filter.value(forKey: kCIInputImageKey))
    }

    func testMismatchedTextureHasNoCoordinates() {
        XCTAssertNil(DualScreenSourceMapping.textureCoordinates(for: [info(deltaTop)],
                                                               textureSize: CGSize(width: 256, height: 240),
                                                               sourceIsBottomUp: false))
    }
}
