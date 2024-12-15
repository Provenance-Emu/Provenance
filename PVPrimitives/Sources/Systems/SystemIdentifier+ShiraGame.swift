import Foundation

public extension SystemIdentifier {
    /// ShiraGame platform ID for this system
    var shiraGameID: String {
        switch self {
        case .NES: return "NES"
        case .SNES: return "SNES"
        case .GB: return "GB"
        case .GBA: return "GBA"
        case .GBC: return "GBC"
        // ... add other mappings based on ShiraGame's platform_id values
        default: return ""
        }
    }

    /// Create a SystemIdentifier from a ShiraGame platform ID
    /// - Parameter platformId: The ShiraGame platform ID string
    /// - Returns: The corresponding SystemIdentifier, if one exists
    static func fromShiraGameID(_ platformId: String) -> SystemIdentifier? {
        switch platformId.uppercased() {
        case "NES": return .NES
        case "SNES": return .SNES
        case "GB": return .GB
        case "GBA": return .GBA
        case "GBC": return .GBC
        // ... add other mappings
        default: return nil
        }
    }
}
