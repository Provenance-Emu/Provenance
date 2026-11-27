//
//  GameExternalOutputViewTests.swift
//  PVUIBaseTests
//
//  The picture shape the output view keeps for the renderer.
//

#if os(iOS) || os(tvOS)
import CoreGraphics
import Metal
import Testing
import SkinKitBezels
@testable import PVUIBase

@Suite("GameExternalOutputView")
@MainActor
struct GameExternalOutputViewTests {

    @Test("A new picture shape is kept with no TV showing, so the renderer stops reporting it")
    func keepsShapeWithoutATV() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let view = GameExternalOutputView(device: device) {}
        #expect(view.pictureShape == .standard)
        #expect(!view.hasBezel)
        view.pictureAspectDidChange(CGSize(width: 16, height: 9))
        #expect(view.pictureShape == .wide)
        view.pictureAspectDidChange(CGSize(width: 4, height: 3))
        #expect(view.pictureShape == .standard)
    }
}
#endif
