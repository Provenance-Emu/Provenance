//
//  DiscoveryAndMappingTests.swift
//  PVLibrarySharingTests
//

import PVSystems
import XCTest
@testable import PVLibrarySharing

final class TXTRecordTests: XCTestCase {
    /// The shape iFly's `ContinuityTXTRecord.encode` produces for a
    /// library-presence advert (AdvertisementCodecTests.testLibraryPresenceAdvert...).
    private let iFlyLibraryTXT = [
        "v": "1", "sid": "library-presence-1", "lib": "1", "pid": "peer-42",
        "u0": "http://host.local:8080", "u1": "http://192.168.1.20:8080"
    ]

    /// iCube's library advert (ContinuityManager.startAdvertisingLibrary): no token,
    /// `dt` set.
    private let iCubeLibraryTXT = [
        "v": "1", "sid": "6B1D", "lib": "1", "pid": "peer-1", "dt": "ip",
        "u0": "http://icube.local/", "u1": "http://192.168.1.5/"
    ]

    func testDecodesLibraryAdvert() throws {
        let advert = try XCTUnwrap(PeerAdvertisement(txt: iFlyLibraryTXT))
        XCTAssertEqual(advert.payloadVersion, 1)
        XCTAssertEqual(advert.sessionId, "library-presence-1")
        XCTAssertTrue(advert.sharesLibrary)
        XCTAssertEqual(advert.peerId, "peer-42")
        XCTAssertEqual(advert.urlCandidates.map(\.absoluteString), ["http://host.local:8080", "http://192.168.1.20:8080"])
        XCTAssertEqual(PeerAdvertisement(txt: iCubeLibraryTXT)?.deviceType, "ip")
    }

    func testRequiresVersionAndSession() {
        var txt = iFlyLibraryTXT
        txt["sid"] = nil
        XCTAssertNil(PeerAdvertisement(txt: txt))
        txt = iFlyLibraryTXT
        txt["v"] = "one"
        XCTAssertNil(PeerAdvertisement(txt: txt))
    }

    func testURLCandidatesStopAtFirstGap() throws {
        var txt = iFlyLibraryTXT
        txt["u1"] = nil
        txt["u2"] = "http://skipped.local"
        XCTAssertEqual(try XCTUnwrap(PeerAdvertisement(txt: txt)).urlCandidates.count, 1)
    }

    func testHandoffOnlyAdvertIsNotALibrary() {
        var txt = iFlyLibraryTXT
        txt["lib"] = nil
        txt["name"] = "Crazy Taxi"
        txt["plat"] = "dreamcast"
        XCTAssertNil(DiscoveredPeer.make(serviceType: "_ifly-continuity._tcp", serviceName: "iFly iPad", txt: txt))
    }

    func testPeerIdentityIsAppAndPid() throws {
        let first = try XCTUnwrap(DiscoveredPeer.make(
            serviceType: "_icube-continuity._tcp.", serviceName: "iPad", txt: iCubeLibraryTXT
        ))
        var readvertised = iCubeLibraryTXT
        readvertised["sid"] = "a-new-uuid"
        let second = try XCTUnwrap(DiscoveredPeer.make(
            serviceType: "_icube-continuity._tcp", serviceName: "iPad", txt: readvertised
        ))
        XCTAssertEqual(first.app, .iCube)
        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(DiscoveredPeer.deduplicated([first, second]).count, 1)

        let ifly = try XCTUnwrap(DiscoveredPeer.make(
            serviceType: "_ifly-continuity._tcp", serviceName: "iFly iPad", txt: iFlyLibraryTXT
        ))
        XCTAssertEqual(DiscoveredPeer.deduplicated([first, ifly]).map(\.app), [.iCube, .iFly])
    }

    func testUnknownServiceTypeIsIgnored() {
        XCTAssertNil(DiscoveredPeer.make(serviceType: "_http._tcp", serviceName: "x", txt: iFlyLibraryTXT))
    }

    func testServiceTypes() {
        XCTAssertEqual(PeerApp.iFly.serviceType, "_ifly-continuity._tcp")
        XCTAssertEqual(PeerApp.iCube.serviceType, "_icube-continuity._tcp")
    }
}

final class SystemMapTests: XCTestCase {
    func testIFlyPlatforms() {
        XCTAssertEqual(SystemMap.systemIdentifier(forPlatform: "Dreamcast", app: .iFly), .Dreamcast)
        XCTAssertEqual(SystemMap.systemIdentifier(forPlatform: "dreamcast", app: .iFly), .Dreamcast)
        XCTAssertEqual(SystemMap.systemIdentifier(forPlatform: "Naomi", app: .iFly), .NAOMI)
        XCTAssertEqual(SystemMap.systemIdentifier(forPlatform: "Naomi 2", app: .iFly), .NAOMI2)
        XCTAssertEqual(SystemMap.systemIdentifier(forPlatform: "Naomi2", app: .iFly), .NAOMI2)
        XCTAssertEqual(SystemMap.systemIdentifier(forPlatform: "Atomiswave", app: .iFly), .Atomiswave)
        XCTAssertNil(SystemMap.systemIdentifier(forPlatform: "System SP", app: .iFly))
        XCTAssertNil(SystemMap.systemIdentifier(forPlatform: "gc", app: .iFly), "maps are per app")
    }

