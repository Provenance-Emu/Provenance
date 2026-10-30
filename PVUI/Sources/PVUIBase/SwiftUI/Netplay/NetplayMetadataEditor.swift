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

    var body: some View {
        NavigationStack {
            NetplayForm {
                NetplayFormSection("Multiplayer Details") {
                    Text(title).font(.title2.bold())
                    Text("Confirm the game's multiplayer mode from its manual or your own play. This applies only to this ROM; it does not verify emulator compatibility.")
                        .foregroundStyle(.secondary)
                    Toggle("Single-player only", isOn: $singlePlayer)
                    if !singlePlayer {
                        Picker("Play style", selection: $mode) {
                            ForEach(NetplayPlayMode.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                        NetplayStepperView(label: "Maximum players", value: $players, in: 2...8)
                    }
                    TextField("Source or notes (required)", text: $reference)
                    if let error { Text(error).foregroundStyle(.red) }
                    Button("Save Details") { save() }
                        .buttonStyle(.borderedProminent)
                        .disabled(reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Reset to Catalog", role: .destructive) {
                        do {
                            try NetplayMetadataStore.shared.save(nil, md5: md5, system: system)
                            onSave()
                            dismiss()
                        } catch { self.error = error.localizedDescription }
                    }
                }
            }
            .netplayNavigationTitle("Multiplayer Details")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
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

    private func save() {
        let metadata = NetplayMultiplayerMetadata(modes: singlePlayer ? [] : [.init(mode, maxPlayers: players)], singlePlayerOnly: singlePlayer,
                                                 source: .userConfirmed, reference: reference.trimmingCharacters(in: .whitespacesAndNewlines))
        do {
            try NetplayMetadataStore.shared.save(metadata, md5: md5, system: system)
            onSave()
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
#endif
