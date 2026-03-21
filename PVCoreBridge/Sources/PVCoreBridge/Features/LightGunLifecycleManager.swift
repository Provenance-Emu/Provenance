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
/// `attach(to:)` accepts any `LightGunResponder`-conforming core (compile-time
/// enforced). If the core reports `gameSupportsLightGun == false` at runtime,
/// any currently-attached driver is first detached, then the function returns
/// without creating a new driver. Callers should check `gameSupportsLightGun`
/// before calling `attach(to:)` if a silent no-op is undesirable.
///
/// `isAttached` reflects whether a driver is currently active and is independent
/// of the attached core's liveness. If the core is deallocated without an explicit
/// `detach()`, `isAttached` remains `true` while the driver silently discards
/// events. Always call `detach()` at the end of a game session.
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

    /// Whether a driver is currently active. Set by `attach(to:)` / `detach()`.
    /// Independent of the attached core's liveness — see `isAttached` docs.
    private var _isAttached = false

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
        _isAttached = true
    }

    /// Detach the light gun driver and release all references.
    public func detach() {
#if canImport(GameController)
        driver?.detach()
        driver = nil
#endif
        _isAttached = false
    }

    /// Whether a light gun driver is currently active.
    ///
    /// Returns `true` after a successful `attach(to:)` call and remains `true`
    /// until `detach()` is explicitly called — even if the core is deallocated
    /// in the meantime (the driver becomes a no-op in that case).
    /// Always call `detach()` at the end of a game session to release resources.
    public var isAttached: Bool {
        return _isAttached
    }
}
