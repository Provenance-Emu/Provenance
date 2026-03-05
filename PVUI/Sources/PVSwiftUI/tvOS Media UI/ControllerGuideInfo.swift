// MARK: - Controller Guide Data Model
// Controller guide info for tvOS empty library states.
// Helps users understand that a hardware controller is strongly recommended
// for gaming; the Siri Remote supports only 1-2 button games.

import Foundation

/// Describes a hardware controller supported by Provenance on tvOS.
public struct ControllerGuideEntry: Identifiable {
    public let id: String
    public let name: String
    public let manufacturer: String
    public let sfSymbol: String
    public let connectionType: ConnectionType
    public let pairingSteps: [String]
    public let notes: String?

    public enum ConnectionType: String {
        case bluetooth = "Bluetooth"
        case usb = "USB"
    }

    public static let recommended: [ControllerGuideEntry] = [
        ControllerGuideEntry(
            id: "xbox-wireless",
            name: "Xbox Wireless Controller",
            manufacturer: "Microsoft",
            sfSymbol: "gamecontroller.fill",
            connectionType: .bluetooth,
            pairingSteps: [
                "Hold the Xbox button until it flashes",
                "Press the Pair button (top of controller) until it flashes fast",
                "On Apple TV: Settings > Remotes and Devices > Bluetooth",
                "Select the controller from the list"
            ],
            notes: "Xbox Series X|S and Xbox One controllers supported"
        ),
        ControllerGuideEntry(
            id: "ps5-dualsense",
            name: "DualSense",
            manufacturer: "Sony",
            sfSymbol: "gamecontroller.fill",
            connectionType: .bluetooth,
            pairingSteps: [
                "Hold Create + PS button until light bar flashes",
                "On Apple TV: Settings > Remotes and Devices > Bluetooth",
                "Select 'DualSense Wireless Controller' from the list"
            ],
            notes: "PS5 DualSense fully supported"
        ),
        ControllerGuideEntry(
            id: "ps4-dualshock",
            name: "DualShock 4",
            manufacturer: "Sony",
            sfSymbol: "gamecontroller.fill",
            connectionType: .bluetooth,
            pairingSteps: [
                "Hold Share + PS button until light bar double-flashes",
                "On Apple TV: Settings > Remotes and Devices > Bluetooth",
                "Select 'DUALSHOCK 4 Wireless Controller' from the list"
            ],
            notes: nil
        ),
        ControllerGuideEntry(
            id: "mfi-generic",
            name: "MFi Game Controller",
            manufacturer: "Various",
            sfSymbol: "gamecontroller",
            connectionType: .bluetooth,
            pairingSteps: [
                "Put controller in Bluetooth pairing mode (see controller manual)",
                "On Apple TV: Settings > Remotes and Devices > Bluetooth",
                "Select controller from the list"
            ],
            notes: "Made for iPhone/iPad/Apple TV certified controllers"
        )
    ]
}

/// Information about the Siri Remote's limitations for gaming.
public enum SiriRemoteLimitations {
    public static let headline = "Siri Remote: Very Limited for Gaming"
    public static let summary = "The Siri Remote only exposes a D-pad, two buttons (clickpad and Play/Pause), and the menu button — sufficient for 1-2 button games only. For most emulated consoles you need a real controller."
    public static let menuButtonCaveat = "Note: the Menu button acts as a system back gesture and cannot be reliably used as a game button."
    public static let sfSymbol = "appletv.remote.gen2"
}
