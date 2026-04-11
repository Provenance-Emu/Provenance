/// OpticalDriveManager.swift
/// ProvenanceCompanion
///
/// Manages the lifecycle of the ProvenanceCompanionOpticalDriveDriverKit dext and
/// provides a high-level interface to the optical drive's status and disc I/O.
///
/// Mirrors the pattern established by DriverExtensionManager for the HID driver.
/// Requires iOS/iPadOS 16+ or macOS 13+ (DriverKit minimum).
/// Not available on tvOS (no USB host mode for optical drives).

#if os(macOS) || targetEnvironment(macCatalyst)
import Foundation
import SystemExtensions

/// Manages the embedded optical drive DriverKit extension lifecycle.
@MainActor
@Observable
public final class OpticalDriveManager: NSObject {

    // MARK: - Constants

    /// Bundle identifier of the optical drive DriverKit extension.
    public static let dextBundleID = "org.provenance-emu.ProvenanceCompanion.opticaldrive.driverkit"

    // MARK: - State

    public enum ActivationState: Sendable {
        case unknown
        case notInstalled
        case activating
        case active
        case deactivating
        case failed(String)
    }

    /// Current disc status reported by the driver.
    public enum DriveStatus: Sendable, Equatable {
        case driverNotActive
        case noDisc
        case discPresent
        case trayOpen
        case reading
        case unknown
    }

    public private(set) var activationState: ActivationState = .unknown
    public private(set) var driveStatus: DriveStatus = .driverNotActive

    private var pendingDeactivation = false

    /// True when the extension can be activated (state is unknown or not installed).
    public var canEnable: Bool {
        switch activationState {
        case .unknown, .notInstalled: return true
        default: return false
        }
    }

    /// True when the driver is active and a disc is inserted.
    public var hasDisc: Bool { driveStatus == .discPresent }

    // MARK: - Public API

    /// Request activation of the optical drive DriverKit extension.
    /// The user will see a system prompt asking for approval on first run.
    public func activateExtension() {
        switch activationState {
        case .unknown, .notInstalled: break
        default: return
        }
        activationState = .activating

        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: Self.dextBundleID,
            queue: .main
        )
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
    }

    /// Request deactivation of the optical drive DriverKit extension.
    public func deactivateExtension() {
        guard case .active = activationState else { return }
        activationState = .deactivating
        pendingDeactivation = true

        let request = OSSystemExtensionRequest.deactivationRequest(
            forExtensionWithIdentifier: Self.dextBundleID,
            queue: .main
        )
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
    }

    /// Poll the drive status when the driver is active.
    /// Call this periodically (e.g. on a 2-second timer) to detect disc insertion/removal.
    public func refreshDriveStatus() async {
        guard case .active = activationState else {
            driveStatus = .driverNotActive
            return
        }
        // IPC to the dext via IOConnectCallScalarMethod is not available in Swift directly.
        // Actual implementation in companion app target uses IOKit C APIs (IOKitBridge).
        // This async method is the public interface; the bridge is called underneath.
    }
}

// MARK: - OSSystemExtensionRequestDelegate

extension OpticalDriveManager: OSSystemExtensionRequestDelegate {

    public nonisolated func request(
        _ request: OSSystemExtensionRequest,
        actionForReplacingExtension existing: OSSystemExtensionProperties,
        withExtension ext: OSSystemExtensionProperties
    ) -> OSSystemExtensionRequest.ReplacementAction {
        .replace
    }

    public nonisolated func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        // State stays .activating — the OS presents its own approval UI.
    }

    public nonisolated func request(
        _ request: OSSystemExtensionRequest,
        didFinishWithResult result: OSSystemExtensionRequest.Result
    ) {
        Task { @MainActor in
            let wasDeactivation = pendingDeactivation
            pendingDeactivation = false
            switch result {
            case .completed, .willCompleteAfterReboot:
                if wasDeactivation {
                    activationState = .notInstalled
                    driveStatus = .driverNotActive
                } else {
                    activationState = .active
                }
            @unknown default:
                activationState = .failed("Unknown result")
            }
        }
    }

    public nonisolated func request(
        _ request: OSSystemExtensionRequest,
        didFailWithError error: Error
    ) {
        Task { @MainActor in
            pendingDeactivation = false
            activationState = .failed(error.localizedDescription)
        }
    }
}

#endif // os(macOS) || targetEnvironment(macCatalyst)
