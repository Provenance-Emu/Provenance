//
//  NearbyPeerLibraryView.swift
//  PVSwiftUI
//
//  One nearby library or content server: pairing, its games, and copying them.
//

#if os(iOS) || os(tvOS)
import PVLibrarySharing
import PVSystems
import PVThemes
import SwiftUI

struct NearbyPeerLibraryView: View {
    let model: NearbyPeerLibraryModel
    @State private var code = ""
    @State private var cursorID: String?
    @State private var downloadSelection: RemoteLibraryItem?
    @State private var gridColumns = NearbyCoverGrid.minimumColumns
    @FocusState private var editingField: String?
    @Environment(NearbyNavigator.self) private var navigator: NearbyNavigator?

    private var isServer: Bool { model.peer.app == .contentServer }

    private var route: NearbyRoute { .peer(id: model.peer.id) }

    var body: some View {
        NearbyScreen(title: model.title, cursorID: cursorID) {
            if isServer { searchField }
            switch model.phase {
            case .idle, .loading:
                NearbyNote(text: progressText, showsProgress: true)
            case .needsPairing:
                pairingPrompt
            case .enteringCode(let handle):
                codeEntry(handle)
            case .confirmingCode:
                NearbyNote(text: "Approve the pairing on \(model.title)…", showsProgress: true)
            case .failed(let message):
                NearbySection {
                    NearbyNote(text: message, systemImage: "exclamationmark.triangle", tint: .orange)
                    Button { model.load() } label: {
                        NearbyRowLabel(title: "Try Again", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(NearbyRowButtonStyle(cursorID: NearbyCursor.tryAgain))
                }
            case .loaded:
                catalogueSections
            }
        }
        .nearbyControllerCursor(
            cursorLayout, cursor: $cursorID, scope: .screen(route), isEditingText: editingField != nil,
            onBack: back, onActivate: activate
        )
        .safeAreaInset(edge: .bottom) {
            if let current = model.activeServerGame {
                transferBar(current)
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
        .settingsSubpageTracking()
    }

    private func transferBar(_ item: RemoteLibraryItem) -> some View {
        let progress = model.copies[item.id]
        return HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title).font(.headline).lineLimit(1)
                switch progress {
                case .downloading(let fraction):
                    ProgressView("Downloading", value: fraction)
                case .verifying:
                    ProgressView("Verifying files")
                case .importing:
                    ProgressView("Adding to Library")
                default:
                    ProgressView("Preparing download")
                }
            }
            if progress != .importing {
                Button("Cancel", systemImage: "xmark.circle") { model.cancelCopy(item) }
                    .labelStyle(.iconOnly)
            }
        }
        .padding()
        .background(.regularMaterial)
    }

    private var progressText: String {
        switch model.phase {
        case .loading(.waitingForApproval):
            return "Waiting for approval on \(model.title)…"
        case .loading(.loadingCatalogue):
            return "Loading the library…"
        default:
            return "Connecting to \(model.title)…"
        }
    }

    private var searchField: some View {
        NearbyTextFieldRow(
            placeholder: "Search games",
            text: Binding(get: { model.searchText }, set: { model.searchText = $0 }),
            cursorID: NearbyCursor.search,
            editing: $editingField
        )
    }

    private var libraryChoices: [String] {
        model.serverLibraries.isEmpty ? [] : [""] + model.serverLibraries.map(\.id)
    }

    private var cursorLayout: TVMediaCursorLayout {
        switch model.phase {
        case .idle, .loading, .confirmingCode: return NearbyCursor.peerLibrary(.waiting, searchWhileLoading: isServer)
        case .failed: return NearbyCursor.peerLibrary(.failed, searchWhileLoading: isServer)
        case .needsPairing: return NearbyCursor.peerLibrary(.needsPairing)
        case .enteringCode: return NearbyCursor.peerLibrary(.enteringCode)
        case .loaded:
            let rows = NearbyCursor.gridRows(sections: model.sections.map { $0.items.map(\.id) }, columns: gridColumns)
            return NearbyCursor.peerLibrary(
                .loaded(libraryIDs: libraryChoices, itemRows: rows), canLoadMore: model.nextServerPage != nil && !model.loadingMore
            )
        }
    }

    @ViewBuilder
    private var catalogueSections: some View {
        if isServer {
            Button("Refresh", systemImage: "arrow.clockwise") { model.load(keepCatalogue: true) }
                .disabled(model.activeServerGame != nil)
        }
        if !isServer { searchField }
        if !model.serverLibraries.isEmpty {
            NearbySection(header: "Library") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: NearbyMetrics.rowSpacing) {
                        ForEach(libraryChoices, id: \.self) { id in
                            Button(libraryName(id)) { model.selectLibrary(id) }
                                .buttonStyle(NearbyChipButtonStyle(
                                    cursorID: NearbyCursor.library(id), isSelected: model.selectedLibraryID == id
                                ))
                        }
                    }
                    .padding(NearbyMetrics.highlightBorderWidth * 4)
                }
            }
        }
        if model.sections.isEmpty && model.nextServerPage == nil {
            NearbyNote(text: model.searchText.isEmpty
                       ? "\(model.title) isn't sharing any games Provenance can play."
                       : "No games match your search.")
        }
        ForEach(model.sections) { section in
            NearbySection(header: section.system.fullName) {
                LazyVGrid(columns: gridItems, alignment: .leading, spacing: NearbyCoverGrid.spacing) {
                    ForEach(section.items) { item in
                        NearbyItemCard(
                            item: item,
                            image: model.artwork[item.id],
                            copyState: model.activeServerGame?.id == item.id ? nil : model.copies[item.id],
                            peerName: model.title,
                            action: itemAction(item),
                            perform: { perform(itemAction(item), on: item) }
                        )
                        .disabled(isServer && model.activeServerGame != nil)
                        .task(id: item.id) { await model.loadArtwork(for: item) }
                    }
                }
            }
            // The controller cursor moves by rows, so it has to know how many cards a row holds.
            .onGeometryChange(for: Int.self) { NearbyCoverGrid.columns(forWidth: $0.size.width) } action: { gridColumns = $0 }
        }
        if model.unsupportedCount > 0 {
            let count = model.unsupportedCount
            NearbyNote(text: "\(count) more game\(count == 1 ? " isn't" : "s aren't") supported by Provenance.")
                .font(.caption)
        }
        if let message = model.pageError {
            NearbyNote(text: message, systemImage: "exclamationmark.triangle", tint: .orange)
        }
        if model.nextServerPage != nil {
            if model.loadingMore {
                ProgressView("Loading more games")
            } else {
                Button { model.load(more: true) } label: {
                    NearbyRowLabel(title: "Load More Games", systemImage: "arrow.down")
                }
                    .buttonStyle(NearbyRowButtonStyle(cursorID: NearbyCursor.loadMore))
                    .disabled(model.activeServerGame != nil)
            }
        }
    }

    private var gridItems: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: NearbyCoverGrid.spacing, alignment: .top), count: gridColumns)
    }

    private func libraryName(_ id: String) -> String {
        id.isEmpty ? "All libraries" : (model.serverLibraries.first { $0.id == id }?.name ?? id)
    }

    private func itemAction(_ item: RemoteLibraryItem) -> NearbyItemAction {
        let isContentServer = model.peer.app == .contentServer
        return NearbyItemAction(
            copyState: model.copies[item.id],
            inLibrary: model.isInLibrary(item),
            missingFile: model.isMissingFile(item),
            canPlay: isContentServer && model.canPlay(item),
            isContentServer: isContentServer
        )
    }

    private func perform(_ action: NearbyItemAction, on item: RemoteLibraryItem) {
        switch action {
        case .stop: model.cancelCopy(item)
        case .play: model.play(item)
        case .downloadAndPlay: downloadSelection = item
        case .retry where isServer: downloadSelection = item
        case .copy, .getFile, .retry: model.copy(item)
        case .importing, .inLibrary: break
        }
    }

    private var pairingPrompt: some View {
        NearbySection(
            footer: "iCube shares its library only with paired devices. A 6-digit code will appear on \(model.title)."
        ) {
            Button { model.beginPairing() } label: {
                NearbyRowLabel(title: "Pair with \(model.title)", systemImage: "link")
            }
            .buttonStyle(NearbyRowButtonStyle(cursorID: NearbyCursor.pair))
        }
    }

    private var trimmedCode: String { code.trimmingCharacters(in: .whitespaces) }

    private func codeEntry(_ handle: ICubePairingHandle) -> some View {
        NearbySection(
            header: "Enter the code shown on \(handle.serverName)",
            footer: model.codeError ?? "Then approve the request on \(handle.serverName)."
        ) {
            NearbyTextFieldRow(
                placeholder: "6-digit code", text: $code, cursorID: NearbyCursor.code, editing: $editingField
            )
                #if os(iOS)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                #endif
            Button { submitCode(handle) } label: {
                NearbyRowLabel(title: "Pair", systemImage: "checkmark.circle")
            }
            .buttonStyle(NearbyRowButtonStyle(cursorID: NearbyCursor.submitCode))
            .disabled(trimmedCode.count != NearbyCursor.pairingCodeLength)
        }
    }

    private func submitCode(_ handle: ICubePairingHandle) {
        guard trimmedCode.count == NearbyCursor.pairingCodeLength else { return }
        model.submitCode(trimmedCode, for: handle)
        code = ""
    }

    /// B: leave the field being typed in first, then go back.
    private func back() {
        if editingField != nil {
            editingField = nil
        } else {
            navigator?.back()
        }
    }

    private func activate(_ id: String) {
        switch id {
        case NearbyCursor.tryAgain: model.load()
        case NearbyCursor.loadMore: model.load(more: true)
        case NearbyCursor.pair: model.beginPairing()
        case NearbyCursor.search, NearbyCursor.code: editingField = id
        case NearbyCursor.submitCode:
            if case .enteringCode(let handle) = model.phase { submitCode(handle) }
        default:
            if let library = libraryChoices.first(where: { NearbyCursor.library($0) == id }) {
                model.selectLibrary(library)
            } else if let item = model.sections.flatMap(\.items).first(where: { NearbyCursor.item($0.id) == id }) {
                perform(itemAction(item), on: item)
            }
        }
    }
}

