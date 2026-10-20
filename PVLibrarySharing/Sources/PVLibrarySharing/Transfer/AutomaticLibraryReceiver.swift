import Foundation

/// Schedules additive copies from explicitly enabled, paired foreground peers.
/// The app supplies verified import and local-presence checks; no protocol or
/// library-file ownership lives in this scheduler.
@MainActor
public final class AutomaticLibraryReceiver {
    public struct Entry: Hashable, Sendable {
        public let id: String
        public init(id: String) { self.id = id }
    }

    public enum State: Equatable, Sendable {
        case disabled
        case waiting
        case checking(peerID: String)
        case copying(peerID: String, entryID: String)
        case upToDate
        case failed(peerID: String, message: String)
    }

    public typealias Cancellation = @MainActor () -> Void
    public typealias Scheduler = @MainActor (TimeInterval, @escaping @MainActor () -> Void) -> Cancellation

    public private(set) var enabledPeerIDs: Set<String> = []
    public private(set) var state: State = .disabled { didSet { onChange?() } }
    public var onChange: (@MainActor () -> Void)?

    private let catalog: @MainActor (String) async throws -> [Entry]
    private let receive: @MainActor (String, Entry) async throws -> Void
    private let cancel: Cancellation
    private let isTrusted: @MainActor (String) -> Bool
    private let isDiscovered: @MainActor (String) -> Bool
    private let isActive: @MainActor () -> Bool
    private let isEmulating: @MainActor () -> Bool
    private let isPresent: @MainActor (String, Entry) -> Bool
    private let schedule: Scheduler
    private var task: Task<Void, Never>?
    private var timerCancellation: Cancellation?
    private var generation: UInt64 = 0
    private var runningGeneration: UInt64?
    private var currentPeer: String?
    private var stopped = false
    private static let pollInterval: TimeInterval = 60

    public init(
        catalog: @escaping @MainActor (String) async throws -> [Entry],
        receive: @escaping @MainActor (String, Entry) async throws -> Void,
        cancel: @escaping Cancellation,
        isTrusted: @escaping @MainActor (String) -> Bool,
        isDiscovered: @escaping @MainActor (String) -> Bool,
        isActive: @escaping @MainActor () -> Bool,
        isEmulating: @escaping @MainActor () -> Bool,
        isPresent: @escaping @MainActor (String, Entry) -> Bool,
        schedule: @escaping Scheduler
    ) {
        self.catalog = catalog
        self.receive = receive
        self.cancel = cancel
        self.isTrusted = isTrusted
        self.isDiscovered = isDiscovered
        self.isActive = isActive
        self.isEmulating = isEmulating
        self.isPresent = isPresent
        self.schedule = schedule
    }

    public func setEnabled(_ enabled: Bool, for peerID: String) {
        guard !peerID.isEmpty else { return }
        if enabled && !isTrusted(peerID) { return }
        if enabled { enabledPeerIDs.insert(peerID) } else { enabledPeerIDs.remove(peerID) }
        stopped = false
        reconcile()
        onChange?()
    }

    public func environmentChanged() {
        stopped = false
        reconcile()
    }

    public func retry() {
        stopped = false
        if case .failed = state { state = .waiting }
        reconcile()
    }

    public func stop() {
        stopped = true
        invalidate()
        state = enabledPeerIDs.isEmpty ? .disabled : .waiting
    }

    private func eligible(_ id: String) -> Bool {
        !stopped && isActive() && !isEmulating() && enabledPeerIDs.contains(id) && isTrusted(id) && isDiscovered(id)
    }

    private func invalidate() {
        timerCancellation?()
        timerCancellation = nil
        if task != nil, runningGeneration == generation {
            generation &+= 1
            task?.cancel()
            cancel()
        } else if task == nil {
            generation &+= 1
        }
    }

    private func reconcile() {
        let trusted = enabledPeerIDs.filter(isTrusted)
        if trusted != enabledPeerIDs {
            enabledPeerIDs = trusted
            onChange?()
        }
        let peers = enabledPeerIDs.filter(eligible).sorted()
        if peers.isEmpty || (currentPeer.map { !eligible($0) } ?? false) {
            invalidate()
            state = enabledPeerIDs.isEmpty ? .disabled : .waiting
        }
        guard !peers.isEmpty, !stopped, task == nil else { return }
        if case .failed = state { return }
        timerCancellation?()
        timerCancellation = nil
        let token = generation
        runningGeneration = token
        currentPeer = peers.first
        state = .checking(peerID: peers[0])
        task = Task { [weak self] in
            guard let self else { return }
            await self.run(peers, token: token)
            self.finished(token: token)
        }
    }

    private func run(_ peers: [String], token: UInt64) async {
        var lastFailure: State?
        for peer in peers {
            guard token == generation, !Task.isCancelled else { return }
            guard eligible(peer) else { continue }
            currentPeer = peer
            state = .checking(peerID: peer)
            do {
                let entries = try await catalog(peer)
                guard token == generation, eligible(peer), !Task.isCancelled else { return }
                var seen: Set<String> = []
                for entry in entries where !entry.id.isEmpty && seen.insert(entry.id).inserted {
                    guard token == generation, eligible(peer), !Task.isCancelled else { return }
                    if isPresent(peer, entry) { continue }
                    state = .copying(peerID: peer, entryID: entry.id)
                    do {
                        try await receive(peer, entry)
                    } catch {
                        guard token == generation, eligible(peer), !Task.isCancelled else { return }
                        // A blocked game must not prevent other additions. Retain
                        // the failure for the owner after the remaining entries run.
                        lastFailure = .failed(peerID: peer, message: error.localizedDescription)
                    }
                    guard token == generation, eligible(peer), !Task.isCancelled else { return }
                }
            } catch {
                guard token == generation, eligible(peer), !Task.isCancelled else { return }
                lastFailure = .failed(peerID: peer, message: error.localizedDescription)
            }
        }
        guard token == generation, !Task.isCancelled else { return }
        state = lastFailure ?? .upToDate
    }

    private func finished(token: UInt64) {
        task = nil
        runningGeneration = nil
        currentPeer = nil
        if token != generation {
            // Retain cancelled work until it exits, even when a delegate
            // ignores cancellation. A replacement must never overlap it.
            if !stopped { reconcile() }
            return
        }
        guard !stopped, enabledPeerIDs.contains(where: eligible) else { return }
        if case .failed = state { return }
        timerCancellation = schedule(Self.pollInterval) { [weak self] in
            guard let self, token == self.generation else { return }
            self.timerCancellation = nil
            self.reconcile()
        }
    }
}
