//
//  RomFileProviderVirtualPathTests.swift
//  PVPrimitivesTests
//

import Foundation
import Testing
@testable import PVPrimitives

@Suite("RomFileProviderVirtualPath")
struct RomFileProviderVirtualPathTests {

    @Test func encodeDecodeSegment_roundTrip() {
        let samples = ["Nintendo", "Sega / Genesis", "Unknown:Test", "日本"]
        for sample in samples {
            let enc = RomFileProviderVirtualPath.encodeSegment(sample)
            #expect(RomFileProviderVirtualPath.decodeSegment(enc) == sample)
        }
    }

    @Test func symlinkIdentifier_deterministic() {
        let md5 = String(repeating: "A", count: 32)
        let first = RomFileProviderVirtualPath.symlinkIdentifier(gameMD5: md5, parentItemRaw: "puball:abc")
        let second = RomFileProviderVirtualPath.symlinkIdentifier(gameMD5: md5, parentItemRaw: "puball:abc")
        #expect(first == second)
        #expect(first.hasPrefix(RomFileProviderVirtualPath.symlinkPrefix))
    }

    @Test func symlinkIdentifier_differentParents() {
        let md5 = String(repeating: "1", count: 32)
        let idParentA = RomFileProviderVirtualPath.symlinkIdentifier(gameMD5: md5, parentItemRaw: "parentA")
        let idParentB = RomFileProviderVirtualPath.symlinkIdentifier(gameMD5: md5, parentItemRaw: "parentB")
        #expect(idParentA != idParentB)
    }

    @Test func parseSymlink_roundTrip() {
        let md5 = String(repeating: "F", count: 32)
        let parent = "year:1999"
        let id = RomFileProviderVirtualPath.symlinkIdentifier(gameMD5: md5, parentItemRaw: parent)
        let parsed = RomFileProviderVirtualPath.parseSymlink(from: id)
        #expect(parsed?.md5 == md5.uppercased())
        #expect(parsed?.parentItemRaw == parent)
        #expect(RomFileProviderVirtualPath.parseSymlinkMD5(from: id) == md5.uppercased())
    }

    @Test func yearBucket() {
        #expect(RomFileProviderVirtualPath.yearBucket(fromPublishDate: nil) == "Unknown")
        #expect(RomFileProviderVirtualPath.yearBucket(fromPublishDate: "1998") == "1998")
        #expect(RomFileProviderVirtualPath.yearBucket(fromPublishDate: "Released 2001") == "2001")
    }

    @Test func publisherGroupingKey() {
        #expect(RomFileProviderVirtualPath.publisherGroupingKey(nil) == RomFileProviderVirtualPath.unknownGroupingKey)
        #expect(RomFileProviderVirtualPath.publisherGroupingKey("  Capcom  ") == "capcom")
    }

    @Test func ratingFolderKeyAndLabel() {
        let unrated = RomFileProviderVirtualPath.ratingFolderKeyAndLabel(rating: -1)
        #expect(unrated.key == "unrated")
        let three = RomFileProviderVirtualPath.ratingFolderKeyAndLabel(rating: 3)
        #expect(three.key == "3")
        #expect(three.label.contains("3"))
    }
}
