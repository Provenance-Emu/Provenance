import Foundation
import PVSystems

public struct OverlayColor: Hashable, Codable, Sendable {
    public var red: Double, green: Double, blue: Double, alpha: Double
    public init(_ red: Double, _ green: Double, _ blue: Double, _ alpha: Double = 1) {
        self.red = red; self.green = green; self.blue = blue; self.alpha = alpha
    }
    public static let white = OverlayColor(1, 1, 1), black = OverlayColor(0, 0, 0)
}

public struct OverlayPalette: Hashable, Codable, Sendable {
    public var shell: OverlayColor, primary: OverlayColor, secondary: OverlayColor, tertiary: OverlayColor
    public var quaternary: OverlayColor, utility: OverlayColor, dpad: OverlayColor
    public var stick: OverlayColor, label: OverlayColor
    public init(shell: OverlayColor, primary: OverlayColor, secondary: OverlayColor, tertiary: OverlayColor,
                quaternary: OverlayColor, utility: OverlayColor, dpad: OverlayColor,
                stick: OverlayColor, label: OverlayColor) {
        self.shell = shell; self.primary = primary; self.secondary = secondary; self.tertiary = tertiary
        self.quaternary = quaternary; self.utility = utility; self.dpad = dpad; self.stick = stick
        self.label = label
    }
    public func color(for slot: OverlayPaletteSlot) -> OverlayColor {
        switch slot {
        case .shell: return shell
        case .primary: return primary
        case .secondary: return secondary
        case .tertiary: return tertiary
        case .quaternary: return quaternary
        case .utility: return utility
        case .dpad: return dpad
        case .stick: return stick
        case .label: return label
        }
    }
    public static let nes = OverlayPalette(
        shell: OverlayColor(0.62, 0.62, 0.64), primary: OverlayColor(0.80, 0.14, 0.16),    // A red
        secondary: OverlayColor(0.80, 0.14, 0.16),                                          // B red
        tertiary: OverlayColor(0.80, 0.14, 0.16), quaternary: OverlayColor(0.80, 0.14, 0.16),
        utility: OverlayColor(0.30, 0.30, 0.33), dpad: OverlayColor(0.15, 0.15, 0.17),
        stick: OverlayColor(0.15, 0.15, 0.17), label: .white)
    public static let gameBoy = OverlayPalette(
        shell: OverlayColor(0.62, 0.60, 0.68), primary: OverlayColor(0.62, 0.15, 0.40),    // A magenta
        secondary: OverlayColor(0.62, 0.15, 0.40),                                          // B magenta
        tertiary: OverlayColor(0.62, 0.15, 0.40), quaternary: OverlayColor(0.62, 0.15, 0.40),
        utility: OverlayColor(0.38, 0.38, 0.45), dpad: OverlayColor(0.18, 0.18, 0.22),
        stick: OverlayColor(0.18, 0.18, 0.22), label: .white)
    public static let genesis = OverlayPalette(
        shell: OverlayColor(0.10, 0.10, 0.12), primary: OverlayColor(0.45, 0.45, 0.48),    // face grey
        secondary: OverlayColor(0.45, 0.45, 0.48), tertiary: OverlayColor(0.45, 0.45, 0.48),
        quaternary: OverlayColor(0.45, 0.45, 0.48),
        utility: OverlayColor(0.75, 0.15, 0.18), dpad: OverlayColor(0.22, 0.22, 0.25),    // Start red
        stick: OverlayColor(0.22, 0.22, 0.25), label: .white)
    public static let ds = OverlayPalette(
        shell: OverlayColor(0.88, 0.88, 0.90), primary: OverlayColor(0.62, 0.62, 0.66),    // face grey
        secondary: OverlayColor(0.62, 0.62, 0.66), tertiary: OverlayColor(0.62, 0.62, 0.66),
        quaternary: OverlayColor(0.62, 0.62, 0.66),
        utility: OverlayColor(0.70, 0.70, 0.74), dpad: OverlayColor(0.62, 0.62, 0.66),
        stick: OverlayColor(0.62, 0.62, 0.66), label: OverlayColor(0.15, 0.15, 0.18))
    /// Super Famicom / PAL SNES colours.
    public static let snes = OverlayPalette(
        shell: OverlayColor(0.80, 0.80, 0.84), primary: OverlayColor(0.86, 0.19, 0.22),  // A red
        secondary: OverlayColor(0.98, 0.78, 0.18),                                        // B yellow
        tertiary: OverlayColor(0.16, 0.40, 0.80),                                         // X blue
        quaternary: OverlayColor(0.18, 0.62, 0.30),                                       // Y green
        utility: OverlayColor(0.45, 0.45, 0.50), dpad: OverlayColor(0.30, 0.30, 0.34),
        stick: OverlayColor(0.30, 0.30, 0.34), label: .white)
    public static let n64 = OverlayPalette(
        shell: OverlayColor(0.35, 0.35, 0.38), primary: OverlayColor(0.86, 0.19, 0.22),
        secondary: OverlayColor(0.98, 0.78, 0.18),   // C buttons yellow
        tertiary: OverlayColor(0.16, 0.40, 0.80),    // A blue
        quaternary: OverlayColor(0.18, 0.62, 0.30),  // B green
        utility: OverlayColor(0.45, 0.45, 0.50), dpad: OverlayColor(0.30, 0.30, 0.34),
        stick: OverlayColor(0.30, 0.30, 0.34), label: .white)
    public static let playStation = OverlayPalette(
        shell: OverlayColor(0.55, 0.55, 0.58), primary: OverlayColor(0.86, 0.28, 0.33),   // circle red
        secondary: OverlayColor(0.45, 0.62, 0.86),                                         // cross blue
        tertiary: OverlayColor(0.86, 0.50, 0.70),                                          // square pink
        quaternary: OverlayColor(0.30, 0.72, 0.52),                                        // triangle green
        utility: OverlayColor(0.40, 0.40, 0.44), dpad: OverlayColor(0.30, 0.30, 0.34),
        stick: OverlayColor(0.30, 0.30, 0.34), label: .white)
    public static let gameCube = OverlayPalette(
        shell: OverlayColor(0.33, 0.30, 0.55), primary: OverlayColor(0.26, 0.68, 0.40),     // A green
        secondary: OverlayColor(0.80, 0.20, 0.22),                                           // B red
        tertiary: OverlayColor(0.62, 0.62, 0.66), quaternary: OverlayColor(0.62, 0.62, 0.66),
        utility: OverlayColor(0.62, 0.62, 0.66), dpad: OverlayColor(0.30, 0.30, 0.34),       // X/Y/Z grey
        stick: OverlayColor(0.30, 0.30, 0.34), label: .white)
    /// Atari: woodgrain-brown shell, orange fire buttons, black keypad and stick.
    public static let atari = OverlayPalette(
        shell: OverlayColor(0.40, 0.26, 0.15), primary: OverlayColor(0.93, 0.45, 0.10),   // fire orange
        secondary: OverlayColor(0.93, 0.45, 0.10), tertiary: OverlayColor(0.93, 0.45, 0.10),
        quaternary: OverlayColor(0.93, 0.45, 0.10),
        utility: OverlayColor(0.12, 0.12, 0.13), dpad: OverlayColor(0.12, 0.12, 0.13),     // keypad black
        stick: OverlayColor(0.12, 0.12, 0.13), label: .white)
    /// Generic arcade cabinet: black panel, red, white, blue and green buttons.
    public static let arcade = OverlayPalette(
        shell: OverlayColor(0.07, 0.07, 0.09), primary: OverlayColor(0.85, 0.15, 0.17),
        secondary: OverlayColor(0.92, 0.92, 0.94), tertiary: OverlayColor(0.15, 0.38, 0.80),
        quaternary: OverlayColor(0.18, 0.62, 0.30),
        utility: OverlayColor(0.40, 0.40, 0.45), dpad: OverlayColor(0.20, 0.20, 0.23),
        stick: OverlayColor(0.85, 0.15, 0.17), label: OverlayColor(0.10, 0.10, 0.12))
    /// Capcom cabinet: blue panel, white buttons, red ball top.
    public static let capcom = OverlayPalette(
        shell: OverlayColor(0.10, 0.20, 0.55), primary: OverlayColor(0.94, 0.94, 0.96),
        secondary: OverlayColor(0.94, 0.94, 0.96), tertiary: OverlayColor(0.94, 0.94, 0.96),
        quaternary: OverlayColor(0.94, 0.94, 0.96),
        utility: OverlayColor(0.80, 0.15, 0.17), dpad: OverlayColor(0.15, 0.15, 0.18),    // Start red
        stick: OverlayColor(0.80, 0.12, 0.14), label: OverlayColor(0.10, 0.10, 0.12))
    /// Neo Geo MVS: black panel, red, yellow, green and blue A B C D.
    public static let neoGeo = OverlayPalette(
        shell: OverlayColor(0.08, 0.08, 0.10), primary: OverlayColor(0.85, 0.15, 0.17),   // A red
        secondary: OverlayColor(0.98, 0.80, 0.18),                                          // B yellow
        tertiary: OverlayColor(0.18, 0.62, 0.30),                                           // C green
        quaternary: OverlayColor(0.16, 0.40, 0.80),                                         // D blue
        utility: OverlayColor(0.35, 0.35, 0.40), dpad: OverlayColor(0.18, 0.18, 0.20),
        stick: OverlayColor(0.15, 0.15, 0.17), label: OverlayColor(0.10, 0.10, 0.12))
    /// Dreamcast: white shell with the red, blue, yellow and green face buttons.
    public static let dreamcast = OverlayPalette(
        shell: OverlayColor(0.94, 0.94, 0.95), primary: OverlayColor(0.86, 0.19, 0.22),   // A red
        secondary: OverlayColor(0.16, 0.40, 0.80),                                          // B blue
        tertiary: OverlayColor(0.98, 0.78, 0.18),                                           // X yellow
        quaternary: OverlayColor(0.18, 0.62, 0.30),                                         // Y green
        utility: OverlayColor(0.62, 0.62, 0.66), dpad: OverlayColor(0.35, 0.35, 0.38),
        stick: OverlayColor(0.35, 0.35, 0.38), label: .white)
    /// Intellivision: brown shell, gold side buttons, cream keypad.
    public static let intellivision = OverlayPalette(
        shell: OverlayColor(0.35, 0.22, 0.13), primary: OverlayColor(0.85, 0.65, 0.20),
        secondary: OverlayColor(0.85, 0.65, 0.20), tertiary: OverlayColor(0.85, 0.65, 0.20),
        quaternary: OverlayColor(0.85, 0.65, 0.20),
        utility: OverlayColor(0.93, 0.88, 0.75), dpad: OverlayColor(0.85, 0.65, 0.20),     // gold disc
        stick: OverlayColor(0.85, 0.65, 0.20), label: OverlayColor(0.15, 0.12, 0.10))
    /// ColecoVision: black shell, red fire buttons, grey keypad.
    public static let coleco = OverlayPalette(
        shell: OverlayColor(0.08, 0.08, 0.09), primary: OverlayColor(0.82, 0.14, 0.16),
        secondary: OverlayColor(0.82, 0.14, 0.16), tertiary: OverlayColor(0.82, 0.14, 0.16),
        quaternary: OverlayColor(0.82, 0.14, 0.16),
        utility: OverlayColor(0.55, 0.55, 0.58), dpad: OverlayColor(0.25, 0.25, 0.28),
        stick: OverlayColor(0.25, 0.25, 0.28), label: .white)
    /// Saturn: charcoal shell, grey face buttons, a blue Start (the Saturn ring).
    public static let saturn = OverlayPalette(
        shell: OverlayColor(0.18, 0.18, 0.20), primary: OverlayColor(0.58, 0.58, 0.62),
        secondary: OverlayColor(0.58, 0.58, 0.62), tertiary: OverlayColor(0.58, 0.58, 0.62),
        quaternary: OverlayColor(0.58, 0.58, 0.62),
        utility: OverlayColor(0.22, 0.38, 0.75), dpad: OverlayColor(0.30, 0.30, 0.33),    // Start blue
        stick: OverlayColor(0.30, 0.30, 0.33), label: .white)
    /// PC Engine: white shell, dark face buttons, orange Run.
    public static let pcEngine = OverlayPalette(
        shell: OverlayColor(0.93, 0.93, 0.94), primary: OverlayColor(0.22, 0.22, 0.25),
        secondary: OverlayColor(0.22, 0.22, 0.25), tertiary: OverlayColor(0.22, 0.22, 0.25),
        quaternary: OverlayColor(0.22, 0.22, 0.25),
        utility: OverlayColor(0.92, 0.50, 0.12), dpad: OverlayColor(0.22, 0.22, 0.25),    // Run orange
        stick: OverlayColor(0.22, 0.22, 0.25), label: .white)
    /// Neo Geo Pocket and WonderSwan: silver shell, blue buttons.
    public static let neoGeoPocket = OverlayPalette(
        shell: OverlayColor(0.78, 0.79, 0.82), primary: OverlayColor(0.16, 0.34, 0.72),
        secondary: OverlayColor(0.16, 0.34, 0.72), tertiary: OverlayColor(0.16, 0.34, 0.72),
        quaternary: OverlayColor(0.16, 0.34, 0.72),
        utility: OverlayColor(0.45, 0.46, 0.50), dpad: OverlayColor(0.20, 0.21, 0.25),
        stick: OverlayColor(0.20, 0.21, 0.25), label: .white)
    /// Magnavox Odyssey 2: silver shell, black buttons.
    public static let odyssey = OverlayPalette(
        shell: OverlayColor(0.72, 0.73, 0.75), primary: OverlayColor(0.10, 0.10, 0.11),
        secondary: OverlayColor(0.10, 0.10, 0.11), tertiary: OverlayColor(0.10, 0.10, 0.11),
        quaternary: OverlayColor(0.10, 0.10, 0.11),
        utility: OverlayColor(0.35, 0.35, 0.38), dpad: OverlayColor(0.12, 0.12, 0.13),
        stick: OverlayColor(0.12, 0.12, 0.13), label: .white)
    /// Vectrex: black shell, white buttons.
    public static let vectrex = OverlayPalette(
        shell: OverlayColor(0.07, 0.07, 0.08), primary: OverlayColor(0.92, 0.92, 0.94),
        secondary: OverlayColor(0.92, 0.92, 0.94), tertiary: OverlayColor(0.92, 0.92, 0.94),
        quaternary: OverlayColor(0.92, 0.92, 0.94),
        utility: OverlayColor(0.40, 0.40, 0.43), dpad: OverlayColor(0.20, 0.20, 0.22),
        stick: OverlayColor(0.20, 0.20, 0.22), label: OverlayColor(0.08, 0.08, 0.10))
    /// Philips CD-i: black remote, white buttons.
    public static let cdi = OverlayPalette(
        shell: OverlayColor(0.09, 0.09, 0.10), primary: OverlayColor(0.94, 0.94, 0.96),
        secondary: OverlayColor(0.94, 0.94, 0.96), tertiary: OverlayColor(0.94, 0.94, 0.96),
        quaternary: OverlayColor(0.94, 0.94, 0.96),
        utility: OverlayColor(0.45, 0.45, 0.48), dpad: OverlayColor(0.22, 0.22, 0.25),
        stick: OverlayColor(0.22, 0.22, 0.25), label: OverlayColor(0.08, 0.08, 0.10))
    /// Virtual Boy: black visor, red buttons.
    public static let virtualBoy = OverlayPalette(
        shell: OverlayColor(0.08, 0.08, 0.09), primary: OverlayColor(0.80, 0.10, 0.12),
        secondary: OverlayColor(0.80, 0.10, 0.12), tertiary: OverlayColor(0.80, 0.10, 0.12),
        quaternary: OverlayColor(0.80, 0.10, 0.12),
        utility: OverlayColor(0.45, 0.10, 0.12), dpad: OverlayColor(0.18, 0.18, 0.20),
        stick: OverlayColor(0.18, 0.18, 0.20), label: .white)
    /// Home computers: beige case, brown keys.
    public static let computer = OverlayPalette(
        shell: OverlayColor(0.80, 0.76, 0.66), primary: OverlayColor(0.40, 0.30, 0.22),
        secondary: OverlayColor(0.40, 0.30, 0.22), tertiary: OverlayColor(0.40, 0.30, 0.22),
        quaternary: OverlayColor(0.40, 0.30, 0.22),
        utility: OverlayColor(0.52, 0.46, 0.38), dpad: OverlayColor(0.28, 0.25, 0.22),
        stick: OverlayColor(0.28, 0.25, 0.22), label: .white)
    /// ZX Spectrum: black case with the rainbow stripe on the face buttons.
    public static let zxSpectrum = OverlayPalette(
        shell: OverlayColor(0.07, 0.07, 0.08), primary: OverlayColor(0.85, 0.15, 0.17),   // red
        secondary: OverlayColor(0.98, 0.80, 0.18),                                          // yellow
        tertiary: OverlayColor(0.18, 0.62, 0.30),                                           // green
        quaternary: OverlayColor(0.16, 0.50, 0.85),                                         // blue
        utility: OverlayColor(0.35, 0.35, 0.38), dpad: OverlayColor(0.18, 0.18, 0.20),
        stick: OverlayColor(0.18, 0.18, 0.20), label: .white)
    /// TIC-80: dark navy with teal buttons.
    public static let tic80 = OverlayPalette(
        shell: OverlayColor(0.10, 0.11, 0.17), primary: OverlayColor(0.16, 0.70, 0.72),
        secondary: OverlayColor(0.16, 0.70, 0.72), tertiary: OverlayColor(0.36, 0.43, 0.80),
        quaternary: OverlayColor(0.36, 0.43, 0.80),
        utility: OverlayColor(0.24, 0.26, 0.38), dpad: OverlayColor(0.20, 0.22, 0.32),
        stick: OverlayColor(0.20, 0.22, 0.32), label: .white)
    /// Atari Lynx: black shell, orange buttons.
    public static let lynx = OverlayPalette(
        shell: OverlayColor(0.07, 0.07, 0.08), primary: OverlayColor(0.93, 0.45, 0.10),
        secondary: OverlayColor(0.93, 0.45, 0.10), tertiary: OverlayColor(0.93, 0.45, 0.10),
        quaternary: OverlayColor(0.93, 0.45, 0.10),
        utility: OverlayColor(0.30, 0.30, 0.33), dpad: OverlayColor(0.18, 0.18, 0.20),
        stick: OverlayColor(0.18, 0.18, 0.20), label: .white)
    public static let wii = OverlayPalette(
        shell: OverlayColor(0.96, 0.96, 0.97), primary: OverlayColor(0.45, 0.70, 0.95),     // A light blue
        secondary: OverlayColor(0.85, 0.85, 0.88), tertiary: OverlayColor(0.85, 0.85, 0.88),
        quaternary: OverlayColor(0.85, 0.85, 0.88),
        utility: OverlayColor(0.85, 0.85, 0.88), dpad: OverlayColor(0.85, 0.85, 0.88),
        stick: OverlayColor(0.85, 0.85, 0.88), label: OverlayColor(0.15, 0.15, 0.18))
}

