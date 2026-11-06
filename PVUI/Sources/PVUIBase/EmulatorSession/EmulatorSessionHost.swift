//
//  EmulatorSessionHost.swift
//  PVUI
//

/// The emulator controller capabilities available to session features.
public protocol EmulatorSessionHost: PVEmualatorControllerProtocol {
    /// `true` once `quit()` has begun. Timers and observers must avoid starting work after this.
    @MainActor var isQuitting: Bool { get }

    /// Presents the core's picture and reports draw timing for features such as the performance HUD.
    @MainActor var gpuViewController: PVGPUViewController { get }

    /// The registered session feature of `type`, if it applies to this session.
    @MainActor func feature<T: EmulatorSessionFeature>(_ type: T.Type) -> T?
}
