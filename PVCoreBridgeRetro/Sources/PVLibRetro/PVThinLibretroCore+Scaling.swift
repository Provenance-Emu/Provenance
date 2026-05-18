//
//  PVThinLibretroCore+Scaling.swift
//  PVCoreBridgeRetro
//
//  Wires the user's `Defaults[.scalingMode]` preference into the per-core
//  libretro options that control widescreen / stretch / aspect overrides.
//
//  Background
//  ----------
//  The host-side renderer (`PVMetalViewController`) already honours
//  `ScalingMode` by sizing the MTKView frame: it reads `aspectSize` /
//  `bufferSize` / `screenRect` from the core and computes letterbox /
//  pillarbox / fill / integer-scale / native-resolution layouts. That
//  behaviour is shared by native cores, the full RetroArch wrapper and
//  the thin libretro wrapper.
//
//  But several libretro cores expose their OWN aspect-ratio toggle as a
//  core option (`mupen64plus-aspect`, `dolphin_aspect_ratio`,
//  `ppsspp_stretch`, `flycast_widescreen_hack`, etc.). The full RetroArch
//  wrapper translates the user's preference into these options
//  implicitly via RA's `video_aspect_ratio_idx = ASPECT_RATIO_CORE` flow.
//  The thin wrapper does not run RA, so without this translation the
//  user's "Stretch" / "Aspect Fit" pause-menu choice silently no-ops for
//  cores that gate widescreen behind a core option.
//
//  This extension closes that gap by:
//   1. Mapping `ScalingMode` → per-core option key/value pairs.
//   2. Applying the mapping at `startEmulation` (after defaults are seeded).
//   3. Observing `Defaults.updates(.scalingMode)` so mid-game changes from
//      the pause menu reach the running core. The observer also re-posts
//      the same notification the bridge fires on geometry change, so
//      `PVMetalViewController` and DeltaSkin views re-layout immediately.
//
//  Created by Claude (Agent) on 2026-05-17.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
import PVLogging
import PVSettings   // @_exported re-exports Defaults — gives us Defaults[...] and Defaults.updates(_:)

extension PVThinLibretroCore {

    // MARK: - Public entry points

    /// Apply the current `Defaults[.scalingMode]` to the loaded core's
    /// libretro options. Safe to call at any point after `loadFileAtPath:`.
    /// Setting an option not declared by the core is a no-op inside the
    /// bridge so this is safe to call for every core.
    @objc func applyScalingModeToCoreOptions() {
        let mode = Defaults[.scalingMode]
        let coreId = (coreIdentifier ?? "").lowercased()
        let pairs = Self.coreOptionOverrides(for: mode, coreIdentifier: coreId)
        guard !pairs.isEmpty else {
            DLOG("ThinCore: scalingMode=\(mode) has no per-core option overrides for \(coreId)")
            return
        }
        for (key, value) in pairs {
            _bridge.setCoreOption(key, value: value)
            ILOG("ThinCore: scalingMode=\(mode) → \(key) = \(value)")
        }
    }

