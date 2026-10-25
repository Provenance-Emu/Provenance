import Testing
import PVPrimitives
@testable import PVUIBase

/// The catalog filter matching itself is tested in SkinKit (`SkinCatalogSystemGroupingTests`).
@Suite("Skin Catalog System Grouping")
struct SkinCatalogSystemGroupingTests {
    @Test("NES includes related FDS group codes")
    func nesRelatedCodesIncludeNES() {
        let related = SystemIdentifier.relatedCatalogSystemCodes(forCatalogCode: "nes")
        #expect(related.contains("nes"))
        #expect(related.count == 1)
    }

    @Test("Genesis expands to Sega MD family")
    func genesisRelatedCodesIncludeSegaFamily() {
        let related = SystemIdentifier.relatedCatalogSystemCodes(forCatalogCode: "genesis")
        #expect(related.contains("genesis"))
        #expect(related.contains("segacd"))
        #expect(related.contains("32x"))
        #expect(related.count == 3)
    }

    @Test("Sega32X expands to Sega MD family")
    func sega32XRelatedCodesIncludeSegaFamily() {
        let related = SystemIdentifier.relatedCatalogSystemCodes(forCatalogCode: "32x")
        #expect(related.contains("genesis"))
        #expect(related.contains("segacd"))
        #expect(related.contains("32x"))
        #expect(related.count == 3)
    }

    @Test("Unknown catalog code falls back to exact normalized code")
    func unknownCodeFallbacksToExactCode() {
        let related = SystemIdentifier.relatedCatalogSystemCodes(forCatalogCode: "my-custom-system")
        #expect(related == ["my-custom-system"])
    }

    @Test("3DS feed tag threeds matches the canonical 3ds filter")
    func threeDSFeedTagMatchesCanonicalFilter() {
        let fromCanonical = SystemIdentifier.relatedCatalogSystemCodes(forCatalogCode: "3ds")
        #expect(fromCanonical.contains("3ds"))
        #expect(fromCanonical.contains("threeds"))
        #expect(fromCanonical.contains("three3ds"))

        let fromFeed = SystemIdentifier.relatedCatalogSystemCodes(forCatalogCode: "threeds")
        #expect(fromFeed.contains("threeds"))
        #expect(fromFeed.contains("3ds"))

        #expect(SystemIdentifier.displayName(forCatalogCode: "threeds") == "Nintendo 3DS")
        #expect(SystemIdentifier.canonicalSkinCatalogCode("threeDS") == "3ds")
    }
}
