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

// MARK: - Button Kind

/// Classifies the visual and interaction style of a skin button.
public enum DeltaSkinButtonKind: String, Codable, Equatable {
    /// Standard push/action button (default).
    case normal
    /// A physical two-position hardware toggle switch (e.g. Atari difficulty switch).
    /// Rendered using `HardwareSwitchView` and tracked with latching state.
    case hardwareSwitch
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

    /// Optional per-button haptic feedback configuration
    public let haptic: DeltaSkinHaptic?

    /// Optional per-button visual states (normal/pressed images, animated frames)
    public let states: DeltaSkinButtonStates?

    /// When true, this is a momentary toggle: it fires on press and auto-retracts on release.
    /// When false (default), it is a latching toggle that changes state each press.
    /// Manic skin parity: `selfRetracting` property.
    /// - Note: Consumed by the button-rendering layer when toggle/switch behaviour is implemented.
    public let selfRetracting: Bool

    /// Visual and interaction style of this button.
    public let buttonKind: DeltaSkinButtonKind

    /// Initialize a new button mapping
    /// - Parameters:
    ///   - id: Unique identifier for this button
    ///   - input: Input actions this button triggers
    ///   - frame: Frame for the button (in relative 0-1 coordinates)
    ///   - extendedEdges: Optional extended touch areas around the button
    ///   - haptic: Optional per-button haptic feedback configuration
    ///   - states: Optional per-button visual states
    ///   - selfRetracting: When true, the button auto-retracts on release (momentary toggle)
    ///   - buttonKind: Visual and interaction style (default `.normal`)
    public init(
        id: String,
        input: DeltaSkinInput,
        frame: CGRect,
        extendedEdges: UIEdgeInsets? = nil,
        haptic: DeltaSkinHaptic? = nil,
        states: DeltaSkinButtonStates? = nil,
        selfRetracting: Bool = false,
        buttonKind: DeltaSkinButtonKind = .normal
    ) {
        self.id = id
        self.input = input
        self.frame = frame
        self.extendedEdges = extendedEdges
        self.haptic = haptic
        self.states = states
        self.selfRetracting = selfRetracting
        self.buttonKind = buttonKind
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case input
        case frame
        case extendedEdges
        case haptic
        case states
        case selfRetracting
        case buttonKind
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        input = try container.decode(DeltaSkinInput.self, forKey: .input)
        frame = try container.decode(CGRect.self, forKey: .frame)
        extendedEdges = try container.decodeIfPresent(UIEdgeInsets.self, forKey: .extendedEdges)
        haptic = try container.decodeIfPresent(DeltaSkinHaptic.self, forKey: .haptic)
        states = try container.decodeIfPresent(DeltaSkinButtonStates.self, forKey: .states)
        selfRetracting = (try container.decodeIfPresent(Bool.self, forKey: .selfRetracting)) ?? false
        buttonKind = (try container.decodeIfPresent(DeltaSkinButtonKind.self, forKey: .buttonKind)) ?? .normal
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(input, forKey: .input)
        try container.encode(frame, forKey: .frame)
        try container.encodeIfPresent(extendedEdges, forKey: .extendedEdges)
        try container.encodeIfPresent(haptic, forKey: .haptic)
        try container.encodeIfPresent(states, forKey: .states)
        if selfRetracting { try container.encode(selfRetracting, forKey: .selfRetracting) }
        if buttonKind != .normal { try container.encode(buttonKind, forKey: .buttonKind) }
    }
}

/// Per-state image config for a button
public struct DeltaSkinButtonStateImage: Codable, Equatable {
    public let image: String
}

/// Animated frame config (fps + looping frame sequence)
public struct DeltaSkinButtonAnimated: Codable, Equatable {
    public let frames: [String]
    public let fps: Double
    public let loops: Bool
}

