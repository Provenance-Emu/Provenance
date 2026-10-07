#if canImport(UIKit)
import Foundation
import Testing
import SwiftUI
import PVSettings
@testable import PVTouchOverlay

@Suite("Overlay art")
struct OverlayArtTests {
    @Test("Every shape produces a non-empty path", arguments: OverlayShape.allCases)
    func shapes(shape: OverlayShape) {
        let path = OverlayShapePath.path(shape, in: CGRect(x: 0, y: 0, width: 56, height: 40))
        #expect(!path.isEmpty)
        #expect(path.boundingRect.width > 0)
    }

    @Test("Pressed spec differs only by pressed flag so Equatable drives redraws")
    func specEquality() {
        let base = OverlayArtSpec(shape: .circle, color: .white, labelColor: .black,
                                  style: .flat, pressed: false, label: "A")
        var pressed = base
        pressed.pressed = true
        #expect(base != pressed)
        #expect(base == OverlayArtSpec(shape: .circle, color: .white, labelColor: .black,
                                       style: .flat, pressed: false, label: "A"))
    }
}

extension OverlayArtTests {
    private static let rect = CGRect(x: 0, y: 0, width: 60, height: 60)
    private static let centre = CGPoint(x: 30, y: 30)

    @Test("Ring has a hole at its centre under even-odd fill; circle does not")
    func ringHole() {
        let ring = OverlayShapePath.path(.ring, in: Self.rect)
        let circle = OverlayShapePath.path(.circle, in: Self.rect)
        #expect(!ring.contains(Self.centre, eoFill: true))
        #expect(circle.contains(Self.centre, eoFill: true))
    }

    @Test("Cross and kidney are single outlines so strokes show no interior seams",
          arguments: [OverlayShape.cross, .kidney])
    func singleSubpath(shape: OverlayShape) {
        var moves = 0
        OverlayShapePath.path(shape, in: Self.rect).forEach { element in
            if case .move = element { moves += 1 }
        }
        #expect(moves == 1)
    }
}
#endif
