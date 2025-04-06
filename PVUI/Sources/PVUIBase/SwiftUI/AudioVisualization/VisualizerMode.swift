import Foundation

/// Defines the available audio visualizer modes
@objc public enum VisualizerMode: Int, CaseIterable, CustomStringConvertible {
    case off
    case standard
    case metal
    
    public var description: String {
        switch self {
        case .off:
            return "Off"
        case .standard:
            return "Classic"
        case .metal:
            return "HD"
        }
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
