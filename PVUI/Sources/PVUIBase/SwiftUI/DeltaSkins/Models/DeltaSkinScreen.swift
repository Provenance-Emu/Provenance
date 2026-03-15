import CoreGraphics
import CoreImage

/// Represents a screen area in a DeltaSkin
public struct DeltaSkinScreen: Identifiable, Codable {
    /// Unique identifier for this screen
    public let id: String

    /// Frame in the source image to capture (in native resolution)
    /// For DS top screen this would be: CGRect(x: 0, y: 0, width: 256, height: 192)
    /// For DS bottom screen: CGRect(x: 0, y: 192, width: 256, height: 192)
    public let inputFrame: CGRect?

    /// Frame to display the screen content (in relative 0-1 coordinates)
    public let outputFrame: CGRect?

    /// Screen placement type (controller or game)
    public let placement: DeltaSkinScreenPlacement

    /// Optional CoreImage filters to apply at render time.
    /// Constructed from the `filters` array in the skin's `info.json` during decoding.
    public let filters: [CIFilter]?

    /// Original filter specs decoded from JSON, preserved for round-trip encoding.
    public let filterInfos: [DeltaSkin.FilterInfo]?

    public init(
        id: String,
        inputFrame: CGRect?,
        outputFrame: CGRect?,
        placement: DeltaSkinScreenPlacement,
        filters: [CIFilter]?,
        filterInfos: [DeltaSkin.FilterInfo]? = nil
    ) {
        self.id = id
        self.inputFrame = inputFrame
        self.outputFrame = outputFrame
        self.placement = placement
        self.filters = filters
        self.filterInfos = filterInfos
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case inputFrame
        case outputFrame
        case placement
        case filters
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        inputFrame = try container.decodeIfPresent(CGRect.self, forKey: .inputFrame)
        outputFrame = try container.decodeIfPresent(CGRect.self, forKey: .outputFrame)
        placement = try container.decode(DeltaSkinScreenPlacement.self, forKey: .placement)

        // Decode the `filters` array as [DeltaSkin.FilterInfo] and construct CIFilter instances.
        // DeltaSkinScreenFilter handles parameter mapping (numbers, vectors, colors, etc.).
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
        // Re-encode the original FilterInfo specs so round-tripped skins remain valid.
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
