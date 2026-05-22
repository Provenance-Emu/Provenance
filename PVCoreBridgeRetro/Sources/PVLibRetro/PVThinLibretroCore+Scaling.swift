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
//  `reicast_widescreen_hack`, `swanstation_GPU_WidescreenHack`, etc.).
//  The full RetroArch wrapper translates the user's preference into these
//  options implicitly via RA's `video_aspect_ratio_idx = ASPECT_RATIO_CORE`
//  flow.
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
            // mupen64plus-aspect (upstream mupen64plus-libretro-nx, libretro/libretro_core_options.h):
            //   "4:3" | "16:9" | "16:9 adjusted"
            // "16:9 adjusted" renders a TRUE widescreen FOV (calculated from the
            // selected 16:9 internal resolution) rather than stretching the 4:3
            // framebuffer. That's a better result on Provenance because our
            // renderer's .stretch fills the screen regardless — picking
            // "16:9 adjusted" means the user sees expanded geometry, not
            // distorted 4:3. Note: the previous value "Stretch" was rejected
            // by mupen as not in the enum, so the core silently kept its 4:3
            // default (root cause of the tester report).
            pairs.append(("mupen64plus-aspect", "16:9 adjusted"))
        }
        if coreIdentifier.contains("dolphin") {
            // dolphin_aspect_ratio (libretro/dolphin Source/Core/DolphinLibretro/Common/Options.cpp):
            //   "0" Auto | "1" Force Wide | "2" Force Standard | "3" Stretch |
            //   "4" Custom | "5" Custom Stretch | "6" Raw
            // dolphin_widescreen_hack: "disabled" | "enabled" — expands the
            //   game's FOV so the rendered framebuffer is true 16:9 instead
            //   of a stretched 4:3 image. Setting both gives the best result.
            // The previous value "Stretch" was rejected (key expects numeric
            // string), so the option no-op'd.
            pairs.append(("dolphin_aspect_ratio", "1"))
            pairs.append(("dolphin_widescreen_hack", "enabled"))
        }
        // PPSSPP intentionally has no widescreen / stretch core option —
        // the PSP framebuffer is natively 480×272 (~16:9). The renderer's
        // .stretch handles the (minor) fill-to-screen.
        if coreIdentifier.contains("flycast") || coreIdentifier.contains("reicast") {
            // Flycast's libretro option prefix is `reicast_*`, NOT `flycast_*`
            // (CORE_OPTION_NAME defined in shell/libretro/libretro_core_option_defines.h).
            // The previous `flycast_widescreen_hack` was rejected by the core,
            // so widescreen never engaged.
            pairs.append(("reicast_widescreen_hack", "enabled"))
        }
        if coreIdentifier.contains("duckstation") || coreIdentifier.contains("swanstation") {
            // The DuckStation libretro fork is `swanstation` (libretro/swanstation,
            // src/libretro/libretro_core_options.h). Keys use UNDERSCORES, not dots:
            //   swanstation_GPU_WidescreenHack: "true" | "false"
            //   swanstation_Display_AspectRatio: "4:3" | "16:9" | "19:9" | "20:9" | "Custom" | "Auto" | "Native"
            // The previous `duckstation_GPU.WidescreenHack` (with dot) didn't
            // match any option the core registers, so widescreen never engaged.
            pairs.append(("swanstation_GPU_WidescreenHack", "true"))
            pairs.append(("swanstation_Display_AspectRatio", "16:9"))
        }
        if coreIdentifier.contains("psx_hw") || coreIdentifier.contains("mednafen_psx_hw") {
            // Beetle PSX HW: key prefix is `beetle_psx_hw_` (see
            // BeetlePSX/beetle-psx/libretro_options.h: `BEETLE_OPT(_o) ("beetle_psx_hw_" # _o)`
            // when built with HAVE_HW). The previous `beetle_psx_widescreen_hack`
            // was for the SOFTWARE core only.
            pairs.append(("beetle_psx_hw_widescreen_hack", "enabled"))
        } else if coreIdentifier.contains("beetle_psx") || coreIdentifier.contains("mednafen_psx") {
            // Beetle PSX (software renderer) — no `_hw_` infix.
            pairs.append(("beetle_psx_widescreen_hack", "enabled"))
        }
        if coreIdentifier.contains("gearcoleco") {
            // gearcoleco_aspect_ratio: "1:1 PAR" | "4:3 DAR" | "16:9 DAR" | "16:10 DAR"
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
