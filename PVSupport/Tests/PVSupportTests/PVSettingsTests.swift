//
//  Test.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 8/6/24.
//

import Testing
@testable import PVLibrary

struct Test {
    var settings: PVSettingsModel = PVSettingsModel()

    @Test func testSettings() async throws {
        #expect(settings.askToAutoLoad)
        #expect(settings.buttonTints)
        #expect(settings.timedAutoSaveInterval == minutes(10))
        
        settings.askToAutoLoad = false

        #expect(!settings.askToAutoLoad)

        settings.toggle(\PVSettingsModel.askToAutoLoad)
        #expect(settings.askToAutoLoad)
        let icValue = UserDefaults.standard.bool(forKey: "askToAutoLoad")
        #expect(icValue)

        #expect(!settings.debugOptions.iCloudSync)
        settings.debugOptions.iCloudSync = true
        #expect(settings.debugOptions.iCloudSync)
        let icValue2 = UserDefaults.standard.bool(forKey: "debugOptions.iCloudSync")
        #expect(icValue2)

        settings.toggle(\PVSettingsModel.debugOptions.iCloudSync)
        #expect(!settings.debugOptions.iCloudSync)
    }

}