/// What pressing a game's card does, from its copy state. One action per card, so the whole
/// card is the button (a controller or the TV remote cannot reach a button inside one).
enum NearbyItemAction: Equatable {
    case stop
    case play
    case copy
    case retry
    case downloadAndPlay
    /// Copied; the importer is still working. Nothing to press.
    case importing
    /// Already in the library. Nothing to press.
    case inLibrary

    /// The library lists the game but its file is not on this device. Pressing copies it.
    case getFile

    init(copyState: NearbyCopyState?, inLibrary: Bool, missingFile: Bool = false, canPlay: Bool, isContentServer: Bool) {
        if copyState?.isActive == true {
            self = .stop
        } else if copyState == .importing {
            self = .importing
        } else if canPlay && isContentServer {
            self = .play
        } else if inLibrary || copyState == .completed {
            self = .inLibrary
        } else if case .failed = copyState {
            self = .retry
        } else if missingFile && !isContentServer {
            self = .getFile
        } else {
            self = isContentServer ? .downloadAndPlay : .copy
        }
    }

    var title: String {
        switch self {
        case .stop: return "Stop"
        case .play: return "Play"
        case .copy: return "Copy"
        case .getFile: return "Get File"
        case .retry: return "Retry"
        case .downloadAndPlay: return "Download & Play"
        case .importing: return "Importing"
        case .inLibrary: return "In your library"
        }
    }

