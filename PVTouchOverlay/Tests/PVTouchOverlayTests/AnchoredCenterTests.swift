import Foundation
import Testing
@testable import PVTouchOverlay

@Suite("AnchoredCenter")
struct AnchoredCenterTests {
    let canvas = OverlayCanvas(size: CGSize(width: 390, height: 844),
                               safeArea: OverlayInsets(top: 59, left: 0, bottom: 34, right: 0))

    @Test("Points in the outer thirds hang from the nearest edge")
    func outerThirds() {
        let anchored = AnchoredCenter.make(center: CGPoint(x: 60, y: 780), in: canvas)
        #expect(anchored.h == .min && anchored.x == 60)
        #expect(anchored.v == .max && anchored.y == 64)           // 844 - 780
        #expect(anchored.resolve(in: canvas) == CGPoint(x: 60, y: 780))
    }

    @Test("Points in the middle third anchor to the centre line")
    func middleThird() {
        let anchored = AnchoredCenter.make(center: CGPoint(x: 200, y: 400), in: canvas)
        #expect(anchored.h == .mid && anchored.x == 5)            // 200 - 195
        #expect(anchored.v == .mid && anchored.y == -22)          // 400 - 422
    }

    @Test("A stored centre survives a wider canvas")
    func survivesResize() {
        let anchored = AnchoredCenter.make(center: CGPoint(x: 330, y: 780), in: canvas)
        let wide = OverlayCanvas(size: CGSize(width: 430, height: 932), safeArea: canvas.safeArea)
        #expect(anchored.resolve(in: wide) == CGPoint(x: 370, y: 868))
    }
}
