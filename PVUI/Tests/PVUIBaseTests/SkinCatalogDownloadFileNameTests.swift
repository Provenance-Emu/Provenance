import Foundation
import Testing
@testable import PVUIBase

@Suite("Skin catalog download file naming")
struct SkinCatalogDownloadFileNameTests {

    @Test("Preferred filename uses sanitized id and .deltaskin suffix")
    func preferredNameSanitizesId() throws {
        let downloadURL = try #require(URL(string: "https://github.com/x/y/releases/download/v1/download"))
        let entry = SkinCatalogEntry(
            id: "com.author/my-skin",
            name: "Cool Skin",
            systems: ["gba"],
            downloadURL: downloadURL
        )
        #expect(entry.preferredLocalDownloadFileName() == "com.author-my-skin.deltaskin")
    }

    @Test("Generic download URL path does not change local filename")
    func genericURLStillGetsStableName() throws {
        let downloadURL = try #require(URL(string: "https://cdn.example.com/files/latest?token=abc"))
        let entry = SkinCatalogEntry(
            id: "com.example.delta",
            name: "Example",
            systems: ["nes"],
            downloadURL: downloadURL
        )
        #expect(entry.preferredLocalDownloadFileName() == "com.example.delta.deltaskin")
    }

    @Test("Empty id after sanitization falls back to skin stem")
    func emptyIdFallback() throws {
        let downloadURL = try #require(URL(string: "https://example.com/a.deltaskin"))
        let entry = SkinCatalogEntry(
            id: "   ",
            name: "X",
            systems: ["gba"],
            downloadURL: downloadURL
        )
        #expect(entry.preferredLocalDownloadFileName() == "skin.deltaskin")
    }
}
