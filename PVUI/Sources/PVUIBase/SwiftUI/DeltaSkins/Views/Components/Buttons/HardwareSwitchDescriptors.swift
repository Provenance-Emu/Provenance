// MARK: - Hardware Switch Model

/// Describes one position of a two-state hardware toggle switch.
struct HardwareSwitchPosition {
    /// Short label shown beside the switch thumb (e.g. "A", "B", "★", "◻")
    let label: String
    /// Button ID forwarded to the input handler when this position is selected
    let buttonId: String
}

/// A descriptor for a pair of hardware toggle switches (e.g. Left Diff / Right Diff).
struct HardwareSwitchDescriptor: Identifiable {
    let id: String
    /// Human-readable name shown under the switch (e.g. "LEFT DIFF")
    let title: String
    /// The two positions, index 0 = default/off, index 1 = toggled/on
    let positions: (off: HardwareSwitchPosition, on: HardwareSwitchPosition)
    /// Starting position (false = off, true = on)
    let defaultState: Bool

    init(
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

// MARK: - System-specific switch descriptors

/// Returns the hardware switches appropriate for the given system identifier string,
/// or `nil` if the system has no hardware switches.
func hardwareSwitches(for systemId: String) -> [HardwareSwitchDescriptor]? {
    switch systemId {
    case "com.provenance.2600":
        return atari2600Switches()
    case "com.provenance.7800":
        return atari7800Switches()
    default:
        return nil
    }
}

func atari2600Switches() -> [HardwareSwitchDescriptor] {
    [
        HardwareSwitchDescriptor(
            id: "left_diff",
            title: "LEFT DIFF",
            offPosition: HardwareSwitchPosition(label: "B", buttonId: "leftdiffb"),
            onPosition:  HardwareSwitchPosition(label: "A", buttonId: "leftdiffa"),
            defaultState: false   // default: B (advanced/expert)
        ),
        HardwareSwitchDescriptor(
            id: "right_diff",
            title: "RIGHT DIFF",
            offPosition: HardwareSwitchPosition(label: "B", buttonId: "rightdiffb"),
            onPosition:  HardwareSwitchPosition(label: "A", buttonId: "rightdiffa"),
            defaultState: false
        )
    ]
}

func atari7800Switches() -> [HardwareSwitchDescriptor] {
    [
        HardwareSwitchDescriptor(
            id: "left_diff",
            title: "LEFT DIFF",
            offPosition: HardwareSwitchPosition(label: "B", buttonId: "leftdiff"),
            onPosition:  HardwareSwitchPosition(label: "A", buttonId: "leftdiff"),
            defaultState: false
        ),
        HardwareSwitchDescriptor(
            id: "right_diff",
            title: "RIGHT DIFF",
            offPosition: HardwareSwitchPosition(label: "B", buttonId: "rightdiff"),
            onPosition:  HardwareSwitchPosition(label: "A", buttonId: "rightdiff"),
            defaultState: false
        )
    ]
}
