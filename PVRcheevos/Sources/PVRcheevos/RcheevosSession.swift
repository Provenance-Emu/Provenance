//
//  RcheevosSession.swift
//  PVRcheevos
//
//  Generic Swift wrapper around an `rc_client_t*` instance, replacing the
//  per-core ad-hoc rc_client integrations (Mednafen's `MednafenRcheevosClient`,
//  the bridge-side rc_client owners in Gambatte/Stella/VBA, etc.).
//
//  ## Lifecycle
//
//  1. Create one `RcheevosSession` per emulation session: `let session = RcheevosSession()`.
//  2. After the core has mapped its RAM, call `setRegions(_:)` with the
//     per-system rcheevos memory map (see `RcheevosAddressSpace`).
//  3. Set the event closures (`onAchievementUnlocked`, etc.) to receive
//     unlock / progress / challenge / leaderboard notifications.
//  4. Call `loginAndLoad(gameHash:)` (async). Reads the user's RA token from
//     `UserDefaults` (keys `ra_username` / `ra_session_token`), authenticates
//     if needed, then loads the game by its console-aware hash.
//  5. Call `doFrame()` once per emulated frame — typically from the core's
//     per-frame execute path, on the emulator thread.
//  6. Call `unload()` when emulation stops.
//
//  ## Design note: closures, not a delegate protocol
//
//  PVRcheevos intentionally does **not** depend on PVCoreBridge (where
//  `RetroAchievementsOSDDelegate` lives) — that would pull in the entire
//  bridge layer, including transitive deps like PVAudio that don't belong
//  in a hashing/cheevos library. Consumers in higher-tier modules
//  (PVUIBase, individual core bridges) wire each closure through to the
//  delegate they care about. See `CoreRetroAchievements+RcheevosSession`
//  for the standard adapter.
//
//  ## Thread safety
//
//  - `doFrame()` must run on the emulator thread.
//  - `loginAndLoad(gameHash:)` and `unload()` may be called from any thread.
//  - Event closures are dispatched onto the main queue.
//
//  rcheevos itself is built with `RC_NO_THREADS=1` (see `Package.swift`).
//  That removes the internal mutex, so callers must avoid concurrent
//  `doFrame()` calls. The single-emulator-thread invariant satisfies that.
//

import CRcheevos
import Foundation
import PVRcheevosCore

// MARK: - Errors

public enum RcheevosSessionError: Error, LocalizedError {
    case noCredentials
    case clientCreationFailed
    case loginFailed(String)
    case loadGameFailed(String)
    case unknownGame

    public var errorDescription: String? {
        switch self {
        case .noCredentials:
            return "No RetroAchievements credentials. Log in via Settings > RetroAchievements."
        case .clientCreationFailed:
            return "Failed to create rcheevos client."
        case .loginFailed(let message):
            return "RetroAchievements login failed: \(message)"
        case .loadGameFailed(let message):
            return "RetroAchievements game load failed: \(message)"
        case .unknownGame:
            return "Game not found in RetroAchievements database."
        }
    }
}

// MARK: - Event payloads
//
// These mirror the rc_client_event_t shapes consumers care about, but are
// independent of any particular OSD/delegate protocol so PVRcheevos stays
// dep-free.

public struct RcheevosUnlockEvent: Sendable {
    public let achievementID: UInt32
    public let title: String
    public let description: String
    public let points: UInt32
    public let badgeName: String
    public let isHardcore: Bool
}

public struct RcheevosProgressEvent: Sendable {
    public let achievementID: UInt32
    public let title: String
    public let progressText: String
}

public struct RcheevosChallengeEvent: Sendable {
    public let achievementID: UInt32
    public let badgeName: String
}

public struct RcheevosLeaderboardEvent: Sendable {
    public let leaderboardID: UInt32
    public let title: String
    public let description: String
    public let scoreText: String
}

// MARK: - Session

/// Owns a single `rc_client_t*`, plus the read-memory / HTTP / event-handler
/// wiring that rcheevos needs.
public final class RcheevosSession: @unchecked Sendable {

    // MARK: Stored state

    private var client: OpaquePointer?
    private var regions: [RcheevosRegion] = []
    private var isGameLoaded = false

    // MARK: Event closures
    //
    // All closures are invoked on the main queue.

