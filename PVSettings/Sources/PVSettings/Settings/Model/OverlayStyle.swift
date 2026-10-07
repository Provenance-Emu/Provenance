import Foundation
import Defaults

/// Visual style of the programmatic touch overlay controls.
public enum OverlayStyle: String, Codable, Sendable, CaseIterable, Identifiable, Defaults.Serializable {
    case flat, glossy, outline

    public var id: String { rawValue }

    public static let defaultStyle: OverlayStyle = .flat

    public var displayName: String {
        switch self {
        case .flat: return "Flat"
        case .glossy: return "Glossy"
        case .outline: return "Outline"
        }
    }
}
