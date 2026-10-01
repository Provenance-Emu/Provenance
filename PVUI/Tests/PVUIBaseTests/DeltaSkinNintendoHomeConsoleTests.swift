//
//  DeltaSkinNintendoHomeConsoleTests.swift
//  PVUIBaseTests
//
//  Manic EMU GameCube / Wii skin support: game-type identifier parsing, the
//  skin-token -> Dolphin button tables, and thumbstick side resolution.
//

import Foundation
import Testing
import PVCoreBridge
import PVPrimitives
@testable import PVUIBase

@Suite("Manic GameCube / Wii identifiers")
struct ManicGameCubeWiiIdentifierTests {

    @Test("Manic GameCube id parses to .gamecube", arguments: [
        "public.aoshuang.game.ngc",
        "PUBLIC.AOSHUANG.GAME.NGC",
        "ngc", "gc", "gcn", "gamecube", "GameCube", "game-cube", "nintendo gamecube"
    ])
    func gameCubeParses(raw: String) {
        #expect(DeltaSkinGameType.fromAnyString(raw) == .gamecube)
    }

    @Test("Manic Wii id parses to .wii", arguments: [
        "public.aoshuang.game.wii", "wii", "Wii"
    ])
    func wiiParses(raw: String) {
        #expect(DeltaSkinGameType.fromAnyString(raw) == .wii)
    }

    @Test("Manic identifier strings use Manic's real slugs")
    func manicIdentifierStrings() {
        #expect(DeltaSkinGameType.gamecube.manicIdentifierString == "public.aoshuang.game.ngc")
        #expect(DeltaSkinGameType.wii.manicIdentifierString == "public.aoshuang.game.wii")
        #expect(DeltaSkinGameType.gamecube.deltaIdentifierString == nil)
        #expect(DeltaSkinGameType.wii.deltaIdentifierString == nil)
    }

    @Test("Every Manic id round-trips through its own manicIdentifierString")
    func manicRoundTrip() {
        for type in [DeltaSkinGameType.gamecube, .wii] {
            let id = type.manicIdentifierString
            #expect(id != nil)
            #expect(DeltaSkinGameType.fromAnyString(id ?? "") == type)
        }
    }

    @Test("Codable decodes the Manic id and re-encodes to it")
    func codableRoundTrip() throws {
        let json = Data(#""public.aoshuang.game.ngc""#.utf8)
        let decoded = try JSONDecoder().decode(DeltaSkinGameType.self, from: json)
        #expect(decoded == .gamecube)
        let reencoded = try JSONDecoder().decode(DeltaSkinGameType.self, from: JSONEncoder().encode(decoded))
        #expect(reencoded == .gamecube)
    }

    @Test("matchesIdentifier accepts the Manic slug")
    func matchesSlug() {
        #expect(DeltaSkinGameType.gamecube.matchesIdentifier("ngc"))
        #expect(DeltaSkinGameType.gamecube.matchesIdentifier("gamecube"))
        #expect(DeltaSkinGameType.wii.matchesIdentifier("wii"))
        #expect(!DeltaSkinGameType.wii.matchesIdentifier("ngc"))
    }

    @Test("GameCube and Wii map to their SystemIdentifier and back")
    func systemIdentifierMapping() {
        #expect(DeltaSkinGameType(systemIdentifier: .GameCube) == .gamecube)
        #expect(DeltaSkinGameType(systemIdentifier: .Wii) == .wii)
        #expect(DeltaSkinGameType.gamecube.systemIdentifier == .GameCube)
        #expect(DeltaSkinGameType.wii.systemIdentifier == .Wii)
    }

    @Test("Existing short codes still resolve (no regression)")
    func noRegression() {
        #expect(DeltaSkinGameType.fromAnyString("public.aoshuang.game.ps1") == .psx)
        #expect(DeltaSkinGameType.fromAnyString("ng") == .neogeo)
        #expect(DeltaSkinGameType.fromAnyString("ngp") == .ngp)
    }
}

@Suite("GameCube skin token mapping")
struct GameCubeSkinTokenTests {

    @Test("Manic pocket skin: r1 = Z, l2 = L, r2 = R")
    func manicTriggerLayout() {
        #expect(DeltaSkinNintendoHomeConsoleMapping.gameCubeButton(forSkinToken: "r1") == .z)
        #expect(DeltaSkinNintendoHomeConsoleMapping.gameCubeButton(forSkinToken: "l2") == .l)
        #expect(DeltaSkinNintendoHomeConsoleMapping.gameCubeButton(forSkinToken: "r2") == .r)
    }

