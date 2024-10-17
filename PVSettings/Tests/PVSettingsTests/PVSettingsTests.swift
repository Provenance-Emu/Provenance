//
//  Test.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 8/6/24.
//

import Testing
@testable import PVSettings
import Foundation

struct Test {

    @Test func testSettings() async throws {
        #expect(Defaults[.askToAutoLoad])
        #expect(Defaults[.buttonTints])
        #expect(Defaults[.timedAutoSaveInterval] == minutes(10))
        
        Defaults[.askToAutoLoad] = false

        #expect(!Defaults[.askToAutoLoad])

        Defaults[.askToAutoLoad].toggle()
        #expect(Defaults[.askToAutoLoad])
        let icValue = UserDefaults.standard.bool(forKey: "askToAutoLoad")
        #expect(icValue)

        #expect(!Defaults[.iCloudSync])
        Defaults[.iCloudSync] = true
        #expect(Defaults[.iCloudSync])
        let icValue2 = UserDefaults.standard.bool(forKey: "iCloudSync")
        #expect(icValue2)

        Defaults[.iCloudSync].toggle()
        #expect(!Defaults[.iCloudSync])
    }
}
