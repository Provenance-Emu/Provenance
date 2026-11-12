import SwiftUI
import PVNetplay

#if !os(watchOS)
/// Exact-ROM confirmations supplement incomplete catalogs without guessing from a title.
struct NetplayMetadataEditor: View {
    let title: String
    let md5: String
    let system: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var mode = NetplayPlayMode.sharedConsole
    @State private var players = 2
    @State private var singlePlayer = false
    @State private var reference = ""
    @State private var error: String?
    /// The iOS controller cursor (plain state: iOS has no focus engine for buttons).
    @State private var cursor: String?
    @FocusState private var referenceFocused: Bool

    var body: some View {
        NavigationStack {
            NetplayForm {
                NetplayFormSection("Multiplayer Details") {
                    Text(title).font(.title2.bold())
                    Text("Confirm the game's multiplayer mode from its manual or your own play. This applies only to this ROM; it does not verify emulator compatibility.")
                        .foregroundStyle(.secondary)
                    Toggle("Single-player only", isOn: $singlePlayer)
                        .netplayCursorItem(NetplayMetadataCursor.singlePlayer, cursor: cursor)
                    if !singlePlayer {
                        NetplayChoiceRow(title: "Play style", choices: NetplayPlayMode.allCases.map { ($0, $0.title) }, selection: $mode,
                                         cursorPrefix: NetplayMetadataCursor.modePrefix, cursor: cursor)
                        NetplayStepperView(label: "Maximum players", value: $players, in: NetplayMetadataCursor.playerRange,
                                           cursorID: NetplayMetadataCursor.players, cursor: cursor)
                    }
                    TextField("Source or notes (required)", text: $reference)
                        .focused($referenceFocused)
                        .netplayCursorItem(NetplayMetadataCursor.reference, cursor: cursor)
                    if let error { Text(error).foregroundStyle(.red) }
                    Button("Save Details") { save() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSave)
                        .netplayCursorItem(NetplayMetadataCursor.save, cursor: cursor)
                    Button("Reset to Catalog", role: .destructive, action: reset)
                        .netplayCursorItem(NetplayMetadataCursor.reset, cursor: cursor)
                }
            }
            .netplayNavigationTitle("Multiplayer Details")
            #if !os(tvOS)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            #endif
            .netplayControllerNavigation(cursorRows, cursor: $cursor) {
                if referenceFocused { referenceFocused = false } else { dismiss() }
            }
            .onAppear {
                if let existing = NetplayMetadataStore.shared.metadata(md5: md5, system: system, serial: nil) {
                    singlePlayer = existing.singlePlayerOnly
                    mode = existing.modes.first?.kind ?? .sharedConsole
                    players = existing.modes.first?.maxPlayers ?? 2
                    reference = existing.reference
                }
            }
        }
    }

    private var canSave: Bool { !reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// What the iOS controller cursor can reach, in the order it is drawn.
    private var cursorRows: [NetplayCursorRow] {
        var rows: [NetplayCursorRow] = [.single(NetplayCursorTarget(id: NetplayMetadataCursor.singlePlayer) { singlePlayer.toggle() })]
        if !singlePlayer {
            rows.append(NetplayChoiceRow.cursorRow(NetplayMetadataCursor.modePrefix, choices: NetplayPlayMode.allCases, selection: $mode,
                                                   isHeader: false))
            rows.append(NetplayStepperView.cursorRow(NetplayMetadataCursor.players, value: $players, in: NetplayMetadataCursor.playerRange))
        }
        rows.append(.single(NetplayCursorTarget(id: NetplayMetadataCursor.reference) { referenceFocused = true }))
        rows.append(.single(NetplayCursorTarget(id: NetplayMetadataCursor.save, isEnabled: canSave, action: save)))
        rows.append(.single(NetplayCursorTarget(id: NetplayMetadataCursor.reset, action: reset)))
        return rows
    }

    private func reset() {
        do {
            try NetplayMetadataStore.shared.save(nil, md5: md5, system: system)
            onSave()
            dismiss()
        } catch { self.error = error.localizedDescription }
    }

    private func save() {
        guard canSave else { return }
        let metadata = NetplayMultiplayerMetadata(modes: singlePlayer ? [] : [.init(mode, maxPlayers: players)], singlePlayerOnly: singlePlayer,
                                                 source: .userConfirmed, reference: reference.trimmingCharacters(in: .whitespacesAndNewlines))
        do {
            try NetplayMetadataStore.shared.save(metadata, md5: md5, system: system)
            onSave()
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

/// Cursor IDs and fixed values of the multiplayer details editor.
enum NetplayMetadataCursor {
    static let singlePlayer = "singlePlayer"
    static let modePrefix = "mode"
    static let players = "players"
    static let reference = "reference"
    static let save = "save"
    static let reset = "reset"

    static let playerRange = 2...8
}
#endif
