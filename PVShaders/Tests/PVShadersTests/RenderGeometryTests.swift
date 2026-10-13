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
}
