import Defaults
import Foundation

/// Portable theme colors encoded as six-digit sRGB hex strings.
public struct ThemeColor: Codable, Hashable, Sendable {
    public let rgb: UInt32

    public init(rgb: UInt32) {
        self.rgb = rgb & 0xFFFFFF
    }

    public var hex: String { String(format: "#%06X", rgb) }

    /// WCAG contrast ratio against another opaque sRGB color.
    public func contrastRatio(with other: Self) -> Double {
        let first = relativeLuminance
        let second = other.relativeLuminance
        return (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }

    private var relativeLuminance: Double {
        func linear(_ shift: UInt32) -> Double {
            let channel = Double((rgb >> shift) & 255) / 255
            return channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(16) + 0.7152 * linear(8) + 0.0722 * linear(0)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        guard value.utf8.count == 7, value.hasPrefix("#"), let rgb = UInt32(value.dropFirst(), radix: 16),
              value.dropFirst().utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) }) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected a color in #RRGGBB format.")
        }
        self.init(rgb: rgb)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hex)
    }
}

/// An editable palette shared by console presets and custom themes.
public struct CustomTheme: Codable, Hashable, Sendable, Defaults.Serializable {
    public var name: String
    public var dark: Bool
    public var background: ThemeColor
    public var surface: ThemeColor
    public var text: ThemeColor
    public var accent: ThemeColor

    public init(name: String, dark: Bool, background: UInt32, surface: UInt32, text: UInt32, accent: UInt32) {
        self.name = name
        self.dark = dark
        self.background = ThemeColor(rgb: background)
        self.surface = ThemeColor(rgb: surface)
        self.text = ThemeColor(rgb: text)
        self.accent = ThemeColor(rgb: accent)
    }

    public static let starter = Self(name: "My Theme", dark: true, background: 0x151B26, surface: 0x263045, text: 0xF4F6FC, accent: 0x93C7FF)

    public var hasValidName: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 60
    }
}

public enum ConsoleThemePreset: String, CaseIterable, Identifiable, Sendable {
    case sega, nes, famicom, pikachu, ps2

    public var id: String { rawValue }

    public var theme: CustomTheme {
        switch self {
        case .sega:
            CustomTheme(name: "Arcade Blue", dark: true, background: 0x111820, surface: 0x202D3C, text: 0xF0F6FF, accent: 0x79BEFF)
        case .nes:
            CustomTheme(name: "8-Bit Gray", dark: false, background: 0xEEEAE6, surface: 0xFBF8F5, text: 0x272324, accent: 0xA22839)
        case .famicom:
            CustomTheme(name: "Crimson Cartridge", dark: false, background: 0xF5E9D4, surface: 0xFFF8EA, text: 0x352423, accent: 0x941C33)
        case .pikachu:
            CustomTheme(name: "Electric Yellow", dark: false, background: 0xFFE475, surface: 0xFFF1AD, text: 0x392A16, accent: 0x8C2333)
        case .ps2:
            CustomTheme(name: "Midnight Vector", dark: true, background: 0x0B0E1D, surface: 0x181E39, text: 0xEAF0FF, accent: 0x9DAFFF)
        }
    }
}

public extension Defaults.Keys {
    static let customTheme = Key<CustomTheme>("customTheme", default: .starter)
}
