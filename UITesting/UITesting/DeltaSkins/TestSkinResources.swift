import Foundation

/// Provides access to test skin resources
enum TestSkinResources {    
    /// URL to the test GBC Sunrise skin
    static var gbcSunriseURL: URL { bundleURL(for: "GBC-Sunrise") }

    /// URL to the test GBA-SharpX! skin
    static var gbaSharpX1URL: URL { bundleURL(for: "GBA-SharpX1") }

    private static func bundleURL(for name: String) -> URL {
        Bundle.main.url(forResource: name, withExtension: "deltaskin")!
    }
}