/// The diamond of a four-button pad. Slots keep their colours; only their positions change.
public enum FourFaceArrangement: Sendable {
    /// X top, Y left, A right, B bottom.
    case superNintendo
    /// Y top, X left, B right, A bottom.
    case dreamcast
}

/// Which family each subtype of a system uses, plus the tokens and art for its slots.
public struct SystemOverlayBinding: Sendable {
    public let system: SystemIdentifier
    public let families: [String: any OverlayFamily.Type]      // subtype -> family
    public let defaultSubtype: String
    public let tokens: [OverlayFamilySlot: String]
    public let labels: [OverlayFamilySlot: String]
    public let palette: OverlayPalette
    /// `HardwareSwitchDescriptor.id`s to show as latching console switches (see `OverlayHardwareSwitch`).
    public let hardwareSwitches: [String]
    /// Function buttons the pad adds beside its inputs (service, flip, disk side).
    public let actions: [OverlayAction]
    /// The system is played sideways: the landscape template is used in either orientation.
    public let landscapeOnly: Bool
    /// Subtypes played sideways although the system is not (WonderSwan "vertical").
    public let landscapeOnlySubtypes: Set<String>
    /// The pad carries a left analog stick (Dreamcast, PSP). `OverlayFamilyKit.padTemplate` adds it.
    public let leftStick: Bool
    /// The shoulder buttons are analog triggers (Dreamcast). Honoured by `FourFaceFamily`.
    public let analogShoulders: Bool
    /// Where `FourFaceFamily` puts the four face buttons.
    public let faceArrangement: FourFaceArrangement

