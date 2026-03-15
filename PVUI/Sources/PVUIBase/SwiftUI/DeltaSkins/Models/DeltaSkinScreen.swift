import CoreGraphics
import CoreImage
import PVLogging

// MARK: - System native resolutions

/// Data-driven registry mapping `DeltaSkinGameType` values to their hardware
/// framebuffer dimensions.
///
/// Resolutions are loaded from `system-native-resolutions.json` bundled with
/// `PVUIBase` so new systems can be added without touching Swift source.
/// The JSON keys are the Swift case-name strings returned by
/// `DeltaSkinGameType.registryKey` (e.g. `"gamegear"`, `"genesis"`).
///
/// Used when `maintainAspectRatio` is `true` so the emulator viewport preserves
/// the correct pixel-aspect ratio for each platform.  Systems that aren't listed
/// here are assumed to run at a standard 4:3 ratio.
public enum DeltaSkinNativeResolution {

    // MARK: - Registry (data-driven)

    /// Thread-safe once-cache of the JSON-decoded registry.
    private static let registry: [String: CGSize] = loadRegistry()

    private static func loadRegistry() -> [String: CGSize] {
        guard
            let url  = Bundle.module.url(forResource: "system-native-resolutions", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            ELOG("DeltaSkinNativeResolution: failed to load or parse system-native-resolutions.json — aspect-ratio enforcement will degrade to 4:3 fallback")
            return [:]
        }
        var result: [String: CGSize] = [:]
        for (key, value) in json {
            guard
                key != "_comment",
                let dict   = value as? [String: Any],
                let widthNum  = dict["width"]  as? NSNumber,
                let heightNum = dict["height"] as? NSNumber
            else { continue }
            let width  = CGFloat(widthNum.doubleValue)
            let height = CGFloat(heightNum.doubleValue)
            guard width > 0, height > 0, width.isFinite, height.isFinite else {
                assertionFailure("DeltaSkinNativeResolution: invalid native resolution for key \(key) — width and height must be positive, finite numbers")
                continue
            }
            result[key] = CGSize(width: width, height: height)
        }
        return result
    }

    // MARK: - Public API

    /// Returns the native framebuffer size for the given game type, or `nil` for
    /// systems that aren't in the registry (they fall back to 4:3).
    public static func size(for gameType: DeltaSkinGameType) -> CGSize? {
        registry[gameType.registryKey]
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

    /// Frame to display the screen content, as decoded from the skin JSON.
    ///
    /// Values may be in 0–1 normalised space (modern skins) or absolute pixel
    /// coordinates relative to the representation's `mappingSize` (most skins).
    /// Callers that need a normalised frame must divide by `mappingSize` themselves
    /// (see `DeltaSkinScreenPositionWrapper` and `PVEmulatorViewController`).
    ///
    /// The raw JSON value is also preserved in `rawOutputFrame` for round-trip
    /// encoding fidelity.
    public let outputFrame: CGRect?

    /// The value as it appears in the skin JSON — identical to `outputFrame`.
    /// Kept for API compatibility and explicit round-trip encoding.
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

    /// Explicit native framebuffer size for this screen, decoded from the skin's
    /// `info.json` (`"nativeResolution": {"width": 160, "height": 144}`).
    ///
    /// When present this takes precedence over the system-level registry
    /// (`DeltaSkinNativeResolution`) during aspect-ratio enforcement.
    /// Skin authors can use this to override the default for a specific layout
    /// without waiting for a registry update.
    public let nativeResolution: CGSize?

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
        maintainAspectRatio: Bool = true,
        nativeResolution: CGSize? = nil
    ) {
        self.id = id
        self.inputFrame = inputFrame
        self.rawOutputFrame = outputFrame
        self.outputFrame = outputFrame
        self.placement = placement
        self.filters = filters
        self.filterInfos = filterInfos
        self.maintainAspectRatio = maintainAspectRatio
        self.nativeResolution = nativeResolution
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case inputFrame
        case outputFrame
        case placement
        case filters
        case maintainAspectRatio
        case nativeResolution
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        inputFrame = try container.decodeIfPresent(CGRect.self, forKey: .inputFrame)
        let decoded = try container.decodeIfPresent(CGRect.self, forKey: .outputFrame)
        rawOutputFrame = decoded
        outputFrame = decoded
        placement = try container.decode(DeltaSkinScreenPlacement.self, forKey: .placement)
        maintainAspectRatio = try container.decodeIfPresent(Bool.self, forKey: .maintainAspectRatio) ?? true
        nativeResolution = try container.decodeIfPresent(CGSize.self, forKey: .nativeResolution)

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
        try container.encodeIfPresent(outputFrame, forKey: .outputFrame)
        try container.encode(placement, forKey: .placement)
        try container.encode(maintainAspectRatio, forKey: .maintainAspectRatio)
        try container.encodeIfPresent(nativeResolution, forKey: .nativeResolution)
        // Re-encode the original FilterInfo specs so round-tripped skins remain valid.
        // Note: `filters` (CIFilter) is intentionally not encoded — `filterInfos` is the
        // canonical source of truth for serialisation. For programmatically-created instances
        // that omit `filterInfos`, filter data will not be included in the encoded output.
        try container.encodeIfPresent(filterInfos, forKey: .filters)
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
