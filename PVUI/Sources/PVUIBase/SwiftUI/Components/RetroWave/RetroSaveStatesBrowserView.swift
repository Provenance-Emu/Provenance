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

    /// Loads the most recent save states for a system
    @discardableResult
    public func loadRecent(forSystemID systemID: String, limit: Int = 8) async -> [RetroSaveStateItem] {
        if let cached = await MainActor.run(body: { recentBySystem[systemID] }), !cached.isEmpty {
            return cached
        }

        let items = await fetchSaveStates(
            predicate: NSPredicate(format: "game.systemIdentifier == %@", systemID),
            limit: limit
        )

        await MainActor.run {
            recentBySystem[systemID] = items
        }

        return items
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

    /// Opens a save state via the root delegate if available
    public func openSaveState(id: String) async {
        await MainActor.run {
            guard let delegate = UIApplication.shared.delegate as? PVRootDelegate else {
                ELOG("RetroSaveStatesStore: PVRootDelegate unavailable; cannot open save state")
                return
            }
            Task { await delegate.root_openSaveState(id) }
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
                let scale = UIScreen.main.scale
                let downsampled = self.downsampleImage(at: url, to: targetSize, scale: scale)
                if let downsampled {
                    self.imageCache.setObject(downsampled, forKey: cacheKey)
                }
                continuation.resume(returning: downsampled)
            }
        }
    }

    private func fetchSaveStates(predicate: NSPredicate, limit: Int?) async -> [RetroSaveStateItem] {
        await withCheckedContinuation { continuation in
            workQueue.async {
                do {
                    let realm = try Realm()
                    let results = realm.objects(PVSaveState.self)
                        .filter(predicate)
                        .sorted(byKeyPath: #keyPath(PVSaveState.date), ascending: false)

                    let collection: [PVSaveState] = {
                        if let limit {
                            return Array(results.prefix(limit))
                        } else {
                            return Array(results)
                        }
                    }()

                    let items = collection.compactMap { state in
                        self.mapSaveState(state)
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
            coreName: coreName
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
}

/// Compact card for a single save state
struct RetroSaveStateCard: View {
    let item: RetroSaveStateItem
    @ObservedObject var store: RetroSaveStatesStore
    let action: () -> Void

    @State private var thumbnail: UIImage?

    private let cardSize = CGSize(width: 220, height: 140)

    var body: some View {
        Button(action: action) {
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
                    .stroke(Color.retroPink.opacity(0.6), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 4)
        }
        .buttonStyle(.plain)
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
struct RetroRecentSaveStatesStrip: View {
    let systemName: String
    let systemId: String
    let items: [RetroSaveStateItem]
    @ObservedObject var store: RetroSaveStatesStore
    let onOpen: (RetroSaveStateItem) -> Void
    let onViewAll: () -> Void

    @FocusState private var focusedID: String?

    var body: some View {
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
                Button(action: onViewAll) {
                    Label("View All", systemImage: "rectangle.stack.badge.play")
                        .font(.callout.weight(.semibold))
                }
                .buttonStyle(.plain)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(items) { item in
                        RetroSaveStateCard(item: item, store: store) {
                            onOpen(item)
                        }
                        #if os(tvOS)
                        .focused($focusedID, equals: item.id)
                        .focusable()
                        #endif
                    }
                }
                .padding(.vertical, 4)
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
                                        RetroSaveStateCard(item: item, store: store) {
                                            Task { await store.openSaveState(id: item.id) }
                                        }
                                        #if os(tvOS)
                                        .focusable()
                                        .focusSection()
                                        #endif
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(gameFilter == nil ? "\(systemName) Saves" : "Saves for \(gameFilter?.title ?? "")")
        .task {
            await load()
        }
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
