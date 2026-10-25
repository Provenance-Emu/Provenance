//
//  CloudSyncManager+Cadence.swift
//  PVLibrary
//
//  Applies the Sync Frequency setting. Immediate keeps sync event-driven (pushes, foreground,
//  local changes). An interval runs automatic syncs at most once per interval and folds requests
//  made in between into one deferred sync. Manual leaves sync to launch and the Sync button.
//  `.automatic` picks one of these from power and network conditions (`CloudKitSyncFrequency.cadence(in:)`).
//

import Combine
import Defaults
import Foundation
import PVLogging
import PVSettings

extension CloudSyncManager {

    /// What asked for an automatic sync.
    enum AutomaticSyncTrigger: String {
        /// A CloudKit database push.
        case push
        /// The app came back to the foreground.
        case foreground
        /// A deferred sync came due: fetch remote changes and upload what was held back.
        case scheduled
    }

    /// How long cadence inputs (setting, power, network) must settle before rescheduling.
    private static let cadenceChangeDebounce: DispatchQueue.SchedulerTimeType.Stride = .seconds(2)

    /// The cadence for the current setting and device conditions.
    var currentSyncCadence: CloudSyncCadence {
        Defaults[.cloudKitSyncFrequency].cadence(in: DeviceConditionsMonitor.shared.current)
    }

    /// Runs an automatic sync now, later, or not at all, depending on the cadence.
    @MainActor
    func requestAutomaticSync(_ trigger: AutomaticSyncTrigger) {
        // Paused (emulation, background) is handled downstream, as before: fetches skip or queue.
        guard Defaults[.iCloudSync] else { return }

        switch currentSyncCadence.timing(lastRun: lastAutomaticSync, now: Date()) {
        case .now:
            lastAutomaticSync = Date()
            runAutomaticSync(trigger)
        case .at(let due):
            scheduleDeferredSync(at: due)
        case .skip:
            DLOG("[SYNC] Manual sync frequency: ignoring \(trigger.rawValue) trigger")
        }
    }

    /// Holds a local change for the next scheduled sync instead of uploading it now.
    @MainActor
    func deferUpload() {
        hasDeferredUploads = true
        requestAutomaticSync(.scheduled)
    }

    /// Reschedules when the setting or device conditions change, so a sync waiting on a long
    /// interval runs as soon as the device is plugged in (or the user picks Immediate).
    @MainActor
    func observeCadenceChanges() {
        let frequency = Defaults.publisher(.cloudKitSyncFrequency).map { _ in () }
        let conditions = DeviceConditionsMonitor.shared.publisher.map { _ in () }
        frequency.merge(with: conditions)
            .debounce(for: Self.cadenceChangeDebounce, scheduler: DispatchQueue.main)
            .sink { [weak self] in
                MainActor.assumeIsolated { self?.cadenceDidChange() }
            }
            .store(in: &cadenceCancellables)
    }

    @MainActor
    private func cadenceDidChange() {
        guard let pending = deferredAutomaticSync else { return }
        pending.cancel()
        deferredAutomaticSync = nil
        requestAutomaticSync(.scheduled)
    }

    @MainActor
    private func scheduleDeferredSync(at due: Date) {
        guard deferredAutomaticSync == nil else { return }
        let delay = max(0, due.timeIntervalSinceNow)
        DLOG("[SYNC] Next automatic sync in \(Int(delay))s")
        deferredAutomaticSync = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            self.deferredAutomaticSync = nil
            // Re-evaluate: the cadence may have changed while waiting.
            self.requestAutomaticSync(.scheduled)
        }
    }

    @MainActor
    private func runAutomaticSync(_ trigger: AutomaticSyncTrigger) {
        let uploadsPending = trigger == .scheduled && hasDeferredUploads
        if uploadsPending {
            hasDeferredUploads = false
        }
        Task { [weak self] in
            guard let self else { return }
            switch trigger {
            case .push:
                await self.fetchRemoteChangesOnly()
            case .foreground:
                await CloudKitSyncerStore.shared.refreshRomRemoteChanges()
                await self.checkForMissingROMFiles(force: false)
            case .scheduled:
                await self.fetchRemoteChangesOnly()
                if uploadsPending {
                    let uploaded = await CloudKitInitialSyncer.shared?.performInitialSync(forceSync: false) ?? 0
                    DLOG("[SYNC] Scheduled sync uploaded \(uploaded) deferred records")
                }
            }
        }
    }
}
