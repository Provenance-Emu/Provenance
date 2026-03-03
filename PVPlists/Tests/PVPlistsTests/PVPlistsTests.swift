import Testing
@testable import PVPlists
import PVPrimitives

@Test func testEmulatorCoreInfoPlist_To_CorePlistEntry() async throws {
    let lhs = EmulatorCoreInfoPlist(identifier: "a", principleClass: "b", supportedSystems: ["c", "d"], projectName: "e", projectURL: "f", projectVersion: "g")

    let rhs = CorePlistEntry.init(lhs)

    #expect(lhs.identifier == rhs.PVCoreIdentifier)
    #expect(lhs.principleClass == rhs.PVPrincipleClass)
    #expect(lhs.supportedSystems == rhs.PVSupportedSystems)
    #expect(lhs.projectName == rhs.PVProjectName)
    #expect(lhs.projectURL == rhs.PVProjectURL)
    #expect(lhs.projectVersion == rhs.PVProjectVersion)
    #expect(lhs.disabled == (rhs.PVDisabled ?? false))
    #expect(lhs.contentless == (rhs.PVContentless ?? false))
    #expect(lhs.appStoreDisabled == (rhs.PVAppStoreDisabled ?? false))
    // supportedCheatTypes round-trips through string representation
    let rhsCheatTypes = (rhs.PVSupportedCheatTypes ?? []).compactMap { CheatCodeTypes(string: $0) }
    #expect(lhs.supportedCheatTypes == rhsCheatTypes)
//    #expect(lhs.subCores == rhs.PVCores)

    #expect(lhs == rhs)
}

@Test func testCorePlistEntry_To_EmulatorCoreInfoPlist() async throws {
    let lhs = CorePlistEntry(PVCoreIdentifier: "a", PVPrincipleClass: "b", PVSupportedSystems: ["c", "d"], PVProjectName: "e", PVProjectURL: "f", PVProjectVersion: "g", PVDisabled: true, PVContentless: nil, PVAppStoreDisabled: false, PVSupportedCheatTypes: nil, PVCores: nil)

    let rhs = EmulatorCoreInfoPlist(lhs)

    #expect(rhs.identifier == lhs.PVCoreIdentifier)
    #expect(rhs.principleClass == lhs.PVPrincipleClass)
    #expect(rhs.supportedSystems == lhs.PVSupportedSystems)
    #expect(rhs.projectName == lhs.PVProjectName)
    #expect(rhs.projectURL == lhs.PVProjectURL)
    #expect(rhs.projectVersion == lhs.PVProjectVersion)
    #expect(rhs.disabled == (lhs.PVDisabled ?? false))
    #expect(rhs.contentless == (lhs.PVContentless ?? false))
    #expect(rhs.appStoreDisabled == (lhs.PVAppStoreDisabled ?? false))
    let lhsCheatTypes = (lhs.PVSupportedCheatTypes ?? []).compactMap { CheatCodeTypes(string: $0) }
    #expect(rhs.supportedCheatTypes == lhsCheatTypes)

    #expect(rhs == lhs)
}

@Test func testEmulatorCoreInfoPlist_CheatTypes_DefaultsToEmpty() throws {
    // When PVSupportedCheatTypes is absent from the dict, it should default to []
    let dict: [String: Any] = [
        "PVCoreIdentifier": "com.provenance.test",
        "PVPrincipleClass": "TestCore",
        "PVSupportedSystems": ["com.provenance.nes"],
        "PVProjectName": "Test Core",
        "PVProjectURL": "https://example.com",
        "PVProjectVersion": "1.0"
    ]
    let plist = try #require(EmulatorCoreInfoPlist(fromInfoDictionary: dict))
    #expect(plist.supportedCheatTypes == [])
}

@Test func testEmulatorCoreInfoPlist_CheatTypes_ParsedFromDict() throws {
    // When PVSupportedCheatTypes is present, it should be parsed correctly into typed values
    let dict: [String: Any] = [
        "PVCoreIdentifier": "com.provenance.test",
        "PVPrincipleClass": "TestCore",
        "PVSupportedSystems": ["com.provenance.nes"],
        "PVProjectName": "Test Core",
        "PVProjectURL": "https://example.com",
        "PVProjectVersion": "1.0",
        "PVSupportedCheatTypes": ["Game Genie", "Pro Action Replay", "Game Shark"]
    ]
    let plist = try #require(EmulatorCoreInfoPlist(fromInfoDictionary: dict))
    #expect(plist.supportedCheatTypes == [.gameGenie, .proActionReplay, .gameShark])
}

