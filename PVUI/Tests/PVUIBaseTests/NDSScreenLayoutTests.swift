//
//  NDSScreenLayoutTests.swift
//  PVUIBaseTests
//
//  Validates the DS framebuffer layout model shared by the Metal dual-screen
//  renderer and every DS core's stylus path.
//

import PVCoreBridge
import CoreGraphics
import XCTest

final class NDSScreenLayoutTests: XCTestCase {

    // MARK: - Option parsing

    func testDefaultIsTopBottomWithoutGap() {
        XCTAssertEqual(NDSScreenLayout.default, NDSScreenLayout(arrangement: .topBottom, gap: 0))
    }

    func testParsesLegacyMelonDSValues() {
        let layout = NDSScreenLayout(family: .melonDS, optionValue: { key in
            [NDSCoreFamily.melonDS.layoutOptionKey: "Bottom/Top",
             NDSCoreFamily.melonDS.gapOptionKey: "12"][key]
        })
        XCTAssertEqual(layout, NDSScreenLayout(arrangement: .bottomTop, gap: 12))
    }

    func testParsesDeSmuMEValues() {
        let layout = NDSScreenLayout(family: .desmume, optionValue: { key in
            [NDSCoreFamily.desmume.layoutOptionKey: "left/right",
             NDSCoreFamily.desmume.gapOptionKey: "5"][key]
        })
        XCTAssertEqual(layout, NDSScreenLayout(arrangement: .leftRight, gap: 5))
    }

    func testParsesMelonDSDSValues() {
        let layout = NDSScreenLayout(family: .melonDSDS, optionValue: { key in
            [NDSCoreFamily.melonDSDS.layoutOptionKey: "top-bottom",
             NDSCoreFamily.melonDSDS.gapOptionKey: "8"][key]
        })
        XCTAssertEqual(layout, NDSScreenLayout(arrangement: .topBottom, gap: 8))
    }

    func testMelonDSIgnoresGapInHorizontalLayouts() {
        // melonDS (legacy and DS) never inserts the gap between side-by-side screens.
        for family in [NDSCoreFamily.melonDS, .melonDSDS] {
            let value = family == .melonDS ? "Left/Right" : "left-right"
            let layout = NDSScreenLayout(family: family, optionValue: { key in
                [family.layoutOptionKey: value, family.gapOptionKey: "40"][key]
            })
            XCTAssertEqual(layout, NDSScreenLayout(arrangement: .leftRight, gap: 0), "\(family)")
        }
    }

    func testDeSmuMEKeepsGapInHorizontalLayouts() {
        let layout = NDSScreenLayout(family: .desmume, optionValue: { key in
            [NDSCoreFamily.desmume.layoutOptionKey: "right/left",
             NDSCoreFamily.desmume.gapOptionKey: "40"][key]
        })
        XCTAssertEqual(layout, NDSScreenLayout(arrangement: .rightLeft, gap: 40))
    }

    func testOnlyAndUnsupportedLayouts() {
        let cases: [(NDSCoreFamily, String, NDSScreenArrangement)] = [
            (.melonDS, "Top Only", .topOnly),
            (.melonDS, "Bottom Only", .bottomOnly),
            (.melonDS, "Hybrid Top", .unsupported),
            (.melonDS, "Hybrid Bottom", .unsupported),
            (.desmume, "top only", .topOnly),
            (.desmume, "bottom only", .bottomOnly),
            (.desmume, "quick switch", .unsupported),
            (.desmume, "hybrid/bottom", .unsupported),
            (.melonDSDS, "top", .topOnly),
            (.melonDSDS, "bottom", .bottomOnly),
            (.melonDSDS, "rotate-left", .unsupported),
            (.melonDSDS, "hybrid-top", .unsupported)
        ]
        for (family, value, expected) in cases {
            let layout = NDSScreenLayout(family: family, optionValue: { key in
                key == family.layoutOptionKey ? value : nil
            })
            XCTAssertEqual(layout.arrangement, expected, "\(family) \(value)")
        }
    }

    func testMissingOrGarbageOptionsFallBackToDefault() {
        let missing = NDSScreenLayout(family: .melonDS, optionValue: { _ in nil })
        XCTAssertEqual(missing, .default)
        let garbage = NDSScreenLayout(family: .desmume, optionValue: { key in
            key == NDSCoreFamily.desmume.layoutOptionKey ? "sideways" : "lots"
        })
        XCTAssertEqual(garbage, .default)
    }

