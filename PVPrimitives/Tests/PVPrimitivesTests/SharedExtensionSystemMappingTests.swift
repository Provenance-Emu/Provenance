//
//  SharedExtensionSystemMappingTests.swift
//  PVPrimitivesTests
//
//  Contract tests for import formats claimed by MANY systems — the case that
//  forces the importer to guess. `.bin` alone is claimed by 13 systems, `.cue`
//  by 13, `.chd` by 15 and `.zip` by 48, so one wrong entry in systems.plist
//  silently changes which system a ROM lands on.
//
//  These live in PVPrimitives (not PVLibrary) deliberately: they are pure plist
//  parsing plus the `SystemIdentifier` enum, and PVPrimitives actually builds and
//  tests standalone (`swift test`). PVLibrary's test target does not currently
//  compile or run — see the cue/bin tests in
//  PVLibrary/Tests/PVLibraryTests/SharedExtensionImportTests.swift.
//

import XCTest
import PVSystems
@testable import PVPrimitives

final class SharedExtensionSystemMappingTests: XCTestCase {

    private struct SystemEntry {
        let identifier: String
        let name: String
        let extensions: [String]
    }

    /// systems.plist lives in PVLibrary's resources; locate it relative to this
    /// source file so the test needs no resource-bundle plumbing.
    private static var systemsPlistURL: URL {
        URL(fileURLWithPath: #filePath)     // .../PVPrimitives/Tests/PVPrimitivesTests/<file>.swift
            .deletingLastPathComponent()    // .../Tests/PVPrimitivesTests
            .deletingLastPathComponent()    // .../Tests
            .deletingLastPathComponent()    // .../PVPrimitives
            .deletingLastPathComponent()    // repo root
            .appendingPathComponent("PVLibrary/Sources/PVLibrary/Resources/systems.plist")
    }

    private func loadSystems() throws -> [SystemEntry] {
        let url = Self.systemsPlistURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            XCTFail("systems.plist not found at \(url.path)")
            return []
        }
        let data = try Data(contentsOf: url)
        guard let raw = try PropertyListSerialization.propertyList(
            from: data, options: [], format: nil) as? [[String: Any]] else {
            XCTFail("systems.plist is not an array of dictionaries")
            return []
        }
        return raw.map {
            SystemEntry(identifier: $0["PVSystemIdentifier"] as? String ?? "",
                        name: $0["PVSystemName"] as? String ?? "",
                        extensions: ($0["PVSupportedExtensions"] as? [String] ?? []))
        }
    }

    private func systems(claiming ext: String, in entries: [SystemEntry]) -> Set<String> {
        Set(entries
            .filter { $0.extensions.contains { $0.lowercased() == ext.lowercased() } }
            .map(\.identifier))
    }

    // MARK: - The .bin ambiguity surface

    /// `.bin` is the worst offender: a bare `.bin` could belong to any of these,
    /// which is why system resolution has to fall through to MD5 / filename /
    /// parent-directory disambiguation. Pin the set so a plist edit that changes
    /// the cost or outcome of that fallback fails loudly.
    func testBinIsClaimedByExpectedSystems() throws {
        let entries = try loadSystems()
        let expected: Set<String> = Set([
            SystemIdentifier.VirtualBoy,
            .Genesis,
            .NAOMI,
            .Atomiswave,
            .NAOMI2,
            .GBA,
            .Atari2600,
            .Atari7800,
            .AtariJaguar,
            .Atari5200,
            .Atari8bit,
            .Intellivision,
            .Supervision
        ].map(\.rawValue))

        XCTAssertEqual(systems(claiming: "bin", in: entries), expected,
                       "The set of systems claiming .bin changed. If intentional, update this "
                       + "expectation — but confirm system resolution still disambiguates correctly.")
    }

    /// Every identifier in the plist must map to a real `SystemIdentifier` case,
    /// otherwise resolution silently drops that system.
    func testEveryPlistSystemMapsToSystemIdentifierEnum() throws {
        let unmapped = try loadSystems()
            .filter { SystemIdentifier(rawValue: $0.identifier) == nil }
            .map { "\($0.identifier) (\($0.name))" }

        XCTAssertTrue(unmapped.isEmpty,
                      "systems.plist has identifiers with no SystemIdentifier case: \(unmapped)")
    }

    /// These formats are inherently multi-system. Assert they stay ambiguous so a
    /// single-system fast path is never wrongly taken for them.
    func testKnownSharedExtensionsRemainAmbiguous() throws {
        let entries = try loadSystems()
        for ext in ["bin", "cue", "chd", "iso", "img", "zip"] {
            let claimants = systems(claiming: ext, in: entries)
            XCTAssertGreaterThan(claimants.count, 1,
                                 ".\(ext) should be claimed by more than one system (got \(claimants.sorted()))")
        }
    }

    /// The same extension listed twice verbatim would inflate the ambiguity count
    /// and skew the "limited systems" (<= 3) heuristic used during resolution.
    func testNoSystemListsTheSameExtensionTwice() throws {
        for entry in try loadSystems() {
            XCTAssertEqual(entry.extensions.count, Set(entry.extensions).count,
                           "\(entry.identifier) lists a duplicate extension: \(entry.extensions)")
        }
    }

    func testNoDuplicateSystemIdentifiers() throws {
        let ids = try loadSystems().map(\.identifier)
        XCTAssertEqual(ids.count, Set(ids).count, "systems.plist has duplicate PVSystemIdentifier entries")
    }

    /// `PVEmulatorConfiguration.systemsFromCache(forFileExtension:)` matches with
    /// `system.supportedExtensions.contains(fileExtension.lowercased())` — the
    /// needle is always lowercased but the stored values are compared verbatim.
    /// So an extension that exists ONLY in uppercase can never match, and files
    /// with it would silently fail to resolve to any system.
    ///
    /// Today 21 uppercase entries exist (e.g. "CONF", "32X", pc98's "D98"/"ZIP"),
    /// but every one has a lowercase twin, so they are dead weight rather than a
    /// live bug. This test guards the case that WOULD be a bug.
    func testNoExtensionIsReachableOnlyInUppercase() throws {
        for entry in try loadSystems() {
            let lowercased = Set(entry.extensions.filter { $0 == $0.lowercased() })
            let unreachable = entry.extensions.filter { $0 != $0.lowercased() && !lowercased.contains($0.lowercased()) }
            XCTAssertTrue(unreachable.isEmpty,
                          "\(entry.identifier) has uppercase-only extensions that can never match: \(unreachable)")
        }
    }

    /// Archives are the other big ambiguity class: `.zip` is claimed by dozens of
    /// systems, so a zip can only be treated as a ROM (rather than extracted) when
    /// something else — the parent system directory or an explicit user choice —
    /// narrows it down.
    func testZipIsClaimedByManySystemsSoItCannotBeResolvedByExtensionAlone() throws {
        let claimants = systems(claiming: "zip", in: try loadSystems())
        XCTAssertGreaterThan(claimants.count, 10,
                             "Expected .zip to be broadly claimed; got \(claimants.count)")
        // Spot-check systems that genuinely ship zip-as-ROM (arcade ROM sets).
        let arcadeSystems: [SystemIdentifier] = [.MAME, .CPS1, .CPS2, .CPS3]
        for arcade in arcadeSystems {
            XCTAssertTrue(claimants.contains(arcade.rawValue),
                          "\(arcade.rawValue) should accept .zip as the ROM itself")
        }
    }
}
