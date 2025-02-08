import CoreGraphics

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

    /// Optional CoreImage filters to apply
    public let filters: [CIFilter]?

    public init(
        id: String,
        inputFrame: CGRect?,
        outputFrame: CGRect?,
        placement: DeltaSkinScreenPlacement,
        filters: [CIFilter]?
    ) {
        self.id = id
        self.inputFrame = inputFrame
        self.outputFrame = outputFrame
        self.placement = placement
        self.filters = filters
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
        // Handle CIFilter decoding separately since it's not Codable
        filters = nil // We'll need special handling for filters
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(inputFrame, forKey: .inputFrame)
        try container.encodeIfPresent(outputFrame, forKey: .outputFrame)
        try container.encode(placement, forKey: .placement)
        // Handle CIFilter encoding separately
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
