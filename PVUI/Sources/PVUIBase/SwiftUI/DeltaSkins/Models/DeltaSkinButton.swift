import CoreGraphics

/// Represents a button input type
public enum DeltaSkinInput: Codable, Equatable {
    case single(String)
    case directional([String: String])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let singleInput = try? container.decode(String.self) {
            self = .single(singleInput)
        } else if let directionalMap = try? container.decode([String: String].self) {
            self = .directional(directionalMap)
        } else {
            throw DecodingError.typeMismatch(
                DeltaSkinInput.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected either string or directional mapping dictionary"
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .single(let input):
            try container.encode(input)
        case .directional(let mapping):
            try container.encode(mapping)
        }
    }
}

/// Represents a button mapping in a DeltaSkin
public struct DeltaSkinButton: Identifiable, Codable, Equatable {
    /// Unique identifier for this button
    public let id: String

    /// Input actions this button triggers
    public let input: DeltaSkinInput

    /// Frame for the button (in relative 0-1 coordinates)
    public let frame: CGRect

    /// Extended touch areas around the button
    public let extendedEdges: UIEdgeInsets?

    /// Initialize a new button mapping
    /// - Parameters:
    ///   - id: Unique identifier for this button
    ///   - input: Input actions this button triggers
    ///   - frame: Frame for the button (in relative 0-1 coordinates)
    ///   - extendedEdges: Optional extended touch areas around the button
    public init(
        id: String,
        input: DeltaSkinInput,
        frame: CGRect,
        extendedEdges: UIEdgeInsets? = nil
    ) {
        self.id = id
        self.input = input
        self.frame = frame
        self.extendedEdges = extendedEdges
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case input
        case frame
        case extendedEdges
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        input = try container.decode(DeltaSkinInput.self, forKey: .input)
        frame = try container.decode(CGRect.self, forKey: .frame)
        extendedEdges = try container.decodeIfPresent(UIEdgeInsets.self, forKey: .extendedEdges)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(input, forKey: .input)
        try container.encode(frame, forKey: .frame)
        try container.encodeIfPresent(extendedEdges, forKey: .extendedEdges)
    }
}

/// Collection of button mappings for a skin
public struct DeltaSkinButtonGroup: Codable, Equatable {
    /// All button mappings in this group
    public let buttons: [DeltaSkinButton]

    /// Extended touch areas for the entire group
    public let extendedEdges: UIEdgeInsets?

    /// Whether buttons should be translucent
    public let translucent: Bool?
}
