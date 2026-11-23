//
//  ThinKeyboardSupportTests.swift
//  PVLibRetroTests
//
//  Which machines take a keyboard, and which put the on-screen one up at launch.
//

import Testing
import PVSystems
@testable import PVCoreBridgeRetro

struct ThinKeyboardSupportTests {

    @Test(arguments: [SystemIdentifier.DOS, .AtariST, .AppleII, .C64, .Macintosh, .MSX, .MSX2, .PC98, .ZXSpectrum])
    func homeComputersShowTheKeyboardAtLaunch(system: SystemIdentifier) {
        let support = PVThinLibretroCore.keyboardSupport(system: system, coreIdentifier: nil)
        #expect(support.supported)
        #expect(support.shownAtLaunch)
    }

    /// A console that only offers a keyboard keeps it out of the way until asked for.
    @Test func consolesWithAKeyboardDoNotShowIt() {
        let support = PVThinLibretroCore.keyboardSupport(system: .PSX, coreIdentifier: nil)
        #expect(support.supported)
        #expect(!support.shownAtLaunch)
    }

    @Test func systemsWithoutAKeyboardHaveNone() {
        let support = PVThinLibretroCore.keyboardSupport(system: .NES, coreIdentifier: nil)
        #expect(!support.supported)
        #expect(!support.shownAtLaunch)
    }

    /// The Amiga runs under the generic RetroArch system, so it is known by its core.
    @Test func amigaIsKnownByItsCore() {
        let support = PVThinLibretroCore.keyboardSupport(system: .RetroArch, coreIdentifier: "com.provenance.core.puae2021")
        #expect(support.supported)
        #expect(support.shownAtLaunch)
    }
}
