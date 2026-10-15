//
//  LibrarySharingService.swift
//  PVSwiftUI
//
//  "Share this library": serves Provenance's games to nearby iFly and iCube
//  devices (phase 3 of
//  docs/superpowers/specs/2026-10-14-cross-app-library-sharing-design.md).
//

#if os(iOS) || os(tvOS)
import Foundation
import Observation
import PVFeatureFlags
import PVLibrary
import PVLibrarySharing
import PVLogging
import PVMediaCache
import PVRealm
import PVSystems
import RealmSwift
import SwiftUI
import UIKit

/// Owns the sharing host while "Share this library" is on.
///
/// Runs only while the app is active on iOS (the listeners stop in the
/// background); tvOS keeps serving while the app is open. Everything is behind
/// the `nearbyLibraries` feature flag.
@MainActor
@Observable
public final class LibrarySharingService {
    public static let shared = LibrarySharingService()

    enum Keys {
        static let enabled = "LibrarySharing.enabled"
        static let excludedSystems = "LibrarySharing.excludedSystems"
    }

    enum Status: Equatable {
        case off
        case starting
        case running(ports: [String])
        case failed(String)
    }

    private(set) var status: Status = .off
    private(set) var trustedPeers: [TrustedPeer] = []
    private(set) var grants: [String: LibraryGrant] = [:]

    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Keys.enabled)
            Task { await apply() }
        }
    }

    /// Systems the owner has turned off, as `SystemIdentifier` raw values.
    var excludedSystems: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(excludedSystems), forKey: Keys.excludedSystems)
            Task { await host?.refreshAdvertisements() }
        }
    }

    @ObservationIgnored private var host: LibrarySharingHost?
    @ObservationIgnored private var appActive = true
    @ObservationIgnored let trust = FileHostTrustStore(fileURL: LibrarySharingService.supportFolder.appendingPathComponent("trusted-peers.json"))

    static var supportFolder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LibrarySharing", isDirectory: true)
    }

    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: Keys.enabled)
        excludedSystems = Set(UserDefaults.standard.stringArray(forKey: Keys.excludedSystems) ?? [])
    }

    /// Every system some peer app can receive, for the settings list.
    static var shareableSystems: [SystemIdentifier] {
        ServedDialect.allCases.flatMap(\.systems).sorted()
    }

    // MARK: - Lifecycle

    /// Called from the app's scene-phase handler.
    public static func handleScenePhase(_ phase: ScenePhase) {
        shared.appActive = phase == .active
        #if os(iOS)
        Task { await shared.apply() }
        #else
        if phase == .active { Task { await shared.apply() } }
        #endif
    }

    private var shouldRun: Bool {
        isEnabled && appActive && PVFeatureFlagsManager.shared.nearbyLibraries
    }

    private func apply() async {
        if shouldRun {
            if let host {
                await host.refreshAdvertisements()
                return
            }
            await start()
        } else if let host {
            self.host = nil
            await host.stop()
            status = .off
        }
    }

    private func start() async {
        status = .starting
        let identity = KeychainPeerIdentityStore().loadOrCreate(name: "Provenance on \(UIDevice.current.name)")
        let device = HostDevice(
            name: UIDevice.current.name,
            platform: UIDevice.current.userInterfaceIdiom == .tv ? "tvOS" : "iOS",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        )
        let host = LibrarySharingHost(
            identity: identity, device: device, library: RealmSharedLibrary(), trust: trust,
            approver: HostPromptPresenter(), hashes: FileHashCache(storeURL: Self.supportFolder.appendingPathComponent("hashes.json"))
        )
        self.host = host
        do {
            try await host.start()
            let ports = await host.ports
            status = .running(ports: ports.sorted { $0.key.rawValue < $1.key.rawValue }.map { "\($0.key.rawValue) :\($0.value)" })
            ILOG("Library sharing: serving on \(ports)")
        } catch {
            self.host = nil
            status = .failed(error.localizedDescription)
            ELOG("Library sharing: couldn't start: \(error)")
        }
        await refreshTrust()
    }

    // MARK: - Trusted devices

    func refreshTrust() async {
        trustedPeers = await trust.allPeers()
        var loaded: [String: LibraryGrant] = [:]
        for peer in trustedPeers {
            loaded[peer.id] = await trust.grant(forPeerId: peer.id) ?? .askPerGame
        }
        grants = loaded
    }

    func setGrant(_ grant: LibraryGrant, for peer: TrustedPeer) {
        Task {
            await trust.setGrant(grant, forPeerId: peer.id)
            if grant == .denied { await host?.revoke(peerId: peer.id) }
            await refreshTrust()
        }
    }

    func remove(_ peer: TrustedPeer) {
        Task {
            await trust.remove(peerId: peer.id)
            await host?.revoke(peerId: peer.id)
            await refreshTrust()
        }
    }
}

// MARK: - The library, from Realm

