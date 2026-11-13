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
    @FocusState private var editingField: String?
    @Environment(NearbyNavigator.self) private var navigator: NearbyNavigator?

    private var route: NearbyRoute { .peer(id: model.peer.id) }

    var body: some View {
        NearbyScreen(title: model.title, cursorID: cursorID) {
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
        .onAppear { model.appear() }
        .onDisappear { model.cancel() }
        .settingsSubpageTracking()
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

    private var libraryChoices: [String] {
        model.serverLibraries.isEmpty ? [] : [""] + model.serverLibraries.map(\.id)
    }

    private var cursorLayout: TVMediaCursorLayout {
        switch model.phase {
        case .idle, .loading, .confirmingCode: return NearbyCursor.peerLibrary(.waiting)
        case .failed: return NearbyCursor.peerLibrary(.failed)
        case .needsPairing: return NearbyCursor.peerLibrary(.needsPairing)
        case .enteringCode: return NearbyCursor.peerLibrary(.enteringCode)
        case .loaded:
            let items = model.sections.flatMap(\.items).map(\.id)
            return NearbyCursor.peerLibrary(.loaded(libraryIDs: libraryChoices, itemIDs: items))
        }
    }

    @ViewBuilder
    private var catalogueSections: some View {
        NearbyTextFieldRow(
            placeholder: "Search games",
            text: Binding(get: { model.searchText }, set: { model.searchText = $0 }),
            cursorID: NearbyCursor.search,
            editing: $editingField
        )
        if !model.serverLibraries.isEmpty {
            NearbySection(header: "Library") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: NearbyMetrics.rowSpacing) {
                        ForEach(libraryChoices, id: \.self) { id in
                            Button(libraryName(id)) { selectLibrary(id) }
                                .buttonStyle(NearbyChipButtonStyle(
                                    cursorID: NearbyCursor.library(id), isSelected: model.selectedLibraryID == id
                                ))
                        }
                    }
                    .padding(NearbyMetrics.highlightBorderWidth * 4)
                }
            }
        }
        if model.sections.isEmpty {
            NearbyNote(text: model.searchText.isEmpty
                       ? "\(model.title) isn't sharing any games Provenance can play."
                       : "No games match your search.")
        }
        ForEach(model.sections) { section in
            NearbySection(header: section.system.fullName) {
                ForEach(section.items) { item in
                    NearbyItemRow(
                        item: item,
                        image: model.artwork[item.id],
                        copyState: model.copies[item.id],
                        peerName: model.title,
                        action: itemAction(item),
                        perform: { perform(itemAction(item), on: item) }
                    )
                    .task(id: item.id) { await model.loadArtwork(for: item) }
                }
            }
        }
        if model.unsupportedCount > 0 {
            let count = model.unsupportedCount
            NearbyNote(text: "\(count) more game\(count == 1 ? " isn't" : "s aren't") supported by Provenance.")
                .font(.caption)
        }
    }

    private func libraryName(_ id: String) -> String {
        id.isEmpty ? "All libraries" : (model.serverLibraries.first { $0.id == id }?.name ?? id)
    }

    private func selectLibrary(_ id: String) {
        model.selectedLibraryID = id
        model.load()
    }

    private func itemAction(_ item: RemoteLibraryItem) -> NearbyItemAction {
        let isContentServer = model.peer.app == .contentServer
        return NearbyItemAction(
            copyState: model.copies[item.id],
            inLibrary: model.isInLibrary(item),
            canPlay: isContentServer && model.canPlay(item),
            isContentServer: isContentServer
        )
    }

    private func perform(_ action: NearbyItemAction, on item: RemoteLibraryItem) {
        switch action {
        case .stop: model.cancelCopy(item)
        case .play: model.play(item)
        case .copy, .retry, .downloadAndPlay: model.copy(item, playAfterImport: model.peer.app == .contentServer)
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
        case NearbyCursor.pair: model.beginPairing()
        case NearbyCursor.search, NearbyCursor.code: editingField = id
        case NearbyCursor.submitCode:
            if case .enteringCode(let handle) = model.phase { submitCode(handle) }
        default:
            if let library = libraryChoices.first(where: { NearbyCursor.library($0) == id }) {
                selectLibrary(library)
            } else if let item = model.sections.flatMap(\.items).first(where: { NearbyCursor.item($0.id) == id }) {
                perform(itemAction(item), on: item)
            }
        }
    }
}

/// What pressing a game row does, from its copy state. One action per row, so the whole
/// row is the button (a controller or the TV remote cannot reach a button inside a row).
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

    init(copyState: NearbyCopyState?, inLibrary: Bool, canPlay: Bool, isContentServer: Bool) {
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
        } else {
            self = isContentServer ? .downloadAndPlay : .copy
        }
    }

    var title: String {
        switch self {
        case .stop: return "Stop"
        case .play: return "Play"
        case .copy: return "Copy"
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
        case .retry: return "arrow.clockwise"
        case .downloadAndPlay: return "arrow.down.to.line"
        case .importing: return "tray.and.arrow.down.fill"
        case .inLibrary: return "checkmark.circle.fill"
        }
    }

    /// Whether pressing the row does anything.
    var isActionable: Bool {
        self != .importing && self != .inLibrary
    }
}

private struct NearbyItemRow: View {
    let item: RemoteLibraryItem
    let image: UIImage?
    let copyState: NearbyCopyState?
    let peerName: String
    let action: NearbyItemAction
    let perform: () -> Void
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        // Rows that have nothing to do stay focusable, so the remote can scroll past them.
        Button(action: perform) {
            HStack(spacing: 16) {
                artwork
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.body.weight(.medium))
                        .lineLimit(2)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(isFailure ? Color.red : themeManager.nearbySecondaryText)
                        .lineLimit(3)
                    if case .downloading(let fraction) = copyState {
                        ProgressView(value: fraction)
                    }
                }
                Spacer(minLength: 12)
                actionBadge
            }
        }
        .buttonStyle(NearbyRowButtonStyle(cursorID: NearbyCursor.item(item.id)))
    }

    private var artwork: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(themeManager.nearbySecondaryText)
            }
        }
        .frame(width: NearbyMetrics.artworkSize, height: NearbyMetrics.artworkSize)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private let badgeOpacity = 0.3

    @ViewBuilder
    private var actionBadge: some View {
        let label = Label(action.title, systemImage: action.systemImage)
            .font(.caption.bold())
        if action.isActionable {
            label
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill((action == .stop ? Color.red : Color.retroBlue).opacity(badgeOpacity)))
        } else {
            label.foregroundStyle(action == .inLibrary ? Color.green : themeManager.nearbySecondaryText)
        }
    }

    private var isFailure: Bool {
        if case .failed = copyState { return true }
        return false
    }

    private var detail: String {
        let size = ByteCountFormatter.string(fromByteCount: item.sizeBytes, countStyle: .file)
        switch copyState {
        case .preparing(.waitingForApproval):
            return "Waiting for approval on \(peerName)…"
        case .preparing(.loadingCatalogue):
            return "Preparing game files…"
        case .preparing:
            return "Connecting…"
        case .downloading(let fraction):
            return "Copying… \(Int(fraction * 100))%"
        case .verifying:
            return "Checking the copy…"
        case .completed:
            return "Imported into your library."
        case .importing:
            return "Copied. Importing into your library…"
        case .failed(let message):
            return message
        case nil:
            return size
        }
    }
}
#endif
