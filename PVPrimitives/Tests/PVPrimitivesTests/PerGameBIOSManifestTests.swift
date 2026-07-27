//
//  PerGameBIOSManifestTests.swift
//  PVPrimitivesTests
//
//  Covers manifest parsing and game → required-BIOS resolution.
//

import Testing
import Foundation
@testable import PVSystems

// MARK: - Fixtures

private enum Fixture {
    static let naomi = SystemIdentifier.NAOMI.rawValue
    static let naomi2 = SystemIdentifier.NAOMI2.rawValue
    static let atomiswave = SystemIdentifier.Atomiswave.rawValue
    static let dreamcast = SystemIdentifier.Dreamcast.rawValue

    /// A hand-written manifest exercising every shape the schema allows:
    /// single BIOS, several BIOS, MD5 matching, and an optional requirement.
    /// `multi` and `md5only` are synthetic — see the note in the test below.
    static let json = """
    {
      "version": 1,
      "biosFiles": [
        { "id": "hod2bios", "filenames": ["hod2bios.zip", "hod2bios.7z"],
          "description": "HOTD2 BIOS", "md5": null, "size": null,
          "installSystem": "com.provenance.naomi" },
        { "id": "f355bios", "filenames": ["f355bios.zip", "f355bios.7z"],
          "description": "F355 BIOS", "md5": null, "size": null },
        { "id": "awbios", "filenames": ["awbios.zip", "awbios.7z"],
          "description": "Atomiswave BIOS", "md5": "ABC", "size": 2048,
          "installSystem": "com.provenance.atomiswave" }
      ],
      "groups": [
        {
          "id": "test-arcade",
          "description": "test",
          "systems": ["com.provenance.naomi", "com.provenance.naomi2"],
          "source": "fixture",
          "entries": [
            { "romSet": "hotd2", "title": "House of the Dead 2", "bios": ["hod2bios"] },
            { "romSet": "multi", "title": "Synthetic multi", "bios": ["hod2bios", "f355bios"] },
            { "romSet": "opt", "title": "Synthetic optional", "bios": ["f355bios"], "optional": true },
            { "md5": "DEADBEEF", "title": "Synthetic md5 match", "bios": ["hod2bios"] }
          ]
        },
        {
          "id": "test-aw",
          "systems": ["com.provenance.atomiswave"],
          "entries": [
            { "romSet": "demofist", "title": "Demolish Fist", "bios": ["awbios"] }
          ]
        }
      ]
    }
    """

    static func resolver() throws -> PerGameBIOSResolver {
        try PerGameBIOSResolver(data: Data(json.utf8))
    }
}

// MARK: - Parsing

@Suite("PerGameBIOS manifest parsing")
struct PerGameBIOSManifestParsingTests {

    @Test("Decodes the fixture manifest")
    func decodesFixture() throws {
        let resolver = try Fixture.resolver()
        #expect(resolver.manifest.version == PerGameBIOSManifest.supportedVersion)
        #expect(resolver.manifest.biosFiles.count == 3)
        #expect(resolver.manifest.groups.count == 2)
        #expect(resolver.coveredSystemIdentifiers.count == 3)
    }

    @Test("Optional MD5/size survive round-tripping as nil")
    func nullHashesStayNil() throws {
        let resolver = try Fixture.resolver()
        let hod2 = try #require(resolver.manifest.biosFiles.first { $0.id == "hod2bios" })
        #expect(hod2.md5 == nil)
        #expect(hod2.size == nil)
        let aw = try #require(resolver.manifest.biosFiles.first { $0.id == "awbios" })
        #expect(aw.md5 == "ABC")
        #expect(aw.size == 2048)
    }

