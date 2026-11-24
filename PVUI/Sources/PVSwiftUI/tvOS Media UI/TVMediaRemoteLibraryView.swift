//
//  TVMediaRemoteLibraryView.swift
//  PVSwiftUI
//
//  A content server's or nearby peer's games, drawn with the library's own game cells,
//  grid and focus handling instead of a separate page.
//  Design: docs/superpowers/specs/2026-11-23-shared-remote-library-browser-design.md
//

#if os(iOS) || os(tvOS)
import PVLibrarySharing
import PVRealm
import PVRemoteLibrary
import PVRemoteLibraryUI
import PVSystems
import PVThemes
import PVUIBase
import SwiftUI

@available(tvOS 16.0, iOS 17.0, *)
struct TVMediaRemoteLibraryView: View {
    let model: NearbyPeerLibraryModel

    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.tvMediaFocusCoordinator) private var focusCoordinator
    @State private var downloadSelection: RemoteLibraryItem?

    private var isServer: Bool { model.peer.app == .contentServer }

    var body: some View {
        Group {
            if model.phase == .loaded {
                library
            } else {
                // Pairing, sign-in, waiting and failures are not a library: the Nearby screen shows them.
                NavigationStack {
                    NearbyPeerLibraryView(model: model, managesLifetime: false)
                }
            }
        }
        .onAppear { model.appear() }
        .onDisappear { model.cancel() }
        .alert(
            downloadSelection?.title ?? "Play Game",
            isPresented: Binding(get: { downloadSelection != nil }, set: { if !$0 { downloadSelection = nil } }),
            presenting: downloadSelection
        ) { item in
            Button("Play Temporarily") { model.copy(item, temporarily: true) }
            Button("Download and Run") { model.copy(item, playAfterImport: true) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Play with a temporary copy or keep the game in your library.")
        }
    }

    // MARK: - Library

    private var library: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
                header
                if model.sections.isEmpty && model.nextServerPage == nil {
                    TVMediaEmptyStateView(
                        title: model.searchText.isEmpty ? "No Games" : "No Matches",
                        subtitle: model.searchText.isEmpty
                            ? "\(model.title) isn't sharing any games Provenance can play."
                            : "No games match your search."
                    )
                }
                ForEach(model.sections) { section in
                    VStack(alignment: .leading, spacing: Metrics.headerSpacing) {
                        sectionHeader(section)
                        TVMediaRemoteGamesGrid(
                            model: model,
                            items: section.items,
                            rowPrefix: "remote|" + section.system.rawValue,
                            status: status(for:),
                            perform: perform(on:)
                        )
                    }
                }
                footer
            }
            .padding(.horizontal, Metrics.horizontalPadding)
            .padding(.vertical, Metrics.verticalPadding)
        }
        .tvMediaCursorScreen(coordinator: focusCoordinator)
        .safeAreaInset(edge: .bottom) { transferBanner }
        .tint(Color.retroPink)
    }

    private var header: some View {
        HStack(spacing: Metrics.headerSpacing) {
            SourcePill(sourceInfo, count: gameCount, isSelected: true)
                .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText))
            if isServer {
                TextField("Search \(model.title)", text: Binding(get: { model.searchText }, set: { model.searchText = $0 }))
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .textFieldStyle(.roundedBorder)
                    #endif
                    .frame(maxWidth: Metrics.searchWidth)
            }
            Spacer()
            Button("Refresh", systemImage: "arrow.clockwise") { model.load(keepCatalogue: true) }
                .disabled(model.activeServerGame != nil)
        }
    }

    private func sectionHeader(_ section: NearbyPeerLibraryModel.SystemSection) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 1)
                .fill(LinearGradient(colors: [Color.retroPink, Color.retroBlue], startPoint: .top, endPoint: .bottom))
                .frame(width: 3, height: 26)
            Text(section.system.fullName.uppercased())
                .font(.system(size: 18, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.95))
            Spacer()
            Text(section.items.count.formatted())
                .font(.system(size: 13, weight: .medium).monospacedDigit())
                .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.72))
        }
    }

    @ViewBuilder
    private var footer: some View {
        if model.unsupportedCount > 0 {
            let count = model.unsupportedCount
            Text("\(count) more game\(count == 1 ? " isn't" : "s aren't") supported by Provenance.")
                .font(.caption)
                .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.6))
        }
        if let message = model.pageError {
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
        }
        if model.nextServerPage != nil {
            if model.loadingMore {
                ProgressView("Loading more games")
                    .frame(maxWidth: .infinity)
            } else {
                Button("Load More Games", systemImage: "arrow.down") { model.load(more: true) }
                    .disabled(model.activeServerGame != nil)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// The copy in front: a server plays one game at a time; a peer may run several, so show the first.
    @ViewBuilder
    private var transferBanner: some View {
        let items = model.sections.flatMap(\.items)
        let current = model.activeServerGame ?? items.first { model.copies[$0.id]?.transferState != nil }
        if let current, let state = model.copies[current.id]?.transferState ?? (model.activeServerGame == nil ? nil : .queued) {
            TransferBanner(
                title: current.title, state: state,
                onCancel: { model.cancelCopy(current) },
                onDismiss: nil
            )
        }
    }

    // MARK: - State

    private var sourceInfo: LibrarySourceInfo {
        LibrarySourceInfo(
            id: LibrarySourceID(rawValue: model.peer.id),
            kind: isServer ? .contentServer : .peer,
            name: model.title,
            symbol: NearbyPeerSymbol.symbol(for: model.peer.app)
        )
    }

    private var gameCount: Int {
        model.sections.reduce(0) { $0 + $1.items.count }
    }

    private func action(for item: RemoteLibraryItem) -> NearbyItemAction {
        NearbyItemAction(
            copyState: model.copies[item.id],
            inLibrary: model.isInLibrary(item),
            missingFile: model.isMissingFile(item),
            canPlay: isServer && model.canPlay(item),
            isContentServer: isServer
        )
    }

    private func status(for item: RemoteLibraryItem) -> TVMediaRemoteGameStatus {
        // The game on screen for a server is the one being copied even before its first progress report.
        let copy = model.activeServerGame?.id == item.id ? (model.copies[item.id] ?? .preparing(.connecting)) : model.copies[item.id]
        return TVMediaRemoteGameStatus(action: action(for: item), transfer: copy?.transferState)
    }

    private func perform(on item: RemoteLibraryItem) {
        guard !isServer || model.activeServerGame == nil || model.activeServerGame?.id == item.id else { return }
        switch action(for: item) {
        case .stop: model.cancelCopy(item)
        case .play: model.play(item)
        case .downloadAndPlay: downloadSelection = item
        case .retry where isServer: downloadSelection = item
        case .copy, .getFile, .retry: model.copy(item)
        case .importing, .inLibrary: break
        }
    }

    private enum Metrics {
        #if os(tvOS)
        static let horizontalPadding: CGFloat = 60
        static let verticalPadding: CGFloat = 40
        static let searchWidth: CGFloat = 520
        #else
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 12
        static let searchWidth: CGFloat = 320
        #endif
        static let sectionSpacing: CGFloat = 28
        static let headerSpacing: CGFloat = 16
    }
}

/// What a remote game's cell says on its corner.
struct TVMediaRemoteGameStatus: Equatable {
    let action: NearbyItemAction
    let transfer: TransferState?
}

/// A grid of remote games drawn with the library's game cells.
@available(tvOS 16.0, iOS 17.0, *)
private struct TVMediaRemoteGamesGrid: View {
    let model: NearbyPeerLibraryModel
    let items: [RemoteLibraryItem]
    /// Unique per grid on the screen: the controller cursor's rows are named from it.
    let rowPrefix: String
    let status: (RemoteLibraryItem) -> TVMediaRemoteGameStatus
    let perform: (RemoteLibraryItem) -> Void

    @Environment(\.tvMediaFocusCoordinator) private var focusCoordinator
    @FocusState private var focusedGameID: String?
    @State private var gridWidth: CGFloat = 0

    private static let minItemWidth: CGFloat = 260
    private static let maxItemWidth: CGFloat = 300
    private static let spacing: CGFloat = 20
    private static let screenMargin: CGFloat = 120

    var body: some View {
        let effectiveWidth = gridWidth > 0 ? gridWidth : max(1, UIScreen.main.bounds.width - Self.screenMargin)
        let columnsPerRow = TVMediaGridMetrics.adaptiveColumnCount(
            availableWidth: effectiveWidth, minItemWidth: Self.minItemWidth, spacing: Self.spacing
        )
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: Self.minItemWidth, maximum: Self.maxItemWidth), spacing: Self.spacing)],
            spacing: Self.spacing
        ) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let game = model.libraryGame(for: item)
                let itemStatus = status(item)
                TVMediaGameTileView(
                    game: game,
                    titleFont: .headline.weight(.semibold),
                    onPlay: { perform(item) },
                    contextMenu: {
                        Button(itemStatus.action.title, systemImage: itemStatus.action.systemImage) { perform(item) }
                            .disabled(!itemStatus.action.isActionable)
                    },
                    isAtLeftEdge: index % max(columnsPerRow, 1) == 0,
                    focusCoordinator: focusCoordinator,
                    focusedGameID: $focusedGameID
                )
                .overlay(alignment: .topLeading) {
                    TVMediaRemoteGameBadge(status: itemStatus)
                        .padding(8)
                        .allowsHitTesting(false)
                }
                .id(game.id)
                .task(id: item.id) { await model.loadArtwork(for: item) }
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { gridWidth = $0 }
        // iOS: the screen's cursor walks these rows; the cells carry their game ID as view ID.
        .tvMediaCursorRows(
            TVMediaCursorLayout(
                gridItems: items.map(NearbyPeerLibraryModel.libraryGameID(for:)), columns: columnsPerRow, rowPrefix: rowPrefix
            ).rows
        )
    }
}

/// The mark on a remote game's cover: a progress ring while it copies, else what pressing it does.
private struct TVMediaRemoteGameBadge: View {
    let status: TVMediaRemoteGameStatus

    private static let ringSize: CGFloat = 44

    var body: some View {
        Group {
            if let transfer = status.transfer {
                TransferRing(state: transfer)
                    .frame(width: Self.ringSize, height: Self.ringSize)
                    .padding(6)
                    .background(.black.opacity(0.7), in: Circle())
            } else {
                Label(status.action.title, systemImage: status.action.systemImage)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.7), in: Capsule())
            }
        }
        .foregroundStyle(.white)
        .tint(Color.retroPink)
        .accessibilityHidden(true)
    }
}
#endif
