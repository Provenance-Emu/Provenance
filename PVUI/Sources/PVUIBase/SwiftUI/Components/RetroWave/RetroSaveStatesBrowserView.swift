import SwiftUI
import RealmSwift
import PVLibrary
import PVRealm
import PVUIBase
import PVLogging
import UIKit

/// Lightweight value used for rendering save states without live Realm bindings
public struct RetroSaveStateItem: Identifiable, Hashable {
    public let id: String
    public let gameId: String
    public let gameTitle: String
    public let systemId: String
    public let systemName: String
    public let date: Date
    public let isAutosave: Bool
    public let isFavorite: Bool
    public let fileSize: Int
    public let imageURL: URL?
    public let coreName: String
    /// The core version that created this save state, if known.
    public let createdWithCoreVersion: String?
    /// The core identifier that created this save state, if known.
    public let coreIdentifier: String?
}

/// Shared store for save-state queries, thumbnail loading, and caching
public final class RetroSaveStatesStore: ObservableObject {
    public static let shared = RetroSaveStatesStore()

    @Published public private(set) var recentBySystem: [String: [RetroSaveStateItem]] = [:]
    @Published public private(set) var statesBySystem: [String: [RetroSaveStateItem]] = [:]
    @Published public private(set) var statesByGame: [String: [RetroSaveStateItem]] = [:]

    private let imageCache = NSCache<NSString, UIImage>()
    private let workQueue = DispatchQueue(label: "org.provenance.retrowave.savestates", qos: .userInitiated)

    private init() {}

    /// Preloads recent save states for the given systems
    public func prefetchRecent(systemIDs: [String], limit: Int = 8) async {
        for systemID in systemIDs {
            _ = await loadRecent(forSystemID: systemID, limit: limit)
        }
    }

    /// Loads the most recent save states for a system.
    ///
    /// Note: This is used by RetroWave/tvOS shelves and always deduplicates
    /// auto-saves (`deduplicateAutosaves: true`). The user setting
    /// `showAutoSavesInRecents` only affects the Home continue strip and is
    /// not consulted here.
    @discardableResult
    public func loadRecent(forSystemID systemID: String, limit: Int = 8) async -> [RetroSaveStateItem] {
        if let cached = await MainActor.run(body: { recentBySystem[systemID] }), !cached.isEmpty {
            return cached
        }

        let items = await fetchSaveStates(
            predicate: NSPredicate(format: "game.systemIdentifier == %@", systemID),
            limit: limit,
            deduplicateAutosaves: true // Always deduplicate autosaves for RetroWave shelves
        )

        await MainActor.run {
            recentBySystem[systemID] = items
        }

        return items
    }

    /// Invalidates the cached recent saves for a system and re-fetches from Realm
    @discardableResult
    public func reloadRecent(forSystemID systemID: String, limit: Int = 8) async -> [RetroSaveStateItem] {
        await MainActor.run { recentBySystem[systemID] = nil }
        return await loadRecent(forSystemID: systemID, limit: limit)
    }

    /// Removes a single item from all cached lists by ID (immediate UI update)
    @MainActor
    public func removeFromCache(id: String, systemID: String) {
        recentBySystem[systemID]?.removeAll { $0.id == id }
        statesBySystem[systemID]?.removeAll { $0.id == id }
        for key in statesByGame.keys {
            statesByGame[key]?.removeAll { $0.id == id }
        }
    }

    /// Loads all save states for a system
    @discardableResult
    public func loadAll(forSystemID systemID: String) async -> [RetroSaveStateItem] {
        let items = await fetchSaveStates(
            predicate: NSPredicate(format: "game.systemIdentifier == %@", systemID),
            limit: nil
        )

        await MainActor.run {
            statesBySystem[systemID] = items
        }

        return items
    }

