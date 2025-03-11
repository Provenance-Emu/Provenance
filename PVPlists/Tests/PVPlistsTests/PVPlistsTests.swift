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

    #expect(rhs == lhs)
}
