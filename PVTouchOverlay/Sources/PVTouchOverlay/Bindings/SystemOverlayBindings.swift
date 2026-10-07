import Foundation
import PVSystems

/// The per-system binding table: which family each controller subtype uses, plus the skin-vocabulary
/// token, on-screen label and palette for each slot.
///
/// Tokens were verified against the system's `PV*Button.init(_:)` and the skin dispatch path
/// (`DeltaSkinInputHandler`, `DeltaSkinNintendoHomeConsoleMapping`); see the Task 8 report.
public enum SystemOverlayBindings {
    public static let phase1Systems: [SystemIdentifier] = [
        .NES, .GB, .GBC, .SNES, .GBA, .Genesis, .Sega32X, .SegaCD, .N64, .PSX, .GameCube, .Wii, .DS
    ]

    public static func binding(for system: SystemIdentifier) -> SystemOverlayBinding? { table[system] }

    private typealias Tokens = [OverlayFamilySlot: String]
    private static let standardSubtype = OverlayPadKind.standardSubtype

    private static let table: [SystemIdentifier: SystemOverlayBinding] = {
        var result: [SystemIdentifier: SystemOverlayBinding] = [:]
        for binding in [twoButton(.NES, palette: .nes), twoButton(.GB, palette: .gameBoy),
                        twoButton(.GBC, palette: .gameBoy), snes, gba, n64, psx, gameCube, wii, nintendoDS]
            + [genesisLike(.Genesis), genesisLike(.Sega32X), genesisLike(.SegaCD)] {
            result[binding.system] = binding
        }
        return result
    }()

    private static func twoButton(_ system: SystemIdentifier, palette: OverlayPalette) -> SystemOverlayBinding {
        SystemOverlayBinding(
            system: system, families: [standardSubtype: TwoButtonFamily.self], defaultSubtype: standardSubtype,
            tokens: [.a: "a", .b: "b", .start: "start", .select: "select"],
            labels: [.a: "A", .b: "B", .start: "START", .select: "SELECT"],
            palette: palette, hardwareSwitches: [])
    }

    private static let fourFaceTokens: Tokens = [
        .a: "a", .b: "b", .x: "x", .y: "y", .l: "l", .r: "r", .start: "start", .select: "select"
    ]
    private static let fourFaceLabels: Tokens = [
        .a: "A", .b: "B", .x: "X", .y: "Y", .l: "L", .r: "R", .start: "START", .select: "SELECT"
    ]

    private static let snes = SystemOverlayBinding(
        system: .SNES, families: [standardSubtype: FourFaceFamily.self], defaultSubtype: standardSubtype,
        tokens: fourFaceTokens, labels: fourFaceLabels, palette: .snes, hardwareSwitches: [])

    private static let nintendoDS = SystemOverlayBinding(
        system: .DS, families: [standardSubtype: DSPadFamily.self], defaultSubtype: standardSubtype,
        tokens: fourFaceTokens, labels: fourFaceLabels, palette: .ds, hardwareSwitches: [])

    private static let gba = SystemOverlayBinding(
        system: .GBA, families: [standardSubtype: GBAFamily.self], defaultSubtype: standardSubtype,
        tokens: [.a: "a", .b: "b", .l: "l", .r: "r", .start: "start", .select: "select"],
        labels: [.a: "A", .b: "B", .l: "L", .r: "R", .start: "START", .select: "SELECT"],
        palette: .gameBoy, hardwareSwitches: [])

    private static func genesisLike(_ system: SystemIdentifier) -> SystemOverlayBinding {
        SystemOverlayBinding(
            system: system,
            families: ["genesis-3btn": ThreeFaceFamily.self, "genesis-6btn": SixFaceFamily.self],
            defaultSubtype: "genesis-3btn",
            tokens: [.a: "a", .b: "b", .c: "c", .x: "x", .y: "y", .z: "z", .start: "start", .select: "mode"],
            labels: [.a: "A", .b: "B", .c: "C", .x: "X", .y: "Y", .z: "Z", .start: "START", .select: "MODE"],
            palette: .genesis, hardwareSwitches: [])
    }

    private static let n64 = SystemOverlayBinding(
        system: .N64, families: [standardSubtype: N64Family.self], defaultSubtype: standardSubtype,
        tokens: [.a: "a", .b: "b", .z: "z", .l: "l", .r: "r", .start: "start",
                 .cUp: "cUp", .cDown: "cDown", .cLeft: "cLeft", .cRight: "cRight"],
        labels: [.a: "A", .b: "B", .z: "Z", .l: "L", .r: "R", .start: "START",
                 .cUp: "C▲", .cDown: "C▼", .cLeft: "C◀", .cRight: "C▶"],
        palette: .n64, hardwareSwitches: [])

    private static let psx = SystemOverlayBinding(
        system: .PSX,
        families: ["psx-digital": DigitalPadFamily.self, "psx-dualshock": DualStickFamily.self],
        defaultSubtype: "psx-dualshock",
        tokens: [.a: "cross", .b: "circle", .x: "triangle", .y: "square", .l: "l1", .r: "r1",
                 .l2: "l2", .r2: "r2", .l3: "l3", .r3: "r3", .start: "start", .select: "select"],
        labels: [.a: "✕", .b: "○", .x: "△", .y: "□", .l: "L1", .r: "R1", .l2: "L2", .r2: "R2",
                 .l3: "L3", .r3: "R3", .start: "START", .select: "SELECT"],
        palette: .playStation, hardwareSwitches: [])

    // GameCube: "l"/"r"/"z" resolve identically through PVGCButton and the skin table.
    private static let gameCube = SystemOverlayBinding(
        system: .GameCube,
        families: ["gc-standard": GameCubeFamily.self, "gc-bongos": GameCubeFamily.self,
                   "gc-keyboard": GameCubeFamily.self],
        defaultSubtype: "gc-standard",
        tokens: [.a: "a", .b: "b", .x: "x", .y: "y", .z: "z", .l: "l", .r: "r", .start: "start"],
        labels: [.a: "A", .b: "B", .x: "X", .y: "Y", .z: "Z", .l: "L", .r: "R", .start: "START"],
        palette: .gameCube, hardwareSwitches: [])

    // Wii: the Wiimote/Nunchuk tokens resolve identically through PVWiiMoteButton and the skin table.
    // Classic / Classic Pro are not bound in Phase 1: the Dolphin bridge's skin path has no Classic routing,
    // so `WiiClassicFamily` waits for Phase 2 (see DeltaSkinNintendoHomeConsoleMapping.wiiButton).
    private static let wii = SystemOverlayBinding(
        system: .Wii,
        families: ["wii-wiimote": WiiRemoteSidewaysFamily.self, "wii-wiimote-nunchuck": WiiRemoteFamily.self],
        defaultSubtype: "wii-wiimote-nunchuck",
        tokens: [.a: "a", .b: "b", .one: "1", .two: "2", .plus: "+", .minus: "-", .home: "home",
                 .c: "c", .z: "z"],
        labels: [.a: "A", .b: "B", .one: "1", .two: "2", .plus: "+", .minus: "−", .home: "⌂", .c: "C", .z: "Z"],
        palette: .wii, hardwareSwitches: [])
}
