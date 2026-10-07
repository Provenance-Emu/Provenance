import Foundation
import Testing
import PVSystems
@testable import PVTouchOverlay

@Suite("OverlayLayoutEngine")
struct OverlayLayoutEngineTests {
    static let phonePortrait = OverlayCanvas(size: CGSize(width: 390, height: 844),
                                             safeArea: OverlayInsets(top: 59, left: 0, bottom: 34, right: 0))
    static let phoneLandscape = OverlayCanvas(size: CGSize(width: 844, height: 390),
                                              safeArea: OverlayInsets(top: 0, left: 59, bottom: 21, right: 59))
    static let padLandscape = OverlayCanvas(size: CGSize(width: 1180, height: 820),
                                            safeArea: OverlayInsets(top: 24, left: 0, bottom: 20, right: 0))

    static let offsetInset = CGPoint(x: 24, y: 40)

    func template(anchor: OverlayPlacement.Anchor, inset: CGPoint) -> OverlayTemplate {
        let btnA = OverlayInputID(system: .SNES, token: "a")
        let btnB = OverlayInputID(system: .SNES, token: "b")
        let grp = OverlayGroup(id: "face", controls: [
            OverlayControl(id: "a", kind: .button(btnA),
                    frame: CGRect(x: 60, y: 0, width: 56, height: 56), shape: .circle, paletteSlot: .primary),
            OverlayControl(id: "b", kind: .button(btnB),
                    frame: CGRect(x: 0, y: 60, width: 56, height: 56), shape: .circle, paletteSlot: .secondary)
        ], placement: OverlayPlacement(anchor: anchor, inset: inset))
        return OverlayTemplate(padKind: .standard(.SNES), orientation: .portrait, groups: [grp], screenPolicy: .topBand)
    }

    @Test("Reference scale is 1 on a 390pt phone and clamps at 1.35")
    func referenceScale() {
        #expect(OverlayLayoutEngine.referenceScale(for: Self.phonePortrait) == 1)
        #expect(OverlayLayoutEngine.referenceScale(for: Self.padLandscape) == 1.35)
    }

    @Test("Bottom-trailing group sits inset from the safe bottom-right corner")
    func bottomTrailing() throws {
        let layout = OverlayLayoutEngine.resolve(template: template(anchor: .bottomTrailing, inset: Self.offsetInset),
                                                 canvas: Self.phonePortrait, overrides: .empty, gameAspect: 4 / 3)
        let grp = try #require(layout.groups.first)
        #expect(grp.frame.maxX == CGFloat(390 - 24))
        #expect(grp.frame.maxY == CGFloat(844 - 34 - 40))
        #expect(grp.frame.size == CGSize(width: 116, height: 116))
    }

    @Test("Group scale enlarges around the centre and clamps inside the safe area")
    func scaleClamps() {
        var overrides = OverlayLayoutOverrides.empty
        overrides.groups["face"] = GroupOverride(center: nil, scale: CGSize(width: 2, height: 2),
                                                 opacity: nil, buttons: [:])
        let layout = OverlayLayoutEngine.resolve(template: template(anchor: .bottomTrailing, inset: Self.offsetInset),
                                                 canvas: Self.phonePortrait, overrides: overrides, gameAspect: 4 / 3)
        let grp = layout.groups[0]
        #expect(grp.frame.size == CGSize(width: 232, height: 232))
        #expect(grp.frame.maxX <= 390)
        #expect(grp.frame.maxY <= 844 - 34)
    }

    @Test("A stored centre overrides the template placement")
    func storedCenter() {
        var overrides = OverlayLayoutOverrides.empty
        overrides.groups["face"] = GroupOverride(center: AnchoredCenter(h: .min, x: 100, v: .min, y: 300),
                                                 scale: nil, opacity: nil, buttons: [:])
        let layout = OverlayLayoutEngine.resolve(template: template(anchor: .bottomTrailing, inset: .zero),
                                                 canvas: Self.phonePortrait, overrides: overrides, gameAspect: 4 / 3)
        #expect(layout.groups[0].frame.midX == 100)
        #expect(layout.groups[0].frame.midY == 300)
    }

