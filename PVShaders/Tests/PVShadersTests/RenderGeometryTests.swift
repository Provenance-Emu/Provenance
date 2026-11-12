//
//  RenderGeometryTests.swift
//  PVShadersTests
//

import CoreGraphics
import Testing
@testable import PVShaders

@Suite("RenderGeometry")
struct RenderGeometryTests {
    @Test("aspect fit letterboxes a wide picture in a tall rect")
    func aspectFitLetterbox() {
        let rect = RenderGeometry.aspectFit(aspect: CGSize(width: 3, height: 2),
                                            in: CGRect(x: 0, y: 0, width: 402, height: 874))
        #expect(rect.width == 402)
        #expect(abs(rect.height - 268) < 0.001)
        #expect(abs(rect.midY - 437) < 0.001)
    }

    @Test("a view already sized to the picture gets the whole drawable")
    func sizedViewIsFullDrawable() {
        let rect = RenderGeometry.contentRect(aspect: CGSize(width: 3, height: 2),
                                              viewSize: CGSize(width: 402, height: 268),
                                              drawableSize: CGSize(width: 1206, height: 804))
        #expect(rect == CGRect(x: 0, y: 0, width: 1206, height: 804))
    }

    @Test("a full-screen placeholder view letterboxes the picture")
    func placeholderViewLetterboxes() {
        let rect = RenderGeometry.contentRect(aspect: CGSize(width: 3, height: 2),
                                              viewSize: CGSize(width: 402, height: 874),
                                              drawableSize: CGSize(width: 1206, height: 2622))
        #expect(rect.width == 1206)
        #expect(rect.height == 804)
        #expect(rect.minY == 909)
    }

    @Test("the fit is computed in view space when the drawable has other proportions")
    func drawableStretchedOverView() {
        // Drawable at full-screen pixels while the view is a 4:3 box: the picture
        // must fill the view, i.e. the whole drawable.
        let rect = RenderGeometry.contentRect(aspect: CGSize(width: 4, height: 3),
                                              viewSize: CGSize(width: 400, height: 300),
                                              drawableSize: CGSize(width: 1206, height: 2622))
        #expect(rect == CGRect(x: 0, y: 0, width: 1206, height: 2622))
    }

    @Test("empty sizes fall back to the whole drawable")
    func emptySizes() {
        let drawable = CGSize(width: 100, height: 50)
        #expect(RenderGeometry.contentRect(aspect: .zero, viewSize: CGSize(width: 10, height: 10),
                                           drawableSize: drawable) == CGRect(origin: .zero, size: drawable))
        #expect(RenderGeometry.contentRect(aspect: CGSize(width: 4, height: 3), viewSize: .zero,
                                           drawableSize: drawable) == CGRect(origin: .zero, size: drawable))
    }

    @Test("A 16:9 scene takes all of a 16:9 display")
    func sceneFillsMatchingDisplay() {
        let rect = RenderGeometry.sceneRect(aspect: CGSize(width: 16, height: 9), drawableSize: CGSize(width: 1920, height: 1080))
        #expect(rect == CGRect(x: 0, y: 0, width: 1920, height: 1080))
    }

    @Test("A 16:9 scene is letterboxed on a 4:3 display")
    func sceneLetterboxed() {
        let rect = RenderGeometry.sceneRect(aspect: CGSize(width: 16, height: 9), drawableSize: CGSize(width: 1024, height: 768))
        #expect(rect == CGRect(x: 0, y: 96, width: 1024, height: 576))
    }

    @Test("A 16:9 scene is pillarboxed on an ultrawide display")
    func scenePillarboxed() {
        let rect = RenderGeometry.sceneRect(aspect: CGSize(width: 16, height: 9), drawableSize: CGSize(width: 3440, height: 1440))
        #expect(rect == CGRect(x: 440, y: 0, width: 2560, height: 1440))
    }

    @Test("An empty drawable gives an empty scene")
    func sceneEmptyDrawable() {
        #expect(RenderGeometry.sceneRect(aspect: CGSize(width: 16, height: 9), drawableSize: .zero).isEmpty)
    }

    @Test("A tube's pixel size follows the scene's")
    func tubePixelSize() {
        let canvas = CGSize(width: 1920, height: 1080)
        let tube = CGSize(width: 1036.8, height: 777.6)
        let hd = RenderGeometry.pixelSize(of: tube, canvas: canvas, sceneSize: canvas)
        #expect(hd.width == 1037 && hd.height == 778)
        let uhd = RenderGeometry.pixelSize(of: tube, canvas: canvas, sceneSize: CGSize(width: 3840, height: 2160))
        #expect(uhd.width == 2074 && uhd.height == 1555)
        let none = RenderGeometry.pixelSize(of: tube, canvas: canvas, sceneSize: .zero)
        #expect(none.width == 1 && none.height == 1)
    }

    @Test("A picture of any shape is fitted inside a 4:3 tube",
          arguments: [(CGSize(width: 4, height: 3), CGRect(x: 0, y: 0, width: 1200, height: 900)),
                      (CGSize(width: 16, height: 9), CGRect(x: 0, y: 112.5, width: 1200, height: 675)),
                      (CGSize(width: 10, height: 9), CGRect(x: 100, y: 0, width: 1000, height: 900)),
                      (CGSize(width: 8, height: 7), CGRect(x: 600.0 - 900.0 * 4.0 / 7.0, y: 0.0, width: 900.0 * 8.0 / 7.0, height: 900.0))])
    func pictureInTube(aspect: CGSize, expected: CGRect) {
        let rect = RenderGeometry.aspectFit(aspect: aspect, in: CGRect(x: 0, y: 0, width: 1200, height: 900))
        #expect(abs(rect.minX - expected.minX) < 0.001 && abs(rect.minY - expected.minY) < 0.001)
        #expect(abs(rect.width - expected.width) < 0.001 && abs(rect.height - expected.height) < 0.001)
    }
}