    /// Loads all save states for a specific game
    @discardableResult
    public func loadAll(forGameID gameID: String) async -> [RetroSaveStateItem] {
        let items = await fetchSaveStates(
            predicate: NSPredicate(format: "game.id == %@", gameID),
            limit: nil
        )

        await MainActor.run {
            statesByGame[gameID] = items
        }

        return items
    }

    /// Loads recent save states across all systems
    @discardableResult
    public func loadAllRecent(limit: Int = 50) async -> [RetroSaveStateItem] {
        let predicate = NSPredicate(format: "game != nil && game.system != nil")
        return await fetchSaveStates(predicate: predicate, limit: limit, deduplicateAutosaves: true)
    }

    /// Loads recent save states filtered by multiple system IDs
    @discardableResult
    public func loadAllRecent(forSystemIDs systemIDs: Set<String>, limit: Int = 100) async -> [RetroSaveStateItem] {
        guard !systemIDs.isEmpty else {
            return await loadAllRecent(limit: limit)
        }
        let predicate = NSPredicate(format: "game != nil && game.system != nil && game.systemIdentifier IN %@", Array(systemIDs))
        return await fetchSaveStates(predicate: predicate, limit: limit, deduplicateAutosaves: true)
    }

    /// Returns all system IDs that have at least one save state
    public func systemIDsWithSaves() async -> [String] {
        await withCheckedContinuation { continuation in
            workQueue.async {
                do {
                    let realm = try Realm()
                    let results = realm.objects(PVSaveState.self)
                    let systemIDs = Set(results.compactMap { $0.game.systemIdentifier })
                    continuation.resume(returning: Array(systemIDs).sorted())
                } catch {
                    ELOG("RetroSaveStatesStore: Failed fetching system IDs with saves: \(error)")
                    continuation.resume(returning: [])
                }
            }
        }
    }

    /// Opens a save state via SceneCoordinator with proper sync validation
    public func openSaveState(id: String) async {
        await MainActor.run {
            let realm = RomDatabase.sharedInstance.realm

            // Find the save state
            guard let saveState = realm.object(ofType: PVSaveState.self, forPrimaryKey: id) else {
                ELOG("RetroSaveStatesStore: Save state not found with id: \(id)")
                Task { @MainActor in
                    SceneCoordinator.shared.alertState.show(
                        title: "Save State Not Found",
                        message: "The save state could not be found. It may have been deleted or is not available.",
                        type: .error
                    )
                }
                return
            }

            // Create frozen copy for thread safety
            let frozenSaveState = saveState.freeze()

            // Use SceneCoordinator to launch with proper sync validation
            ILOG("RetroSaveStatesStore: Launching save state via SceneCoordinator: \(id)")
            SceneCoordinator.shared.launchSaveState(frozenSaveState)
        }
    }

