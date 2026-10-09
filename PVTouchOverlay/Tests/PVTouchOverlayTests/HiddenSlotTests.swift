import Foundation
import Testing
import PVSystems
@testable import PVTouchOverlay

@Suite("Hidden slots")
struct HiddenSlotTests {
    private static func binding(tokens: [OverlayFamilySlot: String],
                                family: any OverlayFamily.Type = TwoButtonFamily.self) -> SystemOverlayBinding {
        SystemOverlayBinding(system: .Atari2600, families: [OverlayPadKind.standardSubtype: family],
                             defaultSubtype: OverlayPadKind.standardSubtype, tokens: tokens,
                             labels: [:], palette: .atari, hardwareSwitches: [])
    }

    private static func template(_ binding: SystemOverlayBinding,
                                 orientation: OverlayOrientation = .portrait) -> OverlayTemplate {
        binding.template(padKind: .standard(.Atari2600), orientation: orientation)
    }

    @Test("A TwoButton pad with one button needs no new family: the slot with no token has no control")
    func oneButtonPad() {
        let ids = OverlayTestSupport.controlIDs(Self.template(Self.binding(
            tokens: [.a: "fire1", .start: "start", .select: "select"])))
        #expect(ids.contains("a") && !ids.contains("b"))
    }

    @Test("Only omittable slots hide: a required slot without a token still draws with its slot name")
    func requiredSlotStillDraws() throws {
        let template = Self.template(Self.binding(tokens: [.start: "start"]))
        let face = try #require(template.groups.first { $0.id == "face" })
        let button = try #require(face.controls.first { $0.id == "a" })
        #expect(button.kind == .button(OverlayInputID(system: .Atari2600, token: "a")))
    }

    @Test("A group whose every control is hidden is dropped")
    func emptyGroupDropped() {
        let template = Self.template(Self.binding(tokens: [.a: "a"]))
        #expect(!template.groups.contains { $0.id == "system" })
        #expect(template.groups.contains { $0.id == "face" })
    }

    @Test("Pills close ranks: hiding Select leaves Start at the row's first column")
    func pillRowClosesRanks() throws {
        let system = try #require(Self.template(Self.binding(tokens: [.a: "a", .start: "start"]))
            .groups.first { $0.id == "system" })
        let start = try #require(system.controls.first)
        #expect(system.controls.count == 1 && start.id == "start" && start.frame.minX == 0)
    }

    @Test("Hiding L and R leaves L2 and R2 on the first shoulder row")
    func shoulderRowClosesRanks() throws {
        let binding = Self.binding(tokens: [.a: "a", .b: "b", .l2: "l2", .r2: "r2"], family: DigitalPadFamily.self)
        let template = Self.template(binding)
        let ids = OverlayTestSupport.controlIDs(template)
        #expect(!ids.contains("l") && !ids.contains("r") && ids.contains("l2") && ids.contains("r2"))
        let plain = Self.template(Self.binding(tokens: [.a: "a", .b: "b", .l: "l", .l2: "l2"],
                                               family: DigitalPadFamily.self))
        let withRow = try #require(plain.groups.first { $0.id == "shoulder-l2" })
        let withoutRow = try #require(template.groups.first { $0.id == "shoulder-l2" })
        #expect(withRow.placement.inset.y > withoutRow.placement.inset.y)
    }

    @Test("isHidden is false for slots a binding tokenises and for slots outside the omittable set")
    func isHidden() {
        let binding = Self.binding(tokens: [.a: "a"])
        #expect(binding.isHidden(.b))
        #expect(!binding.isHidden(.a))
        #expect(!binding.isHidden(.k1))
    }
}
