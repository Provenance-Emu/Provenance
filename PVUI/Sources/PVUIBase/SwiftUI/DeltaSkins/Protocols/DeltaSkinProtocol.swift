
/// Protocol defining core DeltaSkin functionality
public protocol DeltaSkinProtocol: Identifiable, Hashable {
    /// Unique identifier for the skin
    var identifier: String { get }

    /// Display name of the skin
    var name: String { get }

    /// The decoded info.json contents
    var info: DeltaSkin.Info { get }
    
    /// Type of game this skin is for (e.g. "com.rileytestut.delta.game.ds")
    var gameType: DeltaSkinGameType { get }

    /// URL where the skin file is stored
    var fileURL: URL { get }

    /// Whether this skin supports given traits
    func supports(_ traits: DeltaSkinTraits) -> Bool
    
    /// Whether this skin supports given traits
    func supports(_ device: DeltaSkinDevice, orientation: DeltaSkinOrientation?) -> Bool

    /// Get the skin image for given traits
    func image(for traits: DeltaSkinTraits) async throws -> UIImage

    /// Get screen layouts for the current skin and traits
    func screens(for traits: DeltaSkinTraits) -> [DeltaSkinScreen]?

    /// Get the mapping size for layout calculations
    func mappingSize(for traits: DeltaSkinTraits) -> CGSize?

    /// Returns button mappings for the given traits
    func buttons(for traits: DeltaSkinTraits) -> [DeltaSkinButton]?

    /// Returns screen groups for the given traits
    func screenGroups(for traits: DeltaSkinTraits) -> [DeltaSkinScreenGroup]?

    /// Returns whether debug mode is enabled for this skin
    var isDebugEnabled: Bool { get }

    /// The raw JSON representation of the skin
    var jsonRepresentation: [String: Any] { get }
    
    func representation(for traits: DeltaSkinTraits) -> DeltaSkin.RepresentationInfo?
}

extension DeltaSkinProtocol  {
    public var id: String { identifier }

    // Add Hashable conformance
    public static func == (lhs: any DeltaSkinProtocol, rhs: any DeltaSkinProtocol) -> Bool {
        lhs.id == rhs.id
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public extension DeltaSkinProtocol {
    public func supports(_ device: DeltaSkinDevice, orientation: DeltaSkinOrientation? = nil) -> Bool {
        // First check if we have any representation for this device
        // Try direct lookup first
        if let deviceReps = info.representations[device] {
            // If no orientation specified, just return true since we found the device
            if orientation == nil {
                return true
            }
            
            // Check if the standard display type has the requested orientation
            if let standardRep = deviceReps.standard,
               let _ = standardRep[orientation!.rawValue] {
                return true
            }
            
            // If not found directly, try case-insensitive matching for orientation
            if let standardRep = deviceReps.standard {
                for (key, _) in standardRep {
                    if key.lowercased() == orientation!.rawValue.lowercased() {
                        return true
                    }
                }
            }
            
            // Not found with the standard display type
            return false
        }
        
        // If direct lookup fails, try case-insensitive matching for device
        for (deviceKey, deviceReps) in info.representations {
            // Try to match device key case-insensitively
            if deviceKey == device {
                // If no orientation specified, just return true since we found the device
                if orientation == nil {
                    return true
                }
                
                // Check if the standard display type has the requested orientation
                if let standardRep = deviceReps.standard {
                    // Try direct lookup first
                    if let _ = standardRep[orientation!.rawValue] {
                        return true
                    }
                    
                    // If not found directly, try case-insensitive matching for orientation
                    for (key, _) in standardRep {
                        if key.lowercased() == orientation!.rawValue.lowercased() {
                            return true
                        }
                    }
                }
            }
        }
        
        // Also check the raw JSON representation for more flexibility
        if let jsonRep = jsonRepresentation["representations"] as? [String: Any] {
            for (key, value) in jsonRep {
                // Try to match the device key case-insensitively
                if key.lowercased() == device.rawValue.lowercased(),
                   let deviceRep = value as? [String: Any] {
                    
                    // If no orientation specified, just return true since we found the device
                    if orientation == nil {
                        return !deviceRep.isEmpty
                    }
                    
                    // Check for standard display type
                    if let standardRep = deviceRep["standard"] as? [String: Any] {
                        // Try direct lookup first
                        if let _ = standardRep[orientation!.rawValue] as? [String: Any] {
                            return true
                        }
                        
                        // If not found directly, try case-insensitive matching for orientation
                        for (orKey, orValue) in standardRep {
                            if orKey.lowercased() == orientation!.rawValue.lowercased(),
                               let _ = orValue as? [String: Any] {
                                return true
                            }
                        }
                    }
                }
            }
        }
        
        return false
    }
}