    /// Begin observing `Defaults[.scalingMode]` so pause-menu changes
    /// propagate into the running core's options. The observer also asks
    /// the renderer to re-layout immediately by re-broadcasting the
    /// `PVThinLibretroCoreAVInfoDidUpdate` notification — this is the
    /// same path the core uses to signal a geometry change, so cached
    /// aspect-ratio data in SwiftUI skin views is invalidated.
    @objc func startScalingModeObservation() {
        scalingModeObservationTask?.cancel()
        // Capture a generation tag — if this core is torn down and a new
        // one starts, the captured tag stops matching and we bail out.
        let captured = Self.bumpScalingGeneration()
        scalingModeObservationTask = Task { [weak self] in
            // initial: false → don't fire immediately; startEmulation already
            // called applyScalingModeToCoreOptions() synchronously.
            for await _ in Defaults.updates(.scalingMode, initial: false) {
                // Guard against stale task firing after teardown.
                guard let self = self,
                      Self.currentScalingGeneration == captured else { return }
                self.applyScalingModeToCoreOptions()
                // Mirror the geometry-change notification so DeltaSkin and
                // PVMetalViewController re-read `aspectSize` immediately.
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .PVThinLibretroCoreAVInfoDidUpdate,
                        object: nil
                    )
                }
            }
        }
    }

    /// Cancel the pending scaling-mode observer. Called from
    /// `stopEmulation` / `deinit`.
    @objc func stopScalingModeObservation() {
        scalingModeObservationTask?.cancel()
        scalingModeObservationTask = nil
    }

    // MARK: - Mapping table

    /// Returns the `(option-key, option-value)` pairs to apply for a given
    /// `ScalingMode` on a given core identifier. Cores that don't expose a
    /// widescreen / stretch / aspect option return an empty array — the
    /// renderer's view-frame logic handles those cases on its own.
    ///
    /// The mapping intentionally mirrors what the full RetroArch wrapper
    /// achieves via its internal `video_aspect_ratio_idx` flow:
    /// - `.stretch`   → enable widescreen / stretch where supported.
    /// - `.aspectFit` / `.aspectFill` / `.integerScale` / `.nativeResolution`
    ///   → restore the core's natural aspect (disable widescreen hacks).
    /// Stretch is the only mode that distorts the image; the others all
    /// preserve aspect ratio, so they share the "natural aspect" branch.
    static func coreOptionOverrides(
        for mode: ScalingMode,
        coreIdentifier: String
    ) -> [(String, String)] {
        // Only override when the user has explicitly selected stretch.
        // For .aspectFit / .aspectFill / .integerScale / .nativeResolution the
        // renderer handles aspect at the MTKView frame level — we must NOT
        // force `widescreen_hack=disabled` (or similar) here because that
        // changes the core's framebuffer geometry vs whatever it negotiated
        // with our render delegate. flycast specifically crashes on first
        // frame with a Vulkan GPU page fault when we force the option away
        // from its native default (the IOSurface texture we pass back to it
        // ends up sized for the old aspect; flycast writes to the new one).
        // See PROVENANCE-XX investigation 2026-05-18.
        guard mode == .stretch else { return [] }
        var pairs: [(String, String)] = []

        if coreIdentifier.contains("mupen") {
            // mupen64plus-aspect: "4:3" | "16:9" | "Stretch"
            pairs.append(("mupen64plus-aspect", "Stretch"))
        }
        if coreIdentifier.contains("dolphin") {
            // dolphin_aspect_ratio: "Auto" | "Force 4:3" | "Force 16:9" | "Stretch"
            pairs.append(("dolphin_aspect_ratio", "Stretch"))
        }
        if coreIdentifier.contains("ppsspp") {
            // ppsspp_stretch: "enabled" | "disabled"
            pairs.append(("ppsspp_stretch", "enabled"))
        }
        if coreIdentifier.contains("flycast") {
            // flycast_widescreen_hack: "disabled" | "enabled"
            pairs.append(("flycast_widescreen_hack", "enabled"))
        }
        if coreIdentifier.contains("duckstation") {
            // duckstation_GPU.WidescreenHack: "false" | "true"
            pairs.append(("duckstation_GPU.WidescreenHack", "true"))
        }
        if coreIdentifier.contains("beetle_psx") || coreIdentifier.contains("psx_hw") {
            // beetle_psx_widescreen_hack: "disabled" | "enabled"
            pairs.append(("beetle_psx_widescreen_hack", "enabled"))
        }
        if coreIdentifier.contains("gearcoleco") {
            // gearcoleco_aspect_ratio: "1:1 PAR" | "4:3 DAR" | "16:9 DAR"
            pairs.append(("gearcoleco_aspect_ratio", "16:9 DAR"))
        }
        // Note: genesis_plus_gx had no stretch-mode option to set; removed
        // the unconditional `"auto"` push so we don't clobber the user's
        // own choice when scalingMode != .stretch.
        return pairs
    }

    // MARK: - Task storage (associated objects)

    /// Associated-object key for the per-instance observation task.
    /// Using an associated object keeps this extension stored-property-free,
    /// so it can live in a separate file from the main class declaration.
    private static var scalingObservationKey: UInt8 = 0

    /// Backing store for the scaling-mode observation task.
    private var scalingModeObservationTask: Task<Void, Never>? {
        get {
            objc_getAssociatedObject(self, &Self.scalingObservationKey) as? Task<Void, Never>
        }
        set {
            objc_setAssociatedObject(self, &Self.scalingObservationKey, newValue,
                                     .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /// Generation counter used to invalidate stale observation tasks when
    /// a new core spins up. Mirrors the pattern used by the input-poll
    /// closure in `PVThinLibretroCore.swift`.
    nonisolated(unsafe) private static var _scalingGenerationStorage: Int = 0
    private static let scalingGenerationLock = NSLock()

    /// Bump and return the new generation. Called from
    /// `startScalingModeObservation` so each fresh observer sees a fresh tag.
    static func bumpScalingGeneration() -> Int {
        scalingGenerationLock.lock()
        defer { scalingGenerationLock.unlock() }
        _scalingGenerationStorage &+= 1
        return _scalingGenerationStorage
    }

    /// Snapshot of the current generation. Observers compare against this
    /// to bail out when superseded.
    static var currentScalingGeneration: Int {
        scalingGenerationLock.lock()
        defer { scalingGenerationLock.unlock() }
        return _scalingGenerationStorage
    }
}
