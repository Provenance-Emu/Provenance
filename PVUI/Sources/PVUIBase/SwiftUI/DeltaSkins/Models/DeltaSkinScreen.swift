import CoreGraphics
import CoreImage

// MARK: - Legacy coordinate reference size
// Many legacy skins (GBA, GameGear, etc.) encode outputFrame in pixel coordinates
// relative to this canonical mapping canvas.
private let legacyReferenceWidth: CGFloat = 480
private let legacyReferenceHeight: CGFloat = 320

// MARK: - System native resolutions

/// Maps DeltaSkinGameType values to their hardware framebuffer dimensions.
///
/// Used when `maintainAspectRatio` is `true` so the emulator viewport preserves
/// the correct pixel-aspect ratio for each platform.  Systems that aren't listed
/// here are assumed to run at a standard 4:3 ratio.
public enum DeltaSkinNativeResolution {
    // Sega
    public static let gamegear     = CGSize(width: 160, height: 144) // 10:9
    public static let masterSystem = CGSize(width: 256, height: 192) // 4:3
    public static let genesis      = CGSize(width: 320, height: 224) // 10:7

    // Atari
    public static let lynx         = CGSize(width: 160, height: 102) // ~1.57:1
    public static let atari2600    = CGSize(width: 160, height: 192) // approximate (5:6 incl. overscan)
    public static let atari7800    = CGSize(width: 320, height: 240) // 4:3

    // Bandai
    public static let wonderswan   = CGSize(width: 224, height: 144) // ~1.56:1

    // SNK
    public static let ngp          = CGSize(width: 160, height: 152) // 20:19
    public static let ngpc         = CGSize(width: 160, height: 152) // 20:19

    // Nintendo handhelds
    public static let gb           = CGSize(width: 160, height: 144) // 10:9
    public static let gba          = CGSize(width: 240, height: 160) // 3:2
    public static let pokemonMini  = CGSize(width:  96, height:  64) // 3:2

    /// Returns the native framebuffer size for the given game type, or `nil` for
    /// systems that aren't in the registry (they default to a standard 4:3 ratio).
    public static func size(for gameType: DeltaSkinGameType) -> CGSize? {
        switch gameType {
        case .gamegear:                    return gamegear
        case .masterSystem:                return masterSystem
        case .genesis:                     return genesis
        case .lynx:                        return lynx
        case .atari2600:                   return atari2600
        case .atari7800:                   return atari7800
        case .wonderswan, .wonderswancolor: return wonderswan
        case .ngp:                         return ngp
        case .ngpc:                        return ngpc
        case .gb, .gbc:                    return gb
        case .gba:                         return gba
        case .pokemonMini:                 return pokemonMini
        default:                           return nil
        }
    }

    /// Aspect ratio (width / height) for the given game type.
    /// Returns `4.0 / 3.0` for systems not in the registry.
    public static func aspectRatio(for gameType: DeltaSkinGameType) -> CGFloat {
        guard let s = size(for: gameType) else { return 4.0 / 3.0 }
        return s.width / s.height
    }
}

// MARK: - DeltaSkinScreen

/// Represents a screen area in a DeltaSkin
public struct DeltaSkinScreen: Identifiable, Codable {
    /// Unique identifier for this screen
    public let id: String

    /// Frame in the source image to capture (in native resolution)
    /// For DS top screen this would be: CGRect(x: 0, y: 0, width: 256, height: 192)
    /// For DS bottom screen: CGRect(x: 0, y: 192, width: 256, height: 192)
    public let inputFrame: CGRect?

    /// Frame to display the screen content, **always in normalised 0–1 coordinates**.
    ///
    /// Legacy skins (GBA, GameGear, …) encode `outputFrame` as absolute pixel
    /// coordinates on a 480×320 canvas.  During decoding those values are
    /// automatically divided by (480, 320) so callers always receive a 0–1 frame.
    /// The original JSON value is preserved in `rawOutputFrame`.
    public let outputFrame: CGRect?

    /// The un-normalised value as it appears in the skin JSON.
    /// May be in 0–1 space (modern skins) or absolute pixels (legacy skins).
    public let rawOutputFrame: CGRect?

    /// Screen placement type (controller or game)
    public let placement: DeltaSkinScreenPlacement

    /// Optional CoreImage filters to apply at render time.
    /// Constructed from the `filters` array in the skin's `info.json` during decoding.
    public let filters: [CIFilter]?

    /// Original filter specs decoded from JSON, preserved for round-trip encoding.
    public let filterInfos: [DeltaSkin.FilterInfo]?

    /// When `true` (default) the emulator viewport should maintain the system's
    /// native pixel aspect ratio rather than stretching to fill `outputFrame`.
    public let maintainAspectRatio: Bool