/// Animation curve for switch button transitions (Manic-style spring animations)
public enum DeltaSkinSwitchAnimationCurve: String, Codable, Equatable {
    case linear
    case easeIn
    case easeOut
    case easeInOut
    case spring
}

/// Spring animation config for animated switch buttons (Manic skin parity)
public struct DeltaSkinButtonSwitchAnimation: Codable, Equatable {
    /// Animation curve to use
    public let curve: DeltaSkinSwitchAnimationCurve
    /// Duration in seconds (ignored for spring; uses natural frequency)
    public let duration: Double?
    /// Spring damping (0-1); lower = more bounce. Only used when curve == .spring
    public let damping: Double?
    /// Spring initial velocity. Only used when curve == .spring
    public let initialVelocity: Double?

    public init(
        curve: DeltaSkinSwitchAnimationCurve = .spring,
        duration: Double? = nil,
        damping: Double? = 0.6,
        initialVelocity: Double? = 0
    ) {
        self.curve = curve
        self.duration = duration
        self.damping = damping
        self.initialVelocity = initialVelocity
    }
}

/// All visual states for a button
public struct DeltaSkinButtonStates: Codable, Equatable {
    public let normal: DeltaSkinButtonStateImage?
    public let pressed: DeltaSkinButtonStateImage?
    /// Selected/toggled-on state image (for toggle/switch buttons).
    /// - Note: Consumed by the button-rendering layer when toggle state display is implemented.
    public let selected: DeltaSkinButtonStateImage?
    public let animated: DeltaSkinButtonAnimated?
    /// Optional spring-curve animation for transitions between states.
    /// - Note: Consumed by the button-rendering layer when animated toggle transitions are implemented.
    public let switchAnimation: DeltaSkinButtonSwitchAnimation?

