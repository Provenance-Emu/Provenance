//
//  FuzzyGameMatcherTests.swift
//  PVPrimitivesTests
//

import XCTest
@testable import PVPrimitives

final class FuzzyGameMatcherTests: XCTestCase {

    // MARK: - normalize

    func testNormalize_stripsRegionAndRevision() {
        XCTAssertEqual(FuzzyGameMatcher.normalize("Sonic the Hedgehog (USA) (Rev 1)"), "Sonic the Hedgehog")
    }

    func testNormalize_stripsBracketFlags() {
        XCTAssertEqual(FuzzyGameMatcher.normalize("Final Fantasy VII [!]"), "Final Fantasy VII")
    }

    func testNormalize_alreadyClean() {
        XCTAssertEqual(FuzzyGameMatcher.normalize("Castlevania"), "Castlevania")
    }

    func testNormalize_stripsDiscLabel() {
        XCTAssertEqual(FuzzyGameMatcher.normalize("Metal Gear Solid (Disc 1) (USA)"), "Metal Gear Solid")
    }

    func testNormalize_doesNotReturnEmptyWhenAllTagsStripped() {
        // When stripping tags would produce an empty string, the original is returned.
        XCTAssertEqual(FuzzyGameMatcher.normalize("(USA)"), "(USA)")
    }

    // MARK: - editDistance

    func testEditDistance_identical() {
        XCTAssertEqual(FuzzyGameMatcher.editDistance("Castlevania", "Castlevania"), 0)
    }

    func testEditDistance_oneSubstitution() {
        XCTAssertEqual(FuzzyGameMatcher.editDistance("Castlevania", "Castlevan1a"), 1)
    }

    func testEditDistance_emptyStrings() {
        XCTAssertEqual(FuzzyGameMatcher.editDistance("", ""), 0)
        XCTAssertEqual(FuzzyGameMatcher.editDistance("abc", ""), 3)
        XCTAssertEqual(FuzzyGameMatcher.editDistance("", "abc"), 3)
    }

    func testEditDistance_completelyDifferent() {
        let dist = FuzzyGameMatcher.editDistance("Mario", "Zelda")
        XCTAssertGreaterThan(dist, 3)
    }

    // MARK: - similarity

    func testSimilarity_exactMatchAfterNormalization() {
        let score = FuzzyGameMatcher.similarity("Castlevania", "Castlevania (USA)")
        XCTAssertEqual(score, 1.0, accuracy: 0.001)
    }

    func testSimilarity_identical() {
        XCTAssertEqual(FuzzyGameMatcher.similarity("Castlevania", "Castlevania"), 1.0, accuracy: 0.001)
    }

    func testSimilarity_oneTypo() {
        let score = FuzzyGameMatcher.similarity("Castlevania", "Castlevan1a")
        XCTAssertGreaterThan(score, 0.85)
    }

    func testSimilarity_completelyDifferent() {
        let score = FuzzyGameMatcher.similarity("Mario", "Zelda")
        XCTAssertLessThan(score, 0.3)
    }

    func testSimilarity_emptyQuery() {
        let score = FuzzyGameMatcher.similarity("", "Castlevania")
        XCTAssertLessThan(score, 0.1)
    }

    func testSimilarity_bothEmpty() {
        XCTAssertEqual(FuzzyGameMatcher.similarity("", ""), 1.0, accuracy: 0.001)
    }

    func testSimilarity_tokenOverlapDespiteWordOrder() {
        // "Super Mario Bros" vs "Mario Bros Super" — same tokens, different order
        let score = FuzzyGameMatcher.similarity("Super Mario Bros", "Mario Bros Super")
        XCTAssertGreaterThan(score, 0.7)
    }

    // MARK: - rank

    func testRank_returnsHighestScoreFirst() {
        let candidates = ["Castlevania II", "Castlevania", "Super Mario Bros"]
        let results = FuzzyGameMatcher.rank(query: "Castlevania", candidates: candidates)
        XCTAssertFalse(results.isEmpty)
        XCTAssertEqual(results[0].title, "Castlevania")
        XCTAssertGreaterThan(results[0].score, results[1].score)
    }

    func testRank_excludesZeroScores() {
        let candidates = ["Zelda", "Metroid"]
        let results = FuzzyGameMatcher.rank(query: "Castlevania", candidates: candidates)
        XCTAssertTrue(results.allSatisfy { $0.score > 0 })
    }

    func testRank_emptyInputReturnsEmpty() {
        XCTAssertTrue(FuzzyGameMatcher.rank(query: "Mario", candidates: []).isEmpty)
    }

    // MARK: - bestMatch

    func testBestMatch_returnsClosestTitle() {
        let candidates = ["Mega Man 2", "Mega Man", "Pac-Man"]
        let best = FuzzyGameMatcher.bestMatch(query: "Mega Man", candidates: candidates)
        XCTAssertEqual(best, "Mega Man")
    }

    func testBestMatch_emptyCandidatesReturnsNil() {
        XCTAssertNil(FuzzyGameMatcher.bestMatch(query: "Mario", candidates: []))
    }
}
