import Foundation
import Testing
import PVSystems
@testable import PVTouchOverlay

/// Batch 3: computers, handhelds and 8-bit consoles.
@Suite("Batch 3 bindings")
struct Batch3BindingTests {
    private static func binding(_ system: SystemIdentifier) throws -> SystemOverlayBinding {
        try #require(SystemOverlayBindings.binding(for: system))
    }

    private static func template(_ system: SystemIdentifier,
                                 _ orientation: OverlayOrientation = .portrait) throws -> OverlayTemplate {
        try binding(system).template(padKind: OverlayPadKind(system: system, subtype: OverlayPadKind.standardSubtype),
                                     orientation: orientation)
    }

    private static func controls(_ system: SystemIdentifier,
                                 _ orientation: OverlayOrientation = .portrait) throws -> [OverlayControl] {
        try template(system, orientation).groups.flatMap(\.controls)
    }

    private static func ids(_ system: SystemIdentifier,
                            _ orientation: OverlayOrientation = .portrait) throws -> Set<String> {
        Set(try controls(system, orientation).map(\.id))
    }

    private static func label(_ system: SystemIdentifier, _ id: String) throws -> String? {
        try controls(system).first { $0.id == id }?.label
    }

    // MARK: Families

    @Test("Each batch 3 system binds the family the table names")
    func families() throws {
        let expected: [(SystemIdentifier, String)] = [
            (.DOS, DigitalPadFamily.id), (.Quake, DigitalPadFamily.id), (.Quake2, DigitalPadFamily.id),
            (.DOOM, DigitalPadFamily.id), (.Wolf3D, DigitalPadFamily.id), (.TIC80, FourFaceFamily.id),
            (._3DO, SixFaceFamily.id), (.PokemonMini, ThreeFaceFamily.id)
        ]
        for (system, family) in expected {
            let binding = try Self.binding(system)
            #expect(binding.family(for: binding.defaultSubtype).id == family, "\(system)")
        }
        let twoButton: [SystemIdentifier] = [
            .C64, .MSX, .MSX2, .Atari8bit, .AtariST, .ZXSpectrum, .EP128, .PC98, .Macintosh, .PalmOS, .AppleII,
            .Lynx, .MegaDuck, .Supervision, .GameGear, .MasterSystem, .SG1000, .FDS
        ]
        for system in twoButton {
            let binding = try Self.binding(system)
            #expect(binding.family(for: binding.defaultSubtype).id == TwoButtonFamily.id, "\(system)")
        }
    }

    // MARK: Hidden slots and labels

    @Test("Single-fire computers draw a d-pad and one FIRE button, nothing else")
    func singleFire() throws {
        for system in [SystemIdentifier.C64, .ZXSpectrum, .Macintosh, .PalmOS, .AppleII, .AtariST] {
            #expect(try Self.ids(system) == ["dpad", "a"], "\(system)")
            #expect(try Self.label(system, "a") == "FIRE", "\(system)")
        }
    }

    @Test("MSX, MSX2, EP128 and PC-98 draw two fire buttons, Select and Start")
    func twoFire() throws {
        for system in [SystemIdentifier.MSX, .MSX2, .EP128, .PC98] {
            #expect(try Self.ids(system) == ["dpad", "a", "b", "start", "select"], "\(system)")
        }
    }

    @Test("Atari 8-bit draws fire, Start and Select; Option would duplicate Select in the thin core")
    func atari8bit() throws {
        #expect(try Self.ids(.Atari8bit) == ["dpad", "a", "start", "select"])
    }

    @Test("DOS, Quake and Quake 2 draw A B X, both shoulders and triggers; no Y")
    func dosPads() throws {
        for system in [SystemIdentifier.DOS, .Quake, .Quake2] {
            let ids = try Self.ids(system, .landscape)
            #expect(ids.isSuperset(of: ["dpad", "a", "b", "x", "l", "r", "l2", "r2", "start", "select"]), "\(system)")
            #expect(!ids.contains("y"), "\(system)")
        }
    }

    @Test("DOOM draws the PrBoom actions on the RetroPad diamond")
    func doom() throws {
        let controls = try Self.controls(.DOOM, .landscape)
        func label(_ id: String) -> String? { controls.first { $0.id == id }?.label }
        #expect(label("a") == "USE" && label("b") == "STR" && label("x") == "FIRE" && label("y") == "RUN")
        #expect(label("select") == "MAP" && label("start") == "PAUSE")
    }

    @Test("Wolf3D start is the menu and is not the pause-menu token")
    func wolf3D() throws {
        let binding = try Self.binding(.Wolf3D)
        #expect(binding.tokens[.start] == "start" && binding.label(.start) == "MENU")
        #expect(binding.tokens.values.allSatisfy { !$0.lowercased().contains("menu") })
    }

