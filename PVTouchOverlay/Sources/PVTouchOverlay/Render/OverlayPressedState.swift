import Foundation
import Observation
import CoreGraphics

@Observable public final class OverlayPressedState {
    public var pressed: Set<String> = []
    public init() {}
}

@Observable public final class OverlayKnobState {
    public var offset: CGSize = .zero
    public init() {}
}
