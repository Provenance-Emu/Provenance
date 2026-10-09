import Foundation
import PVSystems

/// The per-system binding table: which family each controller subtype uses, plus the skin-vocabulary
/// token, on-screen label and palette for each slot.
///
/// Tokens were verified against the system's `PV*Button.init(_:)` and the skin dispatch path
/// (`DeltaSkinInputHandler`, `DeltaSkinNintendoHomeConsoleMapping`); see the Task 8 report.
public enum SystemOverlayBindings {
    public static let phase1Systems: [SystemIdentifier] = [
        .NES, .GB, .GBC, .SNES, .GBA, .Genesis, .Sega32X, .SegaCD, .N64, .PSX, .GameCube, .Wii, .DS, ._3DS
    ]

    /// Keypad, arcade and Atari systems added with the console-style default overlays (batch 1).
    public static let batch1Systems: [SystemIdentifier] = [
        .Atari2600, .Atari5200, .Atari7800, .AtariJaguar, .AtariJaguarCD, .ColecoVision, .Intellivision,
        .MAME, .CPS1, .CPS2, .CPS3, .NeoGeo, .NeoGeoCD, .NAOMI, .NAOMI2, .Atomiswave
    ]

    /// Sega, NEC, SNK, Sony and the smaller consoles added with the console-style default overlays (batch 2).
    public static let batch2Systems: [SystemIdentifier] = [
        .Saturn, .Dreamcast, .PCE, .SGFX, .PCECD, .PCFX, .NGP, .NGPC, .WonderSwan, .WonderSwanColor,
        .PS2, .PS3, .PSP, .CDi, .Vectrex, .Odyssey2, .VirtualBoy
    ]

    /// Every system with a binding.
    public static let boundSystems: [SystemIdentifier] = phase1Systems + batch1Systems + batch2Systems

    public static func binding(for system: SystemIdentifier) -> SystemOverlayBinding? { table[system] }

    private typealias Tokens = [OverlayFamilySlot: String]
    private static let standardSubtype = OverlayPadKind.standardSubtype