    /// Creates a `DeltaSkinScreen` programmatically.
    ///
    /// - Note: `encode(to:)` serialises `filterInfos`, not `filters`. If you pass `filters`
    ///   without the matching `filterInfos`, any filter data will be omitted when the skin
    ///   is re-encoded. The `init(from:)` decoder always populates both fields together for
    ///   instances loaded from JSON.
    public init(
        id: String,
        inputFrame: CGRect?,
        outputFrame: CGRect?,
        placement: DeltaSkinScreenPlacement,
        filters: [CIFilter]?,
        filterInfos: [DeltaSkin.FilterInfo]? = nil,
        maintainAspectRatio: Bool = true
    ) {
        self.id = id
        self.inputFrame = inputFrame
        self.rawOutputFrame = outputFrame
        self.outputFrame = DeltaSkinScreen.normaliseOutputFrame(outputFrame)
        self.placement = placement
        self.filters = filters
        self.filterInfos = filterInfos
        self.maintainAspectRatio = maintainAspectRatio
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case inputFrame
        case outputFrame
        case placement
        case filters
        case maintainAspectRatio
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        inputFrame = try container.decodeIfPresent(CGRect.self, forKey: .inputFrame)
        let decoded = try container.decodeIfPresent(CGRect.self, forKey: .outputFrame)
        rawOutputFrame = decoded
        outputFrame = DeltaSkinScreen.normaliseOutputFrame(decoded)
        placement = try container.decode(DeltaSkinScreenPlacement.self, forKey: .placement)
        maintainAspectRatio = try container.decodeIfPresent(Bool.self, forKey: .maintainAspectRatio) ?? true

        // Decode the `filters` array as [DeltaSkin.FilterInfo] and construct CIFilter instances.
        // DeltaSkinScreenFilter handles parameter mapping (numbers, vectors, colors, etc.) and
        // sets all parameters on the underlying CIFilter so `filters` has fully configured
        // CIFilter objects (e.g. CIGaussianBlur with inputRadius already applied).
        // `filterInfos` is preserved separately for lossless round-trip encoding.
        if let infos = try container.decodeIfPresent([DeltaSkin.FilterInfo].self, forKey: .filters) {
            filterInfos = infos
            filters = infos.compactMap { DeltaSkinScreenFilter(filterInfo: $0)?.filter }
        } else {
            filterInfos = nil
            filters = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(inputFrame, forKey: .inputFrame)
        // Encode the raw (pre-normalisation) frame so round-tripped skins remain valid
        try container.encodeIfPresent(rawOutputFrame ?? outputFrame, forKey: .outputFrame)
        try container.encode(placement, forKey: .placement)
        try container.encode(maintainAspectRatio, forKey: .maintainAspectRatio)
        // Re-encode the original FilterInfo specs so round-tripped skins remain valid.
        // Note: `filters` (CIFilter) is intentionally not encoded — `filterInfos` is the
        // canonical source of truth for serialisation. For programmatically-created instances
        // that omit `filterInfos`, filter data will not be included in the encoded output.
        try container.encodeIfPresent(filterInfos, forKey: .filters)
    }

    // MARK: - Private helpers

    /// Detect and normalise legacy pixel-coordinate `outputFrame` values.
    ///
    /// A frame is considered to be in legacy pixel space when **any** of its
    /// four components (x, y, width, height) is greater than 1.0.  Such frames
    /// are divided by the legacy reference dimensions (480 × 320) so that the
    /// result lies in the normalised 0–1 space expected by the rest of the UI.
    ///
    /// Frames that are already fully in the 0–1 range are returned unchanged.
    static func normaliseOutputFrame(_ frame: CGRect?) -> CGRect? {
        guard let frame else { return nil }

        // Already normalised – all four components are within [0, 1]
        guard frame.origin.x > 1.0 || frame.origin.y > 1.0 ||
              frame.size.width > 1.0 || frame.size.height > 1.0 else {
            return frame
        }

        return CGRect(
            x: frame.origin.x / legacyReferenceWidth,
            y: frame.origin.y / legacyReferenceHeight,
            width: frame.size.width / legacyReferenceWidth,
            height: frame.size.height / legacyReferenceHeight
        )
    }
}

public enum DeltaSkinScreenPlacement: String, Codable {
    case controller // Screen is part of the controller layout
    case app       // Screen is positioned by the app
}

/// Represents a group of screens in a skin (e.g. DS dual screens)
public struct DeltaSkinScreenGroup: Codable, Identifiable {
    /// Unique identifier for this group
    public let id: String

    /// All screens in this group
    public let screens: [DeltaSkinScreen]

    /// Extended edges for the entire group
    public let extendedEdges: UIEdgeInsets?

    /// Whether screens should be translucent
    public let translucent: Bool?

    /// Frame for the game screen (in native coordinates)
    public let gameScreenFrame: CGRect?

    public init(
        id: String,
        screens: [DeltaSkinScreen],
        extendedEdges: UIEdgeInsets?,
        translucent: Bool?,
        gameScreenFrame: CGRect?
    ) {
        self.id = id
        self.screens = screens
        self.extendedEdges = extendedEdges
        self.translucent = translucent
        self.gameScreenFrame = gameScreenFrame
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case screens
        case extendedEdges
        case translucent
        case gameScreenFrame
    }
}