    @Test("Rejects an unsupported schema version")
    func rejectsBadVersion() throws {
        let json = #"{ "version": 99, "biosFiles": [], "groups": [] }"#
        #expect(throws: PerGameBIOSManifestError.unsupportedVersion(found: 99, supported: 1)) {
            try PerGameBIOSResolver(data: Data(json.utf8))
        }
    }

    @Test("Rejects a rule referencing an unknown BIOS id")
    func rejectsUnknownBIOSID() throws {
        let json = """
        { "version": 1, "biosFiles": [],
          "groups": [ { "id": "g", "systems": ["com.provenance.naomi"],
                        "entries": [ { "romSet": "x", "bios": ["nope"] } ] } ] }
        """
        #expect(throws: PerGameBIOSManifestError.unknownBIOSID("nope", inGroup: "g")) {
            try PerGameBIOSResolver(data: Data(json.utf8))
        }
    }

    @Test("Rejects duplicate BIOS ids")
    func rejectsDuplicateBIOSID() throws {
        let json = """
        { "version": 1,
          "biosFiles": [ { "id": "a", "filenames": ["a.zip"], "description": "A", "md5": null, "size": null },
                         { "id": "a", "filenames": ["a.7z"], "description": "A", "md5": null, "size": null } ],
          "groups": [] }
        """
        #expect(throws: PerGameBIOSManifestError.duplicateBIOSID("a")) {
            try PerGameBIOSResolver(data: Data(json.utf8))
        }
    }

    @Test("Malformed JSON throws rather than crashing")
    func malformedJSONThrows() {
        #expect(throws: (any Error).self) {
            try PerGameBIOSResolver(data: Data("not json".utf8))
        }
    }
}

// MARK: - ROM-set naming

@Suite("PerGameBIOS ROM-set naming")
struct PerGameBIOSRomSetNameTests {

    @Test("Mirrors flycast get_file_basename", arguments: [
        ("hotd2.zip", "hotd2"),
        ("hotd2", "hotd2"),
        ("/roms/naomi/hotd2.zip", "hotd2"),
        ("f355.twin.chd", "f355.twin"),
        (".hidden", ".hidden")
    ])
    func basename(_ input: String, _ expected: String) {
        #expect(PerGameBIOSResolver.romSetName(fromFilename: input) == expected)
    }
}

// MARK: - Resolution

@Suite("PerGameBIOS resolution")
struct PerGameBIOSResolutionTests {

    @Test("Unknown game requires nothing")
    func unknownGame() throws {
        let resolver = try Fixture.resolver()
        #expect(resolver.requirements(systemIdentifier: Fixture.naomi, romFilename: "totallyunknown.zip").isEmpty)
    }

    @Test("Known-system game with no per-game rule requires nothing")
    func gameWithNoPerGameBIOS() throws {
        let resolver = try Fixture.resolver()
        // "gram2000" is a real NAOMI title with a NULL bios field upstream, so
        // it is deliberately absent from the manifest.
        #expect(resolver.requirements(systemIdentifier: Fixture.naomi, romFilename: "gram2000.zip").isEmpty)
    }

    @Test("Game with one required BIOS")
    func gameWithOneBIOS() throws {
        let resolver = try Fixture.resolver()
        let reqs = resolver.requirements(systemIdentifier: Fixture.naomi, romFilename: "hotd2.zip")
        #expect(reqs.count == 1)
        #expect(reqs[0].id == "hod2bios")
        #expect(reqs[0].canonicalFilename == "hod2bios.zip")
        #expect(reqs[0].acceptedFilenames == ["hod2bios.zip", "hod2bios.7z"])
        #expect(reqs[0].optional == false)
        #expect(reqs[0].gameTitle == "House of the Dead 2")
    }

    /// No real entry sourced from `naomi_roms.cpp` needs more than one BIOS —
    /// this uses the synthetic `multi` fixture to prove the schema and resolver
    /// handle it.
    @Test("Game with several required BIOS files")
    func gameWithSeveralBIOS() throws {
        let resolver = try Fixture.resolver()
        let reqs = resolver.requirements(systemIdentifier: Fixture.naomi, romFilename: "multi.zip")
        #expect(reqs.map(\.id) == ["hod2bios", "f355bios"])
    }

    @Test("Matching is case-insensitive and extension-agnostic")
    func caseAndExtensionInsensitive() throws {
        let resolver = try Fixture.resolver()
        #expect(resolver.requirements(systemIdentifier: Fixture.naomi, romFilename: "HOTD2.CHD").count == 1)
        #expect(resolver.requirements(systemIdentifier: Fixture.naomi.uppercased(), romFilename: "hotd2").count == 1)
    }