    func testFamilyDetectionFromCoreIdentifier() {
        XCTAssertEqual(NDSCoreFamily(coreIdentifier: "com.provenance.core.melondsds"), .melonDSDS)
        XCTAssertEqual(NDSCoreFamily(coreIdentifier: "com.provenance.core.melonds"), .melonDS)
        XCTAssertEqual(NDSCoreFamily(coreIdentifier: "com.provenance.core.DeSmuME2015"), .desmume)
        XCTAssertNil(NDSCoreFamily(coreIdentifier: "com.provenance.core.snes9x"))
        XCTAssertNil(NDSCoreFamily(coreIdentifier: nil))
    }

    // MARK: - Geometry

    func testTopBottomGeometry() {
        let layout = NDSScreenLayout(arrangement: .topBottom, gap: 10)
        XCTAssertEqual(layout.framebufferSize, CGSize(width: 256, height: 394))
        XCTAssertEqual(layout.frame(of: .top), CGRect(x: 0, y: 0, width: 256, height: 192))
        XCTAssertEqual(layout.frame(of: .bottom), CGRect(x: 0, y: 202, width: 256, height: 192))
    }

    func testBottomTopGeometry() {
        let layout = NDSScreenLayout(arrangement: .bottomTop, gap: 10)
        XCTAssertEqual(layout.frame(of: .bottom), CGRect(x: 0, y: 0, width: 256, height: 192))
        XCTAssertEqual(layout.frame(of: .top), CGRect(x: 0, y: 202, width: 256, height: 192))
    }

    func testHorizontalGeometry() {
        let leftRight = NDSScreenLayout(arrangement: .leftRight, gap: 6)
        XCTAssertEqual(leftRight.framebufferSize, CGSize(width: 518, height: 192))
        XCTAssertEqual(leftRight.frame(of: .top), CGRect(x: 0, y: 0, width: 256, height: 192))
        XCTAssertEqual(leftRight.frame(of: .bottom), CGRect(x: 262, y: 0, width: 256, height: 192))

        let rightLeft = NDSScreenLayout(arrangement: .rightLeft, gap: 0)
        XCTAssertEqual(rightLeft.frame(of: .bottom), CGRect(x: 0, y: 0, width: 256, height: 192))
        XCTAssertEqual(rightLeft.frame(of: .top), CGRect(x: 256, y: 0, width: 256, height: 192))
    }

    func testSingleScreenAndUnsupportedGeometry() {
        let topOnly = NDSScreenLayout(arrangement: .topOnly, gap: 0)
        XCTAssertEqual(topOnly.framebufferSize, CGSize(width: 256, height: 192))
        XCTAssertEqual(topOnly.frame(of: .top), CGRect(x: 0, y: 0, width: 256, height: 192))
        XCTAssertNil(topOnly.frame(of: .bottom))
        XCTAssertFalse(topOnly.showsBothScreens)

        let bottomOnly = NDSScreenLayout(arrangement: .bottomOnly, gap: 0)
        XCTAssertNil(bottomOnly.frame(of: .top))
        XCTAssertEqual(bottomOnly.frame(of: .bottom), CGRect(x: 0, y: 0, width: 256, height: 192))

        let unsupported = NDSScreenLayout(arrangement: .unsupported, gap: 0)
        XCTAssertNil(unsupported.framebufferSize)
        XCTAssertNil(unsupported.frame(of: .top))
        XCTAssertNil(unsupported.frame(of: .bottom))
        XCTAssertTrue(NDSScreenLayout.default.showsBothScreens)
    }

    // MARK: - Stylus mapping

    func testTopBottomStylusMappingMatchesTaskFormula() throws {
        // ny = (192 + gap + y) / (384 + gap), sampled at the pixel centre.
        let layout = NDSScreenLayout(arrangement: .topBottom, gap: 0)
        let point = try XCTUnwrap(layout.normalizedPointerPosition(forTouchScreenPoint: CGPoint(x: 128, y: 96)))
        XCTAssertEqual(point.x, 128.5 / 256, accuracy: 1e-9)
        XCTAssertEqual(point.y, (192 + 96.5) / 384, accuracy: 1e-9)
    }

    func testStylusMappingClampsOutOfRangeInput() throws {
        let layout = NDSScreenLayout.default
        let low = try XCTUnwrap(layout.normalizedPointerPosition(forTouchScreenPoint: CGPoint(x: -20, y: -20)))
        let high = try XCTUnwrap(layout.normalizedPointerPosition(forTouchScreenPoint: CGPoint(x: 900, y: 900)))
        XCTAssertEqual(decodeLikeMelonDS(low, layout: layout), CGPoint(x: 0, y: 0))
        XCTAssertEqual(decodeLikeMelonDS(high, layout: layout), CGPoint(x: 255, y: 191))
    }