    @Test("Per-control offsets move one button and hit frames are outset")
    func controlOffsetAndHitFrame() throws {
        var overrides = OverlayLayoutOverrides.empty
        overrides.groups["face"] = GroupOverride(center: nil, scale: nil, opacity: nil,
                                                 buttons: ["a": ControlOverride(offset: CGPoint(x: 10, y: -10),
                                                                                scale: 1)])
        let layout = OverlayLayoutEngine.resolve(template: template(anchor: .bottomTrailing, inset: .zero),
                                                 canvas: Self.phonePortrait, overrides: overrides, gameAspect: 4 / 3)
        let grp = layout.groups[0]
        let ctlA = try #require(grp.controls.first { $0.control.id == "a" })
        let ctlB = try #require(grp.controls.first { $0.control.id == "b" })
        #expect(ctlA.frame.minX == grp.frame.minX + 60 + 10)
        #expect(ctlA.frame.minY == grp.frame.minY - 10)
        let edge = OverlayLayoutEngine.extendedEdges
        #expect(ctlB.hitFrame == ctlB.frame.insetBy(dx: -edge, dy: -edge))
    }

    @Test("Opacity override multiplies the group opacity")
    func opacity() {
        var overrides = OverlayLayoutOverrides.empty
        overrides.groups["face"] = GroupOverride(center: nil, scale: nil, opacity: 0.5, buttons: [:])
        let layout = OverlayLayoutEngine.resolve(template: template(anchor: .bottomTrailing, inset: .zero),
                                                 canvas: Self.phonePortrait, overrides: overrides, gameAspect: 4 / 3)
        #expect(layout.groups[0].opacity == 0.5)
    }

    @Test("A stored centre near a corner clamps inside the safe rect")
    func storedCenterClamps() {
        var overrides = OverlayLayoutOverrides.empty
        overrides.groups["face"] = GroupOverride(center: AnchoredCenter(h: .min, x: 5, v: .min, y: 5),
                                                 scale: nil, opacity: nil, buttons: [:])
        let layout = OverlayLayoutEngine.resolve(template: template(anchor: .bottomTrailing, inset: .zero),
                                                 canvas: Self.phonePortrait, overrides: overrides, gameAspect: 1)
        #expect(layout.groups[0].frame.midX == CGFloat(58))
        #expect(layout.groups[0].frame.midY == CGFloat(117))
    }

    @Test("A group larger than the safe rect is centred on it")
    func oversizedGroupCentres() {
        let btn = OverlayInputID(system: .SNES, token: "a")
        let big = OverlayGroup(id: "big", controls: [
            OverlayControl(id: "a", kind: .button(btn), frame: CGRect(x: 0, y: 0, width: 800, height: 500),
                           shape: .bar, paletteSlot: .primary)
        ], placement: OverlayPlacement(anchor: .bottomLeading))
        let tmpl = OverlayTemplate(padKind: .standard(.SNES), orientation: .landscape, groups: [big],
                                   screenPolicy: .fill)
        let canvas = Self.phoneLandscape
        let layout = OverlayLayoutEngine.resolve(template: tmpl, canvas: canvas, overrides: .empty, gameAspect: 1)
        #expect(layout.groups[0].frame.midX == canvas.safeRect.midX)
        #expect(layout.groups[0].frame.midY == canvas.safeRect.midY)
    }

    @Test("Control scale and group opacity overrides are clamped")
    func overrideClamps() throws {
        var overrides = OverlayLayoutOverrides.empty
        overrides.groups["face"] = GroupOverride(center: nil, scale: nil, opacity: 0,
                                                 buttons: ["a": ControlOverride(offset: .zero, scale: 10)])
        let layout = OverlayLayoutEngine.resolve(template: template(anchor: .bottomTrailing, inset: .zero),
                                                 canvas: Self.phonePortrait, overrides: overrides, gameAspect: 1)
        let ctl = try #require(layout.groups[0].controls.first { $0.control.id == "a" })
        #expect(ctl.frame.width == CGFloat(112))
        #expect(layout.groups[0].opacity == 0.1)
    }
}
