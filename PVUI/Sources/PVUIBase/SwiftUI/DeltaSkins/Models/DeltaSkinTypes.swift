/// Core types for DeltaSkin functionality
public enum DeltaSkinDevice: String, Codable, Hashable, Equatable, CaseIterable {
    case iphone
    case ipad
    case tv
}

public enum DeltaSkinDisplayType: String, Codable, Hashable, Equatable, CaseIterable {
    case standard
    case edgeToEdge
    case splitView
    case stageManager    // Stage Manager mode
    case externalDisplay // External display mode
}

public enum DeltaSkinOrientation: String, Codable, Hashable, Equatable, CaseIterable {
    case portrait
    case landscape
}

/// Represents specific iPad models for layout customization
public enum DeltaSkinIPadModel: String, Codable, Hashable, Equatable, CaseIterable {
    case mini    // 8.3"
    case air     // 10.9"
    case pro11   // 11"
    case pro13   // 12.9"

    public var screenSize: CGSize {
        switch self {
        case .mini:   return CGSize(width: 1488, height: 2266)
        case .air:    return CGSize(width: 1640, height: 2360)
        case .pro11:  return CGSize(width: 1668, height: 2388)
        case .pro13:  return CGSize(width: 2048, height: 2732)
        }
    }

    public var aspectRatio: CGFloat {
        screenSize.width / screenSize.height
    }
}

/// Represents display configuration for external screens
public enum DeltaSkinExternalDisplay: String, Codable, Hashable, Equatable, CaseIterable {
    case none      // No external display
    case mirror    // Mirror internal display
    case extended  // Extended desktop mode
    case dedicated // Dedicated game display

    public var supportsFilters: Bool {
        switch self {
        case .none, .mirror: return false
        case .extended, .dedicated: return true
        }
    }
}

public struct DeltaSkinTraits: Codable, Hashable, Equatable {
    public let device: DeltaSkinDevice
    public let displayType: DeltaSkinDisplayType
    public let orientation: DeltaSkinOrientation
    public let iPadModel: DeltaSkinIPadModel?
    public let externalDisplay: DeltaSkinExternalDisplay

    public init(device: DeltaSkinDevice = .iphone,
                displayType: DeltaSkinDisplayType = .standard,
                orientation: DeltaSkinOrientation = .portrait,
                iPadModel: DeltaSkinIPadModel? = nil,
                externalDisplay: DeltaSkinExternalDisplay = .none) {
        self.device = device
        self.displayType = displayType
        self.orientation = orientation
        self.iPadModel = iPadModel
        self.externalDisplay = externalDisplay
    }

    public var description: String {
        var desc = "\(device.rawValue)-\(displayType.rawValue)-\(orientation.rawValue)"
        if let model = iPadModel {
            desc += "-\(model.rawValue)"
        }
        if externalDisplay != .none {
            desc += "-\(externalDisplay.rawValue)"
        }
        return desc
    }
}

extension DeltaSkinDevice {
    /// Standard image sizes for PNG assets
    public struct ImageSizes {
        public struct Standard {
            /// iPhone SE (2016) - 640x1136
            public static let small = CGSize(width: 640, height: 1136)
            /// iPhone 8 - 750x1334
            public static let medium = CGSize(width: 750, height: 1334)
            /// iPhone 8 Plus - 1080x1920
            public static let large = CGSize(width: 1080, height: 1920)
        }

        public struct EdgeToEdge {
            /// iPhone 11 - 828x1792
            public static let small = CGSize(width: 828, height: 1792)
            /// iPhone 11 Pro - 1125x2436
            public static let medium = CGSize(width: 1125, height: 2436)
            /// iPhone 11 Pro Max - 1242x2688
            public static let large = CGSize(width: 1242, height: 2688)
        }
    }

    /// Returns the appropriate asset size for the current device
    func assetSize(for displayType: DeltaSkinDisplayType) -> CGSize {
        switch self {
        case .iphone:
            switch displayType {
            case .standard:
                #if IPHONE_ZOOMED
                return ImageSizes.Standard.medium
                #else
                return ImageSizes.Standard.large
                #endif
            case .edgeToEdge:
                return ImageSizes.EdgeToEdge.large
            default:
                return ImageSizes.Standard.large
            }
        case .ipad:
            // iPad always uses PDF assets
            return .zero
        case .tv:
            return .zero
        }
    }
}

