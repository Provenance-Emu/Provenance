import Testing
import PVPrimitives
@testable import PVUIBase

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

    @Test("Service filter matching uses related system group IDs")
    func serviceFilterMatchesRelatedGroupCodes() {
        let filterCodes = SkinCatalogService.resolvedSystemFilterCodes("genesis")
        #expect(filterCodes != nil)
        guard let filterCodes else { return }

        let matches32X = SkinCatalogService.matchesAnySystemCode(in: ["32x"], filterCodes: filterCodes)
        #expect(matches32X)

        let matchesSegaCD = SkinCatalogService.matchesAnySystemCode(in: ["segacd"], filterCodes: filterCodes)
        #expect(matchesSegaCD)

        let matchesUnrelated = SkinCatalogService.matchesAnySystemCode(in: ["snes"], filterCodes: filterCodes)
        #expect(!matchesUnrelated)
    }
}