    public init(system: SystemIdentifier, families: [String: any OverlayFamily.Type], defaultSubtype: String,
                tokens: [OverlayFamilySlot: String], labels: [OverlayFamilySlot: String],
                palette: OverlayPalette, hardwareSwitches: [String],
                actions: [OverlayAction] = [], landscapeOnly: Bool = false,
                landscapeOnlySubtypes: Set<String> = [], leftStick: Bool = false, analogShoulders: Bool = false,
                faceArrangement: FourFaceArrangement = .superNintendo) {
        precondition(!families.isEmpty && families[defaultSubtype] != nil,
                     "SystemOverlayBinding needs a family for its default subtype")
        self.system = system; self.families = families; self.defaultSubtype = defaultSubtype
        self.tokens = tokens; self.labels = labels; self.palette = palette
        self.hardwareSwitches = hardwareSwitches
        self.actions = actions; self.landscapeOnly = landscapeOnly
        self.landscapeOnlySubtypes = landscapeOnlySubtypes
        self.leftStick = leftStick; self.analogShoulders = analogShoulders
        self.faceArrangement = faceArrangement
    }

    public func inputID(_ slot: OverlayFamilySlot) -> OverlayInputID {
        OverlayInputID(system: system, token: tokens[slot] ?? slot.rawValue)
    }
    public func label(_ slot: OverlayFamilySlot) -> String { labels[slot] ?? slot.rawValue.uppercased() }

