import Foundation

public enum OverlayScreenPolicy: String, Codable, Sendable, Hashable {
    case topBand, centerColumn, dualStacked, fill
}

public struct OverlayTemplate: Hashable, Codable, Sendable {
    public let padKind: OverlayPadKind
    public let orientation: OverlayOrientation
    public let groups: [OverlayGroup]
    public let screenPolicy: OverlayScreenPolicy

    public init(padKind: OverlayPadKind, orientation: OverlayOrientation,
                groups: [OverlayGroup], screenPolicy: OverlayScreenPolicy) {
        self.padKind = padKind; self.orientation = orientation
        self.groups = groups; self.screenPolicy = screenPolicy
    }
}
