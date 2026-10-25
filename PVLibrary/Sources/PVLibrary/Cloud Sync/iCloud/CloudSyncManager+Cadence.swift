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
        // Also re-check held-back uploads: they may have been waiting for a charger or Wi-Fi.
        guard deferredAutomaticSync != nil || hasDeferredUploads else { return }
        deferredAutomaticSync?.cancel()
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
        // Any automatic sync that runs drains held-back uploads, so a pause that cancelled the
        // deferred sync can't strand them.
        let uploadsPending = hasDeferredUploads
        hasDeferredUploads = false
        Task { [weak self] in
            guard let self else { return }
            switch trigger {
            case .push, .scheduled:
                await self.fetchRemoteChangesOnly()
            case .foreground:
                await CloudKitSyncerStore.shared.refreshRomRemoteChanges()
                await self.checkForMissingROMFiles(force: false)
            }
            if uploadsPending {
                await self.flushDeferredUploads()
            }
        }
    }

    /// Uploads what imports held back. The initial syncer queues uploads without the per-upload
    /// checks in `uploadROM(for:)`, so apply them here: the sync gates (power, charging, network
    /// mode), and no metered path, where the cellular size cap can't be applied per file.
    /// When blocked, the uploads stay pending for the next sync or condition change.
    private func flushDeferredUploads() async {
        let allowed = await shouldAllowSync()
        guard allowed, !DeviceConditionsMonitor.shared.current.isExpensiveNetwork else {
            DLOG("[SYNC] Deferred uploads still held back (sync gates or metered network)")
            await MainActor.run { self.hasDeferredUploads = true }
            return
        }
        let uploaded = await CloudKitInitialSyncer.shared?.performInitialSync(forceSync: false) ?? 0
        DLOG("[SYNC] Uploaded \(uploaded) deferred records")
    }
}