/// Reads shareable games from Realm per request: Dreamcast-family and
/// GameCube/Wii games whose files are on this device, minus the systems the
/// owner turned off. Primary file first, then related files (GDI tracks,
/// cue/bin sets) with their path relative to the primary's folder.
final class RealmSharedLibrary: SharedLibraryProviding, @unchecked Sendable {
    private let lock = NSLock()
    /// Game id → artwork cache key, from the last `sharedGames()`.
    private var artKeys: [String: String] = [:]

    func sharedGames() async -> [SharedGame] {
        let excluded = Set(UserDefaults.standard.stringArray(forKey: LibrarySharingService.Keys.excludedSystems) ?? [])
        let systems = ServedDialect.allCases.flatMap(\.systems).map(\.rawValue).filter { !excluded.contains($0) }
        let (games, keys) = await Task.detached(priority: .userInitiated) { Self.read(systems: systems) }.value
        lock.withLock { artKeys = keys }
        return games
    }

    func artwork(forGameId id: String) async -> Data? {
        guard let key = lock.withLock({ artKeys[id] }), let url = PVMediaCache.filePath(forKey: key) else { return nil }
        return try? Data(contentsOf: url)
    }

    private static func read(systems: [String]) -> ([SharedGame], [String: String]) {
        guard let realm = try? Realm(configuration: RealmConfiguration.realmConfig) else { return ([], [:]) }
        var games: [SharedGame] = []
        var keys: [String: String] = [:]
        let rows = realm.objects(PVGame.self).filter("systemIdentifier IN %@ AND isHiddenPatchVariant == false", systems)
        for game in rows {
            guard let system = SystemIdentifier(rawValue: game.systemIdentifier),
                  let primary = game.file?.url, FileManager.default.fileExists(atPath: primary.path) else { continue }
            let folder = primary.deletingLastPathComponent()
            var files = [file(primary, in: folder)]
            for related in game.relatedFiles {
                guard let url = related.url, url != primary, FileManager.default.fileExists(atPath: url.path) else { continue }
                files.append(file(url, in: folder))
            }
            let artKey = [game.customArtworkURL, game.originalArtworkURL].first { !$0.isEmpty && PVMediaCache.fileExists(forKey: $0) }
            if let artKey { keys[game.md5Hash] = artKey }
            games.append(SharedGame(
                id: game.md5Hash, title: game.title, system: system, md5: game.md5Hash,
                serial: game.romSerial, files: files, hasArtwork: artKey != nil
            ))
        }
        return (games, keys)
    }

    private static func file(_ url: URL, in folder: URL) -> SharedFile {
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
        let base = folder.standardizedFileURL.path + "/"
        let path = url.standardizedFileURL.path
        let relative = path.hasPrefix(base) ? String(path.dropFirst(base.count)) : url.lastPathComponent
        return SharedFile(url: url, relativePath: relative, size: size)
    }
}

// MARK: - Owner prompts

/// Asks the owner with an alert on top of whatever is on screen: requests can
/// arrive anywhere in the app, not only in Settings.
struct HostPromptPresenter: LibraryHostApproving {
    func approveBrowse(peerName: String, app: PeerApp) async -> BrowseConsent {
        await ask(
            title: "\(peerName) wants to browse your library",
            message: "\(app.displayName) on that device will see the games it can play.",
            choices: [
                ("Share Everything", .default, BrowseConsent.shareEverything),
                ("Ask for Each Game", .default, .askPerGame),
                ("Don't Share", .cancel, .dontShare)
            ],
            fallback: .dontShare
        )
    }

    func approvePairing(peerName: String, code: String) async -> Bool {
        await ask(
            title: "Pair with \(peerName)?",
            message: "Enter this code on \(peerName):\n\n\(code)",
            choices: [("Allow", .default, true), ("Don't Allow", .cancel, false)],
            fallback: false
        )
    }

    func approvePull(peerName: String, gameTitle: String) async -> PullConsent {
        await ask(
            title: "\(peerName) wants to copy \(gameTitle)",
            message: "BIOS files and saves are never sent.",
            choices: [
                ("Allow", .default, PullConsent.allowOnce),
                ("Always Allow This Device", .default, .allowAlways),
                ("Don't Allow", .cancel, .denyOnce),
                ("Never Allow This Device", .destructive, .denyAlways)
            ],
            fallback: .denyOnce
        )
    }

    @MainActor
    private func ask<T: Sendable>(
        title: String,
        message: String,
        choices: [(String, UIAlertAction.Style, T)],
        fallback: T
    ) async -> T {
        guard let presenter = Self.topViewController() else { return fallback }
        return await withCheckedContinuation { continuation in
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            for (label, style, value) in choices {
                alert.addAction(UIAlertAction(title: label, style: style) { _ in continuation.resume(returning: value) })
            }
            presenter.present(alert, animated: true)
        }
    }

    @MainActor
    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        var top = scenes.first { $0.activationState == .foregroundActive }?.keyWindow?.rootViewController
            ?? scenes.first?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}
#endif
