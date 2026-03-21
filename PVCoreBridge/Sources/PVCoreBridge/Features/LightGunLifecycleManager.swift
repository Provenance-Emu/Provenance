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
/// This type is a **primitive building block** — it provides the attach/detach
/// API but does not wire itself into the game-launch or teardown pipeline.
/// Callers (e.g. the emulator view controller in `PVUIBase`) are responsible
/// for calling `attach(to:)` after the core starts and `detach()` when the
/// game ends.
///
/// `attach(to:)` requires a `LightGunResponder`-conforming core at the call
/// site (compile-time enforced). If the core reports `gameSupportsLightGun == false`
/// at runtime, any currently-attached driver is first detached, then the
/// function returns without creating a new driver.
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
    /// Weak reference to the attached core. Used by `isAttached` to reflect whether
    /// a live, light-gun-capable core is currently bound. If the core is deallocated
    /// without an explicit `detach()` call, this reference becomes nil and `isAttached`
    /// returns `false`; the underlying driver (if any) safely handles nil responders.
    private weak var core: (AnyObject & LightGunResponder)?

    // MARK: - Init

    public init() {}

    // MARK: - Public API

    /// Attach light gun input to the given core if it supports light guns.
    ///
    /// If the core reports `gameSupportsLightGun == false`, any currently-attached driver
    /// is first detached and then the function returns without creating a new driver.
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
    ///
    /// Returns `true` as long as a light-gun-capable core is attached AND still alive.
    /// If the core is deallocated before `detach()` is called, this returns `false`;
    /// the underlying driver will silently discard events until `detach()` is explicitly called.
    public var isAttached: Bool {
        return core != nil
    }
}
