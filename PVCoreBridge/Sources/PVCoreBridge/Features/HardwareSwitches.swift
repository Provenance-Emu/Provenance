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

// MARK: - Momentary Button Models

/// A descriptor for a hardware momentary button — sends a press+release signal
/// (not a latched toggle). Examples: SMS Pause/NMI, arcade Service button.
public struct HardwareMomentaryDescriptor: Identifiable, Sendable {
    public let id: String
    /// Human-readable name shown under the button (e.g. "PAUSE", "SERVICE")
    public let title: String
    /// Short label displayed on the button face (e.g. "⏸", "⚙")
    public let label: String
    /// Button ID forwarded to the input handler on press
    public let buttonId: String

    public init(id: String, title: String, label: String, buttonId: String) {
        self.id = id
        self.title = title
        self.label = label
        self.buttonId = buttonId
    }
}

// MARK: - Protocol

/// Conforming button types declare the hardware switches available for their system.
/// The default implementation returns `nil` (no switches).
public protocol HardwareSwitchProvider {
    /// Returns the hardware switch descriptors for this system, or `nil` if none.
    static var hardwareSwitches: [HardwareSwitchDescriptor]? { get }
    /// Returns momentary hardware button descriptors for this system, or `nil` if none.
    /// Momentary buttons (e.g. SMS Pause/NMI, arcade Service) send a press+release
    /// edge rather than latching to an on/off state.
    static var hardwareMomentaryButtons: [HardwareMomentaryDescriptor]? { get }
}

// MARK: - Default implementation for EmulatorCoreButton

public extension EmulatorCoreButton {
    /// By default, button types report no hardware switches.
    static var hardwareSwitches: [HardwareSwitchDescriptor]? { nil }
    /// By default, button types report no momentary hardware buttons.
    static var hardwareMomentaryButtons: [HardwareMomentaryDescriptor]? { nil }
}