    /// Fetches and caches a thumbnail for the given item
    public func thumbnail(for item: RetroSaveStateItem, targetSize: CGSize) async -> UIImage? {
        let cacheKey = NSString(string: "\(item.id)-\(Int(targetSize.width))x\(Int(targetSize.height))")
        if let cached = imageCache.object(forKey: cacheKey) {
            return cached
        }

        guard let url = item.imageURL else { return nil }

        return await withCheckedContinuation { continuation in
            workQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: nil)
                    return
                }
                let localURL = self.ensureLocalAvailability(for: url)
                let scale = UIScreen.main.scale
                let downsampled = localURL.flatMap { self.downsampleImage(at: $0, to: targetSize, scale: scale) }
                if let downsampled {
                    self.imageCache.setObject(downsampled, forKey: cacheKey)
                }
                continuation.resume(returning: downsampled)
            }
        }
    }

    /// Fetches save states matching `predicate`, sorted newest-first.
    /// - Parameters:
    ///   - predicate: Realm filter predicate.
    ///   - limit: Maximum number of results to return; `nil` fetches all (used by full management UI).
    ///   - deduplicateAutosaves: When `true`, only the most-recent autosave per game is included;
    ///     all manual saves are always included. Defaults to `false` so the full save management
    ///     UI remains unfiltered.
    private func fetchSaveStates(predicate: NSPredicate, limit: Int?, deduplicateAutosaves: Bool = false) async -> [RetroSaveStateItem] {
        await withCheckedContinuation { continuation in
            workQueue.async {
                do {
                    let realm = try Realm()
                    let results = realm.objects(PVSaveState.self)
                        .filter(predicate)
                        .sorted(byKeyPath: #keyPath(PVSaveState.date), ascending: false)

                    // When deduplicating, fetch a larger window so that after removing duplicate
                    // autosaves we still have enough items to fill `limit`. Without this, a batch
                    // that is mostly autosaves from the same game could yield far fewer than `limit`
                    // results after the dedup pass.
                    let fetchLimit: Int? = (deduplicateAutosaves && limit != nil) ? limit.map { $0 * 4 } : limit
                    let collection: [PVSaveState] = {
                        if let fetchLimit {
                            return Array(results.prefix(fetchLimit))
                        } else {
                            return Array(results)
                        }
                    }()

                    let items: [RetroSaveStateItem]
                    if deduplicateAutosaves {
                        // For "Recent Saves" strips: show at most one (the latest) autosave per game.
                        // collection is already date-descending, so the first autosave seen per game
                        // is the most recent one. Apply `limit` after deduplication.
                        var seenAutoSaveGameIDs = Set<String>()
                        let deduped = collection.compactMap { state -> RetroSaveStateItem? in
                            if state.isAutosave {
                                let gameID = state.game?.id ?? ""
                                guard !gameID.isEmpty, seenAutoSaveGameIDs.insert(gameID).inserted else {
                                    return nil
                                }
                            }
                            return self.mapSaveState(state)
                        }
                        items = limit.map { Array(deduped.prefix($0)) } ?? deduped
                    } else {
                        items = collection.compactMap { state in
                            self.mapSaveState(state)
                        }
                    }
                    continuation.resume(returning: items)
                } catch {
                    ELOG("RetroSaveStatesStore: Failed fetching save states: \(error)")
                    continuation.resume(returning: [])
                }
            }
        }
    }

    private func mapSaveState(_ state: PVSaveState) -> RetroSaveStateItem {
        let systemId = state.game.systemIdentifier
        let systemName = state.game.system?.name ?? state.game.systemIdentifier
        let coreName = state.core?.projectName ?? state.core?.identifier ?? ""
        let fileSize = state.fileSize > 0 ? state.fileSize : Int(state.file?.size ?? 0)
        return RetroSaveStateItem(
            id: state.id,
            gameId: state.game.id,
            gameTitle: state.game.title,
            systemId: systemId,
            systemName: systemName,
            date: state.date,
            isAutosave: state.isAutosave,
            isFavorite: state.isFavorite,
            fileSize: fileSize,
            imageURL: state.image?.url,
            coreName: coreName,
            createdWithCoreVersion: state.createdWithCoreVersion,
            coreIdentifier: state.core?.identifier
        )
    }

    private func downsampleImage(at url: URL, to pointSize: CGSize, scale: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }

        let maxDimension = max(pointSize.width, pointSize.height) * scale
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    /// Ensure the file exists locally; if it's a ubiquitous item, trigger download.
    private func ensureLocalAvailability(for url: URL) -> URL? {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        if fm.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue {
            return url
        }

        // Attempt to trigger iCloud download if needed
        if fm.isUbiquitousItem(at: url) {
            try? fm.startDownloadingUbiquitousItem(at: url)
        }
        return fm.fileExists(atPath: url.path) ? url : nil
    }
}

/// Compact card for a single save state
public struct RetroSaveStateCard: View {
    public let item: RetroSaveStateItem
    @ObservedObject public var store: RetroSaveStatesStore
    public let action: () -> Void
    public var isFocused: Bool = false

    @State private var thumbnail: UIImage?

    private let cardSize = CGSize(width: 220, height: 140)