// Add Codable conformance for CGRect
extension CGRect: Codable {
    private enum CodingKeys: String, CodingKey {
        case x, y, width, height
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(CGFloat.self, forKey: .x)
        let y = try container.decode(CGFloat.self, forKey: .y)
        let width = try container.decode(CGFloat.self, forKey: .width)
        let height = try container.decode(CGFloat.self, forKey: .height)
        self.init(x: x, y: y, width: width, height: height)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(origin.x, forKey: .x)
        try container.encode(origin.y, forKey: .y)
        try container.encode(size.width, forKey: .width)
        try container.encode(size.height, forKey: .height)
    }
}

// Also add Codable conformance for CGSize since we use it
extension CGSize: Codable {
    private enum CodingKeys: String, CodingKey {
        case width, height
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let width = try container.decode(CGFloat.self, forKey: .width)
        let height = try container.decode(CGFloat.self, forKey: .height)
        self.init(width: width, height: height)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
    }
}

// Add Codable conformance for UIEdgeInsets
extension UIEdgeInsets: Codable {
    private enum CodingKeys: String, CodingKey {
        case top, left, bottom, right
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let top = try container.decode(CGFloat.self, forKey: .top)
        let left = try container.decode(CGFloat.self, forKey: .left)
        let bottom = try container.decode(CGFloat.self, forKey: .bottom)
        let right = try container.decode(CGFloat.self, forKey: .right)
        self.init(top: top, left: left, bottom: bottom, right: right)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(top, forKey: .top)
        try container.encode(left, forKey: .left)
        try container.encode(bottom, forKey: .bottom)
        try container.encode(right, forKey: .right)
    }
}

/// Filter configuration for screen effects
public struct DeltaSkinFilter: Codable, Hashable, Equatable {
    public let name: String
    public let parameters: [String: FilterParameter]

    public init(name: String, parameters: [String: FilterParameter]) {
        self.name = name
        self.parameters = parameters
    }
}

/// Parameter types for CoreImage filters
public enum FilterParameter: Codable, Hashable, Equatable {
    case number(Float)
    case vector(x: Float, y: Float)
    case color(r: Float, g: Float, b: Float)
    case rectangle(x: Float, y: Float, width: Float, height: Float)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let number = try? container.decode(Float.self) {
            self = .number(number)
        } else if let dict = try? container.decode([String: NumericValue].self) {
            if dict.keys.contains("x") && dict.keys.contains("y") {
                self = .vector(x: dict["x"]!.value, y: dict["y"]!.value)
            } else if dict.keys.contains("r") && dict.keys.contains("g") && dict.keys.contains("b") {
                self = .color(r: dict["r"]!.value, g: dict["g"]!.value, b: dict["b"]!.value)
            } else if dict.keys.contains("x") && dict.keys.contains("y") &&
                      dict.keys.contains("width") && dict.keys.contains("height") {
                self = .rectangle(
                    x: dict["x"]!.value,
                    y: dict["y"]!.value,
                    width: dict["width"]!.value,
                    height: dict["height"]!.value
                )
            } else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Invalid filter parameter format"
                    )
                )
            }
        } else {
            throw DecodingError.typeMismatch(
                FilterParameter.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected number or parameter dictionary"
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .number(let value):
            try container.encode(value)
        case .vector(let x, let y):
            try container.encode(["x": x, "y": y])
        case .color(let r, let g, let b):
            try container.encode(["r": r, "g": g, "b": b])
        case .rectangle(let x, let y, let width, let height):
            try container.encode([
                "x": x, "y": y,
                "width": width, "height": height
            ])
        }
    }
}

/// A type that can decode numbers from various formats (string, int, float)
private struct NumericValue: Codable {
    let value: Float

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let floatValue = try? container.decode(Float.self) {
            value = floatValue
        } else if let intValue = try? container.decode(Int.self) {
            value = Float(intValue) / 255.0 // Convert from 0-255 range
        } else if let stringValue = try? container.decode(String.self),
                  let number = Float(stringValue) {
            value = number > 1.0 ? number / 255.0 : number
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected numeric value"
            )
        }
    }
}

import PVPrimitives

/// Game type identifiers
public enum DeltaSkinGameType: Codable, Hashable, Equatable, Comparable {
    case gb
    case gbc
    case gba
    case nes
    case snes
    case n64
    case nds
    case genesis            // Sega Mega Drive / Genesis
    case gamegear
    case masterSystem
    case psx                // PlayStation (PS1/PSX)
    // Extended support for Manic + others
    case segaCD             // Mega CD / Sega CD
    case sega32X            // 32X
    case sg1000
    case saturn
    case virtualBoy
    case psp
    case threeDS            // 3DS
    case pokemonMini

