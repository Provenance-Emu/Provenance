import Foundation
import UIKit

/// Resources for testing DeltaSkin functionality
public enum TestSkinResources {
    /// URL to the GBC Sunrise skin
    public static let gbcSunriseURL = Bundle.module.url(forResource: "gbc-sunrise", withExtension: "deltaskin")!

    /// URL to the GBA Sharp X1 skin
    public static let gbaSharpX1URL = Bundle.module.url(forResource: "gba-sharpx1", withExtension: "deltaskin")!

    /// All available test skins
    public static var testSkins: [DeltaSkinProtocol] {
        var skins: [DeltaSkinProtocol] = []

        do {
            if let skin = try? DeltaSkin(fileURL: gbcSunriseURL) {
                skins.append(skin)
            }

            if let skin = try? DeltaSkin(fileURL: gbaSharpX1URL) {
                skins.append(skin)
            }
        }

        // If no skins could be loaded, return mock skin
        if skins.isEmpty {
            skins.append(MockDeltaSkin())
        }

        return skins
    }
}
