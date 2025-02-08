import UIKit

// MARK: - CGRect Codable Extension
extension CGRect {
    /// Initialize from either array [x,y,width,height] or dictionary format
    public init(fromDeltaSkin decoder: Decoder) throws {
        // Try dictionary format first {x:0, y:0, width:240, height:160}
        if let container = try? decoder.container(keyedBy: DeltaSkinCodingKeys.self) {
            let x = try container.decode(CGFloat.self, forKey: .x)
            let y = try container.decode(CGFloat.self, forKey: .y)
            let width = try container.decode(CGFloat.self, forKey: .width)
            let height = try container.decode(CGFloat.self, forKey: .height)
            self.init(x: x, y: y, width: width, height: height)
            return
        }

        // Fall back to array format [x, y, width, height]
        let values = try decoder.singleValueContainer().decode([CGFloat].self)
        guard values.count == 4 else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected array of 4 values for CGRect"
                )
            )
        }
        self.init(x: values[0], y: values[1], width: values[2], height: values[3])
    }

    /// Encode to dictionary format for consistency
    public func encodeDeltaSkin(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DeltaSkinCodingKeys.self)
        try container.encode(origin.x, forKey: .x)
        try container.encode(origin.y, forKey: .y)
        try container.encode(size.width, forKey: .width)
        try container.encode(size.height, forKey: .height)
    }
}

// MARK: - CGSize Codable Extension
extension CGSize {
    /// Initialize from dictionary format
    public init(fromDeltaSkin decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DeltaSkinCodingKeys.self)
        let width = try container.decode(CGFloat.self, forKey: .width)
        let height = try container.decode(CGFloat.self, forKey: .height)
        self.init(width: width, height: height)
    }

    /// Encode to dictionary format
    public func encodeDeltaSkin(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DeltaSkinCodingKeys.self)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
    }
}

// MARK: - UIEdgeInsets Codable Extension
extension UIEdgeInsets {
    /// Initialize from dictionary format
    public init(fromDeltaSkin decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DeltaSkinCodingKeys.self)
        let top = try container.decode(CGFloat.self, forKey: .top)
        let left = try container.decode(CGFloat.self, forKey: .left)
        let bottom = try container.decode(CGFloat.self, forKey: .bottom)
        let right = try container.decode(CGFloat.self, forKey: .right)
        self.init(top: top, left: left, bottom: bottom, right: right)
    }

    /// Encode to dictionary format
    public func encodeDeltaSkin(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DeltaSkinCodingKeys.self)
        try container.encode(top, forKey: .top)
        try container.encode(left, forKey: .left)
        try container.encode(bottom, forKey: .bottom)
        try container.encode(right, forKey: .right)
    }
}

// MARK: - Coding Keys
internal enum DeltaSkinCodingKeys: String, CodingKey {
    // Frame and size keys
    case x, y, width, height

    // Edge insets keys
    case top, left, bottom, right

    // Asset keys
    case resizable, small, medium, large

    // Screen keys
    case inputFrame, outputFrame, placement, filters

    // Filter keys
    case name, parameters

    // Item keys
    case inputs, frame, extendedEdges, thumbstick

    // Representation keys
    case assets, items, screens, mappingSize, translucent, gameScreenFrame

    // Device keys
    case standard, edgeToEdge, splitView, stageManager, externalDisplay

    // Info keys
    case identifier, gameTypeIdentifier, debug, representations
}