    // Implement Comparable
    public static func < (lhs: DeltaSkinGameType, rhs: DeltaSkinGameType) -> Bool {
        // Order by console generation/release date
        let order: [DeltaSkinGameType] = [
            .gb, .gbc, .gba,        // Nintendo handhelds
            .nes, .snes,            // Nintendo consoles
            .n64,                   // Nintendo 3D
            .nds,                   // Nintendo DS
            .genesis, .gamegear, .masterSystem, .segaCD, .sega32X, .sg1000, // Sega
            .psx, .psp,             // Sony
            .saturn,                // Sega Saturn
            .virtualBoy,            // Nintendo Virtual Boy
            .threeDS,               // Nintendo 3DS
            .pokemonMini            // Pokemon Mini
        ]

        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }

        return lhsIndex < rhsIndex
    }

    // MARK: - String Decoding Helpers

    /// Create from any known representation: full URN, short code, or suffix (e.g., "com.rileytestut.delta.game.gba", "public.aoshuang.game.ps1", "psx", "md", "sega cd").
    public static func fromAnyString(_ string: String) -> DeltaSkinGameType? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }

        let lower = trimmed.lowercased()

        // Extract last component after last '.' if it looks like a namespaced id
        let suffix: String = {
            if let last = lower.split(separator: ".").last {
                return String(last)
            }
            return lower
        }()

        // Normalize separators/spaces
        let token = suffix
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")

        // Map of aliases -> canonical case
        switch token {
        // Nintendo
        case "gb": return .gb
        case "gbc": return .gbc
        case "gba": return .gba
        case "nes": return .nes
        case "snes": return .snes
        case "n64", "gc", "gamecube": return .n64
        case "ds", "nds": return .nds
        case "vb", "virtualboy": return .virtualBoy
        case "3ds", "three3ds", "threeds": return .threeDS

        // Sega
        case "genesis", "md", "megadrive": return .genesis
        case "gg", "gamegear": return .gamegear
        case "ms", "mastersystem": return .masterSystem
        case "mcd", "segacd", "megacd": return .segaCD
        case "32x", "sega32x": return .sega32X
        case "sg1000": return .sg1000
        case "ss", "saturn": return .saturn

        // Sony
        case "psx", "ps1", "ps2", "ps3": return .psx
        case "psp": return .psp

        // Other
        case "pm", "pokemonmini", "pokemonmini": return .pokemonMini
        default:
            // Try to parse known Delta full IDs explicitly
            if lower.hasPrefix("com.rileytestut.delta.game.") {
                let deltaSlug = token
                return fromAnyString(deltaSlug)
            }
            // Try to parse known Manic full IDs explicitly
            if lower.hasPrefix("public.aoshuang.game.") {
                let manicSlug = token
                return fromAnyString(manicSlug)
            }
            return nil
        }
    }

    // MARK: - Codable

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        if let val = DeltaSkinGameType.fromAnyString(raw) {
            self = val
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported DeltaSkinGameType string: \(raw)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        // Prefer Delta ID when available, otherwise fall back to Manic ID
        if let delta = self.deltaIdentifierString {
            try container.encode(delta)
        } else if let manic = self.manicIdentifierString {
            try container.encode(manic)
        } else {
            // Fallback to simple case name if nothing else
            try container.encode(String(describing: self))
        }
    }

    // MARK: - Identifier Strings

    /// Delta-style identifier (when known)
    public var deltaIdentifierString: String? {
        switch self {
        case .gb: return "com.rileytestut.delta.game.gb"
        case .gbc: return "com.rileytestut.delta.game.gbc"
        case .gba: return "com.rileytestut.delta.game.gba"
        case .nes: return "com.rileytestut.delta.game.nes"
        case .snes: return "com.rileytestut.delta.game.snes"
        case .n64: return "com.rileytestut.delta.game.n64"
        case .nds: return "com.rileytestut.delta.game.ds"
        case .genesis: return "com.rileytestut.delta.game.genesis"
        case .gamegear: return "com.rileytestut.delta.game.gg"
        case .masterSystem: return "com.rileytestut.delta.game.ms"
        case .psx: return "com.rileytestut.delta.game.psx"
        // Not present in Delta’s identifiers
        case .segaCD, .sega32X, .sg1000, .saturn, .virtualBoy, .psp, .threeDS, .pokemonMini:
            return nil
        }
    }

    /// Manic-style identifier (when known)
    public var manicIdentifierString: String? {
        let prefix = "public.aoshuang.game."
        switch self {
        case .gb: return prefix + "gb"
        case .gbc: return prefix + "gbc"
        case .gba: return prefix + "gba"
        case .nes: return prefix + "nes"
        case .snes: return prefix + "snes"
        case .n64: return prefix + "n64"
        case .nds: return prefix + "ds"
        case .genesis: return prefix + "md"         // Mega Drive
        case .gamegear: return prefix + "gg"
        case .masterSystem: return prefix + "ms"
        case .psx: return prefix + "ps1"
        case .segaCD: return prefix + "mcd"
        case .sega32X: return prefix + "32x"
        case .sg1000: return prefix + "sg1000"
        case .saturn: return prefix + "ss"
        case .virtualBoy: return prefix + "vb"
        case .psp: return prefix + "psp"
        case .threeDS: return prefix + "3ds"
        case .pokemonMini: return prefix + "pm"
        }
    }

    // MARK: - SystemIdentifier Mapping

    public init?(systemIdentifier: SystemIdentifier) {
        switch systemIdentifier {
        case .GB: self = .gb
        case .GBC: self = .gbc
        case .GBA: self = .gba
        case .FDS, .NES: self = .nes
        case .SNES: self = .snes
        case .N64, .GameCube: self = .n64
        case .DS: self = .nds
        case .Genesis: self = .genesis
        case .GameGear: self = .gamegear
        case .MasterSystem: self = .masterSystem
        case .SG1000: self = .sg1000
        case .Sega32X: self = .sega32X
        case .SegaCD: self = .segaCD
        case .Saturn: self = .saturn
        case .VirtualBoy: self = .virtualBoy
        case .PSX, .PS2, .PS3: self = .psx
        case .PSP: self = .psp
        case ._3DS: self = .threeDS
        case .PokemonMini: self = .pokemonMini
        default : return nil
        }
    }

    public var systemIdentifier: SystemIdentifier? {
        switch self {
        case .gb: return .GB
        case .gbc: return .GBC
        case .gba: return .GBA
        case .nes: return .NES
        case .snes: return .SNES
        case .n64: return .N64
        case .nds: return .DS
        case .genesis: return .Genesis
        case .gamegear: return .GameGear
        case .masterSystem: return .MasterSystem
        case .sg1000: return .SG1000
        case .sega32X: return .Sega32X
        case .segaCD: return .SegaCD
        case .saturn: return .Saturn
        case .virtualBoy: return .VirtualBoy
        case .psx: return .PSX
        case .psp: return .PSP
        case .threeDS: return ._3DS
        case .pokemonMini: return .PokemonMini
        }
    }

    /// Check whether the game type matches a loose identifier token (e.g., "nes", "md", "ps1").
    public func matchesIdentifier(_ token: String) -> Bool {
        let t = token.lowercased()
        // Match against suffix tokens and both identifier styles
        if let delta = deltaIdentifierString?.split(separator: ".").last?.lowercased(), delta == t { return true }
        if let manic = manicIdentifierString?.split(separator: ".").last?.lowercased(), manic == t { return true }
        // Direct alias matching
        switch (self, t) {
        case (.gb, "gb"),
             (.gbc, "gbc"),
             (.gba, "gba"),
             (.nes, "nes"),
             (.snes, "snes"),
             (.n64, "n64"),
             (.nds, "nds"), (.nds, "ds"),
             (.virtualBoy, "vb"), (.virtualBoy, "virtualboy"),
             (.threeDS, "3ds"),
             (.genesis, "genesis"), (.genesis, "md"), (.genesis, "megadrive"),
             (.gamegear, "gg"), (.gamegear, "gamegear"),
             (.masterSystem, "ms"), (.masterSystem, "mastersystem"),
             (.segaCD, "mcd"), (.segaCD, "segacd"), (.segaCD, "megacd"),
             (.sega32X, "32x"), (.sega32X, "sega32x"),
             (.sg1000, "sg1000"),
             (.saturn, "ss"), (.saturn, "saturn"),
             (.psx, "psx"), (.psx, "ps1"),
             (.psp, "psp"),
             (.pokemonMini, "pm"), (.pokemonMini, "pokemonmini"):
            return true
        default:
            return false
        }
    }
}
