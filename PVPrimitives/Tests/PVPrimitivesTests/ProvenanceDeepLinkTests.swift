import Foundation
import Testing
@testable import PVPrimitives

@Suite("Provenance deep links")
struct ProvenanceDeepLinkTests {
    private let md5 = "0123456789ABCDEF0123456789ABCDEF"

    @Test("Universal link uses the AASA /game/ route")
    func universalLinkFormat() throws {
        let url = try #require(ProvenanceDeepLink.gameUniversalLink(md5))
        #expect(url.absoluteString == "https://provenance-emu.com/game/\(md5)")
    }

    @Test("MD5 round-trips through both game URL forms")
    func md5RoundTrip() throws {
        let universal = try #require(ProvenanceDeepLink.gameUniversalLink(md5))
        let custom = try #require(URL(string: ProvenanceDeepLink.openGameMD5URI(md5)))
        #expect(ProvenanceDeepLink.gameMD5(from: universal) == md5)
        #expect(ProvenanceDeepLink.gameMD5(from: custom) == md5)
    }

    @Test("Accepted variants", arguments: [
        "provenance://open?md5=0123456789abcdef0123456789abcdef",
        "PROVENANCE://OPEN?md5=0123456789abcdef0123456789abcdef",
        "http://provenance-emu.com/game/0123456789abcdef0123456789abcdef",
        "https://provenance.app/game/0123456789abcdef0123456789abcdef/"
    ])
    func acceptedVariants(_ string: String) throws {
        let url = try #require(URL(string: string))
        #expect(ProvenanceDeepLink.gameMD5(from: url) == "0123456789abcdef0123456789abcdef")
    }

    @Test("Rejected URLs", arguments: [
        "provenance://screen/library",
        "provenance://open?title=Zelda",
        "provenance://open?md5=nothex",
        "https://example.com/game/0123456789abcdef0123456789abcdef",
        "https://provenance-emu.com/skins/0123456789abcdef0123456789abcdef",
        "https://provenance-emu.com/game/0123456789abcdef0123456789abcdef/extra",
        "ifly://open?md5=0123456789abcdef0123456789abcdef"
    ])
    func rejected(_ string: String) throws {
        let url = try #require(URL(string: string))
        #expect(ProvenanceDeepLink.gameMD5(from: url) == nil)
    }
}
