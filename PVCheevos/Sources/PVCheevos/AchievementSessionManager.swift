//
//  AchievementSessionManager.swift
//  PVCheevos
//
//  Manages the RetroAchievements session lifecycle during gameplay:
//    1. Resolves the RA game ID from the ROM's MD5 hash.
//    2. Starts a server session so the server knows the player is active.
//    3. Sends periodic pings (every 2 minutes, per RA protocol) to keep
//       the session alive and update Rich Presence.
//    4. Posts achievement unlocks to the server as they occur.
//    5. Tears down cleanly when the game stops.
//
//  Usage:
//    let manager = AchievementSessionManager(client: raClient)
//    let response = try await manager.startSession(gameHash: rom.md5)
//    // … during gameplay …
//    await manager.awardAchievement(id: 12345, hardcore: false)
//    // … when done …
//    await manager.stopSession()
//

import Foundation

/// Coordinates the RetroAchievements server-side session for a single game play.
///
/// Instantiate one manager per emulation session and call `startSession(gameHash:)`
/// after the ROM has loaded. Call `stopSession()` when emulation stops.
///
/// - Note: All methods are safe to call from any concurrency context.
@available(iOS 15.0, tvOS 15.0, macOS 12.0, *)
public actor AchievementSessionManager {

    // MARK: - Configuration

    /// Interval between automatic Rich Presence / keepalive pings (seconds).
    /// RetroAchievements recommends pinging every 2 minutes.
    public static let pingInterval: TimeInterval = 120

    // MARK: - State

    private let client: RetroAchievementsClient
    private var activeGameId: Int?
    private var pingTask: Task<Void, Never>?
    private var richPresenceMessage: String?

    // MARK: - Init

    /// Create a session manager backed by the given authenticated client.
    /// - Parameter client: An authenticated `RetroAchievementsClient`.
    public init(client: RetroAchievementsClient) {
        self.client = client
    }

    // MARK: - Session lifecycle

    /// Start an RA server session for a ROM identified by its MD5 hash.
    ///
    /// - Parameter gameHash: MD5 hex string of the ROM (from PVHashing).
    /// - Returns: The server's `StartSessionResponse`, including the list of
    ///   achievements already unlocked by this user.
    /// - Throws: `RetroError.authenticationFailed` if the client has no valid
    ///   session, or any network / decoding error from the RA API.
    @discardableResult
    public func startSession(gameHash: String) async throws -> StartSessionResponse {
        // Stop any existing session first.
        await stopSession()

        // Resolve the RA game ID from the hash.
        guard let gameId = try await client.getGameId(forHash: gameHash) else {
            throw AchievementSessionError.unknownGame(hash: gameHash)
        }

        // Open the server-side session.
        let response = try await client.startGameSession(gameId: gameId, gameHash: gameHash)
        guard response.success else {
            let reason = response.error ?? "Unknown error"
            throw AchievementSessionError.sessionStartFailed(reason: reason)
        }

        activeGameId = gameId
        startPingLoop()
        return response
    }

    /// Stop the active session and cancel the ping loop.
    ///
    /// Safe to call even when no session is active.
    public func stopSession() {
        pingTask?.cancel()
        pingTask = nil
        activeGameId = nil
        richPresenceMessage = nil
    }

    // MARK: - Rich Presence

    /// Update the Rich Presence message that is included in the next ping.
    ///
    /// The message is formatted by the emulator core (e.g. "Playing World 1-1").
    /// It will be sent to the RA server on the next scheduled ping.
    public func updateRichPresence(_ message: String) {
        richPresenceMessage = message
    }

    // MARK: - Achievement awards

    /// Post an achievement unlock to the RetroAchievements server.
    ///
    /// Call this from `RetroAchievementsOSDDelegate.achievementUnlocked(_:)` when
    /// rcheevos (or a compatible runtime) fires an unlock callback.
    ///
    /// - Parameters:
    ///   - id: The numeric RA achievement ID.
    ///   - hardcore: `true` when earned in hardcore mode (no save states).
    public func awardAchievement(id: UInt32, hardcore: Bool) async {
        guard activeGameId != nil else { return }
        do {
            try await client.awardAchievement(id: id, hardcore: hardcore)
        } catch {
            // Non-fatal: the server will reconcile on the next session start.
            // Optionally surface in debug builds.
            #if DEBUG
            print("[AchievementSessionManager] Failed to award achievement \(id): \(error)")
            #endif
        }
    }

    // MARK: - Accessors

    /// The RA game ID for the currently active session, or `nil` if inactive.
    public var currentGameId: Int? { activeGameId }

    /// Whether an active session is in progress.
    public var isSessionActive: Bool { activeGameId != nil }

    // MARK: - Ping loop

    private func startPingLoop() {
        pingTask?.cancel()
        guard let gameId = activeGameId else { return }

        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(AchievementSessionManager.pingInterval * 1_000_000_000))
                guard !Task.isCancelled else { break }
                guard let self else { break }
                let presence = await self.richPresenceMessage
                _ = try? await self.client.sendPing(gameId: gameId, richPresence: presence)
            }
        }
    }
}

// MARK: - Errors

/// Errors specific to `AchievementSessionManager`.
public enum AchievementSessionError: LocalizedError, Sendable {
    /// The ROM hash is not present in the RetroAchievements database.
    case unknownGame(hash: String)
    /// The server rejected the session start request.
    case sessionStartFailed(reason: String)

    public var errorDescription: String? {
        switch self {
        case .unknownGame(let hash):
            return "ROM with hash \(hash) is not in the RetroAchievements database."
        case .sessionStartFailed(let reason):
            return "RetroAchievements session failed to start: \(reason)"
        }
    }
}
