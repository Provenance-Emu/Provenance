import Testing
import Foundation
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
        let url = LibretroArtwork.constructURLs(
            systemName: "Sega - Dreamcast",
            gameName: "Capcom vs. SNK (USA)",
            types: [.boxart]
        ).first

        #expect(url?.absoluteString == knownValidURLs[1])
    }

    @Test
    func testURLValidation() async throws {
        // Test known valid URL
        let validURL = URL(string: knownValidURLs[0])!
        let isValid = await LibretroArtwork.validateURL(validURL)
        #expect(isValid == true)

        // Test known invalid URL
        let invalidURL = URL(string: "https://thumbnails.libretro.com/Invalid/Path/Game.png")!
        let isInvalid = await LibretroArtwork.validateURL(invalidURL)
        #expect(isInvalid == false)
    }

    @Test
    func testGetValidURLs() async throws {
        let urls = await LibretroArtwork.getValidURLs(
            systemName: "Atari - ST",
            gameName: "Rick Dangerous II"
        )

        #expect(!urls.isEmpty)
        #expect(urls.contains(where: { $0.absoluteString == knownValidURLs[0] }))
    }
}
