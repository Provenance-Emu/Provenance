import Foundation
import PVSystems

/// Batch 3: computers, handhelds and 8-bit consoles. FDS and Mega Duck reuse the NES and Game Boy pads and are
/// built in the main table.
extension SystemOverlayBindings {
    private static let standardSubtype = OverlayPadKind.standardSubtype

    static let batch3Bindings: [SystemOverlayBinding] = [
        dosLike(.DOS), dosLike(.Quake), dosLike(.Quake2), doom, wolf3D, tic80, lynx, atari8bit,
        singleFireComputer(.AtariST), singleFireComputer(.C64),
        singleFireComputer(.ZXSpectrum, palette: .zxSpectrum), singleFireComputer(.Macintosh),
        singleFireComputer(.PalmOS), singleFireComputer(.AppleII),
        twoFireComputer(.MSX), twoFireComputer(.MSX2), twoFireComputer(.EP128), twoFireComputer(.PC98),
        supervision, pokemonMini,
        segaEightBit(.GameGear, startLabel: "START"), segaEightBit(.MasterSystem, startLabel: "PAUSE"),
        segaEightBit(.SG1000, startLabel: "PAUSE"), threeDO
    ]

    //
    // Same rule as batches 1 and 2: every token is the system button enum's own spelling, pinned by
    // Batch3TokenResolutionTests. No pad carries a keyboard or mouse action: `DeltaSkinInputHandler` has no
    // keyboard or mouse token, so the action would be inert. Systems whose core takes only keyboard input
    // still get a fire button, which the thin core maps to a joypad button.

    /// A home computer with one joystick fire button (`PVDOSButton.fire1`).
    private static func singleFireComputer(_ system: SystemIdentifier,
                                           palette: OverlayPalette = .computer) -> SystemOverlayBinding {
        SystemOverlayBinding(
            system: system, families: [standardSubtype: TwoButtonFamily.self], defaultSubtype: standardSubtype,
            tokens: [.a: "fire1"], labels: [.a: "FIRE"], palette: palette, hardwareSwitches: [])
    }

    /// MSX, MSX2, EP128 and PC-98: two fire buttons, Select and Start (`pause`).
    private static func twoFireComputer(_ system: SystemIdentifier) -> SystemOverlayBinding {
        SystemOverlayBinding(
            system: system, families: [standardSubtype: TwoButtonFamily.self], defaultSubtype: standardSubtype,
            tokens: [.a: "fire1", .b: "fire2", .start: "pause", .select: "select"],
            labels: [.a: "1", .b: "2", .start: "START", .select: "SELECT"],
            palette: .computer, hardwareSwitches: [])
    }

    /// Fire, Start and Select. Option is left out: `PVThinLibretroCore` maps both `PVA8Button.optionKey` and
    /// `.selectKey` to RetroPad Select, so an Option pill would only duplicate Select.
    private static let atari8bit = SystemOverlayBinding(
        system: .Atari8bit, families: [standardSubtype: TwoButtonFamily.self], defaultSubtype: standardSubtype,
        tokens: [.a: "fire", .start: "start", .select: "select"],
        labels: [.a: "FIRE", .start: "START", .select: "SELECT"],
        palette: .computer, hardwareSwitches: [])

    /// DOSBox-style pads press `PVDOSButton`s. RetroPad X is `run`; there is no Y.
    private static func dosLike(_ system: SystemIdentifier) -> SystemOverlayBinding {
        SystemOverlayBinding(
            system: system, families: [standardSubtype: DigitalPadFamily.self], defaultSubtype: standardSubtype,
            tokens: [.a: "fire1", .b: "fire2", .x: "run", .l: "strafeleft", .r: "straferight",
                     .l2: "weaponprev", .r2: "weaponnext", .start: "pause", .select: "select"],
            labels: [.a: "A", .b: "B", .x: "X", .l: "L", .r: "R", .l2: "L2", .r2: "R2",
                     .start: "START", .select: "SELECT"],
            palette: .computer, hardwareSwitches: [])
    }

    /// PrBoom's Gamepad Classic: Use south, Strafe east, Fire north, Run west (`PVDoomButton`).
    private static let doom = SystemOverlayBinding(
        system: .DOOM, families: [standardSubtype: DigitalPadFamily.self], defaultSubtype: standardSubtype,
        tokens: [.a: "use", .b: "strafe", .x: "fire", .y: "run", .l: "strafeleft", .r: "straferight",
                 .l2: "weaponprev", .r2: "weaponnext", .start: "pause", .select: "map"],
        labels: [.a: "USE", .b: "STR", .x: "FIRE", .y: "RUN", .l: "STR L", .r: "STR R", .l2: "PREV",
                 .r2: "NEXT", .start: "PAUSE", .select: "MAP"],
        palette: .computer, hardwareSwitches: [])

