import Foundation

/// Defines the available audio visualizer modes
@objc public enum VisualizerMode: Int, CaseIterable, CustomStringConvertible {
    case off
    case standard
    case standardCircular
    case metal
    case metalCircular
    
    public var description: String {
        switch self {
        case .off:
            return "Off"
        case .standard:
            return "Classic"
        case .standardCircular:
            return "Classic Circular"
        case .metal:
            return "HD"
        case .metalCircular:
            return "HD Circular"
        }
    }
    
    /// Returns whether this is a circular visualizer style
    public var isCircular: Bool {
        return self == .standardCircular || self == .metalCircular
    }
    
    /// Returns whether this is a metal-based visualizer
    public var isMetal: Bool {
        return self == .metal || self == .metalCircular
    }
    
    /// The user defaults key for storing the visualizer mode preference
    public static let userDefaultsKey = "PVAudioVisualizerMode"
    
    /// Get the current mode from user defaults
    public static var current: VisualizerMode {
        let rawValue = UserDefaults.standard.integer(forKey: userDefaultsKey)
        return VisualizerMode(rawValue: rawValue) ?? .standard
    }
    
    /// Save the current mode to user defaults
    public func saveToUserDefaults() {
        UserDefaults.standard.set(self.rawValue, forKey: VisualizerMode.userDefaultsKey)
    }
}