    public init(item: RetroSaveStateItem, store: RetroSaveStatesStore, isFocused: Bool = false, action: @escaping () -> Void) {
        self.item = item
        self.store = store
        self.isFocused = isFocused
        self.action = action
    }

    #if os(tvOS)
    private var focusBorderColor: Color {
        isFocused ? Color.retroPink : Color.retroPink.opacity(0.6)
    }

    private var focusBorderWidth: CGFloat {
        isFocused ? 3 : 1
    }

    private var focusShadowColor: Color {
        isFocused ? Color.retroPink.opacity(0.8) : .black.opacity(0.4)
    }

    private var focusShadowRadius: CGFloat {
        isFocused ? 10 : 6
    }
    #else
    private var focusBorderColor: Color {
        Color.retroPink.opacity(0.6)
    }

    private var focusBorderWidth: CGFloat {
        1
    }

    private var focusShadowColor: Color {
        .black.opacity(0.4)
    }

    private var focusShadowRadius: CGFloat {
        6
    }
    #endif

    public var body: some View {
        ZStack(alignment: .bottomLeading) {
            thumbnailView
            overlayText
        }
        .frame(width: cardSize.width, height: cardSize.height)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.retroBlack.opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    focusBorderColor,
                    lineWidth: focusBorderWidth
                )
        )
        .shadow(
            color: focusShadowColor,
            radius: focusShadowRadius,
            x: 0,
            y: 4
        )
        #if os(tvOS)
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
        #endif
        .task {
            if thumbnail == nil {
                thumbnail = await store.thumbnail(for: item, targetSize: cardSize)
            }
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnail {
            Image(uiImage: thumbnail)
                .resizable()
                .scaledToFill()
                .frame(width: cardSize.width, height: cardSize.height)
                .clipped()
        } else {
            ZStack {
                LinearGradient(
                    colors: [.retroBlue.opacity(0.3), .retroPurple.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                VStack(spacing: 6) {
                    Image(systemName: "filmstrip")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white.opacity(0.8))
                    Text("Loading...")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }

    private var overlayText: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.gameTitle)
                .font(.headline)
                .lineLimit(1)
            Text(item.date, style: .relative)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
            HStack(spacing: 8) {
                if item.isAutosave {
                    Label("Auto", systemImage: "clock.arrow.circlepath")
                        .font(.caption2)
                }
                if item.isFavorite {
                    Label("Fav", systemImage: "heart.fill")
                        .font(.caption2)
                }
                if !item.coreName.isEmpty {
                    Label(item.coreName, systemImage: "cpu")
                        .font(.caption2)
                        .lineLimit(1)
                }
            }
            .foregroundColor(.white.opacity(0.85))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [.black.opacity(0.7), .black.opacity(0.2)],
                startPoint: .bottom,
                endPoint: .top
            )
        )
    }
}

/// Horizontal strip of recent save states for a system
public struct RetroRecentSaveStatesStrip: View {
    let systemName: String
    let systemId: String
    let items: [RetroSaveStateItem]
    @ObservedObject var store: RetroSaveStatesStore
    let onOpen: (RetroSaveStateItem) -> Void
    let onViewAll: () -> Void

