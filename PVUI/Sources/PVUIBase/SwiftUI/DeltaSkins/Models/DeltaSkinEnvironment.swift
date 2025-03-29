import SwiftUI

/// Environment key for debug skin mappings
public struct DebugSkinMappingsKey: EnvironmentKey {
    public static let defaultValue: Bool = false
}

extension EnvironmentValues {
    /// Whether to show debug overlays for skin mappings
    public var debugSkinMappings: Bool {
        get { self[DebugSkinMappingsKey.self] }
        set { self[DebugSkinMappingsKey.self] = newValue }
    }
}
