import Testing
import Foundation
import PVLookupTypes
@testable import libretrodb
@testable import PVLookup

struct LibretroArtworkTests {
    /// Known valid libretro artwork URLs for testing
    let knownValidURLs = [
        "https://thumbnails.libretro.com/Atari%20-%20ST/Named_Boxarts/Rick%20Dangerous%20II.png",
        "https://thumbnails.libretro.com/Sega%20-%20Dreamcast/Named_Boxarts/Capcom%20vs.%20SNK%20(USA).png",
        "https://thumbnails.libretro.com/Sega%20-%20Mega-CD%20-%20Sega%20CD/Named_Boxarts/Sonic%20CD%20(USA).png"
    ]

    @Test
    func testURLConstruction() throws {
        let urls = LibretroArtwork.constructURLs(
            systemName: "Sega - Dreamcast",
            gameName: "Capcom vs. SNK (USA)",
            types: [.boxFront, .titleScreen]  // Test multiple types
        )

        // Should get two URLs - one for boxart and one for title screen
        #expect(urls.count == 2)
        #expect(urls.contains(where: { $0.absoluteString == knownValidURLs[1] }))
        #expect(urls.contains(where: { $0.path.contains(libretrodb.ArtworkConstants.titlesPath) }))
    }

    @Test
    func testURLValidationWithDifferentTypes() async throws {
        // Test each artwork type
        let types: [ArtworkType] = [.boxFront, .titleScreen, .screenshot]

        for type in types {
            let urls = LibretroArtwork.constructURLs(
                systemName: "Atari - ST",
                gameName: "Rick Dangerous II",
                types: type
            )
            #expect(urls.count == 1)

            let isValid = await LibretroArtwork.validateURL(urls[0])
            if type == .boxFront {
                #expect(isValid == true)  // Known valid boxart
            }
        }
    }

    @Test
    func testGetValidURLs() async throws {
        let urls = await LibretroArtwork.getValidURLs(
            systemName: "Atari - ST",
            gameName: "Rick Dangerous II",
            types: [.boxFront, .titleScreen, .screenshot]  // Test all supported types
        )

        #expect(!urls.isEmpty)
        #expect(urls.contains(where: { $0.absoluteString == knownValidURLs[0] }))
    }
}
