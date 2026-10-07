import Foundation
import PVSystems

public enum OverlayOrientation: String, Codable, Sendable, Hashable, CaseIterable {
    case portrait, landscape
}

/// A controller subtype for a system. `subtype` is a `ControllerLayoutVariant.id`
/// (e.g. "genesis-6btn", "wii-classic") or `standardSubtype`.
public struct OverlayPadKind: Hashable, Codable, Sendable {
    public static let standardSubtype = "standard"
    public let system: SystemIdentifier
    public let subtype: String

    public init(system: SystemIdentifier, subtype: String) {
        self.system = system
        self.subtype = subtype
    }

    public static func standard(_ system: SystemIdentifier) -> OverlayPadKind {
        OverlayPadKind(system: system, subtype: standardSubtype)
    }

    public func storageKey(for orientation: OverlayOrientation) -> String {
        "\(system.rawValue).\(subtype).\(orientation.rawValue)"
    }
}

/// A skin-vocabulary input token tagged with its system so templates cannot
/// press one system's button on another system's core.
public struct OverlayInputID: Hashable, Codable, Sendable {
    public let system: SystemIdentifier
    public let token: String
    public init(system: SystemIdentifier, token: String) {
        self.system = system
        self.token = token
    }
}
