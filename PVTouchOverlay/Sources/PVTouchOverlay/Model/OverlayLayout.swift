import Foundation
import CoreGraphics

/// UIKit-free safe-area insets.
public struct OverlayInsets: Hashable, Codable, Sendable {
    public var top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat
    public init(top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat) {
        self.top = top; self.left = left; self.bottom = bottom; self.right = right
    }
    public static let zero = OverlayInsets(top: 0, left: 0, bottom: 0, right: 0)
}

/// The full-screen drawing area: window bounds plus the safe-area insets inside it.
public struct OverlayCanvas: Hashable, Sendable {
    public var size: CGSize
    public var safeArea: OverlayInsets
    public init(size: CGSize, safeArea: OverlayInsets) { self.size = size; self.safeArea = safeArea }
    public var bounds: CGRect { CGRect(origin: .zero, size: size) }
    public var safeRect: CGRect {
        CGRect(x: safeArea.left, y: safeArea.top,
               width: max(0, size.width - safeArea.left - safeArea.right),
               height: max(0, size.height - safeArea.top - safeArea.bottom))
    }
    public var orientation: OverlayOrientation { size.height >= size.width ? .portrait : .landscape }
}

public struct ResolvedControl: Hashable, Sendable, Identifiable {
    public var id: String { control.id }
    public let control: OverlayControl
    /// Absolute draw frame in canvas points.
    public let frame: CGRect
    /// Absolute hit frame (draw frame outset by extended edges).
    public let hitFrame: CGRect
}

public struct ResolvedGroup: Hashable, Sendable, Identifiable {
    public var id: String { group.id }
    public let group: OverlayGroup
    public let frame: CGRect
    public let controls: [ResolvedControl]
    public let scale: CGSize
    public let opacity: CGFloat
}

public struct OverlayLayout: Hashable, Sendable {
    public let padKind: OverlayPadKind
    public let orientation: OverlayOrientation
    public let groups: [ResolvedGroup]
    /// One rect, or two for `.dualStacked` (top screen first).
    public let screenFrames: [CGRect]
}
