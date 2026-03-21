//
//  LightGunLifecycleManager.swift
//  PVCoreBridge
//
//  Created by Provenance Emu on 2026-03-21.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation

/// Manages the lifecycle of light gun input for a single game session.
///
/// Call `attach(to:)` after the core starts and `detach()` when the game ends.
/// If the core does not conform to `LightGunResponder` or reports
/// `gameSupportsLightGun == false`, all calls are no-ops.
///
/// Example usage from an emulator view controller:
/// ```swift
/// private let lightGunManager = LightGunLifecycleManager()
///
/// override func viewDidAppear(_ animated: Bool) {
///     super.viewDidAppear(animated)
///     if let responder = core as? LightGunResponder & AnyObject {
///         lightGunManager.attach(to: responder)
///     }
/// }
///
/// override func viewWillDisappear(_ animated: Bool) {
///     super.viewWillDisappear(animated)
///     lightGunManager.detach()
/// }
/// ```
@MainActor
public final class LightGunLifecycleManager {

    // MARK: - Private state

#if canImport(GameController)
    private var driver: GCMouseLightGunDriver?
#endif
    private weak var core: (AnyObject & LightGunResponder)?

    // MARK: - Init

    public init() {}

    // MARK: - Public API

    /// Attach light gun input to the given core if it supports light guns.
    /// Safe to call even if the core reports `gameSupportsLightGun == false` — it will no-op.
    /// Calling this while a driver is already attached will detach the previous driver first.
    public func attach(to core: some LightGunResponder & AnyObject) {
        // Always detach first so any previously-attached driver is released and the
        // core is not left in a permanently-attached state when switching games.
        detach()
        guard core.gameSupportsLightGun else { return }
#if canImport(GameController)
        let d = GCMouseLightGunDriver()
        d.attach(to: core)
        self.driver = d
#endif
        self.core = core
    }

    /// Detach the light gun driver and release all references.
    public func detach() {
#if canImport(GameController)
        driver?.detach()
        driver = nil
#endif
        core = nil
    }

    /// Whether a light gun driver is currently active.
    public var isAttached: Bool {
#if canImport(GameController)
        return driver != nil
#else
        return false
#endif
    }
}