    #if os(tvOS)
    @FocusState private var focusedID: String?
    @FocusState private var viewAllFocused: Bool
    #endif

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recent Saves")
                        .font(.headline)
                    Text(systemName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(items) { item in
                        Button {
                            ILOG("RetroRecentSaveStatesStrip: Button tapped for save state: \(item.id)")
                            Task { @MainActor in
                                onOpen(item)
                            }
                        } label: {
                            RetroSaveStateCard(
                                item: item,
                                store: store,
                                isFocused: {
                                    #if os(tvOS)
                                    return focusedID == item.id
                                    #else
                                    return false
                                    #endif
                                }()
                            ) {
                                // Action handled by parent Button
                            }
                        }
                        #if os(tvOS)
                        .buttonStyle(.card)
                        .focused($focusedID, equals: item.id)
                        #else
                        .buttonStyle(.plain)
                        #endif
                    }
                    #if os(tvOS)
                    Button(action: onViewAll) {
                        HStack(spacing: 8) {
                            Image(systemName: "rectangle.stack.badge.play")
                            Text("View All")
                                .font(.callout.weight(.semibold))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(viewAllFocused ? Color.retroPink.opacity(0.2) : Color.retroBlack.opacity(0.4))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    viewAllFocused ? Color.retroPink : Color.retroPink.opacity(0.6),
                                    lineWidth: viewAllFocused ? 3 : 1
                                )
                        )
                        .shadow(
                            color: viewAllFocused ? Color.retroPink.opacity(0.8) : .black.opacity(0.4),
                            radius: viewAllFocused ? 10 : 6
                        )
                        .scaleEffect(viewAllFocused ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: viewAllFocused)
                    }
                    .buttonStyle(.plain)
                    .focused($viewAllFocused)
                    #else
                    Button(action: onViewAll) {
                        Label("View All", systemImage: "rectangle.stack.badge.play")
                            .font(.callout.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    #endif
                }
                .padding(.vertical, 4)
                #if os(tvOS)
                .focusSection()
                .defaultFocus($focusedID, items.first?.id)
                #endif
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.retroBlack.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.retroBlue.opacity(0.3), lineWidth: 1)
                )
        )
        #if os(tvOS)
        .focusSection()
        #endif
    }
}

/// Full browser for save states, grouped by game
public struct RetroSaveStatesBrowserView: View {
    @ObservedObject var store: RetroSaveStatesStore = .shared
    public let systemID: String
    public let systemName: String
    public let gameFilter: PVGame?

    @State private var items: [RetroSaveStateItem] = []
    @State private var isLoading = true
    @FocusState private var focusedSaveID: String?

    public init(
        systemID: String,
        systemName: String,
        gameFilter: PVGame? = nil,
        store: RetroSaveStatesStore = .shared
    ) {
        self.systemID = systemID
        self.systemName = systemName
        self.gameFilter = gameFilter
        self.store = store
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                if isLoading {
                    ProgressView("Loading save states…")
                        .padding()
                } else if items.isEmpty {
                    Text("No save states found for \(systemName)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(groupedItems(), id: \.key) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.value.first?.gameTitle ?? "Unknown Game")
                                .font(.title3.weight(.semibold))
                                .padding(.horizontal)
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 14) {
                                    ForEach(group.value) { item in
                                        RetroSaveStateCard(
                                            item: item,
                                            store: store,
                                            isFocused: focusedSaveID == item.id
                                        ) {
                                            Task { await store.openSaveState(id: item.id) }
                                        }
                                        #if os(tvOS)
                                        .focusable()
                                        .focused($focusedSaveID, equals: item.id)
                                        #endif
                                    }
                                }
                                .padding(.horizontal)
                                #if os(tvOS)
                                .focusSection()
                                #endif
                            }
                        }
                    }
                }
            }
            .padding(.vertical)
            #if os(tvOS)
            .focusSection()
            #endif
        }
        .navigationTitle(gameFilter == nil ? "\(systemName) Saves" : "Saves for \(gameFilter?.title ?? "")")
        .task {
            await load()
        }
        #if os(tvOS)
        .defaultFocus($focusedSaveID, items.first?.id)
        #endif
    }

    private func load() async {
        isLoading = true
        if let gameFilter {
            items = await store.loadAll(forGameID: gameFilter.id)
        } else {
            items = await store.loadAll(forSystemID: systemID)
        }
        isLoading = false
    }

    private func groupedItems() -> [(key: String, value: [RetroSaveStateItem])] {
        Dictionary(grouping: items, by: { $0.gameId })
            .sorted { lhs, rhs in
                (lhs.value.first?.date ?? .distantPast) > (rhs.value.first?.date ?? .distantPast)
            }
    }
}
