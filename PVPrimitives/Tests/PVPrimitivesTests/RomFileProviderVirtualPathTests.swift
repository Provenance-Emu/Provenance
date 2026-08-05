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

    // MARK: - Save state identifiers

    @Test func saveStateGameFolderIdentifier_roundTrip() {
        let md5 = String(repeating: "A", count: 32)
        let id = RomFileProviderVirtualPath.saveStateGameFolderIdentifier(gameMD5: md5)
        #expect(id.hasPrefix(RomFileProviderVirtualPath.saveStateGameFolderPrefix))
        #expect(RomFileProviderVirtualPath.parseSaveStateGameMD5(from: id) == md5.uppercased())
    }

    @Test func saveStateItemIdentifier_roundTrip() {
        let ssID = "550e8400-e29b-41d4-a716-446655440000"
        let id = RomFileProviderVirtualPath.saveStateItemIdentifier(saveStateID: ssID)
        #expect(id.hasPrefix(RomFileProviderVirtualPath.saveStateItemPrefix))
        #expect(RomFileProviderVirtualPath.parseSaveStateID(from: id) == ssID)
    }

    @Test func parseSaveStateID_invalidPrefix() {
        #expect(RomFileProviderVirtualPath.parseSaveStateID(from: "game:ABCD") == nil)
        #expect(RomFileProviderVirtualPath.parseSaveStateGameMD5(from: "rating:5") == nil)
        // Empty id after prefix
        #expect(RomFileProviderVirtualPath.parseSaveStateID(from: "ss:") == nil)
        // Empty MD5 after folder prefix
        #expect(RomFileProviderVirtualPath.parseSaveStateGameMD5(from: "ss-game:") == nil)
    }

    // MARK: - Screenshot identifiers

    @Test func screenshotGameFolderIdentifier_roundTrip() {
        let md5 = String(repeating: "B", count: 32)
        let id = RomFileProviderVirtualPath.screenshotGameFolderIdentifier(gameMD5: md5)
        #expect(id.hasPrefix(RomFileProviderVirtualPath.screenshotGameFolderPrefix))
        #expect(RomFileProviderVirtualPath.parseScreenshotGameMD5(from: id) == md5.uppercased())
    }

    @Test func screenshotItemIdentifier_roundTrip() {
        let md5 = String(repeating: "C", count: 32)
        let index = 7
        let id = RomFileProviderVirtualPath.screenshotItemIdentifier(gameMD5: md5, index: index)
        #expect(id.hasPrefix(RomFileProviderVirtualPath.screenshotItemPrefix))
        let parsed = RomFileProviderVirtualPath.parseScreenshotID(from: id)
        #expect(parsed?.gameMD5 == md5.uppercased())
        #expect(parsed?.index == index)
    }

    @Test func parseScreenshotID_invalidPrefix() {
        #expect(RomFileProviderVirtualPath.parseScreenshotID(from: "game:ABCD") == nil)
        #expect(RomFileProviderVirtualPath.parseScreenshotGameMD5(from: "year:1998") == nil)
        // Empty MD5 after folder prefix
        #expect(RomFileProviderVirtualPath.parseScreenshotGameMD5(from: "sc-game:") == nil)
        // sc-game: prefix must NOT be parsed as a screenshot item (sc: prefix)
        let scGameRaw = "sc-game:" + String(repeating: "A", count: 32)
        #expect(RomFileProviderVirtualPath.parseScreenshotID(from: scGameRaw) == nil)
    }

    @Test func screenshotItemIdentifier_zeroIndex() {
        let md5 = String(repeating: "D", count: 32)
        let id = RomFileProviderVirtualPath.screenshotItemIdentifier(gameMD5: md5, index: 0)
        let parsed = RomFileProviderVirtualPath.parseScreenshotID(from: id)
        #expect(parsed?.gameMD5 == md5.uppercased())
        #expect(parsed?.index == 0)
    }

    @Test func parseScreenshotID_rejectsNegativeIndex() {
        let md5 = String(repeating: "E", count: 32)
        let raw = "\(RomFileProviderVirtualPath.screenshotItemPrefix)\(md5):-1"
        #expect(RomFileProviderVirtualPath.parseScreenshotID(from: raw) == nil)
    }

    // MARK: - Root categories

    @Test func rootCategory_saveStatesAndScreenshots_present() {
        let cases = RomFileProviderRootCategory.allCases.map { $0 }
        #expect(cases.contains(.saveStates))
        #expect(cases.contains(.screenshots))
        #expect(RomFileProviderRootCategory.saveStates.folderDisplayName == "Save States")
        #expect(RomFileProviderRootCategory.screenshots.folderDisplayName == "Screenshots")
    }
}
