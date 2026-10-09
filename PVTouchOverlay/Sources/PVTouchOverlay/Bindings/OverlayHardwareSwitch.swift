import Foundation

/// A latching console switch drawn as a pill that flips on each press. The token is the position-less id
/// `DeltaSkinInputHandler`'s switch latch resolves to the core's on or off position; `id` is the
/// `HardwareSwitchDescriptor.id` a binding lists in `hardwareSwitches`.
public struct OverlayHardwareSwitch: Hashable, Sendable {
    public let id: String
    public let token: String
    public let label: String

    public static let all: [OverlayHardwareSwitch] = [
        OverlayHardwareSwitch(id: "left_diff", token: "leftdiff", label: "L DIFF"),
        OverlayHardwareSwitch(id: "right_diff", token: "rightdiff", label: "R DIFF"),
        OverlayHardwareSwitch(id: "color_bw", token: "tvtype", label: "TV")
    ]

    public static func named(_ id: String) -> OverlayHardwareSwitch? { all.first { $0.id == id } }
}
