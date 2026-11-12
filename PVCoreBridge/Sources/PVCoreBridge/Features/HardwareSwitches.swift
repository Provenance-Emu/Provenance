// MARK: - Hardware Switch Models

/// Describes one position of a hardware switch.
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
    public let positionList: [HardwareSwitchPosition]
    public let initialPositionIndex: Int
    /// A position-less input token that advances through the available positions.
    public let advanceButtonId: String?
    /// Binary accessors for existing switch views.
    public var positions: (off: HardwareSwitchPosition, on: HardwareSwitchPosition) {
        (positionList[0], positionList[1])
    }
    public var defaultState: Bool { initialPositionIndex == 1 }

    public init(
        id: String,
        title: String,
        offPosition: HardwareSwitchPosition,
        onPosition: HardwareSwitchPosition,
        defaultState: Bool = false
    ) {
        self.id = id
        self.title = title
        self.positionList = [offPosition, onPosition]
        self.initialPositionIndex = defaultState ? 1 : 0
        self.advanceButtonId = nil
    }

    public init?(id: String, title: String, positions: [HardwareSwitchPosition],
                 initialPositionIndex: Int = 0, advanceButtonId: String? = nil) {
        guard positions.count >= 2, positions.indices.contains(initialPositionIndex) else { return nil }
        self.id = id
        self.title = title
        self.positionList = positions
        self.initialPositionIndex = initialPositionIndex
        self.advanceButtonId = advanceButtonId
    }

    public func nextPosition(after index: Int) -> Int {
        let current = positionList.indices.contains(index) ? index : initialPositionIndex
        return (current + 1) % positionList.count
    }

    /// True when all positions forward the same button id, so the core can only
    /// see "the switch was pressed" and not which position was chosen. Such a
    /// switch is a press-to-toggle (e.g. the 7800 difficulty switches, which
    /// ProSystem flips on every push); the UI must send that single id once per
    /// flip rather than trying to select a position.
    public var isPressToToggle: Bool {
        positionList.allSatisfy { $0.buttonId == positionList[0].buttonId }
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
