import Foundation
import Testing
import PVNetplay
@testable import PVUIBase

struct NetplayCoreCompatibilityTests {
    @Test func nativeLinkHasTwoSeatsAndNoSpectators() throws {
        let support = try #require(NetplayCoreCompatibility.support(coreIdentifier: "com.provenance.core.mGBA",
                                                                   systemIdentifier: "com.provenance.gba", coreVersion: "test"))
        #expect(support.modes == [.linkCable])
        #expect(support.maxPlayers == 2)
        #expect(!support.supportsSpectators)
        #expect(support.coreVersion == "test")
    }

    @Test func consoleAndHistoricalRetroArchSupportAreInsufficient() {
        #expect(NetplayCoreCompatibility.support(coreIdentifier: "com.provenance.core.mGBA", systemIdentifier: "com.provenance.gamecube") == nil)
        #expect(NetplayCoreCompatibility.support(coreIdentifier: "snes9x.libretro.framework", systemIdentifier: "com.provenance.snes") == nil)
        #expect(NetplayCoreCompatibility.support(coreIdentifier: "com.provenance.core.stella", systemIdentifier: "com.provenance.2600") == nil)
    }

    @Test func wirelessDoesNotProvideSharedConsoleOrSpectators() throws {
        let support = try #require(NetplayCoreCompatibility.support(coreIdentifier: "com.provenance.core.ppsspp", systemIdentifier: "com.provenance.psp"))
        #expect(support.modes == [.localWireless])
        #expect(!support.supportsSpectators)
        #expect(!support.supportsFrameDelay)
    }

    @Test func netpacketMustBeObservedAndObservationIsVersionScoped() throws {
        let version = "test-" + UUID().uuidString
        let identifier = "gpsp.libretro.framework"
        defer { NetplayCoreCompatibility.recordNetpacket(coreIdentifier: identifier, coreVersion: version, available: false) }
        #expect(NetplayCoreCompatibility.support(coreIdentifier: identifier, systemIdentifier: "com.provenance.gba", coreVersion: version) == nil)
        NetplayCoreCompatibility.recordNetpacket(coreIdentifier: identifier, coreVersion: version, available: true)
        #expect(NetplayCoreCompatibility.support(coreIdentifier: identifier, systemIdentifier: "com.provenance.gba", coreVersion: version)?.modes == [.linkCable])
        #expect(NetplayCoreCompatibility.support(coreIdentifier: identifier, systemIdentifier: "com.provenance.gba", coreVersion: version + "new") == nil)
    }
}