    @Test("A rule only applies to the systems its group lists")
    func systemScoping() throws {
        let resolver = try Fixture.resolver()
        #expect(resolver.requirements(systemIdentifier: Fixture.naomi2, romFilename: "hotd2.zip").count == 1)
        #expect(resolver.requirements(systemIdentifier: Fixture.atomiswave, romFilename: "hotd2.zip").isEmpty)
        #expect(resolver.requirements(systemIdentifier: Fixture.dreamcast, romFilename: "hotd2.zip").isEmpty)
    }

    @Test("MD5 is an alternative match key")
    func md5Matching() throws {
        let resolver = try Fixture.resolver()
        let reqs = resolver.requirements(systemIdentifier: Fixture.naomi, romFilename: "renamed.zip", md5: "deadbeef")
        #expect(reqs.map(\.id) == ["hod2bios"])
    }

    @Test("A pinned BIOS file is only offered to its install system")
    func installSystemScopesRegistration() throws {
        let resolver = try Fixture.resolver()
        let naomi = resolver.biosFiles(forSystemIdentifier: Fixture.naomi).map(\.id)
        let naomi2 = resolver.biosFiles(forSystemIdentifier: Fixture.naomi2).map(\.id)
        // hod2bios is pinned to NAOMI; f355bios is unpinned so both groups offer it.
        #expect(naomi.contains("hod2bios"))
        #expect(!naomi2.contains("hod2bios"))
        #expect(naomi.contains("f355bios"))
        #expect(naomi2.contains("f355bios"))
        #expect(resolver.biosFiles(forSystemIdentifier: Fixture.atomiswave).map(\.id) == ["awbios"])
    }

    @Test("Requirements carry the install system through")
    func requirementCarriesInstallSystem() throws {
        let resolver = try Fixture.resolver()
        let reqs = resolver.requirements(systemIdentifier: Fixture.naomi2, romFilename: "hotd2.zip")
        #expect(reqs.first?.installSystem == Fixture.naomi)
    }

    @Test("Typed SystemIdentifier overload matches the raw-string overload")
    func typedOverload() throws {
        let resolver = try Fixture.resolver()
        let typed = resolver.requirements(system: .NAOMI, romFilename: "hotd2.zip")
        let raw = resolver.requirements(systemIdentifier: Fixture.naomi, romFilename: "hotd2.zip")
        #expect(typed == raw)
    }
}

// MARK: - Missing files

@Suite("PerGameBIOS missing-file detection")
struct PerGameBIOSMissingTests {

    @Test("Missing file is reported")
    func missingFile() throws {
        let resolver = try Fixture.resolver()
        let missing = resolver.missingRequirements(systemIdentifier: Fixture.naomi,
                                                   romFilename: "hotd2.zip",
                                                   existingFilenames: ["naomi.zip"])
        #expect(missing.map(\.canonicalFilename) == ["hod2bios.zip"])
    }

    @Test("Present file satisfies the requirement")
    func presentFile() throws {
        let resolver = try Fixture.resolver()
        let missing = resolver.missingRequirements(systemIdentifier: Fixture.naomi,
                                                   romFilename: "hotd2.zip",
                                                   existingFilenames: ["hod2bios.zip"])
        #expect(missing.isEmpty)
    }

    @Test("Any accepted filename satisfies the requirement")
    func alternateExtensionSatisfies() throws {
        let resolver = try Fixture.resolver()
        let missing = resolver.missingRequirements(systemIdentifier: Fixture.naomi,
                                                   romFilename: "hotd2.zip",
                                                   existingFilenames: ["HOD2BIOS.7Z"])
        #expect(missing.isEmpty)
    }

    @Test("Only the absent file of a multi-BIOS set is reported")
    func partiallySatisfiedMultiSet() throws {
        let resolver = try Fixture.resolver()
        let missing = resolver.missingRequirements(systemIdentifier: Fixture.naomi,
                                                   romFilename: "multi.zip",
                                                   existingFilenames: ["hod2bios.zip"])
        #expect(missing.map(\.id) == ["f355bios"])
    }

    @Test("Optional requirements are still listed but flagged optional")
    func optionalFlagPreserved() throws {
        let resolver = try Fixture.resolver()
        let missing = resolver.missingRequirements(systemIdentifier: Fixture.naomi,
                                                   romFilename: "opt.zip",
                                                   existingFilenames: [])
        #expect(missing.count == 1)
        #expect(missing[0].optional == true)
    }

