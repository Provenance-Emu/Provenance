//
//  LibrarySharingService.swift
//  PVSwiftUI
//
//  "Share this library": serves Provenance's games to nearby iFly and iCube
//  devices (phase 3 of
//  docs/superpowers/specs/2026-10-14-cross-app-library-sharing-design.md).
//

#if os(iOS) || os(tvOS)
import Combine
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
    @ObservationIgnored private var flagObserver: AnyCancellable?
    @ObservationIgnored let trust = FileHostTrustStore(fileURL: LibrarySharingService.supportFolder.appendingPathComponent("trusted-peers.json"))

    static var supportFolder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LibrarySharing", isDirectory: true)
    }

    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: Keys.enabled)
        excludedSystems = Set(UserDefaults.standard.stringArray(forKey: Keys.excludedSystems) ?? [])
        // Turning the flag on or off (Feature Flags screen, remote config)
        // starts or stops a saved "Share This Library" at once, not at the
        // next trip through the background.
        flagObserver = PVFeatureFlags.shared.stateDidChange
            .map { _ in PVFeatureFlags.shared.isEnabled(.nearbyLibraries) }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { await self?.apply() }
            }
    }

    /// Systems with at least one game in the library, for the settings list.
    /// `_pvlibrary` serves all of them; iFly and iCube see only their own.
    private(set) var librarySystems: [SystemIdentifier] = []

    func loadLibrarySystems() async {
        librarySystems = await Task.detached(priority: .userInitiated) { () -> [SystemIdentifier] in
            guard let realm = try? Realm(configuration: RealmConfiguration.realmConfig) else { return [] }
            let ids = Set(realm.objects(PVGame.self).distinct(by: ["systemIdentifier"]).map(\.systemIdentifier))
            return ids.compactMap(SystemIdentifier.init(rawValue:)).sorted()
        }.value
    }

    // MARK: - Lifecycle

    /// Called from the app's scene-phase handler. Only `.background` stops
    /// the listeners: `.inactive` also covers the Local Network permission
    /// alert that the first listener start raises, and Control Center, and
    /// stopping there would churn the host.
    public static func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            shared.appActive = true
        case .background:
            #if os(iOS)
            shared.appActive = false
            #endif
        default:
            return
        }
        Task { await shared.apply() }
    }

    private var shouldRun: Bool {
        // The engine, not PVFeatureFlagsManager: the manager's copy updates on
        // its own main-queue hop, possibly after this one.
        isEnabled && appActive && PVFeatureFlags.shared.isEnabled(.nearbyLibraries)
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

/// Reads shareable games from Realm (cached briefly): every game whose files
/// are on this device, minus the systems the owner turned off. Each dialect
/// then lists only its own systems. Primary file first, then related files (GDI tracks,
/// cue/bin sets) with their path relative to the primary's folder.
final class RealmSharedLibrary: SharedLibraryProviding, @unchecked Sendable {
    /// How long one read of the library serves catalogue, art and file
    /// requests. A browse fires one art request per visible row; re-reading
    /// Realm and stat-ing every file for each would be wasteful.
    static let snapshotLifetime: TimeInterval = 30

    private struct Snapshot {
        let excluded: Set<String>
        let games: [SharedGame]
        let artKeys: [String: String]
        let takenAt: Date
    }

    private let lock = NSLock()
    private var snapshot: Snapshot?

    func sharedGames() async -> [SharedGame] {
        await current().games
    }

    func artwork(forGameId id: String) async -> Data? {
        guard let key = await current().artKeys[id], let url = PVMediaCache.filePath(forKey: key) else { return nil }
        return try? Data(contentsOf: url)
    }

    private func current() async -> Snapshot {
        let excluded = Set(UserDefaults.standard.stringArray(forKey: LibrarySharingService.Keys.excludedSystems) ?? [])
        if let cached = lock.withLock({ snapshot }), cached.excluded == excluded,
           Date().timeIntervalSince(cached.takenAt) < Self.snapshotLifetime {
            return cached
        }
        let (games, keys) = await Task.detached(priority: .userInitiated) { Self.read(excluding: Array(excluded)) }.value
        let fresh = Snapshot(excluded: excluded, games: games, artKeys: keys, takenAt: Date())
        lock.withLock { snapshot = fresh }
        return fresh
    }

    private static func read(excluding excluded: [String]) -> ([SharedGame], [String: String]) {
        guard let realm = try? Realm(configuration: RealmConfiguration.realmConfig) else { return ([], [:]) }
        var games: [SharedGame] = []
        var keys: [String: String] = [:]
        let rows = realm.objects(PVGame.self).filter("NOT (systemIdentifier IN %@) AND isHiddenPatchVariant == false", excluded)
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

    /// A little under the servers' 120 s approval window, so the alert goes
    /// away before the peer is told "no".
    static let promptTimeout: TimeInterval = 115

    /// One alert at a time: a prompt that arrives while another is up waits
    /// its turn instead of failing to present.
    @MainActor private static var showing = false
    @MainActor private static var waiting: [CheckedContinuation<Void, Never>] = []

    @MainActor
    private func ask<T: Sendable>(
        title: String,
        message: String,
        choices: [(String, UIAlertAction.Style, T)],
        fallback: T
    ) async -> T {
        if Self.showing {
            await withCheckedContinuation { Self.waiting.append($0) }
        }
        Self.showing = true
        defer {
            if Self.waiting.isEmpty {
                Self.showing = false
            } else {
                Self.waiting.removeFirst().resume()
            }
        }
        guard let presenter = Self.topViewController() else { return fallback }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        return await withCheckedContinuation { (continuation: CheckedContinuation<T, Never>) in
            var answered = false
            let answer: (T) -> Void = { value in
                guard !answered else { return }
                answered = true
                continuation.resume(returning: value)
            }
            for (label, style, value) in choices {
                alert.addAction(UIAlertAction(title: label, style: style) { _ in answer(value) })
            }
            presenter.present(alert, animated: true)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(Self.promptTimeout * 1_000_000_000))
                guard !answered else { return }
                alert.dismiss(animated: true)
                answer(fallback)
            }
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
