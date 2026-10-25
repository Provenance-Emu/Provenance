//
//  DeviceConditionsMonitor.swift
//  PVSettings
//
//  Keeps a live `DeviceConditions` from NWPathMonitor, Low Power Mode changes and,
//  on iOS, battery state. The rules that use it live in `DeviceConditions.swift`.
//

#if canImport(Network) && canImport(Combine)
import Combine
import Foundation
import Network
#if os(iOS)
import UIKit
#endif

/// Live power and network conditions. Starts observing when `shared` is first used.
public final class DeviceConditionsMonitor: @unchecked Sendable {
    public static let shared = DeviceConditionsMonitor()

    private let lock = NSLock()
    private var state: DeviceConditions
    private let subject: CurrentValueSubject<DeviceConditions, Never>
    private let pathMonitor = NWPathMonitor()
    private var observers: [NSObjectProtocol] = []

    /// Devices with no battery are always on external power.
    private static let hasNoBattery: Bool = {
        #if os(tvOS) || os(macOS)
        return true
        #else
        return false
        #endif
    }()

    private init() {
        let initial = DeviceConditions(isLowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
                                       isOnExternalPower: Self.hasNoBattery)
        state = initial
        subject = CurrentValueSubject(initial)
        startObserving()
    }

    /// The latest conditions. Until the first network path arrives the network counts as available
    /// and unmetered, so nothing is held back at launch.
    public var current: DeviceConditions {
        lock.withLock { state }
    }

    /// The current conditions, then every change. Delivered on whichever queue observed the change;
    /// debounce and hop to your own queue as needed.
    public var publisher: AnyPublisher<DeviceConditions, Never> {
        subject.removeDuplicates().eraseToAnyPublisher()
    }

    private func update(_ change: (inout DeviceConditions) -> Void) {
        let updated: DeviceConditions? = lock.withLock {
            var next = state
            change(&next)
            guard next != state else { return nil }
            state = next
            return next
        }
        if let updated {
            subject.send(updated)
        }
    }

    private func startObserving() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            self?.update { conditions in
                conditions.isNetworkAvailable = path.status == .satisfied
                conditions.isExpensiveNetwork = path.isExpensive
                conditions.isConstrainedNetwork = path.isConstrained
                conditions.isCellular = path.usesInterfaceType(.cellular)
            }
        }
        pathMonitor.start(queue: DispatchQueue(label: "org.provenance.device-conditions", qos: .utility))

        let powerObserver = NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: nil
        ) { [weak self] _ in
            let isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
            self?.update { $0.isLowPowerMode = isLowPowerMode }
        }
        lock.withLock { observers.append(powerObserver) }

        #if os(iOS)
        Task { @MainActor [weak self] in
            self?.startBatteryMonitoring()
        }
        #endif
    }

    #if os(iOS)
    /// `UIDevice.batteryState` is `.unknown` until monitoring is turned on.
    @MainActor
    private func startBatteryMonitoring() {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        applyBatteryState(device.batteryState)
        let batteryObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.batteryStateDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.applyBatteryState(UIDevice.current.batteryState)
            }
        }
        lock.withLock { observers.append(batteryObserver) }
    }

    @MainActor
    private func applyBatteryState(_ batteryState: UIDevice.BatteryState) {
        let onExternalPower = Self.isOnExternalPower(batteryState, isiOSAppOnMac: ProcessInfo.processInfo.isiOSAppOnMac)
        update { $0.isOnExternalPower = onExternalPower }
    }

    /// A Mac running the iOS app reports `.unknown`; treat it as plugged in.
    static func isOnExternalPower(_ batteryState: UIDevice.BatteryState, isiOSAppOnMac: Bool) -> Bool {
        switch batteryState {
        case .charging, .full:
            return true
        case .unplugged:
            return false
        case .unknown:
            return isiOSAppOnMac
        @unknown default:
            return false
        }
    }
    #endif
}
#endif
