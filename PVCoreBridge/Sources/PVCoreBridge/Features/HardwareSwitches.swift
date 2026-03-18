// MARK: - Hardware Switch Models

/// Describes one position of a two-state hardware toggle switch.
public struct HardwareSwitchPosition: Sendable {
    /// Short label shown beside the switch thumb (e.g. "A", "B", "★", "◻")
    public let label: String
    /// Button ID forwarded to the input handler when this position is selected
    public let buttonId: String

    public init(label: String, buttonId: String) {
        self.label = label
        self.buttonId = buttonId
    }
}

/// A descriptor for a hardware toggle switch (e.g. Left Difficulty).
public struct HardwareSwitchDescriptor: Identifiable, Sendable {
    public let id: String
    /// Human-readable name shown under the switch (e.g. "LEFT DIFF")
    public let title: String
    /// The two positions: index 0 = off/default, index 1 = on/toggled
    public let positions: (off: HardwareSwitchPosition, on: HardwareSwitchPosition)
    /// Starting state (false = off, true = on)
    public let defaultState: Bool

    public init(
        id: String,
        title: String,
        offPosition: HardwareSwitchPosition,
        onPosition: HardwareSwitchPosition,
        defaultState: Bool = false
    ) {
        self.id = id
        self.title = title
        self.positions = (off: offPosition, on: onPosition)
        self.defaultState = defaultState
    }
}

// MARK: - Protocol

/// Conforming button types declare the hardware switches available for their system.
/// The default implementation returns `nil` (no switches).
public protocol HardwareSwitchProvider {
    /// Returns the hardware switch descriptors for this system, or `nil` if none.
    static var hardwareSwitches: [HardwareSwitchDescriptor]? { get }
}

// MARK: - Default implementation for EmulatorCoreButton

public extension EmulatorCoreButton {
    /// By default, button types report no hardware switches.
    static var hardwareSwitches: [HardwareSwitchDescriptor]? { nil }
}