    public var onAchievementUnlocked: (@Sendable (RcheevosUnlockEvent) -> Void)?
    public var onAchievementProgress: (@Sendable (RcheevosProgressEvent) -> Void)?
    public var onChallengeShow: (@Sendable (RcheevosChallengeEvent) -> Void)?
    public var onChallengeHide: (@Sendable (UInt32) -> Void)?
    public var onLeaderboardStarted: (@Sendable (RcheevosLeaderboardEvent) -> Void)?
    public var onLeaderboardFailed: (@Sendable (UInt32) -> Void)?
    public var onLeaderboardSubmitted: (@Sendable (RcheevosLeaderboardEvent) -> Void)?

    // MARK: Init / deinit

    /// Create the rc_client and wire its three C callbacks (read-memory,
    /// server-call, event-handler) so they can recover `self` via `userdata`.
    /// Returns `nil` if rcheevos failed to allocate the client.
    public init?() {
        guard let client = rc_client_create(rcSessionReadMemory, rcSessionServerCall) else {
            return nil
        }
        self.client = client
        rc_client_set_userdata(client, Unmanaged.passUnretained(self).toOpaque())
        rc_client_set_event_handler(client, rcSessionEventHandler)
    }

    deinit {
        if let client {
            rc_client_destroy(client)
        }
    }

    // MARK: Configuration

    /// Register the memory regions rcheevos may read from. Must be called
    /// before `loginAndLoad(gameHash:)`. The pointers in `regions` must
    /// remain valid for the lifetime of this session.
    public func setRegions(_ regions: [RcheevosRegion]) {
        self.regions = regions
    }

    /// Toggle hardcore mode on the underlying rc_client. Save-state loads
    /// must be denied at the UI layer when this is on (the protocol's
    /// `hardcoreMode` flag handles that — this only mirrors the state
    /// into rc_client so it tags unlocks as hardcore).
    public func setHardcoreEnabled(_ enabled: Bool) {
        guard let client else { return }
        rc_client_set_hardcore_enabled(client, enabled ? 1 : 0)
    }

    /// `true` after `loginAndLoad(gameHash:)` succeeded for the current game.
    public var isLoaded: Bool { isGameLoaded }

    // MARK: Game lifecycle

    /// Authenticate with the user's stored RA credentials (if needed) and
    /// load the game identified by `gameHash`.
    ///
    /// The hash must already be in the format RA expects — Provenance
    /// computes this in `PVEmulatorViewController+Achievements.swift`
    /// (MD5-first with `RcheevosHash.compute(filePath:)` fallback).
    public func loginAndLoad(gameHash: String) async throws {
        guard let client else { throw RcheevosSessionError.clientCreationFailed }

        let defaults = UserDefaults.standard
        guard let username = defaults.string(forKey: "ra_username"), !username.isEmpty,
              let token = defaults.string(forKey: "ra_session_token"), !token.isEmpty else {
            throw RcheevosSessionError.noCredentials
        }

        if rc_client_get_user_info(client) == nil {
            try await beginLogin(username: username, token: token)
        }
        try await beginLoadGame(hash: gameHash)
        isGameLoaded = true
    }

    /// Tear down the active game. Safe to call when no game is loaded.
    public func unload() {
        guard let client else { return }
        rc_client_unload_game(client)
        isGameLoaded = false
    }

    /// Advance the achievement runtime by one emulated frame. Reads memory
    /// through the registered regions and fires event closures for any
    /// events that occurred this frame.
    ///
    /// Must be called from the emulator thread.
    public func doFrame() {
        guard let client, isGameLoaded else { return }
        rc_client_do_frame(client)
    }

    // MARK: - Internal trampolines

    fileprivate func readMemory(
        address: UInt32,
        buffer: UnsafeMutablePointer<UInt8>,
        numBytes: UInt32
    ) -> UInt32 {
        for region in regions where region.contains(address: address) {
            let offset = address &- region.rcAddress
            let remaining = region.size &- offset
            let readable = min(numBytes, remaining)
            let basePtr = region.base.assumingMemoryBound(to: UInt8.self)
            switch region.byteSwapMode {
            case .off:
                memcpy(buffer, basePtr.advanced(by: Int(offset)), Int(readable))
            case .word16:
                // Saturn Work RAM: bytes within each 16-bit word are swapped
                // on little-endian hosts. Logical offset k maps to physical k^1.
                for i in 0..<readable {
                    buffer[Int(i)] = basePtr[Int((offset &+ i) ^ 1)]
                }
            }
            return readable
        }
        return 0
    }

