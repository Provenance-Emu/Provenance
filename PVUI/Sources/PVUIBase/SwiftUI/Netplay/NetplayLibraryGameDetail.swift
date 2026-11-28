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
    let onLaunch: (NetplayGameOption, NetplayLaunchIntent.Action, String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var optionID = ""
    @State private var password = ""
    /// The iOS controller cursor (plain state: iOS has no focus engine for buttons).
    @State private var cursor: String?
    @FocusState private var passwordFocused: Bool

    private var options: [NetplayGameOption] { entry.eligibility.options }
    private var chosen: NetplayGameOption? { options.first { $0.id == optionID } ?? options.first }

    var body: some View {
        NavigationStack {
            NetplayForm {
                NetplayFormSection {
                    GameItemView(game: entry.game, viewType: .row) { }
                        .allowsHitTesting(false)
                    if let hint = entry.hint.label {
                        Label(hint, systemImage: entry.hint == .reportedBroken ? "exclamationmark.bubble" : "checkmark.bubble")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .accessibilityIdentifier("netplay.detail.hint")
                    }
                    switch entry.eligibility {
                    case .unavailable(let reason):
                        Label(reason, systemImage: "exclamationmark.triangle")
                            .accessibilityIdentifier("netplay.detail.unavailable")
                    case .available:
                        Text("Play with").font(.subheadline).foregroundStyle(.secondary)
                        ForEach(options) { option in
                            let id = NetplayDetailCursor.option(option.id)
                            NetplayChoiceChip(title: "\(option.mode.title) · up to \(option.maxPlayers) players · \(coreName(option))",
                                              selected: option.id == chosen?.id, isCursor: cursor == id) {
                                optionID = option.id
                            }
                            .netplayCursorItem(id, cursor: cursor, cornerRadius: 16)
                        }
                        Text("Both players need the same game and compatible core. The running core is checked again before connecting.")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Host This Game", systemImage: "person.2.fill", action: host)
                            .netplayButtonStyle(prominent: true)
                            .disabled(!Defaults[.netplayEnabled])
                            .netplayCursorItem(NetplayDetailCursor.host, cursor: cursor)
                    }
                }
                if !roomsForGame.isEmpty {
                    NetplayFormSection("Rooms for This Game") {
                        ForEach(roomsForGame) { room in
                            let option = NetplayLibraryEligibility.option(for: room, entry: entry)
                            VStack(alignment: .leading, spacing: 12) {
                                Text("\(room.hostName) · \(room.playerCountDisplay)")
                                if room.isPasswordProtected {
                                    SecureField("Room password", text: $password)
                                        .focused($passwordFocused)
                                        .netplayCursorItem(NetplayDetailCursor.password(room.id), cursor: cursor)
                                }
                                if room.gameHash.caseInsensitiveCompare(entry.id) != .orderedSame {
                                    Text("Different ROM: use the same file as the host.").foregroundStyle(.secondary)
                                } else if option == nil && !room.isFull {
                                    Text("The host uses a core or version that is not installed on this device.").foregroundStyle(.secondary)
                                }
                                Button(room.isFull ? "Room Full" : "Join Room") { join(room) }
                                    .netplayButtonStyle(prominent: true)
                                    .disabled(!canJoin(room))
                                    .netplayCursorItem(NetplayDetailCursor.join(room.id), cursor: cursor)
                            }
                        }
                    }
                }
            }
            .netplayNavigationTitle("Play with Friends")
            #if !os(tvOS)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Back") { dismiss() } } }
            #endif
            .netplayControllerNavigation(cursorRows, cursor: $cursor) {
                if passwordFocused { passwordFocused = false } else { dismiss() }
            }
        }
        .onAppear { optionID = options.first?.id ?? "" }
    }

    private var roomsForGame: [NetplayRoom] {
        rooms.filter {
            $0.gameHash.caseInsensitiveCompare(entry.id) == .orderedSame
                || (!$0.gameSerial.isEmpty && $0.gameSerial == entry.game.romSerial && $0.systemIdentifier == entry.game.systemIdentifier)
        }
    }

    private func host() {
        if let chosen { onLaunch(chosen, .host, nil) }
    }

    private func canJoin(_ room: NetplayRoom) -> Bool {
        NetplayLibraryEligibility.option(for: room, entry: entry) != nil && Defaults[.netplayEnabled]
            && !(room.isPasswordProtected && password.isEmpty)
    }

    private func join(_ room: NetplayRoom) {
        guard canJoin(room), let option = NetplayLibraryEligibility.option(for: room, entry: entry) else { return }
        onLaunch(option, .join(room), password.isEmpty ? nil : password)
    }

    /// What the iOS controller cursor can reach, in the order it is drawn.
    private var cursorRows: [NetplayCursorRow] {
        var rows: [NetplayCursorRow] = []
        if case .available = entry.eligibility {
            rows += options.map { option in
                .single(NetplayCursorTarget(id: NetplayDetailCursor.option(option.id)) { optionID = option.id }, isHeader: true)
            }
            rows.append(.single(NetplayCursorTarget(id: NetplayDetailCursor.host, isEnabled: Defaults[.netplayEnabled], action: host)))
        }
        for room in roomsForGame {
            if room.isPasswordProtected {
                rows.append(.single(NetplayCursorTarget(id: NetplayDetailCursor.password(room.id)) { passwordFocused = true }))
            }
            rows.append(.single(NetplayCursorTarget(id: NetplayDetailCursor.join(room.id), isEnabled: canJoin(room)) { join(room) }))
        }
        return rows
    }

    private func coreName(_ option: NetplayGameOption) -> String {
        RomDatabase.sharedInstance.realm.object(ofType: PVCore.self, forPrimaryKey: option.core.coreIdentifier)?.projectName ?? option.core.coreIdentifier
    }
}
/// Cursor IDs on a game's Network Play screen.
enum NetplayDetailCursor {
    static let host = "host"

    static func option(_ id: String) -> String { "option.\(id)" }
    static func password(_ room: UUID) -> String { "password.\(room)" }
    static func join(_ room: UUID) -> String { "join.\(room)" }
}
#endif
