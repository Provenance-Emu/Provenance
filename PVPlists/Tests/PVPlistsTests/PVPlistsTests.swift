import Testing
@testable import PVPlists

@Test func testEmulatorCoreInfoPlist_To_CorePlistEntry() async throws {
    let lhs = EmulatorCoreInfoPlist(identifier: "a", principleClass: "b", supportedSystems: ["c", "d"], projectName: "e", projectURL: "f", projectVersion: "g")

    let rhs = CorePlistEntry.init(lhs)

    #expect(lhs.identifier == rhs.PVCoreIdentifier)
    #expect(lhs.principleClass == rhs.PVPrincipleClass)
    #expect(lhs.supportedSystems == rhs.PVSupportedSystems)
    #expect(lhs.projectName == rhs.PVProjectName)
    #expect(lhs.projectURL == rhs.PVProjectURL)
    #expect(lhs.projectVersion == rhs.PVProjectVersion)
    #expect(lhs.disabled == rhs.PVDisabled)
    #expect(lhs.contentless == rhs.PVContentless)
    #expect(lhs.appStoreDisabled == rhs.PVAppStoreDisabled)
    #expect(lhs.supportedCheatTypes == (rhs.PVSupportedCheatTypes ?? []))
//    #expect(lhs.subCores == rhs.PVCores)

    #expect(lhs == rhs)
}

@Test func testCorePlistEntry_To_EmulatorCoreInfoPlist() async throws {
    let lhs = CorePlistEntry(PVCoreIdentifier: "a", PVPrincipleClass: "b", PVSupportedSystems: ["c", "d"], PVProjectName: "e", PVProjectURL: "f", PVProjectVersion: "g", PVDisabled: true, PVAppStoreDisabled: false, PVCores: nil)

    let rhs = EmulatorCoreInfoPlist(lhs)

    #expect(rhs.identifier == lhs.PVCoreIdentifier)
    #expect(rhs.principleClass == lhs.PVPrincipleClass)
    #expect(rhs.supportedSystems == lhs.PVSupportedSystems)
    #expect(rhs.projectName == lhs.PVProjectName)
    #expect(rhs.projectURL == lhs.PVProjectURL)
    #expect(rhs.projectVersion == lhs.PVProjectVersion)
    #expect(rhs.disabled == lhs.PVDisabled)
    #expect(rhs.contentless == lhs.PVContentless)
    #expect(rhs.appStoreDisabled == lhs.PVAppStoreDisabled)
    #expect(rhs.supportedCheatTypes == (lhs.PVSupportedCheatTypes ?? []))

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
    // When PVSupportedCheatTypes is present, it should be parsed correctly
    let cheatTypes = ["Game Genie", "Pro Action Replay", "Game Shark"]
    let dict: [String: Any] = [
        "PVCoreIdentifier": "com.provenance.test",
        "PVPrincipleClass": "TestCore",
        "PVSupportedSystems": ["com.provenance.nes"],
        "PVProjectName": "Test Core",
        "PVProjectURL": "https://example.com",
        "PVProjectVersion": "1.0",
        "PVSupportedCheatTypes": cheatTypes
    ]
    let plist = try #require(EmulatorCoreInfoPlist(fromInfoDictionary: dict))
    #expect(plist.supportedCheatTypes == cheatTypes)
}

@Test func testCorePlistEntry_CheatTypes_RoundTrip() {
    // Create a plist with cheat types and verify round-trip conversion preserves them
    let cheatTypes = ["Code Breaker", "Game Genie", "Raw Code"]
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
    #expect(entry.PVSupportedCheatTypes == cheatTypes)

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
