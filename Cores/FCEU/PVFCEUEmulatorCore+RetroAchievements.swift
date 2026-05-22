//
//  PVFCEUEmulatorCore+RetroAchievements.swift
//  PVFCEU
//
//  Conformance of PVFCEUEmulatorCore (NES/Famicom) to CoreRetroAchievements.
//
//  ## Current status: bridge RAM exposed, Swift extension pending xcodeproj wiring
//
//  The ObjC bridge (`PVFCEUEmulatorCoreBridge`) now exposes `systemRAMPtr` /
//  `systemRAMSize` (the 2 KiB internal NES RAM block from FCEUX's `RAM[]`
//  global at `fceux/src/fceu.h`). The remaining work to make NES achievements
//  actually pop is:
//
//  1. Add `PVRcheevos` and `PVRcheevosBridge` as XCLocalSwiftPackageReference
//     entries in `PVFCEU.xcodeproj/project.pbxproj` (mirror the C0C0CAFE-
//     prefixed UUID pattern used by `Cores/SNES9x/PVSNES9x.xcodeproj` —
//     8 entries: 2 PBXBuildFile, 2 in Frameworks build phase, 2
//     packageProductDependencies, 2 XCLocalSwiftPackageReference).
//  2. Replace this stub with the SNES9x-style `rcheevosRegions()` that
//     reads `systemRAMPtr` / `systemRAMSize` and returns a single
//     `RcheevosRegion(rcAddress: 0x0000, base: ptr, size: byteCount)`.
//     The default protocol impls in PVRcheevosBridge handle
//     `prepareAchievements` / `tickAchievements` / hardcore.
//
//  Until those frameworks are wired in, this extension picks up the no-op
//  default impls in PVCoreBridge's CoreRetroAchievements extension — that
//  is why NES achievements appear "tracking enabled" via toast but never
//  pop (Section E.1 of the 2026-05-22 cheevos audit).
//

import Foundation
import PVCoreBridge

extension PVFCEUEmulatorCore: CoreRetroAchievements {

    // MARK: - Delegate

    public var achievementsDelegate: (any RetroAchievementsOSDDelegate)? {
        get { _achievementsDelegate }
        set { _achievementsDelegate = newValue }
    }

    // MARK: - Session lifecycle

    public func prepareAchievements(gameHash: String) async {
        // TODO: once PVRcheevos / PVRcheevosBridge are added to PVFCEU.xcodeproj,
        // delete this whole stub file and replace with the SNES9x pattern (just
        // `rcheevosRegions()`). The bridge's `systemRAMPtr` / `systemRAMSize`
        // are already in place at PVFCEUEmulatorCore.{h,mm}.
    }

    public func stopAchievements() {
        // TODO: see prepareAchievements stub above.
    }

    // MARK: - Per-frame tick

    public func tickAchievements() {
        // TODO: see prepareAchievements stub above.
    }

    // MARK: - Memory regions

    public func achievementMemoryRegions() -> [AchievementMemoryRegion] {
        // TODO: see prepareAchievements stub above.
        return []
    }

    // MARK: - State

    public var achievementsActive: Bool {
        return false // TODO: reflect rc_client state once wired.
    }

    public var hardcoreMode: Bool {
        get { _hardcoreMode }
        set { _hardcoreMode = newValue }
    }
}