    func testStylusUnavailableWhenBottomScreenHidden() {
        XCTAssertNil(NDSScreenLayout(arrangement: .topOnly, gap: 0)
            .normalizedPointerPosition(forTouchScreenPoint: CGPoint(x: 10, y: 10)))
        XCTAssertNil(NDSScreenLayout(arrangement: .unsupported, gap: 0)
            .normalizedPointerPosition(forTouchScreenPoint: CGPoint(x: 10, y: 10)))
    }

    /// Encode through the frontends' libretro pointer conversion, then decode with
    /// each core's own integer inverse; every DS pixel must come back unchanged.
    func testStylusRoundTripsThroughBothCoresPointerDecoders() throws {
        let layouts = [
            NDSScreenLayout(arrangement: .topBottom, gap: 0),
            NDSScreenLayout(arrangement: .topBottom, gap: 5),
            NDSScreenLayout(arrangement: .topBottom, gap: 90),
            NDSScreenLayout(arrangement: .bottomTop, gap: 0),
            NDSScreenLayout(arrangement: .bottomTop, gap: 64),
            NDSScreenLayout(arrangement: .leftRight, gap: 0),
            NDSScreenLayout(arrangement: .leftRight, gap: 64),
            NDSScreenLayout(arrangement: .rightLeft, gap: 5),
            NDSScreenLayout(arrangement: .bottomOnly, gap: 0)
        ]
        let samples: [CGPoint] = [
            CGPoint(x: 0, y: 0), CGPoint(x: 255, y: 0), CGPoint(x: 0, y: 191),
            CGPoint(x: 255, y: 191), CGPoint(x: 128, y: 96), CGPoint(x: 1, y: 190)
        ]
        for layout in layouts {
            for sample in samples {
                let position = try XCTUnwrap(layout.normalizedPointerPosition(forTouchScreenPoint: sample))
                XCTAssertEqual(decodeLikeMelonDS(position, layout: layout), sample, "melonDS \(layout) \(sample)")
                XCTAssertEqual(decodeLikeDeSmuME(position, layout: layout), sample, "DeSmuME \(layout) \(sample)")
            }
        }
    }

    func testLibretroPointerCoordinateRange() {
        XCTAssertEqual(NDSScreenLayout.libretroPointerCoordinate(0), -0x7fff)
        XCTAssertEqual(NDSScreenLayout.libretroPointerCoordinate(1), 0x7fff)
        XCTAssertEqual(NDSScreenLayout.libretroPointerCoordinate(0.5), 0)
        XCTAssertEqual(NDSScreenLayout.libretroPointerCoordinate(-3), -0x7fff)
        XCTAssertEqual(NDSScreenLayout.libretroPointerCoordinate(3), 0x7fff)
    }

    // MARK: - Core-side inverses (mirrors of the upstream libretro input code)

    /// Bottom-screen origin the core tests touches against. DeSmuME's horizontal
    /// layouts accept touches from x = 256 even when a gap is inserted.
    private func touchOrigin(of layout: NDSScreenLayout) -> CGPoint {
        switch layout.arrangement {
        case .topBottom: return CGPoint(x: 0, y: 192 + layout.gap)
        case .leftRight: return CGPoint(x: 256, y: 0)
        default: return .zero
        }
    }

    /// melonDS `input.cpp`: x = (pointer + 0x8000) * buffer_width / 0x10000 (unsigned ints).
    private func decodeLikeMelonDS(_ position: CGPoint, layout: NDSScreenLayout) -> CGPoint {
        guard let size = layout.framebufferSize else { return CGPoint(x: -1, y: -1) }
        let px = Int(NDSScreenLayout.libretroPointerCoordinate(position.x))
        let py = Int(NDSScreenLayout.libretroPointerCoordinate(position.y))
        let x = (px + 0x8000) * Int(size.width) / 0x10000
        let y = (py + 0x8000) * Int(size.height) / 0x10000
        let origin = touchOrigin(of: layout)
        return CGPoint(x: x - Int(origin.x), y: y - Int(origin.y))
    }

    /// DeSmuME `libretro.cpp`: x = (pointer + 32768.0f) * (width / 65536.0f), truncated.
    private func decodeLikeDeSmuME(_ position: CGPoint, layout: NDSScreenLayout) -> CGPoint {
        guard let size = layout.framebufferSize else { return CGPoint(x: -1, y: -1) }
        let px = Float(NDSScreenLayout.libretroPointerCoordinate(position.x))
        let py = Float(NDSScreenLayout.libretroPointerCoordinate(position.y))
        let x = (px + 32768) * (Float(size.width) / 65536)
        let y = (py + 32768) * (Float(size.height) / 65536)
        let origin = touchOrigin(of: layout)
        return CGPoint(x: Int(x - Float(origin.x)), y: Int(y - Float(origin.y)))
    }
}
