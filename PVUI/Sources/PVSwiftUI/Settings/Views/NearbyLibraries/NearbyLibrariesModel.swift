//
//  NearbyLibrariesModel.swift
//  PVSwiftUI
//
//  State for Settings › Library › Nearby Libraries: Bonjour discovery of iFly
//  and iCube libraries plus one browse model per opened peer. Read-only (phase
//  1 of docs/superpowers/specs/2026-10-14-cross-app-library-sharing-design.md).
//

#if os(iOS) || os(tvOS)
import Foundation
import Observation
import PVLibrary
import PVLibrarySharing
import PVLogging
import PVRealm
import PVSystems
import RealmSwift
import UIKit

/// Discovery plus the shared pieces every peer browse needs.
@MainActor
@Observable
final class NearbyLibrariesModel {
    private(set) var snapshot = PeerBrowserSnapshot()
    /// Systems Provenance has a core for; peers and items outside it are hidden.
    private(set) var playableSystems: Set<SystemIdentifier> = []
    private(set) var localIndex = LocalLibraryIndex(entries: [])
    /// "N systems · M games" once a peer's catalogue has been loaded, keyed by peer id.
    private(set) var loadedSummaries: [String: String] = [:]

    @ObservationIgnored private let browser = PeerBrowser()
    @ObservationIgnored private var browseTask: Task<Void, Never>?
    @ObservationIgnored private var peerModels: [String: NearbyPeerLibraryModel] = [:]
    @ObservationIgnored let identity: PeerIdentity

    init() {
        // Name Provenance so the iFly/iCube owner knows which app is asking.
        identity = KeychainPeerIdentityStore().loadOrCreate(name: "Provenance on \(UIDevice.current.name)")
    }

    /// Peers worth listing: libraries whose app serves a system Provenance plays.
    var visiblePeers: [DiscoveredPeer] {
        snapshot.peers.filter { !SystemMap.systems(servedBy: $0.app).isDisjoint(with: playableSystems) }
    }

    /// Browse failures per app, for the status footer. An empty list with a
    /// failed `_icube-continuity._tcp` browse must not look like "no peers".
    var browseProblems: [BrowseProblem] {
        PeerApp.allCases.compactMap { app in
            switch snapshot.states[app] {
            case .failed(let reason):
                return BrowseProblem(app: app, message: "Couldn't search for \(app.displayName) libraries: \(reason)")
            case .waiting(let reason, let denied) where !denied:
                return BrowseProblem(app: app, message: "Waiting to search for \(app.displayName) libraries: \(reason)")
            default:
                return nil
            }
        }
    }

    struct BrowseProblem: Identifiable {
        let app: PeerApp
        let message: String
        var id: PeerApp { app }
    }

    func start() {
        guard browseTask == nil else { return }
        loadLocalLibrary()
        let stream = browser.snapshots()
        browseTask = Task { [weak self] in
            for await snapshot in stream {
                self?.snapshot = snapshot
            }
        }
    }

    func stop() {
        browseTask?.cancel()
        browseTask = nil
        browser.stop()
    }

    /// One browse model per peer, kept so returning to a peer reuses its
    /// token, cached catalogue and art.
    func peerModel(for peer: DiscoveredPeer) -> NearbyPeerLibraryModel {
        if let existing = peerModels[peer.id] { return existing }
        let model = NearbyPeerLibraryModel(peer: peer, owner: self)
        peerModels[peer.id] = model
        return model
    }

    func didLoad(_ catalogue: RemoteCatalogue, for peer: DiscoveredPeer) {
        let systems = catalogue.systems.filter(playableSystems.contains).count
        let games = catalogue.filtered(to: playableSystems).items.count
        loadedSummaries[peer.id] = "\(systems) system\(systems == 1 ? "" : "s") · \(games) game\(games == 1 ? "" : "s")"
    }

    func isInLibrary(_ item: RemoteLibraryItem) -> Bool {
        localIndex.contains(item)
    }

    // MARK: - Local library

    /// Reads which systems have a core and the MD5s of the games on the
    /// systems peers can serve. Single-file images only: Provenance hashes the
    /// cue/m3u/gdi text of CD sets, which never matches a peer's MD5.
    private func loadLocalLibrary() {
        do {
            let realm = try Realm(configuration: RealmConfiguration.realmConfig)
            playableSystems = Set(realm.objects(PVSystem.self)
                .filter { !$0.cores.isEmpty }
                .compactMap { SystemIdentifier(rawValue: $0.identifier) })

            let shareable = PeerApp.allCases.reduce(into: Set<SystemIdentifier>()) {
                $0.formUnion(SystemMap.systems(servedBy: $1))
            }
            let ids = shareable.map(\.rawValue)
            let entries: [LocalLibraryEntry] = realm.objects(PVGame.self)
                .filter("systemIdentifier IN %@", ids)
                .compactMap { game in
                    guard let system = SystemIdentifier(rawValue: game.systemIdentifier), !game.md5Hash.isEmpty else {
                        return nil
                    }
                    return LocalLibraryEntry(
                        md5: game.md5Hash,
                        systemIdentifier: system,
                        sizeBytes: Int64(game.fileSize),
                        isSingleFileImage: LocalLibraryEntry.isSingleFileImage(
                            primaryFileExtension: (game.romPath as NSString).pathExtension,
                            relatedFileCount: game.relatedFiles.count
                        )
                    )
                }
            localIndex = LocalLibraryIndex(entries: entries)
        } catch {
            ELOG("Nearby Libraries: couldn't read the local library: \(error)")
        }
    }
}

