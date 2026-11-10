//
//  SkinViewportGeometryTests.swift
//  PVUIBaseTests
//

import CoreGraphics
import Testing
@testable import PVUIBase

@Suite("SkinViewportGeometry")
struct SkinViewportGeometryTests {
    /// iPhone 17 in portrait, and the edge-to-edge mapping size most iPhone skins ship.
    let portrait = CGSize(width: 402, height: 874)
    let mapping = CGSize(width: 414, height: 896)
    /// "Jaguar Paw" (deltastyles.com), the skin the misplaced-picture report was made with.
    let jaguarPawScreen = CGRect(x: 12, y: 74, width: 390, height: 298)

    private func isClose(_ lhs: CGRect, _ rhs: CGRect, tolerance: CGFloat = 0.01) -> Bool {
        abs(lhs.minX - rhs.minX) < tolerance && abs(lhs.minY - rhs.minY) < tolerance
            && abs(lhs.width - rhs.width) < tolerance && abs(lhs.height - rhs.height) < tolerance
    }

    @Test("The renderer draws an iPhone portrait skin full width, resting on the bottom edge")
    func portraitSkinImage() throws {
        let frame = try #require(SkinViewportGeometry.skinImageFrame(
            containerSize: portrait, mappingSize: mapping, restsOnBottomEdge: true))
        // Same numbers as the renderer logs: scale 0.971, 402 x 870.03 at y 3.97.
        #expect(isClose(frame, CGRect(x: 0, y: 3.971, width: 402, height: 870.029)))
    }

    @Test("The screen rect lands where the renderer broadcasts it")
    func screenMatchesRenderer() throws {
        let skinImage = try #require(SkinViewportGeometry.skinImageFrame(
            containerSize: portrait, mappingSize: mapping, restsOnBottomEdge: true))
        let screen = SkinViewportGeometry.screenFrame(jaguarPawScreen, mappingSize: mapping, in: skinImage)
        // The renderer's rect for this skin, before it fits the 4:3 picture inside: x 11.65, width 378.70.
        #expect(isClose(screen, CGRect(x: 11.652, y: 75.826, width: 378.696, height: 289.362)))
    }

    @Test("Laying the skin out inside the safe area, as the view controller used to, misses the screen")
    func safeAreaInsetsMoveTheScreen() throws {
        let insets = SkinViewportGeometry.Insets(top: 62, left: 0, bottom: 34, right: 0)
        let skinImage = try #require(SkinViewportGeometry.skinImageFrame(
            containerSize: portrait, mappingSize: mapping, insets: insets, restsOnBottomEdge: true))
        let wrong = SkinViewportGeometry.screenFrame(jaguarPawScreen, mappingSize: mapping, in: skinImage)
        let right = SkinViewportGeometry.screenFrame(
            jaguarPawScreen, mappingSize: mapping,
            in: try #require(SkinViewportGeometry.skinImageFrame(containerSize: portrait, mappingSize: mapping,
                                                                 restsOnBottomEdge: true)))
        #expect(wrong.minY - right.minY > 40)
        #expect(wrong.maxY > right.maxY, "the old rect ran past the bottom of the skin's screen")
        #expect(wrong.width < right.width)
    }

    @Test("Landscape and iPad skins are centred")
    func centred() throws {
        let landscape = CGSize(width: 874, height: 402)
        let frame = try #require(SkinViewportGeometry.skinImageFrame(
            containerSize: landscape, mappingSize: CGSize(width: 896, height: 414), restsOnBottomEdge: false))
        #expect(isClose(frame, CGRect(x: 1.986, y: 0, width: 870.029, height: 402)))
    }

    @Test("A screen rect already in 0...1 is used as it is")
    func normalisedScreen() {
        let skinImage = CGRect(x: 10, y: 20, width: 400, height: 800)
        let unit = CGRect(x: 0.25, y: 0.1, width: 0.5, height: 0.25)
        #expect(SkinViewportGeometry.screenFrame(unit, mappingSize: mapping, in: skinImage)
                == CGRect(x: 110, y: 100, width: 200, height: 200))
        #expect(SkinViewportGeometry.normalized(unit, mappingSize: mapping) == unit)
    }

    @Test("Sizes with no area produce no frame")
    func emptySizes() {
        #expect(SkinViewportGeometry.skinImageFrame(containerSize: .zero, mappingSize: mapping,
                                                    restsOnBottomEdge: true) == nil)
        #expect(SkinViewportGeometry.skinImageFrame(containerSize: portrait, mappingSize: .zero,
                                                    restsOnBottomEdge: false) == nil)
    }
}