    func testICubePlatforms() {
        XCTAssertEqual(SystemMap.systemIdentifier(forPlatform: "gc", app: .iCube), .GameCube)
        XCTAssertEqual(SystemMap.systemIdentifier(forPlatform: "GameCube", app: .iCube), .GameCube)
        XCTAssertEqual(SystemMap.systemIdentifier(forPlatform: "wii", app: .iCube), .Wii)
        XCTAssertEqual(SystemMap.systemIdentifier(forPlatform: "Wii", app: .iCube), .Wii)
        XCTAssertNil(SystemMap.systemIdentifier(forPlatform: "wiiu", app: .iCube))
    }

    func testSystemsServed() {
        XCTAssertEqual(SystemMap.systems(servedBy: .iFly), [.Dreamcast, .NAOMI, .NAOMI2, .Atomiswave])
        XCTAssertEqual(SystemMap.systems(servedBy: .iCube), [.GameCube, .Wii])
    }

    func testCatalogueFiltersToPlayableSystems() throws {
        let catalogue = try ICubeContinuitySource.decodeCatalogue(Fixture.data("icube-library-catalog"))
        let gameCubeOnly = catalogue.filtered(to: [.GameCube])
        XCTAssertEqual(gameCubeOnly.items.map(\.systemIdentifier), [.GameCube, .GameCube])
    }
}

final class LocalLibraryIndexTests: XCTestCase {
    private func remote(md5: String?, system: SystemIdentifier? = .GameCube, size: Int64 = 1000) -> RemoteLibraryItem {
        RemoteLibraryItem(id: "k", title: "T", platform: "gc", systemIdentifier: system, md5: md5,
                          sizeBytes: size, artKey: nil, source: .iCube)
    }

    /// Provenance stores MD5 upper-case; peers send lower-case.
    func testMatchesUpperCaseLocalMD5() {
        let index = LocalLibraryIndex(entries: [
            LocalLibraryEntry(md5: "ABCDEF0123456789ABCDEF0123456789", systemIdentifier: .GameCube,
                              sizeBytes: 1000, isSingleFileImage: true)
        ])
        XCTAssertTrue(index.contains(remote(md5: "abcdef0123456789abcdef0123456789")))
        XCTAssertFalse(index.contains(remote(md5: "abcdef0123456789abcdef0123456789", system: .Wii)))
        XCTAssertFalse(index.contains(remote(md5: "abcdef0123456789abcdef0123456789", size: 999)))
        XCTAssertFalse(index.contains(remote(md5: nil)))
    }

    func testUnknownSizeOnEitherSideStillMatches() {
        let index = LocalLibraryIndex(entries: [
            LocalLibraryEntry(md5: "AA", systemIdentifier: .Dreamcast, sizeBytes: 0, isSingleFileImage: true)
        ])
        XCTAssertTrue(index.contains(remote(md5: "aa", system: .Dreamcast, size: 123)))
        XCTAssertTrue(index.contains(remote(md5: "aa", system: .Dreamcast, size: 0)))
    }

    /// CD sets hash the cue/m3u/gdi text in Provenance, so they never match.
    func testMultiFileImagesNeverMatch() {
        XCTAssertTrue(LocalLibraryEntry.isSingleFileImage(primaryFileExtension: "rvz", relatedFileCount: 0))
        XCTAssertTrue(LocalLibraryEntry.isSingleFileImage(primaryFileExtension: "CHD", relatedFileCount: 0))
        XCTAssertFalse(LocalLibraryEntry.isSingleFileImage(primaryFileExtension: "gdi", relatedFileCount: 0))
        XCTAssertFalse(LocalLibraryEntry.isSingleFileImage(primaryFileExtension: "cue", relatedFileCount: 0))
        XCTAssertFalse(LocalLibraryEntry.isSingleFileImage(primaryFileExtension: "bin", relatedFileCount: 1))

        let index = LocalLibraryIndex(entries: [
            LocalLibraryEntry(md5: "BB", systemIdentifier: .Dreamcast, sizeBytes: 10, isSingleFileImage: false)
        ])
        XCTAssertTrue(index.isEmpty)
        XCTAssertFalse(index.contains(remote(md5: "bb", system: .Dreamcast, size: 10)))
    }
}
