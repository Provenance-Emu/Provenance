//
//  ROMTitleNormalizationServiceTests.swift
//  PVLibraryTests
//
//  Tests for ROMTitleNormalizationService using an in-memory Realm instance.
//

import XCTest
import RealmSwift
@testable import PVLibrary
@testable import PVRealm

final class ROMTitleNormalizationServiceTests: XCTestCase {

    // MARK: - Setup / Teardown

    private var previousRealmConfiguration: Realm.Configuration?

    override func setUp() {
        super.setUp()
        previousRealmConfiguration = Realm.Configuration.defaultConfiguration
        Realm.Configuration.defaultConfiguration = Realm.Configuration(
            inMemoryIdentifier: "ROMTitleNormalizationServiceTests-\(name)"
        )
    }

    override func tearDown() {
        if let realm = try? Realm() {
            try? realm.write { realm.deleteAll() }
        }
        if let previous = previousRealmConfiguration {
            Realm.Configuration.defaultConfiguration = previous
        }
        super.tearDown()
    }

    // MARK: - Helpers

    /// Inserts a PVGame with the given title and md5Hash into the default (in-memory) Realm.
    private func insertGame(md5Hash: String, title: String) throws {
        let realm = try Realm()
        let game = PVGame()
        game.md5Hash = md5Hash
        game.title = title
        try realm.write { realm.add(game) }
    }

    private let service = ROMTitleNormalizationService()

    // MARK: - buildProposals tests

    func testBuildProposals_returnsProposalForAnnotatedTitle() async throws {
        try insertGame(md5Hash: "aabbcc", title: "Bomberman (USA) [!]")

        let proposals = try await service.buildProposals()

        XCTAssertEqual(proposals.count, 1)
        XCTAssertEqual(proposals[0].id, "aabbcc")
        XCTAssertEqual(proposals[0].currentTitle, "Bomberman (USA) [!]")
        XCTAssertEqual(proposals[0].proposedTitle, "Bomberman")
    }

    func testBuildProposals_excludesAlreadyCleanTitle() async throws {
        try insertGame(md5Hash: "ddeeff", title: "Castlevania")

        let proposals = try await service.buildProposals()

        XCTAssertTrue(proposals.isEmpty)
    }

    func testBuildProposals_returnsMultipleProposals() async throws {
        try insertGame(md5Hash: "111111", title: "Tetris (Japan) [!]")
        try insertGame(md5Hash: "222222", title: "Super Mario Bros.")
        try insertGame(md5Hash: "333333", title: "Mega Man (USA)")

        let proposals = try await service.buildProposals()

        XCTAssertEqual(proposals.count, 2)
        let ids = Set(proposals.map(\.id))
        XCTAssertTrue(ids.contains("111111"))
        XCTAssertTrue(ids.contains("333333"))
        XCTAssertFalse(ids.contains("222222"))
    }

    // MARK: - applyProposals tests

    func testApplyProposals_updatesTitleInRealm() async throws {
        try insertGame(md5Hash: "abc123", title: "Sonic (USA)")
        let proposal = ROMTitleRenameProposal(id: "abc123", currentTitle: "Sonic (USA)", proposedTitle: "Sonic")

        try await service.applyProposals([proposal])

        let realm = try Realm()
        let game = realm.object(ofType: PVGame.self, forPrimaryKey: "abc123")
        XCTAssertEqual(game?.title, "Sonic")
    }

    func testApplyProposals_skipsUnknownID() async throws {
        let proposal = ROMTitleRenameProposal(id: "nonexistent", currentTitle: "Foo (Bar)", proposedTitle: "Foo")

        // Should not throw even if the game is missing; returns 0 since nothing was updated
        let count = try await service.applyProposals([proposal])
        XCTAssertEqual(count, 0)
    }

    func testApplyProposals_returnsAccurateCount() async throws {
        try insertGame(md5Hash: "real001", title: "Sonic (USA)")
        let p1 = ROMTitleRenameProposal(id: "real001", currentTitle: "Sonic (USA)", proposedTitle: "Sonic")
        let p2 = ROMTitleRenameProposal(id: "ghost999", currentTitle: "Ghost (USA)", proposedTitle: "Ghost")

        let count = try await service.applyProposals([p1, p2])
        // Only the game with a real ID should be counted
        XCTAssertEqual(count, 1)
    }

    func testApplyProposals_handlesDuplicateIDsWithLastWriteWins() async throws {
        try insertGame(md5Hash: "dup001", title: "Game (USA)")
        let p1 = ROMTitleRenameProposal(id: "dup001", currentTitle: "Game (USA)", proposedTitle: "Game A")
        let p2 = ROMTitleRenameProposal(id: "dup001", currentTitle: "Game (USA)", proposedTitle: "Game B")

        try await service.applyProposals([p1, p2])

        let realm = try Realm()
        let game = realm.object(ofType: PVGame.self, forPrimaryKey: "dup001")
        // Last-write-wins dedup — either "Game A" or "Game B", but not the original
        XCTAssertNotEqual(game?.title, "Game (USA)")
    }

    // MARK: - buildProposals + applyProposals round-trip

    func testNormalizeAll_updatesAllAnnotatedTitles() async throws {
        try insertGame(md5Hash: "r001", title: "Final Fantasy VII (Disc 2) (USA)")
        try insertGame(md5Hash: "r002", title: "Mega Man X")

        try await service.normalizeAll()

        let realm = try Realm()
        XCTAssertEqual(realm.object(ofType: PVGame.self, forPrimaryKey: "r001")?.title, "Final Fantasy VII")
        XCTAssertEqual(realm.object(ofType: PVGame.self, forPrimaryKey: "r002")?.title, "Mega Man X")
    }
}
