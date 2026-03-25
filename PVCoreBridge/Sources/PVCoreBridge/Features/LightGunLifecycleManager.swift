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
/// `attach(to:)` accepts any `LightGunResponder`-conforming core. Callers
/// typically cast with `core as? any LightGunResponder & AnyObject` before
/// calling `attach(to:)`. If the core reports `gameSupportsLightGun == false` at runtime,
/// any currently-attached driver is first detached, then the function returns
/// without creating a new driver. Callers should check `gameSupportsLightGun`
/// before calling `attach(to:)` if a silent no-op is undesirable.
///
/// `isAttached` reflects whether a `GCMouseLightGunDriver` is currently installed.
/// It returns `false` on platforms where `GameController` is unavailable.
/// Always call `detach()` at the end of a game session to release resources.
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

    // MARK: - Init

    public init() {}

    // MARK: - Public API

    /// Sensitivity multiplier forwarded to the ``GCMouseLightGunDriver`` on attach.
    ///
    /// Set this before calling ``attach(to:)`` — or update it at any point while
    /// the driver is active. Valid range 0.1 – 5.0; default 1.0.
    ///
    /// Callers at higher tiers (e.g. PVUIBase) should read the effective value from
    /// `Defaults.effectiveLightGunSensitivity(forGameMD5:)` and assign it here so that
    /// per-game and global sensitivity preferences are applied.
    public var sensitivity: Double = 1.0 {
        didSet {
#if canImport(GameController)
            driver?.sensitivity = CGFloat(sensitivity)
#endif
        }
    }

    /// Attach light gun input to the given core if it supports light guns.
    ///
    /// If the core reports `gameSupportsLightGun == false`, any currently-attached driver
    /// is first detached and then the function returns without creating a new driver.
    /// Calling this while a driver is already attached will detach the previous driver first.
    public func attach(to core: any LightGunResponder & AnyObject) {
        // Always detach first so any previously-attached driver is released and the
        // core is not left in a permanently-attached state when switching games.
        detach()
        guard core.gameSupportsLightGun else { return }
#if canImport(GameController)
        let d = GCMouseLightGunDriver()
        d.sensitivity = CGFloat(sensitivity)
        d.attach(to: core)
        self.driver = d
#endif
    }

    /// Detach the light gun driver and release all references.
    public func detach() {
#if canImport(GameController)
        driver?.detach()
        driver = nil
#endif
    }

    /// Whether a light gun driver is currently active.
    ///
    /// Derived from whether a driver instance exists. Returns `true` only when
    /// `GameController` is available and a driver has been successfully attached.
    /// On platforms without `GameController` support this always returns `false`.
    public var isAttached: Bool {
#if canImport(GameController)
        return driver != nil
#else
        return false
#endif
    }
}