    /// ECWolf: Fire south, Open east, Run north, Strafe west (`PVWolf3DButton`). Start is the menu; the token is
    /// "start" because "menu" would open the frontend's pause menu.
    private static let wolf3D = SystemOverlayBinding(
        system: .Wolf3D, families: [standardSubtype: DigitalPadFamily.self], defaultSubtype: standardSubtype,
        tokens: [.a: "fire", .b: "open", .x: "run", .y: "strafeon", .l: "strafeleft", .r: "straferight",
                 .l2: "weaponprev", .r2: "weaponnext", .start: "start", .select: "map"],
        labels: [.a: "FIRE", .b: "OPEN", .x: "RUN", .y: "STR", .l: "STR L", .r: "STR R", .l2: "PREV",
                 .r2: "NEXT", .start: "MENU", .select: "MAP"],
        palette: .computer, hardwareSwitches: [])

    /// TIC-80: A B X Y, Start, Select. The handler routes it through `PVTIC80Button`.
    private static let tic80 = SystemOverlayBinding(
        system: .TIC80, families: [standardSubtype: FourFaceFamily.self], defaultSubtype: standardSubtype,
        tokens: [.a: "a", .b: "b", .x: "x", .y: "y", .start: "start", .select: "select"],
        labels: [.a: "A", .b: "B", .x: "X", .y: "Y", .start: "START", .select: "SELECT"],
        palette: .tic80, hardwareSwitches: [])

    /// A, B, Option 1 and 2, Pause. There is no flip action: the handler has no flip token.
    private static let lynx = SystemOverlayBinding(
        system: .Lynx, families: [standardSubtype: TwoButtonFamily.self], defaultSubtype: standardSubtype,
        tokens: [.a: "a", .b: "b", .start: "option1", .select: "option2", .reset: "pause"],
        labels: [.a: "A", .b: "B", .start: "OPT 1", .select: "OPT 2", .reset: "PAUSE"],
        palette: .lynx, hardwareSwitches: [])

    private static let supervision = SystemOverlayBinding(
        system: .Supervision, families: [standardSubtype: TwoButtonFamily.self], defaultSubtype: standardSubtype,
        tokens: [.a: "a", .b: "b", .start: "start", .select: "select"],
        labels: [.a: "A", .b: "B", .start: "START", .select: "SELECT"],
        palette: .gameBoy, hardwareSwitches: [])

    /// A B C and the Menu key. "select" reaches `PVPMButton.menu`; the literal token "menu" would open the pause menu.
    private static let pokemonMini = SystemOverlayBinding(
        system: .PokemonMini, families: [standardSubtype: ThreeFaceFamily.self], defaultSubtype: standardSubtype,
        tokens: [.a: "a", .b: "b", .c: "c", .start: "select"],
        labels: [.a: "A", .b: "B", .c: "C", .start: "MENU"],
        palette: .gameBoy, hardwareSwitches: [])

    /// Game Gear, Master System and SG-1000: button 1 is `b` (RetroPad B), button 2 is `c` (RetroPad A), drawn
    /// 1 left and 2 right.
    private static func segaEightBit(_ system: SystemIdentifier, startLabel: String) -> SystemOverlayBinding {
        SystemOverlayBinding(
            system: system, families: [standardSubtype: TwoButtonFamily.self], defaultSubtype: standardSubtype,
            tokens: [.b: "b", .a: "c", .start: "start"],
            labels: [.b: "1", .a: "2", .start: startLabel],
            palette: .genesis, hardwareSwitches: [])
    }

    /// A B C, L R, and the P (play) and X (stop) keys on the Start and Select slots.
    private static let threeDO = SystemOverlayBinding(
        system: ._3DO, families: [standardSubtype: SixFaceFamily.self], defaultSubtype: standardSubtype,
        tokens: [.a: "a", .b: "b", .c: "c", .l: "l", .r: "r", .start: "p", .select: "x"],
        labels: [.a: "A", .b: "B", .c: "C", .l: "L", .r: "R", .start: "P", .select: "X"],
        palette: .cdi, hardwareSwitches: [])
}