    @Test("TIC-80 draws A B X Y, Start and Select, no shoulders")
    func tic80() throws {
        let ids = try Self.ids(.TIC80)
        #expect(ids == ["dpad", "a", "b", "x", "y", "start", "select"])
    }

    @Test("Lynx draws A B, Option 1, Option 2 and Pause, with no flip action and a normal orientation")
    func lynx() throws {
        let binding = try Self.binding(.Lynx)
        #expect(!binding.landscapeOnly && binding.actions.isEmpty)
        #expect(try Self.ids(.Lynx) == ["dpad", "a", "b", "start", "select", "reset"])
        #expect(try Self.label(.Lynx, "start") == "OPT 1" && Self.label(.Lynx, "select") == "OPT 2")
        #expect(try Self.label(.Lynx, "reset") == "PAUSE")
        #expect(try Self.template(.Lynx, .portrait).orientation == .portrait)
    }

    @Test("Game Gear, Master System and SG-1000 draw 1 left of 2 and Start; no Select")
    func segaEightBit() throws {
        for system in [SystemIdentifier.GameGear, .MasterSystem, .SG1000] {
            let all = try Self.controls(system)
            #expect(Set(all.map(\.id)) == ["dpad", "a", "b", "start"], "\(system)")
            let one = try #require(all.first { $0.id == "b" }), two = try #require(all.first { $0.id == "a" })
            #expect(one.label == "1" && two.label == "2" && one.frame.minX < two.frame.minX, "\(system)")
        }
        #expect(try Self.label(.MasterSystem, "start") == "PAUSE")
        #expect(try Self.label(.GameGear, "start") == "START")
    }

    @Test("Pokemon Mini draws A B C and a MENU pill")
    func pokemonMini() throws {
        #expect(try Self.ids(.PokemonMini) == ["dpad", "a", "b", "c", "start"])
        #expect(try Self.label(.PokemonMini, "start") == "MENU")
    }

    @Test("3DO draws A B C, L R, P and X")
    func threeDO() throws {
        let ids = try Self.ids(._3DO)
        #expect(ids.isSuperset(of: ["dpad", "a", "b", "c", "l", "r", "start", "select"]))
        #expect(ids.isDisjoint(with: ["x", "y", "z"]))
    }

    @Test("FDS and Mega Duck share the NES and Game Boy pads; FDS has no disk action")
    func plainPads() throws {
        for system in [SystemIdentifier.FDS, .MegaDuck, .Supervision] {
            #expect(try Self.ids(system) == ["dpad", "a", "b", "start", "select"], "\(system)")
            #expect(try Self.binding(system).actions.isEmpty, "\(system)")
        }
        #expect(try Self.binding(.FDS).palette == .nes)
        #expect(try Self.binding(.MegaDuck).palette == .gameBoy)
    }

    // MARK: Palettes and policy

    @Test("Palettes follow the table")
    func palettes() throws {
        let computers: [SystemIdentifier] = [
            .DOS, .DOOM, .Wolf3D, .Quake, .Quake2, .C64, .MSX, .MSX2, .Atari8bit, .AtariST, .EP128, .PC98,
            .Macintosh, .PalmOS, .AppleII
        ]
        for system in computers { #expect(try Self.binding(system).palette == .computer, "\(system)") }
        #expect(try Self.binding(.ZXSpectrum).palette == .zxSpectrum)
        #expect(try Self.binding(.TIC80).palette == .tic80)
        #expect(try Self.binding(.Lynx).palette == .lynx)
        for system in [SystemIdentifier.GameGear, .MasterSystem, .SG1000] {
            #expect(try Self.binding(system).palette == .genesis, "\(system)")
        }
        for system in [SystemIdentifier.PokemonMini, .Supervision] {
            #expect(try Self.binding(system).palette == .gameBoy, "\(system)")
        }
    }

    @Test("No batch 3 system forces landscape; each keeps the top band in portrait")
    func topBand() throws {
        for system in SystemOverlayBindings.batch3Systems {
            let binding = try Self.binding(system)
            #expect(!binding.landscapeOnly && binding.landscapeOnlySubtypes.isEmpty, "\(system)")
            #expect(try Self.template(system, .portrait).screenPolicy == .topBand, "\(system)")
        }
    }

    @Test("The binding lists do not overlap")
    func listsDisjoint() {
        let lists = [SystemOverlayBindings.phase1Systems, SystemOverlayBindings.batch1Systems,
                     SystemOverlayBindings.batch2Systems, SystemOverlayBindings.batch3Systems]
        #expect(Set(lists.flatMap { $0 }).count == lists.map(\.count).reduce(0, +))
    }
}
