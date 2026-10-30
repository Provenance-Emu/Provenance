#if !os(watchOS)
import SwiftUI
import PVNetplay
import PVLibrary
import PVRealm
import Defaults
import PVSettings

@MainActor
struct NetplayLibraryGameDetail: View {
    let entry: NetplayLibraryEligibility.Entry
    let rooms: [NetplayRoom]
    let onMetadataChanged: () -> Void
    let onLaunch: (NetplayGameOption, NetplayLaunchIntent.Action, String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var optionID = ""
    @State private var showMetadata = false
    @State private var password = ""
    @State private var refreshedEntry: NetplayLibraryEligibility.Entry?

    private var current: NetplayLibraryEligibility.Entry { refreshedEntry ?? entry }
    private var options: [NetplayGameOption] { current.eligibility.options }
    private var chosen: NetplayGameOption? { options.first { $0.id == optionID } ?? options.first }

    var body: some View {
        NavigationStack {
            NetplayForm {
                NetplayFormSection {
                    GameItemView(game: entry.game, viewType: .row) { }
                        .allowsHitTesting(false)
                    if let metadata = current.metadata {
                        Text(metadata.source == .gameTDB ? "Multiplayer details: GameTDB" : "Multiplayer details: your confirmation")
                            .font(.caption).foregroundStyle(.secondary)
                        Text(metadata.reference).font(.caption).foregroundStyle(.secondary)
                    }
                    switch current.eligibility {
                    case .unverified:
                        Label("Multiplayer Unverified", systemImage: "questionmark.circle")
                        Text("Confirm this game's multiplayer mode to check its available cores. It will stay out of recommendations until then.")
                    case .unavailable(let reason):
                        Label(reason, systemImage: "exclamationmark.triangle")
                    case .supported:
                        Picker("Play with", selection: $optionID) {
                            ForEach(options) { option in
                                Text("\(option.mode.title) · up to \(option.maxPlayers) players · \(coreName(option))").tag(option.id)
                            }
                        }
                        Text("Both players need the same game and compatible core. The running core is checked again before connecting.")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Host This Game", systemImage: "person.2.fill") {
                            if let chosen { onLaunch(chosen, .host, nil) }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!Defaults[.netplayEnabled])
                    }
                    Button("Review Multiplayer Details", systemImage: "info.circle") { showMetadata = true }
                }
                if !roomsForGame.isEmpty {
                    NetplayFormSection("Rooms for This Game") {
                        ForEach(roomsForGame) { room in
                            let option = NetplayLibraryEligibility.option(for: room, entry: current)
                            VStack(alignment: .leading, spacing: 12) {
                                Text("\(room.hostName) · \(room.playerCountDisplay)")
                                if room.isPasswordProtected { SecureField("Room password", text: $password) }
                                if room.gameHash.caseInsensitiveCompare(entry.id) != .orderedSame {
                                    Text("Different ROM: use the same file as the host.").foregroundStyle(.secondary)
                                } else if option == nil && !room.isFull {
                                    Text("This core and multiplayer mode are not verified on this device.").foregroundStyle(.secondary)
                                }
                                Button(room.isFull ? "Room Full" : "Join Room") {
                                    if let option { onLaunch(option, .join(room), password.isEmpty ? nil : password) }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(option == nil || !Defaults[.netplayEnabled] || (room.isPasswordProtected && password.isEmpty))
                            }
                        }
                    }
                }
            }
            .netplayNavigationTitle("Play with Friends")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Back") { dismiss() } } }
        }
        .netplayPresentation(isPresented: $showMetadata, onDismiss: refresh) {
            NetplayMetadataEditor(title: entry.game.title, md5: entry.id, system: entry.game.systemIdentifier, onSave: refresh)
        }
        .onAppear { optionID = options.first?.id ?? "" }
    }

    private var roomsForGame: [NetplayRoom] {
        rooms.filter {
            $0.gameHash.caseInsensitiveCompare(entry.id) == .orderedSame
                || (!$0.gameSerial.isEmpty && $0.gameSerial == entry.game.romSerial && $0.systemIdentifier == entry.game.systemIdentifier)
        }
    }

    private func coreName(_ option: NetplayGameOption) -> String {
        RomDatabase.sharedInstance.realm.object(ofType: PVCore.self, forPrimaryKey: option.core.coreIdentifier)?.projectName ?? option.core.coreIdentifier
    }

    private func refresh() {
        refreshedEntry = NetplayLibraryEligibility.entry(entry.game, realm: RomDatabase.sharedInstance.realm)
        onMetadataChanged()
    }
}
#endif