    var systemImage: String {
        switch self {
        case .stop: return "stop.circle"
        case .play: return "play.fill"
        case .copy: return "arrow.down.circle"
        case .getFile: return "icloud.and.arrow.down"
        case .retry: return "arrow.clockwise"
        case .downloadAndPlay: return "arrow.down.to.line"
        case .importing: return "tray.and.arrow.down.fill"
        case .inLibrary: return "checkmark.circle.fill"
        }
    }

    /// Whether pressing the card does anything.
    var isActionable: Bool {
        self != .importing && self != .inLibrary
    }
}

private struct NearbyItemCard: View {
    let item: RemoteLibraryItem
    let image: UIImage?
    let copyState: NearbyCopyState?
    let peerName: String
    let action: NearbyItemAction
    let perform: () -> Void
    @ObservedObject private var themeManager = ThemeManager.shared

    private let coverFillOpacity = 0.06
    private let titleLineLimit = 2
    private let statusLineLimit = 2

    var body: some View {
        // Cards that have nothing to do stay focusable, so the remote can move past them.
        Button(action: perform) {
            VStack(alignment: .leading, spacing: 6) {
                cover
                // Two lines are always reserved, so the cards of a row line up.
                Text(item.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(titleLineLimit, reservesSpace: true)
                    .multilineTextAlignment(.leading)
                status
            }
        }
        .buttonStyle(NearbyCardButtonStyle(cursorID: NearbyCursor.item(item.id)))
        .accessibilityLabel(Text("\(item.title), \(statusText)"))
    }

    private var cover: some View {
        RoundedRectangle(cornerRadius: NearbyCoverGrid.coverCornerRadius, style: .continuous)
            .fill(Color.white.opacity(coverFillOpacity))
            .aspectRatio(NearbyCoverGrid.coverAspectRatio, contentMode: .fit)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "photo")
                        .font(.title)
                        .foregroundStyle(themeManager.nearbySecondaryText)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: NearbyCoverGrid.coverCornerRadius, style: .continuous))
    }

    @ViewBuilder
    private var status: some View {
        if case .downloading(let fraction) = copyState {
            ProgressView(value: fraction)
        }
        Label(statusText, systemImage: action.systemImage)
            .font(.caption2.weight(.medium))
            .foregroundStyle(statusColor)
            .lineLimit(statusLineLimit, reservesSpace: true)
            .multilineTextAlignment(.leading)
    }

    private var statusColor: Color {
        if case .failed = copyState { return .red }
        switch action {
        case .inLibrary: return .green
        case .stop: return .red
        case .importing: return themeManager.nearbySecondaryText
        case .play, .copy, .getFile, .retry, .downloadAndPlay: return .retroBlue
        }
    }

    /// What pressing does, or what is happening to the copy.
    private var statusText: String {
        switch copyState {
        case .preparing(.waitingForApproval):
            return "Waiting for approval on \(peerName)…"
        case .preparing:
            return "Connecting…"
        case .downloading(let fraction):
            return "Stop · \(Int(fraction * 100))%"
        case .verifying:
            return "Checking the copy…"
        case .importing:
            return "Importing…"
        case .failed(let message):
            return "Retry · \(message)"
        case .completed, nil:
            guard action.isActionable else { return action.title }
            let size = ByteCountFormatter.string(fromByteCount: item.sizeBytes, countStyle: .file)
            return "\(action.title) · \(size)"
        }
    }
}
#endif
