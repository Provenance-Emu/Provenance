//
//  ArtworkBackfillTriageTests.swift
//  PVLibraryTests
//
//  Tests for CloudKitRomsSyncer's artwork triage logic — the decision of
//  which recovery strategy to use for each game during sync artwork backfill.
//

import XCTest
@testable import PVLibrary

final class ArtworkBackfillTriageTests: XCTestCase {

    // MARK: - triageArtwork tests

    func test_httpURL_classifiedAsRedownload() {
        let result = CloudKitRomsSyncer.triageArtwork(
            originalArtworkURL: "https://cdn.thegamesdb.net/images/boxart/front/12345-1.jpg",
            customArtworkURL: ""
        )
        XCTAssertEqual(result, .httpRedownload)
    }

    func test_httpURL_withPort_classifiedAsRedownload() {
        let result = CloudKitRomsSyncer.triageArtwork(
            originalArtworkURL: "http://images.example.com:8080/art/game.png",
            customArtworkURL: ""
        )
        XCTAssertEqual(result, .httpRedownload)
    }

    func test_customArtwork_classifiedAsCloudKit() {
        let result = CloudKitRomsSyncer.triageArtwork(
            originalArtworkURL: "https://cdn.example.com/art.jpg",
            customArtworkURL: "custom_artwork/my_cover.png"
        )
        XCTAssertEqual(result, .cloudKitAsset)
    }

    func test_customArtwork_taksPriorityOverHTTPURL() {
        // Even when originalArtworkURL is a valid HTTP URL, custom artwork wins
        let result = CloudKitRomsSyncer.triageArtwork(
            originalArtworkURL: "https://example.com/original.jpg",
            customArtworkURL: "user_uploaded.png"
        )
        XCTAssertEqual(result, .cloudKitAsset)
    }

    func test_emptyBothURLs_classifiedAsNeedsLookup() {
        let result = CloudKitRomsSyncer.triageArtwork(
            originalArtworkURL: "",
            customArtworkURL: ""
        )
        XCTAssertEqual(result, .needsLookup)
    }

    func test_fileURL_classifiedAsNeedsLookup() {
        // file:// URLs can't be re-downloaded from the network
        let result = CloudKitRomsSyncer.triageArtwork(
            originalArtworkURL: "file:///var/mobile/Containers/Data/art.jpg",
            customArtworkURL: ""
        )
        XCTAssertEqual(result, .needsLookup)
    }

    func test_dataURL_classifiedAsNeedsLookup() {
        let result = CloudKitRomsSyncer.triageArtwork(
            originalArtworkURL: "data:image/png;base64,iVBORw0KGgo=",
            customArtworkURL: ""
        )
        XCTAssertEqual(result, .needsLookup)
    }

    func test_malformedURL_classifiedAsNeedsLookup() {
        let result = CloudKitRomsSyncer.triageArtwork(
            originalArtworkURL: "not a valid url at all",
            customArtworkURL: ""
        )
        XCTAssertEqual(result, .needsLookup)
    }

    func test_ftpURL_classifiedAsNeedsLookup() {
        let result = CloudKitRomsSyncer.triageArtwork(
            originalArtworkURL: "ftp://files.example.com/art.jpg",
            customArtworkURL: ""
        )
        XCTAssertEqual(result, .needsLookup)
    }

    func test_customArtworkOnly_noOriginal_classifiedAsCloudKit() {
        let result = CloudKitRomsSyncer.triageArtwork(
            originalArtworkURL: "",
            customArtworkURL: "my_custom_art.png"
        )
        XCTAssertEqual(result, .cloudKitAsset)
    }
}

// MARK: - Equatable conformance for test assertions

extension CloudKitRomsSyncer.ArtworkBucket: Equatable {}