    public func family(for subtype: String) -> any OverlayFamily.Type {
        // swiftlint:disable:next force_unwrapping
        families[subtype] ?? families[defaultSubtype]!
    }

    /// Whether `slot` has no control: the binding gave it no token and the slot may be omitted.
    public func isHidden(_ slot: OverlayFamilySlot) -> Bool {
        tokens[slot] == nil && OverlayFamilySlot.omittable.contains(slot)
    }

    /// The orientation whose template is drawn for a canvas in `orientation`.
    public func effectiveOrientation(for orientation: OverlayOrientation,
                                     subtype: String? = nil) -> OverlayOrientation {
        let sideways = landscapeOnly || subtype.map(landscapeOnlySubtypes.contains) == true
        return sideways ? .landscape : orientation
    }

    /// The family's template for the pad kind, without the controls of hidden slots.
    public func template(padKind: OverlayPadKind, orientation: OverlayOrientation) -> OverlayTemplate {
        let drawn = effectiveOrientation(for: orientation, subtype: padKind.subtype)
        let template = family(for: padKind.subtype).template(binding: self, padKind: padKind, orientation: drawn)
        return template.removingControls { control in
            switch control.kind {
            case .button, .analogTrigger: return isHidden(OverlayFamilySlot(rawValue: control.id))
            default: return false
            }
        }
    }
}
