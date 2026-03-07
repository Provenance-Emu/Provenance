//
//  CoreRetroAchievements.swift
//  PVCoreBridge
//
//  Protocol for emulator cores that support RetroAchievements via rcheevos.
//
//  ## Integration overview for native cores
//
//  1. Conform your bridge class to `CoreRetroAchievements`.
//  2. After the ROM loads, store the game's MD5 hash (available from PVHashing)
//     and call `prepareAchievements(gameHash:)` to initialise the runtime.
//  3. At the end of every emulated frame, call `tickAchievements()`.
//     rcheevos will read memory via the regions returned by
//     `achievementMemoryRegions()` and fire delegate callbacks on unlocks.
//  4. Forward `RetroAchievementsOSDDelegate` calls to your view controller so
//     the UI can show toast notifications.
//  5. Respect `hardcoreMode` — deny save-state loads when it is true.
//
//  ## RetroArch / libretro cores (PVCoreBridgeRetro)
//
//  RetroArch already contains cheevos.c which drives rcheevos internally and
//  renders its own OSD inside the GL buffer.  PVLibRetroCoreBridge conforms
//  to this protocol but only exposes the delegate callbacks for events that
//  need to reach the native Swift layer (sounds, CloudKit progress, etc.).
//  The in-GL badge rendering is left to RetroArch.
//

import Foundation

// MARK: - Core Protocol

/// Emulator cores that provide RetroAchievements support should conform to this protocol.
///
/// Conforming to this protocol does **not** automatically enable achievements;
/// the game must also be identified in the RA database and the user must be
/// authenticated.  Use `PVCheevos.RetroAchievementsClient` for authentication.
public protocol CoreRetroAchievements: AnyObject {

    // MARK: Delegate

    /// Receives OSD events (unlocks, progress, challenge indicators, leaderboards).
    var achievementsDelegate: (any RetroAchievementsOSDDelegate)? { get set }

    // MARK: Session lifecycle

    /// Prepare the achievement runtime for the loaded game.
    ///
    /// Call this after the ROM has been loaded and memory is mapped.
    /// `gameHash` should be the MD5 hash of the ROM file (PVHashing provides this).
    ///
    /// - Parameter gameHash: MD5 hex string identifying the game on retroachievements.org.
    func prepareAchievements(gameHash: String) async

    /// Tear down the achievement runtime.
    ///
    /// Call this when emulation stops or a new game is loaded.
    func stopAchievements()

    // MARK: Per-frame update

    /// Advance the achievement runtime by one emulated frame.
    ///
    /// Call this at the **end** of each emulated frame, after the core has
    /// updated all memory.  rcheevos evaluates conditions and fires callbacks
    /// from within this call.
    func tickAchievements()

    // MARK: Memory access

    /// Provide the memory regions that rcheevos should read.
    ///
    /// Return all regions that contain game state (system RAM, VRAM, etc.).
    /// The returned pointers must remain valid for the entire session.
    func achievementMemoryRegions() -> [AchievementMemoryRegion]

    // MARK: State

    /// Whether the achievement runtime is currently active for a loaded game.
    var achievementsActive: Bool { get }

    /// Hardcore mode — when true, save-state loads must be disallowed.
    var hardcoreMode: Bool { get set }
}

// MARK: - Default implementations

public extension CoreRetroAchievements {

    /// No-op default — cores that don't yet implement per-frame ticking still compile.
    func tickAchievements() {}

    /// Default: no memory regions exposed.
    func achievementMemoryRegions() -> [AchievementMemoryRegion] { [] }

    /// Default: inactive.
    var achievementsActive: Bool { false }
}
