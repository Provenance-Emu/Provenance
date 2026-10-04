//
//  PVCoreHasCoreClassTests.swift
//  PVLibraryTests
//
//  RetroArch-list cores run on the thin wrapper, which loads them from the app
//  bundle; they are available only when their libretro dylib ships.
//

import XCTest
@testable import PVRealm

final class PVCoreHasCoreClassTests: XCTestCase {

    private func core(identifier: String, principleClass: String) -> PVCore {
        let core = PVCore()
        core.identifier = identifier
        core.principleClass = principleClass
        return core
    }

    func testLibretroCoreWithoutBundledDylibIsUnavailable() {
        // The test runner bundles no libretro cores, like a Lite build.
        let snes9x = core(identifier: "snes9x.libretro.framework", principleClass: "PVRetroArch.PVRetroArchCoreCore")
        XCTAssertFalse(snes9x.hasCoreClass)
    }

    func testRetiredThickLauncherIsUnavailable() {
        let launcher = core(identifier: "com.provenance.core.retroarch", principleClass: "PVRetroArch.PVRetroArchCoreCore")
        XCTAssertFalse(launcher.hasCoreClass)
    }

    func testOnlyLibretroFrameworkIdentifiersCountAsBundled() {
        XCTAssertFalse(PVCore.isBundledLibretroCore("com.provenance.core.retroarch"))
        XCTAssertFalse(PVCore.isBundledLibretroCore("snes9x.libretro.framework"))
    }
}