    @Test("Empty resolver never reports anything missing")
    func emptyResolver() {
        let missing = PerGameBIOSResolver.empty.missingRequirements(systemIdentifier: Fixture.naomi,
                                                                    romFilename: "hotd2.zip",
                                                                    existingFilenames: [])
        #expect(missing.isEmpty)
    }
}

// MARK: - Shipped manifest

@Suite("PerGameBIOS shipped manifest")
struct PerGameBIOSBundledManifestTests {

    @Test("The bundled manifest loads and validates")
    func bundledLoads() throws {
        let resolver = try PerGameBIOSResolver.loadBundled()
        #expect(resolver.manifest.version == PerGameBIOSManifest.supportedVersion)
        #expect(!resolver.manifest.groups.isEmpty)
    }

    @Test("Known flycast per-title BIOS sets resolve")
    func knownFlycastTitles() throws {
        let resolver = try PerGameBIOSResolver.loadBundled()
        let cases: [(String, String, String)] = [
            (Fixture.naomi, "hotd2.zip", "hod2bios.zip"),
            (Fixture.naomi, "f355.zip", "f355dlx.zip"),
            (Fixture.naomi, "f355twin.zip", "f355bios.zip"),
            (Fixture.naomi, "alpilot.zip", "airlbios.zip"),
            (Fixture.naomi2, "vf4tuned.zip", "naomi2.zip")
        ]
        for (system, rom, expected) in cases {
            let reqs = resolver.requirements(systemIdentifier: system, romFilename: rom)
            #expect(reqs.map(\.canonicalFilename) == [expected], "\(rom)")
        }
    }

    @Test("Every shipped requirement resolves to a declared BIOS file")
    func everyRuleResolves() throws {
        let resolver = try PerGameBIOSResolver.loadBundled()
        let declared = Set(resolver.manifest.biosFiles.map(\.id))
        for group in resolver.manifest.groups {
            for entry in group.entries {
                #expect(!entry.bios.isEmpty)
                for id in entry.bios {
                    #expect(declared.contains(id))
                }
            }
        }
    }

    @Test("No shipped BIOS file claims an unverified hash or size")
    func noFabricatedHashes() throws {
        let resolver = try PerGameBIOSResolver.loadBundled()
        for file in resolver.manifest.biosFiles {
            #expect(file.md5 == nil, "\(file.id) must not claim an unverified MD5")
            #expect(file.size == nil, "\(file.id) must not claim an unverified size")
            #expect(!file.filenames.isEmpty)
        }
    }

    @Test("Every shipped BIOS file pins a covered install system")
    func installSystemsArePinnedAndCovered() throws {
        let resolver = try PerGameBIOSResolver.loadBundled()
        let covered = Set(resolver.coveredSystemIdentifiers)
        for file in resolver.manifest.biosFiles {
            let installSystem = try #require(file.installSystem, "\(file.id) must pin an install system")
            #expect(covered.contains(installSystem))
            #expect(SystemIdentifier(rawValue: installSystem) != nil, "\(installSystem) is not a real system")
        }
    }

    @Test("Each shipped BIOS file is offered to exactly one system")
    func oneInstallSystemPerFile() throws {
        let resolver = try PerGameBIOSResolver.loadBundled()
        for file in resolver.manifest.biosFiles {
            let owners = resolver.coveredSystemIdentifiers.filter { system in
                resolver.biosFiles(forSystemIdentifier: system).contains { $0.id == file.id }
            }
            #expect(owners.count == 1, "\(file.id)")
            #expect(owners.first == file.installSystem, "\(file.id)")
        }
    }

    @Test("Games with no explicit upstream BIOS are absent from the manifest")
    func defaultBIOSGamesNotListed() throws {
        let resolver = try PerGameBIOSResolver.loadBundled()
        // gram2000 / mvsc2 have a NULL `bios` field in naomi_roms.cpp — they fall
        // back to flycast's default and are deliberately not transcribed.
        for rom in ["gram2000", "mvsc2", "mushike"] {
            #expect(resolver.requirements(systemIdentifier: Fixture.naomi, romFilename: rom).isEmpty, "\(rom)")
        }
    }
}
