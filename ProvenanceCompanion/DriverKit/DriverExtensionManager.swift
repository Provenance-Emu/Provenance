/// DriverExtensionManager.swift
/// ProvenanceCompanion
///
/// Manages system extension lifecycle for the embedded DriverKit HID driver.
/// Handles activation, deactivation, and status reporting.

import Foundation
import SystemExtensions

/// Manages the embedded ProvenanceCompanionDriverKit dext lifecycle.
@MainActor
@Observable
public final class DriverExtensionManager: NSObject {

    // MARK: - Constants

    /// Bundle identifier of the embedded DriverKit extension.
    public static let dextBundleID = "org.provenance-emu.ProvenanceCompanion.driverkit"

    // MARK: - State

    public enum ActivationState: Sendable {
        case unknown
        case notInstalled
        case activating
        case active
        case deactivating
        case failed(String)
    }

    public private(set) var activationState: ActivationState = .unknown
    public private(set) var isActivating = false

    // Tracks whether the in-flight request is a deactivation so that
    // `didFinishWithResult` can transition to the correct terminal state.
    private var pendingDeactivation = false

    /// True when the extension can be activated (state is unknown or not installed).
    public var canEnable: Bool {
        switch activationState {
        case .unknown, .notInstalled: return true
        default: return false
        }
    }

    // MARK: - Public API

    /// Request activation of the DriverKit extension.
    /// The user will see a system prompt asking for approval on first run.
    /// Allowed from `.unknown` as well as `.notInstalled` — the OS deduplicates
    /// activation requests if the dext is already active.
    public func activateExtension() {
        switch activationState {
        case .unknown, .notInstalled: break
        default: return
        }
        isActivating = true
        activationState = .activating

        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: Self.dextBundleID,
            queue: .main
        )
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
    }

    /// Request deactivation (unloading) of the DriverKit extension.
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

    /// Query the current extension state from SystemExtensions.
    public func refreshState() {
        // OSSystemExtensionManager doesn't have a direct "list active extensions" API;
        // activation state is tracked via delegate callbacks and persisted here.
        // On app launch, assume unknown until activation is attempted or succeeds.
    }
}

// MARK: - OSSystemExtensionRequestDelegate

extension DriverExtensionManager: OSSystemExtensionRequestDelegate {

    public nonisolated func request(
        _ request: OSSystemExtensionRequest,
        actionForReplacingExtension existing: OSSystemExtensionProperties,
        withExtension ext: OSSystemExtensionProperties
    ) -> OSSystemExtensionRequest.ReplacementAction {
        // Always replace with the newer bundled version.
        return .replace
    }

    public nonisolated func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        Task { @MainActor in
            // State stays .activating — the OS presents its own approval UI.
        }
    }

    public nonisolated func request(
        _ request: OSSystemExtensionRequest,
        didFinishWithResult result: OSSystemExtensionRequest.Result
    ) {
        Task { @MainActor in
            isActivating = false
            let wasDeactivation = pendingDeactivation
            pendingDeactivation = false
            switch result {
            case .completed, .willCompleteAfterReboot:
                activationState = wasDeactivation ? .notInstalled : .active
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
            isActivating = false
            pendingDeactivation = false
            activationState = .failed(error.localizedDescription)
        }
    }
}
