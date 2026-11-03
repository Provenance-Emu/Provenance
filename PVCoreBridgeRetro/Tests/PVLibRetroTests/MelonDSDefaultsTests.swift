//
//  MelonDSDefaultsTests.swift
//  PVLibRetroTests
//
//  Both melonDS libretro cores ship, with different layout keys and value spellings.
//  The platform defaults must name only keys the loaded core reads, never a
//  `melondsds_*` key (neither core has one).
//

import Testing
@testable import PVCoreBridgeRetro

struct MelonDSDefaultsTests {
    private func defaults(_ id: String, tvOS: Bool) -> [String: String] {
        Dictionary(uniqueKeysWithValues: PVThinLibretroCore
            .melonDSDefaults(coreIdentifier: id, isTVOS: tvOS)
            .map { ($0.key, $0.value) })
    }

    @Test("Legacy melonDS keeps touch mode everywhere and side by side only on tvOS")
    func legacyMelonDS() {
        let id = "melonds.libretro.framework"
        #expect(defaults(id, tvOS: false) == ["melonds_touch_mode": "Touch"])
        #expect(defaults(id, tvOS: true) == [
            "melonds_touch_mode": "Touch",
            "melonds_screen_layout": "Left/Right"
        ])
    }

    @Test("melonDS DS sets its first layout slot with lowercase values, only on tvOS")
    func melonDSDS() {
        let id = "melondsds.libretro.framework"
        #expect(defaults(id, tvOS: false) == ["melonds_touch_mode": "Touch"])
        #expect(defaults(id, tvOS: true) == [
            "melonds_touch_mode": "Touch",
            "melonds_screen_layout1": "left-right"
        ])
    }

    @Test("No core is given a melondsds_ key, and other cores get nothing")
    func noBogusKeys() {
        for id in ["melonds.libretro.framework", "melondsds.libretro.framework"] {
            for tvOS in [false, true] {
                #expect(!defaults(id, tvOS: tvOS).keys.contains { $0.hasPrefix("melondsds_") })
            }
        }
        #expect(defaults("desmume.libretro.framework", tvOS: true).isEmpty)
        #expect(defaults("snes9x.libretro.framework", tvOS: true).isEmpty)
    }
}
