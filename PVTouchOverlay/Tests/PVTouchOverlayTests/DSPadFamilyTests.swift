import Foundation
import Testing
import PVSystems
@testable import PVTouchOverlay

@Suite("DS pad family")
struct DSPadFamilyTests {
    let dsBinding = SystemOverlayBinding(
        system: .DS, families: [OverlayPadKind.standardSubtype: DSPadFamily.self],
        defaultSubtype: OverlayPadKind.standardSubtype,
        tokens: [.a: "a", .b: "b", .x: "x", .y: "y", .l: "l", .r: "r", .start: "start", .select: "select"],
        labels: [:], palette: .snes, hardwareSwitches: [])

    @Test("DS portrait stacks two screens and the stylus surface covers the bottom one")
    func stacked() {
        let template = DSPadFamily.template(binding: dsBinding, padKind: .standard(.DS), orientation: .portrait)
        #expect(template.screenPolicy == .dualStacked)
        let layout = OverlayLayoutEngine.resolve(template: template, canvas: OverlayLayoutEngineTests.phonePortrait,
                                                 overrides: .empty, gameAspect: OverlayScreenPlanner.dsAspect)
        #expect(layout.screenFrames.count == 2)
        #expect(layout.surfaceFrame(for: .dsScreen) == layout.screenFrames[1])
    }

    @Test("Pointer surface covers the first screen frame")
    func pointerSurface() {
        let kind = OverlayPadKind(system: .Wii, subtype: "wii-wiimote-nunchuck")
        let template = WiiRemoteFamily.template(binding: OverlayFamilyTests.wiiBinding, padKind: kind,
                                                orientation: .landscape)
        let layout = OverlayLayoutEngine.resolve(template: template, canvas: OverlayLayoutEngineTests.phoneLandscape,
                                                 overrides: .empty, gameAspect: 16.0 / 9.0)
        #expect(layout.surfaceFrame(for: .wiiPointer) == layout.screenFrames[0])
    }

    @Test("Surface group frame and hit frame match the screen frame")
    func groupMatchesScreen() throws {
        let template = DSPadFamily.template(binding: dsBinding, padKind: .standard(.DS), orientation: .portrait)
        let layout = OverlayLayoutEngine.resolve(template: template, canvas: OverlayLayoutEngineTests.phonePortrait,
                                                 overrides: .empty, gameAspect: OverlayScreenPlanner.dsAspect)
        let group = try #require(layout.groups.first { $0.id == "stylus" })
        let control = try #require(group.controls.first)
        #expect(group.frame == layout.screenFrames[1])
        #expect(control.frame == layout.screenFrames[1])
        #expect(control.hitFrame == layout.screenFrames[1])
    }
}
