import UIKit
import CoreImage
import PVLibrary

/// Provides predefined screen filters for the emulator
public class DefaultScreenFilters {
    
    /// All available screen filters
    public static var allFilters: [DeltaSkinScreenFilter] {
        return [
            // CRT filter
            createSimpleFilter(name: "CIPixellate", displayName: "CRT", parameters: ["inputScale": .number(8)]),
            
            // Scanline filter
            createSimpleFilter(name: "CILineScreen", displayName: "Scanlines", parameters: ["inputWidth": .number(2), "inputSharpness": .number(0.7)]),
            
            // Sepia filter
            createSimpleFilter(name: "CISepiaTone", displayName: "Sepia", parameters: ["inputIntensity": .number(0.8)]),
            
            // Noir filter
            createSimpleFilter(name: "CIPhotoEffectNoir", displayName: "Noir", parameters: [:]),
            
            // Game Boy filter
            createSimpleFilter(name: "CIColorMonochrome", displayName: "Game Boy", parameters: [
                "inputColor": .color(r: 0.1, g: 0.8, b: 0.1),
                "inputIntensity": .number(1.0)
            ])
        ].compactMap { $0 }
    }
    
    /// Create a simple filter with the specified parameters
    private static func createSimpleFilter(name: String, displayName: String, parameters: [String: FilterParameter]) -> DeltaSkinScreenFilter? {
        let filterInfo = DeltaSkin.FilterInfo(name: name, parameters: parameters)
        guard let filter = DeltaSkinScreenFilter(filterInfo: filterInfo) else { return nil }
        
        // Add metadata for UI display
        filter.metadata["displayName"] = displayName
        filter.metadata["identifier"] = name.lowercased()
        
        return filter
    }
    
    /// Get a filter by identifier
    public static func filter(withIdentifier identifier: String) -> DeltaSkinScreenFilter? {
        return allFilters.first { $0.metadata["identifier"] as? String == identifier }
    }
    
    /// Get the display name for a filter
    public static func displayName(for filter: DeltaSkinScreenFilter) -> String {
        return filter.metadata["displayName"] as? String ?? filter.filter.name.replacingOccurrences(of: "CI", with: "")
    }
}
