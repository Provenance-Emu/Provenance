//
//  LibretroThumbnailNamingTests.swift
//  PVLookup
//

import Testing
import Foundation
@testable import libretrodb
import PVLookupTypes

/// libretro names thumbnails with `&*/:`<>?\|"` replaced by `_` and without per-track tags.
struct LibretroThumbnailNamingTests {

    @Test("Reserved characters become underscores")
    func reservedCharactersReplaced() {
        #expect(LibretroArtwork.thumbnailFileName(for: "Sonic & Knuckles (World)") == "Sonic _ Knuckles (World)")
        #expect(LibretroArtwork.thumbnailFileName(for: #"a&b*c/d:e`f<g>h?i\j|k"l"#) == "a_b_c_d_e_f_g_h_i_j_k_l")
    }

    @Test("Track tag is dropped, disc tag is kept")
    func trackTagDropped() {
        #expect(LibretroArtwork.thumbnailFileName(for: "Game (USA) (Disc 1) (Track 1)") == "Game (USA) (Disc 1)")
        #expect(LibretroArtwork.thumbnailFileName(for: "Game (Track 12)") == "Game")
    }

    @Test("Plain names are unchanged")
    func plainNameUnchanged() {
        #expect(LibretroArtwork.thumbnailFileName(for: "Aircars (USA)") == "Aircars (USA)")
    }

    @Test("Constructed URL uses the sanitized name")
    func constructedURLIsSanitized() {
        let url = LibretroArtwork.constructURL(
            systemName: "Sega - Mega Drive - Genesis",
            gameName: "Sonic & Knuckles (World).md",
            type: .boxFront
        )
        #expect(url?.absoluteString
            == "https://thumbnails.libretro.com/Sega%20-%20Mega%20Drive%20-%20Genesis/Named_Boxarts/Sonic%20_%20Knuckles%20(World).png")
    }

    @Test("Percent-encoded track names resolve to the disc thumbnail")
    func encodedTrackName() {
        let url = LibretroArtwork.constructURL(
            systemName: "Sony - PlayStation",
            gameName: "Game%20(USA)%20(Disc%201)%20(Track%201).bin",
            type: .titleScreen
        )
        #expect(url?.absoluteString
            == "https://thumbnails.libretro.com/Sony%20-%20PlayStation/Named_Titles/Game%20(USA)%20(Disc%201).png")
    }

    @Test("Dots inside a title are not mistaken for a file extension")
    func titleDotsKept() {
        #expect(LibretroArtwork.strippingROMFileExtension(from: "Tekken 4 (Europe) (v2.00)") == "Tekken 4 (Europe) (v2.00)")
        #expect(LibretroArtwork.strippingROMFileExtension(from: "Yie Ar Kung-Fu (Japan) (Rev 1.2)") == "Yie Ar Kung-Fu (Japan) (Rev 1.2)")
        #expect(LibretroArtwork.strippingROMFileExtension(from: "Dr. Mario (Japan, USA)") == "Dr. Mario (Japan, USA)")
        #expect(LibretroArtwork.strippingROMFileExtension(from: "Tekken 4 (Europe) (v2.00).iso") == "Tekken 4 (Europe) (v2.00)")
        #expect(LibretroArtwork.strippingROMFileExtension(from: "Super Mario Bros. 3 (USA).nes") == "Super Mario Bros. 3 (USA)")
    }

    @Test("Versioned titles keep their version in the thumbnail URL")
    func versionedTitleURL() {
        let url = LibretroArtwork.constructURL(
            systemName: "Sony - PlayStation 2",
            gameName: "Tekken Tag Tournament (USA) (v2.00)",
            type: .boxFront
        )
        #expect(url?.absoluteString
            == "https://thumbnails.libretro.com/Sony%20-%20PlayStation%202/Named_Boxarts/Tekken%20Tag%20Tournament%20(USA)%20(v2.00).png")
    }
}