    fileprivate func performServerRequest(
        request: UnsafePointer<rc_api_request_t>,
        callback: rc_client_server_callback_t?,
        callbackData: UnsafeMutableRawPointer?
    ) {
        guard let callback else { return }
        let req = request.pointee
        guard let urlPtr = req.url, let url = URL(string: String(cString: urlPtr)) else {
            invokeServerCallback(callback, callbackData: callbackData, statusCode: 400, body: nil)
            return
        }

        var urlRequest = URLRequest(url: url, timeoutInterval: 30)
        if let postPtr = req.post_data, strlen(postPtr) > 0 {
            urlRequest.httpMethod = "POST"
            urlRequest.httpBody = Data(bytes: postPtr, count: strlen(postPtr))
            urlRequest.setValue("application/x-www-form-urlencoded",
                                forHTTPHeaderField: "Content-Type")
        } else {
            urlRequest.httpMethod = "GET"
        }
        urlRequest.setValue("Provenance/PVRcheevos", forHTTPHeaderField: "User-Agent")

        // The C callback + its userdata are not Sendable, but rcheevos
        // guarantees the lifetime is valid until we invoke the callback.
        nonisolated(unsafe) let cb = callback
        nonisolated(unsafe) let cbData = callbackData
        URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            if let data, error == nil {
                data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
                    invokeServerCallback(cb,
                                         callbackData: cbData,
                                         statusCode: Int32(statusCode),
                                         body: raw.baseAddress?.assumingMemoryBound(to: CChar.self),
                                         bodyLength: data.count)
                }
            } else {
                invokeServerCallback(cb,
                                     callbackData: cbData,
                                     statusCode: 0,
                                     body: nil)
            }
        }.resume()
    }

    fileprivate func handleEvent(_ eventPtr: UnsafePointer<rc_client_event_t>) {
        let event = eventPtr.pointee
        let isHardcore = (client.flatMap { rc_client_get_hardcore_enabled($0) } ?? 0) != 0

        switch Int(event.type) {
        case RC_CLIENT_EVENT_ACHIEVEMENT_TRIGGERED:
            guard let ach = event.achievement else { return }
            let unlock = RcheevosUnlockEvent(
                achievementID: ach.pointee.id,
                title: cString(ach.pointee.title),
                description: cString(ach.pointee.description),
                points: ach.pointee.points,
                badgeName: cStringFromTuple(ach.pointee.badge_name),
                isHardcore: isHardcore
            )
            dispatchOnMain { [weak self] in
                self?.onAchievementUnlocked?(unlock)
            }

        case RC_CLIENT_EVENT_ACHIEVEMENT_PROGRESS_INDICATOR_SHOW,
             RC_CLIENT_EVENT_ACHIEVEMENT_PROGRESS_INDICATOR_UPDATE:
            guard let ach = event.achievement else { return }
            let progress = RcheevosProgressEvent(
                achievementID: ach.pointee.id,
                title: cString(ach.pointee.title),
                progressText: cStringFromTuple(ach.pointee.measured_progress)
            )
            dispatchOnMain { [weak self] in
                self?.onAchievementProgress?(progress)
            }

        case RC_CLIENT_EVENT_ACHIEVEMENT_CHALLENGE_INDICATOR_SHOW:
            guard let ach = event.achievement else { return }
            let challenge = RcheevosChallengeEvent(
                achievementID: ach.pointee.id,
                badgeName: cStringFromTuple(ach.pointee.badge_name)
            )
            dispatchOnMain { [weak self] in
                self?.onChallengeShow?(challenge)
            }

        case RC_CLIENT_EVENT_ACHIEVEMENT_CHALLENGE_INDICATOR_HIDE:
            guard let ach = event.achievement else { return }
            let id = ach.pointee.id
            dispatchOnMain { [weak self] in
                self?.onChallengeHide?(id)
            }

        case RC_CLIENT_EVENT_LEADERBOARD_STARTED:
            guard let lb = event.leaderboard else { return }
            let started = RcheevosLeaderboardEvent(
                leaderboardID: lb.pointee.id,
                title: cString(lb.pointee.title),
                description: cString(lb.pointee.description),
                scoreText: cString(lb.pointee.tracker_value)
            )
            dispatchOnMain { [weak self] in
                self?.onLeaderboardStarted?(started)
            }

        case RC_CLIENT_EVENT_LEADERBOARD_FAILED:
            guard let lb = event.leaderboard else { return }
            let id = lb.pointee.id
            dispatchOnMain { [weak self] in
                self?.onLeaderboardFailed?(id)
            }

        case RC_CLIENT_EVENT_LEADERBOARD_SUBMITTED:
            guard let lb = event.leaderboard else { return }
            let submitted = RcheevosLeaderboardEvent(
                leaderboardID: lb.pointee.id,
                title: cString(lb.pointee.title),
                description: cString(lb.pointee.description),
                scoreText: cString(lb.pointee.tracker_value)
            )
            dispatchOnMain { [weak self] in
                self?.onLeaderboardSubmitted?(submitted)
            }

        default:
            break
        }
    }

    // MARK: - Login / load helpers

    private func beginLogin(username: String, token: String) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            guard let client else {
                cont.resume(throwing: RcheevosSessionError.clientCreationFailed)
                return
            }
            let context = RcCallbackContext { result, message in
                if result == RC_OK {
                    cont.resume()
                } else {
                    cont.resume(throwing: RcheevosSessionError.loginFailed(message ?? "Unknown error"))
                }
            }
            let userdata = Unmanaged.passRetained(context).toOpaque()
            username.withCString { uPtr in
                token.withCString { tPtr in
                    _ = rc_client_begin_login_with_token(client, uPtr, tPtr,
                                                         rcSessionCallbackTrampoline, userdata)
                }
            }
        }
    }

    private func beginLoadGame(hash: String) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            guard let client else {
                cont.resume(throwing: RcheevosSessionError.clientCreationFailed)
                return
            }
            let context = RcCallbackContext { result, message in
                if result == RC_OK {
                    cont.resume()
                } else if result == RC_NO_GAME_LOADED {
                    cont.resume(throwing: RcheevosSessionError.unknownGame)
                } else {
                    cont.resume(throwing: RcheevosSessionError.loadGameFailed(message ?? "Unknown error"))
                }
            }
            let userdata = Unmanaged.passRetained(context).toOpaque()
            hash.withCString { hPtr in
                _ = rc_client_begin_load_game(client, hPtr,
                                              rcSessionCallbackTrampoline, userdata)
            }
        }
    }
}

