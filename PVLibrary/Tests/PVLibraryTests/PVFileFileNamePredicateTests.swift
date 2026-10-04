//
//  PVFileFileNamePredicateTests.swift
//  PVLibraryTests
//
//  `PVFile.fileName` is computed, so querying it directly made Realm throw
//  "Invalid property name" on every M3U import. The predicate matches the
//  stored partialPath instead.
//

import XCTest
import RealmSwift
@testable import PVRealm

final class PVFileFileNamePredicateTests: XCTestCase {

    private var realm: Realm!

    override func setUpWithError() throws {
        realm = try Realm(configuration: Realm.Configuration(inMemoryIdentifier: UUID().uuidString))
        try realm.write {
            for path in ["ROMs/com.provenance.psx/Game (Disc 1).cue",
                         "ROMs/com.provenance.psx/Other Game (Disc 1).cue",
                         "Game (Disc 2).cue"] {
                realm.add(PVFile(withPartialPath: path))
            }
        }
    }

    override func tearDownWithError() throws {
        realm = nil
    }

    private func matches(_ fileName: String) -> [String] {
        realm.objects(PVFile.self).filter(PVFile.fileNamePredicate(fileName)).map(\.partialPath).sorted()
    }

    func testMatchesTheLastPathComponentOnly() {
        // "Other Game (Disc 1).cue" also ends in "Game (Disc 1).cue" but not in
        // "/Game (Disc 1).cue".
        XCTAssertEqual(matches("Game (Disc 1).cue"), ["ROMs/com.provenance.psx/Game (Disc 1).cue"])
    }

    func testMatchesAPathWithNoDirectory() {
        XCTAssertEqual(matches("Game (Disc 2).cue"), ["Game (Disc 2).cue"])
    }

    func testNoMatch() {
        XCTAssertEqual(matches("Missing.cue"), [])
    }
}
