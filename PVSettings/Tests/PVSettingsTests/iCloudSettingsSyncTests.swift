//
//  iCloudSettingsSyncTests.swift
//  PVSettings
//

import Testing
@testable import PVSettings

/// The KVS-synced sync settings must survive an upgrade from 3.3.x: a device that already has its
/// own value keeps it, and launching one device must not push its value onto every other device.
@Suite("iCloud settings sync startup")
struct iCloudSettingsSyncStartupTests {
    @Test("Upgrade: a value already on this device wins over iCloud")
    func localValueWins() {
        #expect(iCloudSettingsSync.startupAction(hasLocalValue: true, hasRemoteValue: true) == .keepLocal)
    }

    @Test("Reinstall or new device: restore the value from iCloud")
    func restoreWhenLocalMissing() {
        #expect(iCloudSettingsSync.startupAction(hasLocalValue: false, hasRemoteValue: true) == .adoptRemote)
    }

    @Test("First device to sync: seed iCloud with this device's value")
    func seedWhenRemoteMissing() {
        #expect(iCloudSettingsSync.startupAction(hasLocalValue: true, hasRemoteValue: false) == .seedRemote)
    }

    @Test("Nothing chosen anywhere: leave both alone")
    func nothingToDo() {
        #expect(iCloudSettingsSync.startupAction(hasLocalValue: false, hasRemoteValue: false) == .none)
    }
}
