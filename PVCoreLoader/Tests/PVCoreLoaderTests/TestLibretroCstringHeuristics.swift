import XCTest
@testable import PVCoreLoader

/// `retro_system_info` recovery from a dylib's `__cstring` table.
/// Regression: a TestFlight user saw the flycast version as "DEBUGBREAK!".
final class TestLibretroCstringHeuristics: XCTestCase {

    private func pick(_ strings: [String]) -> LibretroCstringHeuristics.Guess? {
        guard let idx = LibretroCstringHeuristics.validExtensionsIndex(in: strings) else { return nil }
        return LibretroCstringHeuristics.pickNameAndVersion(strings: strings, extensionsIndex: idx)
    }

    func testFlycastJitlessGitDescribeVersionBeatsLaterLiteral() {
        let strings = [
            "retro_run", "Flycast",
            "pre-upstream-merge-2026-10-12-23-g7957775f5",
            "chd|cdi|elf|cue|gdi|lst|bin|dat|zip|7z|m3u",
            "DEBUGBREAK!", "unrelated literal"
        ]
        XCTAssertEqual(pick(strings)?.name, "Flycast")
        XCTAssertEqual(pick(strings)?.version, "pre-upstream-merge-2026-10-12-23-g7957775f5")
    }

    func testOldFlycastVersion() {
        let strings = ["Flycast", "v2.4-477-gb797eb408", "chd|cdi|elf|cue|gdi|lst|bin|dat|zip|7z|m3u", "DEBUGBREAK!"]
        XCTAssertEqual(pick(strings), .init(name: "Flycast", version: "v2.4-477-gb797eb408"))
    }

    func testDigitOnlyAdjacentVersionIsAccepted() {
        let strings = ["Some Core", "0.9.8", "gb|gbc|dmg", "DEBUGBREAK!"]
        XCTAssertEqual(pick(strings), .init(name: "Some Core", version: "0.9.8"))
    }

    func testStringsAfterValidExtensionsLoseToStringBefore() {
        let strings = ["mGBA", "0.11-8c4b3a1", "gba|gb|gbc", "DEBUGBREAK!", "Unknown error"]
        XCTAssertEqual(pick(strings)?.version, "0.11-8c4b3a1")
    }

    func testFallbackWindowWhenAdjacentStringIsJunk() {
        let strings = ["Foo Core", "v1.2.3", "%s: error", "gb|gbc", "DEBUGBREAK!"]
        XCTAssertEqual(pick(strings), .init(name: "Foo Core", version: "v1.2.3"))
    }

    func testFallbackWhenAdjacentVersionIsADate() {
        let strings = ["Foo Core", "v1.2.3", "2024.10.29", "gb|gbc"]
        XCTAssertEqual(pick(strings), .init(name: "Foo Core", version: "v1.2.3"))
    }

    func testFallbackUsesStringAfterOnlyWhenNothingBefore() {
        let strings = ["Foo Core", "%s", "gb|gbc", "v3.1"]
        XCTAssertEqual(pick(strings), .init(name: "Foo Core", version: "v3.1"))
    }

    func testAdjacentNameOnlyDoesNotBecomeVersion() {
        // No digit in the adjacent string: it is the name, not the version.
        let strings = ["Foo Core", "gb|gbc", "v3.1"]
        XCTAssertEqual(pick(strings), .init(name: "Foo Core", version: "v3.1"))
    }

    func testVersionLengthCapAllowsGitDescribe() {
        let version = String(repeating: "a1", count: 32)   // 64 chars
        XCTAssertTrue(LibretroCstringHeuristics.isPlausibleVersion(version))
        XCTAssertFalse(LibretroCstringHeuristics.isPlausibleVersion(version + "x"))
    }

    func testNoNameReturnsNil() {
        XCTAssertNil(pick(["%d", "1.0", "gb|gbc"]))
    }

    func testCacheRevisionBumpedPastLegacyHeuristic() {
        // Legacy caches: metadata reader v4, scanner v3. A stale "DEBUGBREAK!" lives in those.
        XCTAssertGreaterThan(LibretroCstringHeuristics.cacheRevision, 4)
    }
}