    public init(
        normal: DeltaSkinButtonStateImage? = nil,
        pressed: DeltaSkinButtonStateImage? = nil,
        selected: DeltaSkinButtonStateImage? = nil,
        animated: DeltaSkinButtonAnimated? = nil,
        switchAnimation: DeltaSkinButtonSwitchAnimation? = nil
    ) {
        self.normal = normal
        self.pressed = pressed
        self.selected = selected
        self.animated = animated
        self.switchAnimation = switchAnimation
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

/// Represents a button mapping in a Delta skin
public struct DeltaSkinButtonMapping: Identifiable {
    /// Unique identifier for the button
    public let id: String

    /// Frame of the button in normalized coordinates (0-1)
    public let frame: CGRect?

    /// Input identifiers associated with this button
    public let inputs: [String]

    /// Extended edges for touch area
    public let extendedEdges: UIEdgeInsets?

    /// Creates a button mapping
    public init(id: String, frame: CGRect?, inputs: [String], extendedEdges: UIEdgeInsets? = nil) {
        self.id = id
        self.frame = frame
        self.inputs = inputs
        self.extendedEdges = extendedEdges
    }
}

/// Extension to DeltaSkinProtocol to add button mapping support
public extension DeltaSkinProtocol {
    /// Get button mappings for the given traits
    func buttonMappings(for traits: DeltaSkinTraits) -> [DeltaSkinButtonMapping] {
        // Default implementation returns an empty array
        // Concrete implementations should override this
        return []
    }
}

/// Extension to DeltaSkin to implement button mappings
extension DeltaSkin {
    /// Get button mappings for the given traits
    public func buttonMappings(for traits: DeltaSkinTraits) -> [DeltaSkinButtonMapping] {
        guard let representation = representation(for: traits) else {
            return []
        }

        var mappings: [DeltaSkinButtonMapping] = []

        // Check if the representation has items (newer format)
        if let items = representation.items {
            // Convert ItemRepresentation objects to button mappings
            for (index, item) in items.enumerated() {
                if let mapping = createButtonMapping(from: item, index: index) {
                    mappings.append(mapping)
                }
            }
        }

        // If we have no mappings, try to create some from the skin's layout
        if mappings.isEmpty {
            // Create standard button mappings based on the system type
            mappings.append(contentsOf: createStandardButtonMappings(for: traits))
        }

        return mappings
    }

    /// Create a button mapping from an ItemRepresentation
    private func createButtonMapping(from item: ItemRepresentation, index: Int) -> DeltaSkinButtonMapping? {
        // Get inputs
        var inputStrings: [String] = []

        let inputs = item.inputs
        // Handle different input formats
        if let inputsDict = inputs as? [String: String] {
            // Format: "inputs": {"up": "up", "down": "down"}
            inputStrings = Array(inputsDict.values)
        } else if let inputsArray = inputs as? [String] {
            // Format: "inputs": ["a", "b"]
            inputStrings = inputsArray
        }

        // Get frame
        let frame = item.frame
        let buttonFrame = CGRect(
            x: frame.minX,
            y: frame.minY,
            width: frame.width,
            height: frame.height
        )


        // Get extended edges
        var extendedEdges: UIEdgeInsets?
        if let edges = item.extendedEdges {
            extendedEdges = UIEdgeInsets(
                top: edges.top,
                left: edges.left,
                bottom: edges.bottom,
                right: edges.right
            )
        }

        // Create a unique ID for the button
        let buttonId: String
        if inputStrings.count == 1 {
            buttonId = inputStrings[0]
        } else if !inputStrings.isEmpty {
            buttonId = "button_\(index)"
        } else {
            buttonId = "unknown_\(index)"
        }

        // Create the button mapping
        return DeltaSkinButtonMapping(
            id: buttonId,
            frame: buttonFrame,
            inputs: inputStrings,
            extendedEdges: extendedEdges
        )
    }

    /// Create standard button mappings based on the system type
    private func createStandardButtonMappings(for traits: DeltaSkinTraits) -> [DeltaSkinButtonMapping] {
        var mappings: [DeltaSkinButtonMapping] = []

        // Get the screen size
        guard let screenSize = representation(for: traits)?.mappingSize else {
            return []
        }

        // Create a D-pad in the bottom left
        let dpadSize = min(screenSize.width, screenSize.height) * 0.25
        let dpadFrame = CGRect(
            x: dpadSize * 0.6,
            y: screenSize.height - dpadSize * 1.2,
            width: dpadSize,
            height: dpadSize
        )

        mappings.append(DeltaSkinButtonMapping(
            id: "dpad",
            frame: dpadFrame,
            inputs: ["up", "down", "left", "right"]
        ))

        // Create A/B buttons in the bottom right
        let buttonSize = dpadSize * 0.4
        let buttonSpacing = buttonSize * 0.3

        // A button
        mappings.append(DeltaSkinButtonMapping(
            id: "a",
            frame: CGRect(
                x: screenSize.width - buttonSize * 1.2,
                y: screenSize.height - buttonSize * 1.2,
                width: buttonSize,
                height: buttonSize
            ),
            inputs: ["a"]
        ))

        // B button
        mappings.append(DeltaSkinButtonMapping(
            id: "b",
            frame: CGRect(
                x: screenSize.width - buttonSize * 2.5,
                y: screenSize.height - buttonSize * 1.2,
                width: buttonSize,
                height: buttonSize
            ),
            inputs: ["b"]
        ))

        // Start button
        mappings.append(DeltaSkinButtonMapping(
            id: "start",
            frame: CGRect(
                x: screenSize.width * 0.6,
                y: screenSize.height - buttonSize * 0.6,
                width: buttonSize * 1.5,
                height: buttonSize * 0.5
            ),
            inputs: ["start"]
        ))

        // Select button
        mappings.append(DeltaSkinButtonMapping(
            id: "select",
            frame: CGRect(
                x: screenSize.width * 0.4,
                y: screenSize.height - buttonSize * 0.6,
                width: buttonSize * 1.5,
                height: buttonSize * 0.5
            ),
            inputs: ["select"]
        ))

        return mappings
    }
}
