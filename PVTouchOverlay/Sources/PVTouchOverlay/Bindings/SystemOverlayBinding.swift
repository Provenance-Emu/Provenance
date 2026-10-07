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
    public static let wii = OverlayPalette(
        shell: OverlayColor(0.96, 0.96, 0.97), primary: OverlayColor(0.45, 0.70, 0.95),     // A light blue
        secondary: OverlayColor(0.85, 0.85, 0.88), tertiary: OverlayColor(0.85, 0.85, 0.88),
        quaternary: OverlayColor(0.85, 0.85, 0.88),
        utility: OverlayColor(0.85, 0.85, 0.88), dpad: OverlayColor(0.85, 0.85, 0.88),
        stick: OverlayColor(0.85, 0.85, 0.88), label: OverlayColor(0.15, 0.15, 0.18))
}

/// Which family each subtype of a system uses, plus the tokens and art for its slots.
public struct SystemOverlayBinding: Sendable {
    public let system: SystemIdentifier
    public let families: [String: any OverlayFamily.Type]      // subtype -> family
    public let defaultSubtype: String
    public let tokens: [OverlayFamilySlot: String]
    public let labels: [OverlayFamilySlot: String]
    public let palette: OverlayPalette
    /// `HardwareSwitchDescriptor.id`s to show (Phase 2 families use these).
    public let hardwareSwitches: [String]

    public init(system: SystemIdentifier, families: [String: any OverlayFamily.Type], defaultSubtype: String,
                tokens: [OverlayFamilySlot: String], labels: [OverlayFamilySlot: String],
                palette: OverlayPalette, hardwareSwitches: [String]) {
        precondition(!families.isEmpty && families[defaultSubtype] != nil,
                     "SystemOverlayBinding needs a family for its default subtype")
        self.system = system; self.families = families; self.defaultSubtype = defaultSubtype
        self.tokens = tokens; self.labels = labels; self.palette = palette
        self.hardwareSwitches = hardwareSwitches
    }

    public func inputID(_ slot: OverlayFamilySlot) -> OverlayInputID {
        OverlayInputID(system: system, token: tokens[slot] ?? slot.rawValue)
    }
    public func label(_ slot: OverlayFamilySlot) -> String { labels[slot] ?? slot.rawValue.uppercased() }

    public func family(for subtype: String) -> any OverlayFamily.Type {
        // swiftlint:disable:next force_unwrapping
        families[subtype] ?? families[defaultSubtype]!
    }

    public func template(padKind: OverlayPadKind, orientation: OverlayOrientation) -> OverlayTemplate {
        family(for: padKind.subtype).template(binding: self, padKind: padKind, orientation: orientation)
    }
}