    private static let table: [SystemIdentifier: SystemOverlayBinding] = {
        var result: [SystemIdentifier: SystemOverlayBinding] = [:]
        for binding in [twoButton(.NES, palette: .nes), twoButton(.GB, palette: .gameBoy),
                        twoButton(.GBC, palette: .gameBoy), snes, gba, n64, psx, gameCube, wii, nintendoDS,
                        nintendo3DS]
            + [genesisLike(.Genesis), genesisLike(.Sega32X), genesisLike(.SegaCD)]
            + [atari2600, atari5200, atari7800, jaguar(.AtariJaguar), jaguar(.AtariJaguarCD), colecoVision,
               intellivision, mame, neoGeo(.NeoGeo, coinLabel: "COIN"), neoGeo(.NeoGeoCD, coinLabel: "SELECT")]
            + [capcom(.CPS1), capcom(.CPS2), capcom(.CPS3)]
            + [segaArcade(.NAOMI), segaArcade(.NAOMI2), segaArcade(.Atomiswave)]
            + [saturn, dreamcast, pcEngine(.PCE), pcEngine(.SGFX), pcEngine(.PCECD), pcFX]
            + [neoGeoPocket(.NGP), neoGeoPocket(.NGPC), wonderSwan(.WonderSwan), wonderSwan(.WonderSwanColor)]
            + [playStation2(.PS2), playStation2(.PS3), psp, cdi, vectrex, odyssey2, virtualBoy] {
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

    private static let nintendo3DS = SystemOverlayBinding(
        system: ._3DS, families: [standardSubtype: N3DSPadFamily.self], defaultSubtype: standardSubtype,
        tokens: fourFaceTokens, labels: fourFaceLabels, palette: .ds, hardwareSwitches: [])

    private static let gba = SystemOverlayBinding(
        system: .GBA, families: [standardSubtype: GBAFamily.self], defaultSubtype: standardSubtype,
        tokens: [.a: "a", .b: "b", .l: "l", .r: "r", .start: "start", .select: "select"],
        labels: [.a: "A", .b: "B", .l: "L", .r: "R", .start: "START", .select: "SELECT"],
        palette: .gameBoy, hardwareSwitches: [])

    // Default is the 6-button pad: it is a superset of the core's "Joypad Auto", so an untouched
    // game is drawn with every button it might use and the host never pushes a device for it.
    private static func genesisLike(_ system: SystemIdentifier) -> SystemOverlayBinding {
        SystemOverlayBinding(
            system: system,
            families: ["genesis-3btn": ThreeFaceFamily.self, "genesis-6btn": SixFaceFamily.self],
            defaultSubtype: "genesis-6btn",
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
    // Bongos and keyboard have no pad of their own yet, so only the standard controller is bound.
    private static let gameCube = SystemOverlayBinding(
        system: .GameCube,
        families: ["gc-standard": GameCubeFamily.self],
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

    // MARK: - Batch 1: keypad, arcade and Atari
    //
    // Every token below is the system button enum's own spelling (`controllerType.init(token)`), which the
    // handler's normaliser passes through; BindingTokenResolutionTests pins each one.
    //
    // "reset" is never a token: `DeltaSkinInputHandler.buttonPressed` treats it as "restart the game".
    // The 5200 and 7800 console reset button is "r" (`PV5200Button` / `PV7800Button`), and the 2600's is "start".

    /// Keypad keys 1-9, 0, * and #, labelled by their digit.
    private static let digitKeys: Tokens = [
        .k1: "1", .k2: "2", .k3: "3", .k4: "4", .k5: "5", .k6: "6", .k7: "7", .k8: "8", .k9: "9", .k0: "0",
        .kStar: "*", .kPound: "#"
    ]
    private static let digitLabels: Tokens = [
        .k1: "1", .k2: "2", .k3: "3", .k4: "4", .k5: "5", .k6: "6", .k7: "7", .k8: "8", .k9: "9", .k0: "0",
        .kStar: "*", .kPound: "#"
    ]

    /// Joystick, fire button, the console's RESET and SELECT, and the three console switches.
    /// The 2600 paddle is not bound: no layout variant selects it and Stella gets no paddle device.
    private static let atari2600 = SystemOverlayBinding(
        system: .Atari2600, families: [standardSubtype: TwoButtonFamily.self], defaultSubtype: standardSubtype,
        tokens: [.a: "fire1", .start: "start", .select: "select"],
        labels: [.a: "FIRE", .start: "RESET", .select: "SELECT"],
        palette: .atari, hardwareSwitches: ["left_diff", "right_diff", "color_bw"])

    private static let atari5200 = SystemOverlayBinding(
        system: .Atari5200,
        families: ["5200-joystick": KeypadFamily.self, "5200-joystick-only": TwoButtonFamily.self],
        defaultSubtype: "5200-joystick",
        tokens: digitKeys.merging([.a: "fire1", .b: "fire2", .start: "start", .select: "pause", .reset: "r"]) { $1 },
        labels: digitLabels.merging([.a: "F1", .b: "F2", .start: "START", .select: "PAUSE", .reset: "RESET"]) { $1 },
        palette: .atari, hardwareSwitches: [])

    private static let atari7800 = SystemOverlayBinding(
        system: .Atari7800, families: [standardSubtype: TwoButtonFamily.self], defaultSubtype: standardSubtype,
        tokens: [.a: "fire1", .b: "fire2", .start: "pause", .select: "select", .reset: "r"],
        labels: [.a: "FIRE", .b: "FIRE", .start: "PAUSE", .select: "SELECT", .reset: "RESET"],
        palette: .atari, hardwareSwitches: [])

    /// Jaguar and Jaguar CD share `PVJaguarButton`: A B C, Option, Pause and the keypad.
    private static func jaguar(_ system: SystemIdentifier) -> SystemOverlayBinding {
        SystemOverlayBinding(
            system: system, families: [standardSubtype: KeypadFamily.self], defaultSubtype: standardSubtype,
            tokens: digitKeys.merging([.a: "a", .b: "b", .c: "c", .start: "pause", .select: "option"]) { $1 },
            labels: digitLabels.merging([.a: "A", .b: "B", .c: "C", .start: "PAUSE", .select: "OPTION"]) { $1 },
            palette: .atari, hardwareSwitches: [])
    }

    private static let colecoVision = SystemOverlayBinding(
        system: .ColecoVision, families: [standardSubtype: KeypadFamily.self], defaultSubtype: standardSubtype,
        tokens: digitKeys.merging([.a: "leftAction", .b: "rightAction"]) { $1 },
        labels: digitLabels.merging([.a: "FIRE", .b: "FIRE"]) { $1 },
        palette: .coleco, hardwareSwitches: [])

    /// The disc is the d-pad; the keypad's bottom row is CLEAR, 0 and ENTER.
    private static let intellivision = SystemOverlayBinding(
        system: .Intellivision, families: [standardSubtype: KeypadFamily.self], defaultSubtype: standardSubtype,
        tokens: digitKeys.merging([.a: "topAction", .b: "bottomLeftAction", .c: "bottomRightAction",
                                   .kStar: "clear", .kPound: "enter"]) { $1 },
        labels: digitLabels.merging([.a: "T", .b: "L", .c: "R", .kStar: "CLR", .kPound: "ENT"]) { $1 },
        palette: .intellivision, hardwareSwitches: [])

    /// RetroPad order on the arcade panel: Y X L over B A R (`PVThinLibretroCore.mameMap`).
    private static let mame = SystemOverlayBinding(
        system: .MAME, families: [standardSubtype: ArcadeStickFamily.self], defaultSubtype: standardSubtype,
        tokens: sixButtonTokens(top: ["square", "triangle", "l1"], bottom: ["cross", "circle", "r1"]),
        labels: sixButtonLabels(top: ["4", "5", "6"], bottom: ["1", "2", "3"]),
        palette: .arcade, hardwareSwitches: [], actions: [.service])

    private static func capcom(_ system: SystemIdentifier) -> SystemOverlayBinding {
        SystemOverlayBinding(
            system: system, families: [standardSubtype: ArcadeStickFamily.self], defaultSubtype: standardSubtype,
            tokens: sixButtonTokens(top: ["square", "triangle", "l1"], bottom: ["cross", "circle", "r1"]),
            labels: sixButtonLabels(top: ["LP", "MP", "HP"], bottom: ["LK", "MK", "HK"]),
            palette: .capcom, hardwareSwitches: [])
    }

    /// A B C D on one row. `PVNeoGeoButton` has no coin: the libretro cores read the pad's Select as the coin
    /// slot, so the coin slot carries "select" and the Select slot stays hidden.
    private static func neoGeo(_ system: SystemIdentifier, coinLabel: String) -> SystemOverlayBinding {
        SystemOverlayBinding(
            system: system, families: [standardSubtype: ArcadeStickFamily.self], defaultSubtype: standardSubtype,
            tokens: [.a: "triangle", .b: "circle", .c: "cross", .x: "square", .coin: "select", .start: "start"],
            labels: [.a: "A", .b: "B", .c: "C", .x: "D", .coin: coinLabel, .start: "START"],
            palette: .neoGeo, hardwareSwitches: [])
    }

    /// NAOMI, NAOMI 2 and Atomiswave run the Dreamcast core: A B R over X Y L, plus `PVDreamcastButton.coin`.
    private static func segaArcade(_ system: SystemIdentifier) -> SystemOverlayBinding {
        SystemOverlayBinding(
            system: system, families: [standardSubtype: ArcadeStickFamily.self], defaultSubtype: standardSubtype,
            tokens: [.a: "a", .b: "b", .c: "r", .x: "x", .y: "y", .z: "l", .coin: "coin", .start: "start"],
            labels: [.a: "A", .b: "B", .c: "R", .x: "X", .y: "Y", .z: "L", .coin: "COIN", .start: "START"],
            palette: .dreamcast, hardwareSwitches: [])
    }

    private static let arcadeTail: Tokens = [.coin: "coin", .start: "start"]
    private static let arcadeTailLabels: Tokens = [.coin: "COIN", .start: "START"]

    private static func sixButtonTokens(top: [String], bottom: [String]) -> Tokens {
        let slots: [OverlayFamilySlot] = [.x, .y, .z, .a, .b, .c]
        return arcadeTail.merging(Dictionary(uniqueKeysWithValues: zip(slots, top + bottom))) { $1 }
    }

    private static func sixButtonLabels(top: [String], bottom: [String]) -> Tokens {
        let slots: [OverlayFamilySlot] = [.x, .y, .z, .a, .b, .c]
        return arcadeTailLabels.merging(Dictionary(uniqueKeysWithValues: zip(slots, top + bottom))) { $1 }
    }

    // MARK: - Batch 2: Sega, NEC, SNK, Sony and the smaller consoles
    //
    // Same rule as batch 1: every token is the system button enum's own spelling, pinned by
    // BindingTokenResolutionTests. Slots a system has no button for get no token and are hidden.

    /// The six numbered buttons of a PC Engine / PC-FX pad. Bottom row I II III, top row IV V VI.
    private static let numberedFaceTokens: Tokens = [
        .a: "button1", .b: "button2", .c: "button3", .x: "button4", .y: "button5", .z: "button6",
        .start: "run", .select: "select"
    ]
    private static let numberedFaceLabels: Tokens = [
        .a: "I", .b: "II", .c: "III", .x: "IV", .y: "V", .z: "VI", .start: "RUN", .select: "SELECT"
    ]

    private static let saturn = SystemOverlayBinding(
        system: .Saturn, families: [standardSubtype: SixFaceFamily.self], defaultSubtype: standardSubtype,
        tokens: [.a: "a", .b: "b", .c: "c", .x: "x", .y: "y", .z: "z", .l: "l", .r: "r", .start: "start"],
        labels: [.a: "A", .b: "B", .c: "C", .x: "X", .y: "Y", .z: "Z", .l: "L", .r: "R", .start: "START"],
        palette: .saturn, hardwareSwitches: [])

    /// The standard pad has the analog stick, d-pad and triggers; the arcade stick draws A B X Y. The
    /// triggers are `PVDreamcastButton.l` / `.r` (there is no l2 / r2 case).
    private static let dreamcast = SystemOverlayBinding(
        system: .Dreamcast,
        families: ["dreamcast-standard": FourFaceFamily.self, "dreamcast-arcade": ArcadeStickFamily.self],
        defaultSubtype: "dreamcast-standard",
        tokens: [.a: "a", .b: "b", .x: "x", .y: "y", .l: "l", .r: "r", .start: "start"],
        labels: [.a: "A", .b: "B", .x: "X", .y: "Y", .l: "L", .r: "R", .start: "START"],
        palette: .dreamcast, hardwareSwitches: [],
        leftStick: true, analogShoulders: true, faceArrangement: .dreamcast)

    /// PCE, SuperGrafx and PC Engine CD: Run is "run" (the enums' "start" alias is not in `PVPCFXButton`).
    private static func pcEngine(_ system: SystemIdentifier) -> SystemOverlayBinding {
        SystemOverlayBinding(
            system: system, families: ["pce-2btn": TwoButtonFamily.self, "pce-6btn": SixFaceFamily.self],
            defaultSubtype: "pce-2btn", tokens: numberedFaceTokens, labels: numberedFaceLabels,
            palette: .pcEngine, hardwareSwitches: [])
    }

    private static let pcFX = SystemOverlayBinding(
        system: .PCFX, families: [standardSubtype: SixFaceFamily.self], defaultSubtype: standardSubtype,
        tokens: numberedFaceTokens, labels: numberedFaceLabels, palette: .pcEngine, hardwareSwitches: [])

    /// `PVNGPButton` has no start: Option is the one system button.
    private static func neoGeoPocket(_ system: SystemIdentifier) -> SystemOverlayBinding {
        SystemOverlayBinding(
            system: system, families: [standardSubtype: TwoButtonFamily.self], defaultSubtype: standardSubtype,
            tokens: [.a: "a", .b: "b", .start: "option"], labels: [.a: "A", .b: "B", .start: "OPTION"],
            palette: .neoGeoPocket, hardwareSwitches: [])
    }

    /// The d-pad is the X cluster (x1 up, x2 right, x3 down, x4 left) and the second d-pad the Y cluster,
    /// as in `PVThinLibretroCore.wsMap`. Vertical is drawn sideways: both d-pads flank a tall picture.
    private static func wonderSwan(_ system: SystemIdentifier) -> SystemOverlayBinding {
        SystemOverlayBinding(
            system: system,
            families: ["ws-horizontal": DualDPadFamily.self, "ws-vertical": DualDPadFamily.self],
            defaultSubtype: "ws-horizontal",
            tokens: [.a: "a", .b: "b", .start: "start", .select: "sound",
                     .dpad2Up: "y1", .dpad2Right: "y2", .dpad2Down: "y3", .dpad2Left: "y4"],
            labels: [.a: "A", .b: "B", .start: "START", .select: "SOUND"],
            palette: .neoGeoPocket, hardwareSwitches: [])
    }

    /// PS2 and PS3 share `PVPS2Button`. Shape names, as for the PSX binding.
    private static func playStation2(_ system: SystemIdentifier) -> SystemOverlayBinding {
        SystemOverlayBinding(
            system: system, families: [standardSubtype: DualStickFamily.self], defaultSubtype: standardSubtype,
            tokens: [.a: "cross", .b: "circle", .x: "triangle", .y: "square", .l: "l1", .r: "r1",
                     .l2: "l2", .r2: "r2", .l3: "l3", .r3: "r3", .start: "start", .select: "select"],
            labels: [.a: "✕", .b: "○", .x: "△", .y: "□", .l: "L1", .r: "R1", .l2: "L2", .r2: "R2",
                     .l3: "L3", .r3: "R3", .start: "START", .select: "SELECT"],
            palette: .playStation, hardwareSwitches: [])
    }

    /// One analog stick, no L2 / R2 / L3 / R3.
    private static let psp = SystemOverlayBinding(
        system: .PSP, families: [standardSubtype: DigitalPadFamily.self], defaultSubtype: standardSubtype,
        tokens: [.a: "cross", .b: "circle", .x: "triangle", .y: "square", .l: "l1", .r: "r1",
                 .start: "start", .select: "select"],
        labels: [.a: "✕", .b: "○", .x: "△", .y: "□", .l: "L", .r: "R", .start: "START", .select: "SELECT"],
        palette: .playStation, hardwareSwitches: [], leftStick: true)

    /// Two buttons side by side, I left and II right. There is no start: `PVCDiButton` maps it to RESET.
    private static let cdi = SystemOverlayBinding(
        system: .CDi, families: [standardSubtype: TwoButtonFamily.self], defaultSubtype: standardSubtype,
        tokens: [.a: "button2", .b: "button1"], labels: [.a: "II", .b: "I"],
        palette: .cdi, hardwareSwitches: [])

    /// Four numbered buttons; the stick is the d-pad (`PVVectrexButton` maps directions to analog). The
    /// picture is tall, so the pad is drawn sideways in either orientation.
    private static let vectrex = SystemOverlayBinding(
        system: .Vectrex, families: [standardSubtype: FourFaceFamily.self], defaultSubtype: standardSubtype,
        tokens: [.a: "button1", .b: "button2", .x: "button3", .y: "button4"],
        labels: [.a: "1", .b: "2", .x: "3", .y: "4"],
        palette: .vectrex, hardwareSwitches: [])

    /// One Action button. The keypad toggle is not offered: the handler has no keyboard action.
    private static let odyssey2 = SystemOverlayBinding(
        system: .Odyssey2, families: [standardSubtype: TwoButtonFamily.self], defaultSubtype: standardSubtype,
        tokens: [.a: "action"], labels: [.a: "ACTION"], palette: .odyssey, hardwareSwitches: [])

    /// Left d-pad, right d-pad (`PVVBButton.rightUp` ...), A B, L R. Always drawn sideways.
    private static let virtualBoy = SystemOverlayBinding(
        system: .VirtualBoy, families: [standardSubtype: DualDPadFamily.self], defaultSubtype: standardSubtype,
        tokens: [.a: "a", .b: "b", .l: "l", .r: "r", .start: "start", .select: "select",
                 .dpad2Up: "rightUp", .dpad2Down: "rightDown", .dpad2Left: "rightLeft", .dpad2Right: "rightRight"],
        labels: [.a: "A", .b: "B", .l: "L", .r: "R", .start: "START", .select: "SELECT"],
        palette: .virtualBoy, hardwareSwitches: [])
}
