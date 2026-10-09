import Foundation

public enum OverlayScreenPolicy: String, Codable, Sendable, Hashable {
    case topBand, centerColumn, dualStacked, dualStacked3DS, fill
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

public extension OverlayTemplate {
    /// The template without the controls `shouldRemove` picks; a group left with no controls goes too.
    func removingControls(where shouldRemove: (OverlayControl) -> Bool) -> OverlayTemplate {
        let kept = groups.compactMap { group -> OverlayGroup? in
            var trimmed = group
            trimmed.controls = group.controls.filter { !shouldRemove($0) }
            return trimmed.controls.isEmpty ? nil : trimmed
        }
        return OverlayTemplate(padKind: padKind, orientation: orientation, groups: kept, screenPolicy: screenPolicy)
    }
}