    @Test("Face buttons, start and D-pad map to themselves")
    func basics() {
        let expected: [(String, PVGCButton)] = [
            ("a", .a), ("b", .b), ("x", .x), ("y", .y), ("start", .start),
            ("up", .up), ("down", .down), ("left", .left), ("right", .right)
        ]
        for (token, button) in expected {
            #expect(DeltaSkinNintendoHomeConsoleMapping.gameCubeButton(forSkinToken: token) == button)
        }
    }

    @Test("Tokens are case-insensitive")
    func caseInsensitive() {
        #expect(DeltaSkinNintendoHomeConsoleMapping.gameCubeButton(forSkinToken: "R1") == .z)
    }

    @Test("Controls the pad lacks are unmapped, not defaulted to A")
    func unmapped() {
        for token in ["select", "l3", "r3", "bogus", "quicksave"] {
            #expect(DeltaSkinNintendoHomeConsoleMapping.gameCubeButton(forSkinToken: token) == nil)
        }
    }
}

@Suite("Wii skin token mapping")
struct WiiSkinTokenTests {

    @Test("Wiimote + Nunchuk scheme")
    func wiimoteNunchuk() {
        let expected: [(String, PVWiiMoteButton)] = [
            ("a", .wiiA), ("b", .wiiB), ("x", .wiiOne), ("y", .wiiTwo),
            ("start", .wiiPlus), ("select", .wiiMinus),
            ("up", .wiiDPadUp), ("down", .wiiDPadDown), ("left", .wiiDPadLeft), ("right", .wiiDPadRight),
            ("l1", .nunchukC), ("l2", .nunchukC), ("c", .nunchukC),
            ("r1", .nunchukZ), ("r2", .nunchukZ), ("z", .nunchukZ),
            ("r3", .wiiHome)
        ]
        for (token, button) in expected {
            #expect(DeltaSkinNintendoHomeConsoleMapping.wiiButton(forSkinToken: token) == button)
        }
    }

    @Test("Unmapped tokens return nil instead of reaching the bridge's Home default")
    func unmapped() {
        for token in ["l3", "bogus", "quicksave"] {
            #expect(DeltaSkinNintendoHomeConsoleMapping.wiiButton(forSkinToken: token) == nil)
        }
    }
}

@Suite("Thumbstick side resolution")
struct ThumbstickSideTests {

    private let skinId = "starvingartist.ngc.gcpocket-indigo-button-1"

    @Test("Manic leftThumbstick* mapping resolves left")
    func left() {
        let input = DeltaSkinInput.directional([
            "up": "leftThumbstickUp", "down": "leftThumbstickDown",
            "left": "leftThumbstickLeft", "right": "leftThumbstickRight"
        ])
        #expect(DeltaSkinNintendoHomeConsoleMapping.stickSide(for: input, buttonId: skinId) == .left)
    }

    @Test("Manic rightThumbstick* mapping resolves right even though the id never says so")
    func right() {
        let input = DeltaSkinInput.directional([
            "up": "rightThumbstickUp", "down": "rightThumbstickDown",
            "left": "rightThumbstickLeft", "right": "rightThumbstickRight"
        ])
        let side = DeltaSkinNintendoHomeConsoleMapping.stickSide(for: input, buttonId: skinId)
        #expect(side == .right)
        #expect(side.analogStickId == "rightAnalog")
    }

    @Test("A plain D-pad mapping is not mistaken for a right stick")
    func dpadIsNotRight() {
        let input = DeltaSkinInput.directional(["up": "up", "down": "down", "left": "left", "right": "right"])
        #expect(DeltaSkinNintendoHomeConsoleMapping.stickSide(for: input, buttonId: skinId) == .left)
    }

    @Test("Falls back to the button id when the mapping carries no stick name")
    func idFallback() {
        let input = DeltaSkinInput.single("a")
        #expect(DeltaSkinNintendoHomeConsoleMapping.stickSide(for: input, buttonId: "rightstick") == .right)
        #expect(DeltaSkinNintendoHomeConsoleMapping.stickSide(for: input, buttonId: "leftstick") == .left)
    }
}
