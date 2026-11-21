//
//  CloudSyncSettingsRegistrationTests.swift
//  PVSettingsTests
//

import Foundation
import Testing
@testable import PVSettings

@Suite("CloudSyncSettingsRegistration")
struct CloudSyncSettingsRegistrationTests {
    @Test @MainActor func registersADefaultForEverySyncSetting() {
        CloudSyncSettingsRegistration.registerDefaults()
        let registered = UserDefaults.standard.volatileDomain(forName: UserDefaults.registrationDomain)
        for name in CloudSyncSettingsRegistration.keyNames {
            #expect(registered[name] != nil, "no default registered for \(name)")
        }
    }

    /// The setting whose first read, from a sync task, was in the watchdog report.
    @Test func coversTheSyncContentSetting() {
        #expect(CloudSyncSettingsRegistration.keyNames.contains("cloudKitSyncContentType"))
    }

    @Test func listsEachSettingOnce() {
        let names = CloudSyncSettingsRegistration.keyNames
        #expect(Set(names).count == names.count)
    }
}