/// Browsing one peer: auth or pairing, catalogue, art.
@MainActor
@Observable
final class NearbyPeerLibraryModel {
    enum Phase: Equatable {
        case idle
        case loading(LibraryBrowseProgress)
        case loaded
        /// iCube: this device isn't paired. Offer to show a code on the iCube device.
        case needsPairing
        /// iCube: the code is on the other screen; waiting for the user to type it.
        case enteringCode(ICubePairingHandle)
        case confirmingCode
        case failed(String)
    }

    let peer: DiscoveredPeer
    private(set) var phase: Phase = .idle
    private(set) var catalogue: RemoteCatalogue?
    /// Set when a code entry was rejected, shown under the code field.
    private(set) var codeError: String?
    private(set) var artwork: [String: UIImage] = [:]

    @ObservationIgnored private weak var owner: NearbyLibrariesModel?
    @ObservationIgnored private let source: any LibrarySource
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var pairedThisSession = false
    @ObservationIgnored private var artRequested: Set<String> = []

    init(peer: DiscoveredPeer, owner: NearbyLibrariesModel) {
        self.peer = peer
        self.owner = owner
        switch peer.app {
        case .iFly:
            source = IFlyContinuitySource(baseURLs: peer.baseURLs, identity: owner.identity)
        case .iCube:
            source = ICubeContinuitySource(baseURLs: peer.baseURLs, identity: owner.identity)
        }
    }

    var title: String { catalogue?.deviceName ?? peer.serviceName }

    struct SystemSection: Identifiable {
        let system: SystemIdentifier
        let items: [RemoteLibraryItem]
        var id: SystemIdentifier { system }
    }

    /// Supported items grouped by system, in system order.
    var sections: [SystemSection] {
        guard let catalogue, let owner else { return [] }
        let playable = catalogue.filtered(to: owner.playableSystems).items
        return Dictionary(grouping: playable) { $0.systemIdentifier ?? .Unknown }
            .sorted { $0.key < $1.key }
            .map { group in
                SystemSection(
                    system: group.key,
                    items: group.value.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                )
            }
    }

    /// Items on systems Provenance can't play, shown as a count only.
    var unsupportedCount: Int {
        guard let catalogue, let owner else { return 0 }
        return catalogue.items.count - catalogue.filtered(to: owner.playableSystems).items.count
    }

    func isInLibrary(_ item: RemoteLibraryItem) -> Bool {
        owner?.isInLibrary(item) ?? false
    }

    // MARK: - Browse

    func load() {
        guard loadTask == nil else { return }
        phase = .loading(.connecting)
        loadTask = Task { [weak self] in
            await self?.runLoad()
            self?.loadTask = nil
        }
    }

    /// Stops polling (consent or approval) when the view goes away.
    func cancel() {
        loadTask?.cancel()
        loadTask = nil
        if case .loading = phase { phase = .idle }
        if phase == .confirmingCode { phase = .needsPairing }
    }

    private func runLoad() async {
        do {
            let loaded = try await source.catalogue { [weak self] progress in
                Task { @MainActor in
                    guard let self, case .loading = self.phase else { return }
                    self.phase = .loading(progress)
                }
            }
            catalogue = loaded
            phase = .loaded
            owner?.didLoad(loaded, for: peer)
        } catch is CancellationError {
            return
        } catch LibrarySharingError.notPaired where peer.app == .iCube && !pairedThisSession {
            phase = .needsPairing
        } catch LibrarySharingError.notPaired {
            // Paired, yet still refused: iCube answers 403 alike for "not paired"
            // and "not sharing with you", so after a successful pairing it's the latter.
            phase = .failed("\(title) isn't sharing its library with this device. Check Library Sharing in iCube.")
        } catch {
            WLOG("Nearby Libraries: browsing \(peer.serviceName) failed: \(error)")
            phase = .failed(error.localizedDescription)
        }
    }

    // MARK: - iCube pairing

    func beginPairing() {
        guard let iCube = source as? ICubeContinuitySource else { return }
        codeError = nil
        phase = .loading(.connecting)
        loadTask = Task { [weak self] in
            do {
                let handle = try await iCube.beginPairing()
                self?.phase = .enteringCode(handle)
            } catch is CancellationError {
                return
            } catch {
                self?.phase = .failed(error.localizedDescription)
            }
            self?.loadTask = nil
        }
    }

    func submitCode(_ code: String, for handle: ICubePairingHandle) {
        guard let iCube = source as? ICubeContinuitySource else { return }
        codeError = nil
        phase = .confirmingCode
        loadTask = Task { [weak self] in
            do {
                try await iCube.completePairing(handle, code: code)
                self?.pairedThisSession = true
                self?.loadTask = nil
                self?.load()
                return
            } catch LibrarySharingError.wrongCode {
                self?.codeError = LibrarySharingError.wrongCode.localizedDescription
                self?.phase = .enteringCode(handle)
            } catch is CancellationError {
                return
            } catch {
                self?.phase = .failed(error.localizedDescription)
            }
            self?.loadTask = nil
        }
    }

    // MARK: - Art

    func loadArtwork(for item: RemoteLibraryItem) async {
        guard item.artKey != nil, artRequested.insert(item.id).inserted else { return }
        guard let data = try? await source.artwork(for: item), let image = UIImage(data: data) else { return }
        artwork[item.id] = image
    }
}
#endif
