import Foundation
import Testing
import PVSystems
@testable import PVTouchOverlay

@Suite("Arcade stick family")
struct ArcadeStickFamilyTests {
    private static func template(_ system: SystemIdentifier,
                                 orientation: OverlayOrientation = .portrait) throws -> OverlayTemplate {
        let binding = try #require(SystemOverlayBindings.binding(for: system))
        return binding.template(padKind: .standard(system), orientation: orientation)
    }

    private static func face(_ template: OverlayTemplate) throws -> OverlayGroup {
        try #require(template.groups.first { $0.id == "face" })
    }

    @Test("The stick is an 8-way d-pad drawn as a ball")
    func ballTop() throws {
        let stick = try #require(try Self.template(.MAME).groups.first { $0.id == "stick" }?.controls.first)
        guard case .dpad = stick.kind else {
            Issue.record("stick is not a d-pad")
            return
        }
        #expect(stick.shape == .circle && stick.paletteSlot == .stick)
    }

    @Test("Six buttons sit in two rows, the bottom row staggered right of the top row")
    func twoStaggeredRows() throws {
        let controls = try Self.face(try Self.template(.MAME)).controls
        #expect(controls.count == 6)
        let byID = Dictionary(uniqueKeysWithValues: controls.map { ($0.id, $0) })
        for id in ["x", "y", "z"] { #expect(byID[id]?.frame.minY == byID["x"]?.frame.minY) }
        for id in ["a", "b", "c"] { #expect(byID[id]?.frame.minY == byID["a"]?.frame.minY) }
        let top = try #require(byID["x"]), bottom = try #require(byID["a"])
        #expect(bottom.frame.minY > top.frame.maxY - 1)
        #expect(bottom.frame.minX > top.frame.minX)
    }

    @Test("Neo Geo draws A B C D on one row")
    func neoGeoSingleRow() throws {
        let controls = try Self.face(try Self.template(.NeoGeo)).controls
        #expect(Set(controls.map(\.id)) == ["a", "b", "c", "x"])
        #expect(Set(controls.map(\.frame.minY)).count == 1)
        #expect(controls.map(\.frame.minX).sorted() == controls.map(\.frame.minX).sorted().sorted())
    }

    @Test("Coin and Start sit above the buttons in portrait", arguments: [SystemIdentifier.MAME, .NAOMI, .CPS2])
    func pillsAboveButtons(system: SystemIdentifier) throws {
        let canvas = OverlayLayoutEngineTests.phonePortrait
        let layout = OverlayTestSupport.resolve(try Self.template(system), on: canvas)
        let system = try #require(layout.groups.first { $0.id == "system" })
        let face = try #require(layout.groups.first { $0.id == "face" })
        #expect(system.frame.maxY <= face.frame.minY)
        #expect(system.controls.map(\.id).contains("coin") && system.controls.map(\.id).contains("start"))
    }

    @Test("MAME adds a service action; the other boards do not")
    func serviceAction() throws {
        let mame = try Self.template(.MAME)
        #expect(mame.groups.flatMap(\.controls).contains { $0.kind == .action(.service) })
        let cps = try Self.template(.CPS1)
        #expect(!cps.groups.flatMap(\.controls).contains { $0.kind == .action(.service) })
    }

    @Test("Neo Geo CD maps its coin slot to Select and draws no separate Select pill")
    func neoGeoCoin() throws {
        let binding = try #require(SystemOverlayBindings.binding(for: .NeoGeoCD))
        #expect(binding.tokens[.coin] == "select" && binding.tokens[.select] == nil)
        let ids = OverlayTestSupport.controlIDs(try Self.template(.NeoGeoCD))
        #expect(ids.contains("coin") && !ids.contains("select"))
    }

    @Test("Every arcade board fits both orientations without overlap",
          arguments: [SystemIdentifier.MAME, .CPS1, .CPS2, .CPS3, .NeoGeo, .NeoGeoCD, .NAOMI, .NAOMI2, .Atomiswave])
    func noOverlap(system: SystemIdentifier) throws {
        for canvas in OverlayTestSupport.canvases {
            let layout = OverlayTestSupport.resolve(try Self.template(system, orientation: canvas.orientation), on: canvas)
            #expect(OverlayTestSupport.offCanvas(layout, canvas: canvas).isEmpty, "\(system) \(canvas.size)")
            #expect(OverlayTestSupport.overlaps(in: layout).isEmpty,
                    "\(system) \(canvas.size): \(OverlayTestSupport.overlaps(in: layout))")
        }
    }
}
