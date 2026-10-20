#if os(iOS) || os(tvOS)
import Combine
import Foundation
import Observation
import PVFeatureFlags
import PVLibrary
import PVLibrarySharing
import PVRealm
import PVSystems
import PVUIBase
import RealmSwift
import SwiftUI
import UIKit

/// Nearby, additive ROM copying. Subscriptions are bound to paired cryptographic IDs,
/// never service names or IP addresses; unlinking a source never deletes local games.
@MainActor @Observable final class NearbyLibraryAutomaticService {
    static let shared = NearbyLibraryAutomaticService()
    private static let enabledKey = "LibrarySharing.automaticICubePeers"
    private(set) var state: AutomaticLibraryReceiver.State = .disabled
    private(set) var enabledPeerIDs: Set<String> = []
    private(set) var discoveryProblem: String?
    @ObservationIgnored private var restoredSubscriptions = false
    @ObservationIgnored private var active = true
    @ObservationIgnored private var emulating = false
    @ObservationIgnored private var booted = false
    @ObservationIgnored private var trustedIDs: Set<String> = []
    @ObservationIgnored private var peers: [String: DiscoveredPeer] = [:]
    @ObservationIgnored private let browser = PeerBrowser(apps: [.iCube])
    @ObservationIgnored private var browseTask: Task<Void, Never>?
    @ObservationIgnored private var observations: Set<AnyCancellable> = []
    @ObservationIgnored private var sources: [String: ICubeContinuitySource] = [:]
    @ObservationIgnored private var items: [String: [String: RemoteLibraryItem]] = [:]
    @ObservationIgnored private var manifests: [String: [String: RemoteManifest]] = [:]
    @ObservationIgnored private var receipts: [String: NearbyLibraryReceipt] = [:]
    @ObservationIgnored private let staging = LibraryStaging(root: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("LibrarySharing/Incoming", isDirectory: true))
    @ObservationIgnored private lazy var identity = KeychainPeerIdentityStore().loadOrCreate(name: "Provenance on \(UIDevice.current.name)")
    @ObservationIgnored private lazy var receiver = AutomaticLibraryReceiver(
        catalog: { [weak self] id in try await self?.catalog(id) ?? [] },
        receive: { [weak self] id, entry in try await self?.receive(id, entry: entry) },
        cancel: {},
        isTrusted: { [weak self] in self?.trustedIDs.contains($0) == true },
        isDiscovered: { [weak self] in self?.peers[$0] != nil },
        isActive: { [weak self] in self?.canRun == true },
        isEmulating: { [weak self] in self?.emulating != false },
        isPresent: { [weak self] id, entry in self?.isPresent(id, entry: entry) == true },
        schedule: { delay, action in
            let task = Task { @MainActor in
                do { try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)); action() } catch {}
            }
            return { task.cancel() }
        })

    private var receiptsURL: URL { LibrarySharingService.supportFolder.appendingPathComponent("automatic-receipts.json") }
    private var canRun: Bool { active && booted && !emulating && PVFeatureFlags.shared.isEnabled(.nearbyLibraries) && !GameImporter.shared.isPausedForEmulation }

    private init() {
        let savedPeerIDs = UserDefaults.standard.stringArray(forKey: Self.enabledKey) ?? []
        if let data = try? Data(contentsOf: receiptsURL) { receipts = (try? JSONDecoder().decode([String: NearbyLibraryReceipt].self, from: data)) ?? [:] }
        receiver.onChange = { [weak self] in
            guard let self else { return }
            state = receiver.state
            enabledPeerIDs = receiver.enabledPeerIDs
            if restoredSubscriptions { UserDefaults.standard.set(Array(enabledPeerIDs), forKey: Self.enabledKey) }
        }
        AppState.shared.$emulationUIState.sink { [weak self] value in
            let isPlaying = value.currentGame != nil
            Task { @MainActor in self?.emulating = isPlaying; self?.environmentChanged() }
        }.store(in: &observations)
        AppState.shared.bootupStateManager.$isBootupCompleted.sink { [weak self] value in
            Task { @MainActor in self?.booted = value; self?.environmentChanged() }
        }.store(in: &observations)
        PVFeatureFlags.shared.stateDidChange.sink { [weak self] _ in
            Task { @MainActor in self?.environmentChanged() }
        }.store(in: &observations)
        Task {
            await LibrarySharingService.shared.refreshTrust()
            for id in savedPeerIDs { receiver.setEnabled(true, for: id) }
            restoredSubscriptions = true
            UserDefaults.standard.set(Array(receiver.enabledPeerIDs), forKey: Self.enabledKey)
            environmentChanged()
        }
    }

    func trustChanged(_ trusted: [TrustedPeer]) {
        trustedIDs = Set(trusted.filter { $0.app == PeerApp.iCube.rawValue }.map(\.id))
        environmentChanged()
    }

    func sceneChanged(_ phase: ScenePhase) { active = phase == .active; environmentChanged() }
    func setEnabled(_ value: Bool, peerID: String) { receiver.setEnabled(value, for: peerID); environmentChanged() }
    func retry() { receiver.retry(); environmentChanged() }
    func stopAll() { for id in receiver.enabledPeerIDs { receiver.setEnabled(false, for: id) }; environmentChanged() }

    private func environmentChanged() {
        if canRun && !receiver.enabledPeerIDs.isEmpty {
            if browseTask == nil {
                let stream = browser.snapshots()
                browseTask = Task { [weak self] in
                    for await snapshot in stream {
                        guard let self else { return }
                        peers = Dictionary(snapshot.peers.compactMap { peer in
                            peer.advertisement.peerId.map { ($0, peer) }
                        }, uniquingKeysWith: { first, _ in first })
                        switch snapshot.states[.iCube] {
                        case .failed(let message): discoveryProblem = message
                        case .waiting(let message, _): discoveryProblem = message
                        default: discoveryProblem = nil
                        }
                        receiver.environmentChanged()
                    }
                }
            }
        } else {
            browseTask?.cancel(); browseTask = nil; browser.stop(); peers = [:]
        }
        receiver.environmentChanged()
    }

    private func catalog(_ id: String) async throws -> [AutomaticLibraryReceiver.Entry] {
        guard canRun, trustedIDs.contains(id), let peer = peers[id] else { throw CancellationError() }
        let source = ICubeContinuitySource(baseURLs: peer.baseURLs, identity: identity, expectedPeerID: id)
        sources[id] = source
        let catalogue = try await source.catalogue { _ in }
        let realm = try Realm(configuration: RealmConfiguration.realmConfig)
        let playable = Set(realm.objects(PVSystem.self).filter { $0.cores.contains { !$0.disabled && $0.hasCoreClass } }.map(\.identifier))
        var offered: [String: RemoteLibraryItem] = [:]
        var fresh: [String: RemoteManifest] = [:]
        for item in catalogue.items where item.systemIdentifier.map({ playable.contains($0.rawValue) }) == true {
            try Task.checkCancellation()
            let manifest = try await source.pullManifest(for: item) { _ in }
            guard manifest.itemId == item.id, manifest.gameFiles.count == 1 else { continue }
            offered[item.id] = item; fresh[item.id] = manifest
        }
        items[id] = offered; manifests[id] = fresh
        return offered.keys.sorted().map { .init(id: $0) }
    }

    private func isPresent(_ id: String, entry: AutomaticLibraryReceiver.Entry) -> Bool {
        guard let manifest = manifests[id]?[entry.id] else { return false }
        return receipts[receiptKey(id, entry.id)]?.isPresent(manifest: manifest) == true
    }

    private func receive(_ id: String, entry: AutomaticLibraryReceiver.Entry) async throws {
        guard canRun, trustedIDs.contains(id), let source = sources[id],
              let item = items[id]?[entry.id], let manifest = manifests[id]?[entry.id] else { throw CancellationError() }
        let receipt = try await NearbyLibraryReceiveService.receive(item, source: source, peerKey: "icube:" + id, staging: staging, manifest: manifest) { _ in }
        try Task.checkCancellation()
        receipts[receiptKey(id, entry.id)] = receipt
        try FileManager.default.createDirectory(at: LibrarySharingService.supportFolder, withIntermediateDirectories: true)
        try JSONEncoder().encode(receipts).write(to: receiptsURL, options: .atomic)
    }
    private func receiptKey(_ id: String, _ item: String) -> String { id + "|" + item }
}
#endif
