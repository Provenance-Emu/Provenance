//
//  GameMatchSourceTests.swift
//  PVPrimitivesTests
//
//  Tests for GameMatchSource enum and GameCustomizedFields OptionSet.
//

import XCTest
@testable import PVPrimitives

final class GameMatchSourceTests: XCTestCase {

    // MARK: - GameMatchSource raw value round-trips

    func testMatchSourceNoneIsZero() {
        XCTAssertEqual(GameMatchSource.none.rawValue, 0)
    }

    func testMatchSourceFromValidRawValues() {
        XCTAssertEqual(GameMatchSource(rawValue: 0), .none)
        XCTAssertEqual(GameMatchSource(rawValue: 1), .md5)
        XCTAssertEqual(GameMatchSource(rawValue: 2), .nameLookup)
        XCTAssertEqual(GameMatchSource(rawValue: 3), .userImported)
        XCTAssertEqual(GameMatchSource(rawValue: 4), .manual)
    }

    func testMatchSourceFromInvalidRawValueReturnsNil() {
        XCTAssertNil(GameMatchSource(rawValue: -1))
        XCTAssertNil(GameMatchSource(rawValue: 99))
    }

    func testMatchSourceDescriptionsAreNonEmpty() {
        let cases: [GameMatchSource] = [.none, .md5, .nameLookup, .userImported, .manual]
        for source in cases {
            XCTAssertFalse(source.description.isEmpty, "Description for \(source) should not be empty")
        }
    }

    func testMatchSourceRawValueRoundTrip() {
        let original = GameMatchSource.md5
        let stored = original.rawValue
        let restored = GameMatchSource(rawValue: stored)
        XCTAssertEqual(restored, original)
    }
}

final class GameCustomizedFieldsTests: XCTestCase {

    // MARK: - OptionSet semantics

    func testEmptySetHasRawValueZero() {
        let empty = GameCustomizedFields()
        XCTAssertEqual(empty.rawValue, 0)
    }

    func testSingleFieldContainsCorrectly() {
        let fields = GameCustomizedFields([.title])
        XCTAssertTrue(fields.contains(.title))
        XCTAssertFalse(fields.contains(.artwork))
    }

    func testMultipleFieldsUnion() {
        let fields: GameCustomizedFields = [.title, .developer, .publisher]
        XCTAssertTrue(fields.contains(.title))
        XCTAssertTrue(fields.contains(.developer))
        XCTAssertTrue(fields.contains(.publisher))
        XCTAssertFalse(fields.contains(.artwork))
        XCTAssertFalse(fields.contains(.genres))
    }

    func testIsDisjointNoOverlap() {
        let a: GameCustomizedFields = [.title, .artwork]
        let b: GameCustomizedFields = [.developer, .publisher]
        XCTAssertTrue(a.isDisjoint(with: b))
    }

    func testIsDisjointWithOverlap() {
        let a: GameCustomizedFields = [.title, .artwork]
        let b: GameCustomizedFields = [.title, .developer]
        XCTAssertFalse(a.isDisjoint(with: b))
    }

    func testSubtractingFieldRemovesIt() {
        var fields: GameCustomizedFields = [.title, .developer]
        fields.subtract(.title)
        XCTAssertFalse(fields.contains(.title))
        XCTAssertTrue(fields.contains(.developer))
    }

    func testAllDefinedFieldsHaveDistinctBitmasks() {
        let allFields: [GameCustomizedFields] = [
            .title, .artwork, .description, .developer, .publisher,
            .genres, .releaseDate, .rating, .boxBackArt, .referenceURL
        ]
        let rawValues = allFields.map(\.rawValue)
        let uniqueValues = Set(rawValues)
        XCTAssertEqual(uniqueValues.count, allFields.count, "Every field must have a unique bitmask")
    }

    func testRawValueRoundTrip() {
        let original: GameCustomizedFields = [.title, .artwork, .developer]
        let restored = GameCustomizedFields(rawValue: original.rawValue)
        XCTAssertEqual(restored, original)
    }

    func testDefaultRawValueIsEmpty() {
        let fields = GameCustomizedFields(rawValue: 0)
        XCTAssertTrue(fields.isEmpty)
    }
}
