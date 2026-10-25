//
//  DeviceConditionsTests.swift
//  PVSettings
//

import Foundation
import Testing
import Defaults
@testable import PVSettings

@Suite("CloudKitSyncFrequency cadence")
struct CloudSyncCadenceTests {

    private let charging = DeviceConditions(isOnExternalPower: true)
    private let onBattery = DeviceConditions(isOnExternalPower: false)

    @Test("Automatic is immediate on external power with a free network")
    func automaticCharging() {
        #expect(CloudKitSyncFrequency.automatic.cadence(in: charging) == .immediate)
    }

    @Test("Automatic waits 15 minutes on battery")
    func automaticBattery() {
        #expect(CloudKitSyncFrequency.automatic.cadence(in: onBattery) == .interval(15 * 60))
    }

    @Test("Automatic falls back to hourly in Low Power Mode, even while charging")
    func automaticLowPower() {
        var conditions = charging
        conditions.isLowPowerMode = true
        #expect(CloudKitSyncFrequency.automatic.cadence(in: conditions) == .interval(60 * 60))
    }

    @Test("Automatic falls back to hourly on cellular, hotspot or Low Data Mode",
          arguments: [
            DeviceConditions(isOnExternalPower: true, isExpensiveNetwork: true, isCellular: true),
            DeviceConditions(isOnExternalPower: true, isExpensiveNetwork: true),
            DeviceConditions(isOnExternalPower: true, isConstrainedNetwork: true)
          ])
    func automaticMeteredNetwork(conditions: DeviceConditions) {
        #expect(CloudKitSyncFrequency.automatic.cadence(in: conditions) == .interval(60 * 60))
    }

    @Test("Fixed frequencies ignore conditions")
    func fixedFrequencies() {
        let saving = DeviceConditions(isLowPowerMode: true, isExpensiveNetwork: true)
        for conditions in [charging, onBattery, saving] {
            #expect(CloudKitSyncFrequency.immediate.cadence(in: conditions) == .immediate)
            #expect(CloudKitSyncFrequency.fiveMinutes.cadence(in: conditions) == .interval(5 * 60))
            #expect(CloudKitSyncFrequency.fifteenMinutes.cadence(in: conditions) == .interval(15 * 60))
            #expect(CloudKitSyncFrequency.hourly.cadence(in: conditions) == .interval(60 * 60))
            #expect(CloudKitSyncFrequency.manual.cadence(in: conditions) == .manual)
        }
    }

    @Test("Only immediate uploads local changes as they happen")
    func uploadsImmediately() {
        #expect(CloudSyncCadence.immediate.uploadsImmediately)
        #expect(!CloudSyncCadence.interval(60).uploadsImmediately)
        #expect(!CloudSyncCadence.manual.uploadsImmediately)
    }

    @Test("Default frequency is Automatic on iOS and Immediate on tvOS")
    func platformDefault() {
        #if os(tvOS)
        #expect(Defaults.Keys.cloudKitSyncFrequency.defaultValue == .immediate)
        #else
        #expect(Defaults.Keys.cloudKitSyncFrequency.defaultValue == .automatic)
        #endif
    }
}

@Suite("CloudSyncCadence timing")
struct CloudSyncTimingTests {

    private let now = Date(timeIntervalSinceReferenceDate: 1_000_000)

    @Test("Immediate always runs now")
    func immediate() {
        #expect(CloudSyncCadence.immediate.timing(lastRun: now, now: now) == .now)
    }

    @Test("Manual never runs on its own")
    func manual() {
        #expect(CloudSyncCadence.manual.timing(lastRun: .distantPast, now: now) == .skip)
    }

    @Test("An interval runs now once it has elapsed")
    func intervalElapsed() {
        let cadence = CloudSyncCadence.interval(900)
        #expect(cadence.timing(lastRun: .distantPast, now: now) == .now)
        #expect(cadence.timing(lastRun: now.addingTimeInterval(-900), now: now) == .now)
    }

    @Test("An interval waits until it has elapsed")
    func intervalPending() {
        let lastRun = now.addingTimeInterval(-300)
        #expect(CloudSyncCadence.interval(900).timing(lastRun: lastRun, now: now) == .at(lastRun.addingTimeInterval(900)))
    }
}

@Suite("BackgroundWorkPolicy")
struct BackgroundWorkPolicyTests {

    @Test("Free network on battery allows all work")
    func unrestricted() {
        for work in BackgroundWork.allCases {
            #expect(BackgroundWorkPolicy.deferral(for: work, in: DeviceConditions()) == nil)
        }
    }

    @Test("Low Power Mode defers all work, even on external power")
    func lowPowerMode() {
        let conditions = DeviceConditions(isLowPowerMode: true, isOnExternalPower: true)
        for work in BackgroundWork.allCases {
            #expect(BackgroundWorkPolicy.deferral(for: work, in: conditions) == .lowPowerMode)
        }
    }

    @Test("Bulk network work waits for a free network")
    func bulkNetwork() {
        #expect(BackgroundWorkPolicy.deferral(for: .bulkNetwork, in: DeviceConditions(isNetworkAvailable: false)) == .noNetwork)
        #expect(BackgroundWorkPolicy.deferral(for: .bulkNetwork, in: DeviceConditions(isExpensiveNetwork: true)) == .meteredNetwork)
        #expect(BackgroundWorkPolicy.deferral(for: .bulkNetwork, in: DeviceConditions(isConstrainedNetwork: true)) == .meteredNetwork)
    }

    @Test("Bulk local work ignores the network")
    func bulkLocal() {
        let conditions = DeviceConditions(isNetworkAvailable: false, isExpensiveNetwork: true, isConstrainedNetwork: true)
        #expect(BackgroundWorkPolicy.deferral(for: .bulkLocal, in: conditions) == nil)
    }
}