@Test func testCorePlistEntry_CheatTypes_RoundTrip() {
    // Create a plist with cheat types and verify round-trip conversion preserves them
    let cheatTypes: [CheatCodeTypes] = [.codeBreaker, .gameGenie, .rawCode]
    let plist = EmulatorCoreInfoPlist(
        identifier: "com.provenance.test",
        principleClass: "TestCore",
        supportedSystems: ["com.provenance.gbc"],
        projectName: "Test",
        projectURL: "https://example.com",
        projectVersion: "1.0",
        supportedCheatTypes: cheatTypes
    )

    let entry = CorePlistEntry(plist)
    // CorePlistEntry stores display-name strings
    #expect(entry.PVSupportedCheatTypes == cheatTypes.map { $0.stringValue })

    // Round-trip back to typed values
    let backToPlist = EmulatorCoreInfoPlist(entry)
    #expect(backToPlist.supportedCheatTypes == cheatTypes)
}

@Test func testCorePlistEntry_NoCheatTypes_RoundTrip() {
    // When no cheat types, PVSupportedCheatTypes should be nil in CorePlistEntry
    // and [] in EmulatorCoreInfoPlist
    let plist = EmulatorCoreInfoPlist(
        identifier: "com.provenance.test",
        principleClass: "TestCore",
        supportedSystems: ["com.provenance.gbc"],
        projectName: "Test",
        projectURL: "https://example.com",
        projectVersion: "1.0"
    )

    #expect(plist.supportedCheatTypes == [])

    let entry = CorePlistEntry(plist)
    #expect(entry.PVSupportedCheatTypes == nil)

    let backToPlist = EmulatorCoreInfoPlist(entry)
    #expect(backToPlist.supportedCheatTypes == [])
}

@Test func testCheatCodeTypes_StringRoundTrip() {
    // Every known case should survive a string round-trip
    for cheatType in CheatCodeTypes.allCases {
        let string = cheatType.stringValue
        let parsed = CheatCodeTypes(string: string)
        #expect(parsed != nil, "Failed to parse '\(string)'")
        #expect(parsed == cheatType, "Round-trip mismatch for \(cheatType): got \(String(describing: parsed))")
    }
}

@Test func testCheatCodeTypes_UnknownStringReturnsNil() {
    #expect(CheatCodeTypes(string: "Unknown Format XYZ") == nil)
    #expect(CheatCodeTypes(string: "") == nil)
}

@Test func testCheatCodeTypes_CoreAliases() {
    // "Gateway" is emitted by 3DS cores (Azahar, emuThree)
    #expect(CheatCodeTypes(string: "Gateway") == .gateway,
            "Gateway alias should parse to .gateway")

    // "Raw Address Value Pairs (PPSSPP CwCheat)" is emitted by the PPSSPP core
    #expect(CheatCodeTypes(string: "Raw Address Value Pairs (PPSSPP CwCheat)") == .rawMemAddress,
            "PPSSPP CwCheat alias should parse to .rawMemAddress")

    // "GameShark" (no space) is a common alias across multiple cores
    #expect(CheatCodeTypes(string: "GameShark") == .gameShark,
            "GameShark (no space) should parse to .gameShark")

    // "Action Replay" variants emitted by Mednafen and other cores
    #expect(CheatCodeTypes(string: "Action Replay") == .proActionReplay,
            "Action Replay should parse to .proActionReplay")
    #expect(CheatCodeTypes(string: "Action Replay v1") == .proActionReplayV1,
            "Action Replay v1 should parse to .proActionReplayV1")
    #expect(CheatCodeTypes(string: "Action Replay v2") == .proActionReplayV2,
            "Action Replay v2 should parse to .proActionReplayV2")
    #expect(CheatCodeTypes(string: "Action Replay v1/v2") == .proActionReplayV2,
            "Action Replay v1/v2 (slash variant used by VisualBoyAdvance) should parse to .proActionReplayV2")
    #expect(CheatCodeTypes(string: "Action Replay v3") == .proActionReplayV2,
            "Action Replay v3 should map to .proActionReplayV2 (closest available)")
}
