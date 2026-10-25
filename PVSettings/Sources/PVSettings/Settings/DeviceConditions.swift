//
//  DeviceConditions.swift
//  PVSettings
//
//  Power and network state, and the pure rules that decide how heavy background work
//  (CloudKit sync, artwork backfill, audits) behaves under it. The live values come from
//  `DeviceConditionsMonitor`; everything here is a plain function of a snapshot so it can be tested.
//

import Foundation

/// A snapshot of the power and network state that background work cares about.
public struct DeviceConditions: Sendable, Equatable {
    /// iOS Low Power Mode.
    public var isLowPowerMode: Bool
    /// Charging, full on the charger, or a device without a battery (Apple TV).
    public var isOnExternalPower: Bool
    /// The network path is satisfied.
    public var isNetworkAvailable: Bool
    /// Cellular or a personal hotspot (`NWPath.isExpensive`).
    public var isExpensiveNetwork: Bool
    /// Low Data Mode (`NWPath.isConstrained`).
    public var isConstrainedNetwork: Bool
    /// The path goes over cellular.
    public var isCellular: Bool

    public init(isLowPowerMode: Bool = false,
                isOnExternalPower: Bool = false,
                isNetworkAvailable: Bool = true,
                isExpensiveNetwork: Bool = false,
                isConstrainedNetwork: Bool = false,
                isCellular: Bool = false) {
        self.isLowPowerMode = isLowPowerMode
        self.isOnExternalPower = isOnExternalPower
        self.isNetworkAvailable = isNetworkAvailable
        self.isExpensiveNetwork = isExpensiveNetwork
        self.isConstrainedNetwork = isConstrainedNetwork
        self.isCellular = isCellular
    }

    /// Cellular, hotspot or Low Data Mode: data the user may pay for or has asked us to save.
    public var isMeteredNetwork: Bool { isExpensiveNetwork || isConstrainedNetwork }
}

// MARK: - Sync cadence

/// How often CloudKit sync runs on its own, resolved from `CloudKitSyncFrequency`.
public enum CloudSyncCadence: Sendable, Equatable {
    /// Push notifications and local changes sync as they happen.
    case immediate
    /// Remote fetches and deferred uploads run at most once per interval.
    case interval(TimeInterval)
    /// Only at launch and when the user taps Sync.
    case manual
}

/// When a requested remote fetch should run.
public enum SyncTiming: Sendable, Equatable {
    case now
    /// Wait until this date, then run once for every request made until then.
    case at(Date)
    /// Don't run on its own.
    case skip
}

public extension CloudKitSyncFrequency {
    /// `.automatic` on mains power with a free network.
    static let automaticExternalPowerCadence: CloudSyncCadence = .immediate
    /// `.automatic` on battery with a free network: the previous default frequency.
    static let automaticBatteryCadence: CloudSyncCadence = .interval(fifteenMinutesInterval)
    /// `.automatic` in Low Power Mode or on cellular, a hotspot or Low Data Mode.
    static let automaticPowerSavingCadence: CloudSyncCadence = .interval(hourlyInterval)

    /// The cadence this frequency means under `conditions`.
    func cadence(in conditions: DeviceConditions) -> CloudSyncCadence {
        switch self {
        case .automatic:
            if conditions.isLowPowerMode || conditions.isMeteredNetwork {
                return Self.automaticPowerSavingCadence
            }
            return conditions.isOnExternalPower ? Self.automaticExternalPowerCadence : Self.automaticBatteryCadence
        case .immediate:
            return .immediate
        case .fiveMinutes, .fifteenMinutes, .hourly:
            return .interval(timeInterval ?? 0)
        case .manual:
            return .manual
        }
    }
}

public extension CloudSyncCadence {
    /// Whether local changes (e.g. a newly imported ROM) upload as soon as they happen,
    /// rather than waiting for the next scheduled sync.
    var uploadsImmediately: Bool { self == .immediate }

    /// When an automatic sync requested at `now` should run, given the last one ran at `lastRun`.
    func timing(lastRun: Date, now: Date) -> SyncTiming {
        switch self {
        case .immediate:
            return .now
        case .manual:
            return .skip
        case .interval(let interval):
            let due = lastRun.addingTimeInterval(interval)
            return due <= now ? .now : .at(due)
        }
    }
}

// MARK: - Background work

/// Heavy work that runs without the user asking for it.
public enum BackgroundWork: Sendable, CaseIterable {
    /// Many network requests or downloads: artwork backfill, CloudKit audits, metadata fan-out.
    case bulkNetwork
    /// CPU and disk heavy local work: whole-library scans and re-hashing.
    case bulkLocal
}

/// Why background work was put off.
public enum BackgroundWorkDeferral: String, Sendable, Equatable {
    case lowPowerMode
    case noNetwork
    case meteredNetwork
}

/// Shared rule for automatic heavy work. Work the user asked for (a tapped download, an
/// import, the BIOS for the game being launched) should not consult it.
public enum BackgroundWorkPolicy {
    /// `nil` when `work` may run now, otherwise why it should wait.
    public static func deferral(for work: BackgroundWork, in conditions: DeviceConditions) -> BackgroundWorkDeferral? {
        if conditions.isLowPowerMode {
            return .lowPowerMode
        }
        switch work {
        case .bulkNetwork:
            if !conditions.isNetworkAvailable { return .noNetwork }
            if conditions.isMeteredNetwork { return .meteredNetwork }
            return nil
        case .bulkLocal:
            return nil
        }
    }
}