// MARK: - Helpers

private func cString(_ ptr: UnsafePointer<CChar>?) -> String {
    guard let ptr else { return "" }
    return String(cString: ptr)
}

/// Convert a fixed-size C `char[N]` array (imported as a Swift tuple) into a
/// Swift `String`. rcheevos uses these for short fields like `badge_name[8]`
/// and `measured_progress[24]`.
private func cStringFromTuple<T>(_ tuple: T) -> String {
    withUnsafePointer(to: tuple) { ptr in
        ptr.withMemoryRebound(to: CChar.self, capacity: MemoryLayout<T>.size) {
            String(cString: $0)
        }
    }
}

private func dispatchOnMain(_ work: @escaping @Sendable () -> Void) {
    if Thread.isMainThread {
        work()
    } else {
        DispatchQueue.main.async(execute: work)
    }
}

private func invokeServerCallback(
    _ callback: rc_client_server_callback_t,
    callbackData: UnsafeMutableRawPointer?,
    statusCode: Int32,
    body: UnsafePointer<CChar>?,
    bodyLength: Int = 0
) {
    var response = rc_api_server_response_t()
    response.body = body
    response.body_length = bodyLength
    response.http_status_code = statusCode
    callback(&response, callbackData)
}

/// Holds the Swift completion handler that the C trampoline will invoke.
/// Passed across the C boundary as a retained `Unmanaged` pointer.
private final class RcCallbackContext {
    let completion: (Int32, String?) -> Void
    init(_ completion: @escaping (Int32, String?) -> Void) {
        self.completion = completion
    }
}

// MARK: - C trampolines

private let rcSessionReadMemory: rc_client_read_memory_func_t = { address, buffer, numBytes, client in
    guard let client,
          let userdata = rc_client_get_userdata(client),
          let buffer else { return 0 }
    let session = Unmanaged<RcheevosSession>.fromOpaque(userdata).takeUnretainedValue()
    return session.readMemory(address: address, buffer: buffer, numBytes: numBytes)
}

private let rcSessionServerCall: rc_client_server_call_t = { request, callback, callbackData, client in
    guard let client,
          let userdata = rc_client_get_userdata(client),
          let request else { return }
    let session = Unmanaged<RcheevosSession>.fromOpaque(userdata).takeUnretainedValue()
    session.performServerRequest(request: request, callback: callback, callbackData: callbackData)
}

private let rcSessionEventHandler: rc_client_event_handler_t = { event, client in
    guard let client,
          let userdata = rc_client_get_userdata(client),
          let event else { return }
    let session = Unmanaged<RcheevosSession>.fromOpaque(userdata).takeUnretainedValue()
    session.handleEvent(event)
}

private let rcSessionCallbackTrampoline: rc_client_callback_t = { result, errorMessage, _, userdata in
    guard let userdata else { return }
    let context = Unmanaged<RcCallbackContext>.fromOpaque(userdata).takeRetainedValue()
    let message = errorMessage.map { String(cString: $0) }
    context.completion(result, message)
}
