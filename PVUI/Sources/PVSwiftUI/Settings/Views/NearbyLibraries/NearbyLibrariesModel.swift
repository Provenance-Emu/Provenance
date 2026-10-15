//
//  NearbyLibrariesModel.swift
//  PVSwiftUI
//
//  State for Settings › Library › Nearby Libraries: Bonjour discovery of iFly
//  and iCube libraries, one browse model per opened peer, and copying a game
//  into the local library (phases 1-2 of
//  docs/superpowers/specs/2026-10-14-cross-app-library-sharing-design.md).
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
    /// Copies land here before the importer moves them into the library.
    /// App Caches, not `Imports/`: that folder is watched (see `LibraryStaging`).
    @ObservationIgnored let staging = LibraryStaging(
        root: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LibrarySharing/Incoming", isDirectory: true)
    )
    @ObservationIgnored private var browseTask: Task<Void, Never>?
    @ObservationIgnored private var peerModels: [String: NearbyPeerLibraryModel] = [:]
    /// Loaded on first use, not in `init`: the Keychain is only touched when a peer is opened.
    @ObservationIgnored private var loadedIdentity: PeerIdentity?
    var identity: PeerIdentity {
        if let loadedIdentity { return loadedIdentity }
        // Name Provenance so the iFly/iCube owner knows which app is asking.
        let created = KeychainPeerIdentityStore().loadOrCreate(name: "Provenance on \(UIDevice.current.name)")
        loadedIdentity = created
        return created
    }

    init() {}

    /// This device's own peer id: with Share This Library on, its own adverts
    /// show up in the browse and must be left out.
    private(set) var ownPeerId: String?

    /// Peers worth listing: libraries whose app serves a system Provenance
    /// plays, never this device itself.
    var visiblePeers: [DiscoveredPeer] {
        snapshot.peers.filter { peer in
            peer.advertisement.peerId != ownPeerId
                && !SystemMap.systems(servedBy: peer.app).isDisjoint(with: playableSystems)
                // v1.1 `sys`: hide a peer that says it has nothing this device plays.
                && peer.advertisement.mayServe(playableSystems)
        }
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
        ownPeerId = identity.id
        loadLocalLibrary()
        let staging = staging
        Task.detached(priority: .utility) { staging.sweep() }
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
                // A system is playable only with a core that can actually launch:
                // enabled, and its class or bundled libretro dylib present. Lite
                // builds carry rows for cores they do not ship.
                .filter { system in system.cores.contains { !$0.disabled && $0.hasCoreClass } }
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

/// Where one copy stands, for its row.
enum NearbyCopyState: Equatable {
    case preparing(LibraryBrowseProgress)
    /// 0...1 over the game's files.
    case downloading(Double)
    case verifying
    /// The importer has the files; the game appears in the library once it's done.
    case importing
    case failed(String)

    var isActive: Bool {
        switch self {
        case .preparing, .downloading, .verifying: return true
        case .importing, .failed: return false
        }
    }
}

/// Browsing one peer: auth or pairing, catalogue, art, copies.
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
    /// Copies started from this peer, by item id.
    private(set) var copies: [String: NearbyCopyState] = [:]

    @ObservationIgnored private weak var owner: NearbyLibrariesModel?
    @ObservationIgnored private var copyTasks: [String: Task<Void, Never>] = [:]
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
        case .pvLibrary:
            // Ask only for what this device plays; the source filters locally too.
            source = PVLibrarySource(baseURLs: peer.baseURLs, identity: owner.identity, systems: owner.playableSystems)
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

    // MARK: - Copy

    /// Copies `item` into staging, verified, then hands every game file to the
    /// importer with the mapped system. Tapping again after a failure resumes
    /// from the partial files and the cached pull manifest.
    func copy(_ item: RemoteLibraryItem) {
        guard copyTasks[item.id] == nil, let owner, let system = item.systemIdentifier else { return }
        let puller = LibraryPuller(staging: owner.staging, peerKey: peer.id)
        let staging = owner.staging
        let source = source
        copies[item.id] = .preparing(.connecting)
        copyTasks[item.id] = Task { [weak self] in
            do {
                let pulled = try await puller.pull(item, from: source) { progress in
                    Task { @MainActor in self?.update(item.id, with: progress) }
                }
                if !pulled.skippedKinds.isEmpty {
                    ILOG("Nearby Libraries: \(item.title): left \(pulled.skippedKinds.joined(separator: ", ")) on the other device")
                }
                await GameImporter.shared.addImports(forPaths: pulled.gameFiles, targetSystem: system)
                GameImporter.shared.startProcessing()
                staging.markHandedOff(pulled.folder)
                self?.copies[item.id] = .importing
            } catch is CancellationError {
                self?.copies[item.id] = nil
            } catch {
                WLOG("Nearby Libraries: copying \(item.title) from \(self?.peer.serviceName ?? "?") failed: \(error)")
                self?.copies[item.id] = .failed(error.localizedDescription)
            }
            self?.copyTasks[item.id] = nil
        }
    }

    /// Stops a copy. Its partial files stay, so copying again resumes.
    func cancelCopy(_ item: RemoteLibraryItem) {
        copyTasks[item.id]?.cancel()
    }

    private func update(_ itemId: String, with progress: LibraryPullProgress) {
        guard copies[itemId]?.isActive == true else { return }
        switch progress {
        case .preparing(let step):
            copies[itemId] = .preparing(step)
        case let .downloading(_, _, _, done, total):
            copies[itemId] = .downloading(total > 0 ? Double(done) / Double(total) : 0)
        case .verifying:
            copies[itemId] = .verifying
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
