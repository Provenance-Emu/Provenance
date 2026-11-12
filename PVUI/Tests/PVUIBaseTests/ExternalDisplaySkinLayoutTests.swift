//
//  ExternalDisplaySkinLayoutTests.swift
//  PVUIBaseTests
//
//  Which skin layout frames the picture on an external display.
//

#if os(iOS)
import CoreGraphics
import SkinKitCore
import Testing
@testable import PVUIBase

@Suite("ExternalDisplaySkinLayout")
struct ExternalDisplaySkinLayoutTests {
    private let tv = CGSize(width: 1920, height: 1080)
    private let screenFrame = CGRect(x: 248, y: 20, width: 400, height: 300)

    /// The bundled Backbone GBA skin's landscape layouts: mapping size and game screen.
    private let backbone: [String: (mapping: CGSize, screen: CGRect)] = [
        "iphone-standard": (CGSize(width: 1334, height: 750), CGRect(x: 417, y: 115, width: 500, height: 520)),
        "iphone-edgeToEdge": (CGSize(width: 852, height: 393), CGRect(x: 266, y: 60, width: 319, height: 272)),
        "ipad-standard": (CGSize(width: 1366, height: 1024), CGRect(x: 427, y: 157, width: 512, height: 710))
    ]

    private func screen(_ frame: CGRect?, placement: DeltaSkinScreenPlacement = .controller,
                        maintainAspectRatio: Bool = true) -> DeltaSkinScreen {
        DeltaSkinScreen(id: "screen", inputFrame: nil, outputFrame: frame, placement: placement,
                        filters: nil, maintainAspectRatio: maintainAspectRatio)
    }

    private func key(_ traits: DeltaSkinTraits) -> String {
        "\(traits.device.rawValue)-\(traits.displayType.rawValue)"
    }

    /// A skin whose layouts are `layouts` (keyed "device-displayType"), each with one screen.
    private func resolve(_ layouts: [String: (mapping: CGSize, screen: CGRect)],
                         containerSize: CGSize? = nil) -> ExternalDisplaySkinLayout? {
        ExternalDisplaySkinLayout.resolve(gameIdentifiers: ["abc"],
                                          usesAltRepresentations: false,
                                          containerSize: containerSize ?? tv,
                                          screens: { traits in layouts[key(traits)].map { [screen($0.screen)] } },
                                          mappingSize: { traits in layouts[key(traits)]?.mapping })
    }

    /// A skin with one iPhone layout whose screens are `screens`.
    private func resolve(screens: [DeltaSkinScreen]) -> ExternalDisplaySkinLayout? {
        ExternalDisplaySkinLayout.resolve(gameIdentifiers: [],
                                          usesAltRepresentations: false,
                                          containerSize: tv,
                                          screens: { $0.device == .iphone && $0.displayType == .standard ? screens : nil },
                                          mappingSize: { _ in CGSize(width: 896, height: 414) })
    }

    @Test("The layout is landscape and carries the game's keys")
    func traits() {
        let layout = resolve(backbone)
        #expect(layout?.traits.orientation == .landscape)
        #expect(layout?.traits.gameIdentifiers == ["abc"])
    }

    @Test("A layout made for a TV wins over the device layouts, however small its screen")
    func prefersTVLayout() {
        var layouts = backbone
        layouts["tv-standard"] = (CGSize(width: 1920, height: 1080), CGRect(x: 800, y: 400, width: 300, height: 200))
        #expect(resolve(layouts)?.traits.device == .tv)
    }

    @Test("A layout made for an external display wins over the device layouts")
    func prefersExternalDisplayLayout() {
        var layouts = backbone
        layouts["iphone-externalDisplay"] = (CGSize(width: 1280, height: 720), CGRect(x: 400, y: 100, width: 480, height: 320))
        let layout = resolve(layouts)
        #expect(layout?.traits.device == .iphone)
        #expect(layout?.traits.displayType == .externalDisplay)
    }

    @Test("On a 16:9 TV the device layout with the largest picture is the iPhone's, not the 4:3 iPad's")
    func largestPictureOnTV() {
        let layout = resolve(backbone)
        #expect(layout?.traits.device == .iphone)
        #expect(layout?.traits.displayType == .standard)
        #expect(layout?.mappingSize == CGSize(width: 1334, height: 750))
    }

    @Test("On a 4:3 display the iPad layout gives the largest picture")
    func largestPictureOnFourByThree() {
        let layout = resolve(backbone, containerSize: CGSize(width: 1024, height: 768))
        #expect(layout?.traits.device == .ipad)
    }

    @Test("Before the display has a size the first device layout is used")
    func noContainerSize() {
        #expect(resolve(backbone, containerSize: .zero)?.traits.displayType == .standard)
        #expect(resolve(backbone, containerSize: .zero)?.traits.device == .iphone)
    }

    @Test("An iPad-only skin uses its landscape layout")
    func onlyLayout() {
        let layout = resolve(["ipad-standard": (CGSize(width: 1366, height: 1024), screenFrame)])
        #expect(layout?.traits.device == .ipad)
        #expect(layout?.screen == screenFrame)
    }

    @Test("A skin with no landscape layout shows the picture alone")
    func unsupportedSkin() {
        #expect(resolve([:]) == nil)
    }

    @Test("Layouts with no screen, several screens or an app-placed screen do not qualify")
    func needsOneFramedScreen() {
        #expect(resolve(screens: []) == nil)
        #expect(resolve(screens: [screen(screenFrame), screen(screenFrame)]) == nil)
        #expect(resolve(screens: [screen(nil)]) == nil)
        #expect(resolve(screens: [screen(screenFrame, placement: .app)]) == nil)
        #expect(resolve(screens: [screen(screenFrame)]) != nil)
    }

    @Test("The screen's stretch flag is kept")
    func keepsAspectFlag() {
        #expect(resolve(screens: [screen(screenFrame, maintainAspectRatio: false)])?.maintainsAspectRatio == false)
        #expect(resolve(screens: [screen(screenFrame)])?.maintainsAspectRatio == true)
    }

    @Test("On a 1080p display the skin is scaled to fit and centred, with its screen inside")
    func framesOnTV() throws {
        let layout = try #require(resolve(screens: [screen(screenFrame)]))
        let frames = try #require(layout.frames(in: tv))
        // 896 x 414 fits by width: scale 1920 / 896.
        let scale: CGFloat = 1920 / 896
        #expect(abs(frames.image.width - 1920) < 0.01)
        #expect(abs(frames.image.height - 414 * scale) < 0.01)
        #expect(abs(frames.image.midY - 540) < 0.01)
        #expect(abs(frames.screen.minX - 248 * scale) < 0.01)
        #expect(abs(frames.screen.minY - (frames.image.minY + 20 * scale)) < 0.01)
        #expect(abs(frames.screen.width - 400 * scale) < 0.01)
    }
}
#endif
