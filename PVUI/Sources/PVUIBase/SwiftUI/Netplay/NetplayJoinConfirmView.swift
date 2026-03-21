//
//  NetplayJoinConfirmView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/21/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if !os(watchOS)
import SwiftUI
import PVNetplay

/// Pre-join confirmation screen that verifies the local ROM hash matches the host's.
///
/// Shown before joining a room so the player knows immediately if there is a
/// ROM version mismatch. A mismatch doesn't block joining (desync is the host's
/// problem), but it shows a prominent warning to set expectations.
///
/// Usage:
/// ```swift
/// NetplayJoinConfirmView(room: selectedRoom, localGameHash: game.md5Hash) {
///     performJoin(room: selectedRoom)
/// } onCancel: {
///     dismiss()
/// }
/// ```
@MainActor
public struct NetplayJoinConfirmView: View {

    // MARK: - Properties

    let room: NetplayRoom
    let localGameHash: String
    var onConfirm: () -> Void
    var onCancel: () -> Void

    private var hashesMatch: Bool {
        !localGameHash.isEmpty &&
        !room.gameHash.isEmpty &&
        localGameHash.lowercased() == room.gameHash.lowercased()
    }

    private var localHashUnknown: Bool { localGameHash.isEmpty }
    private var remoteHashUnknown: Bool { room.gameHash.isEmpty }

    // MARK: - Init

    public init(
        room: NetplayRoom,
        localGameHash: String,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.room = room
        self.localGameHash = localGameHash
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    hashStatusHeader
                    roomInfoSection
                    hashDetailSection
                    if !hashesMatch && !localHashUnknown && !remoteHashUnknown {
                        mismatchWarning
                    }
                }
                .padding()
            }
            .navigationTitle("Join Room")
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel, action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(hashesMatch ? "Join" : "Join Anyway") {
                        onConfirm()
                    }
                    .bold(hashesMatch)
                    .tint(hashesMatch ? .accentColor : .orange)
                }
            }
        }
    }

    // MARK: - Subviews

    private var hashStatusHeader: some View {
        VStack(spacing: 12) {
            statusIcon
                .font(.system(size: 56))
            Text(statusTitle)
                .font(.title2.bold())
            Text(statusSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var statusIcon: some View {
        if localHashUnknown || remoteHashUnknown {
            Image(systemName: "questionmark.circle.fill")
                .foregroundStyle(.gray)
        } else if hashesMatch {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
    }

    private var statusTitle: String {
        if localHashUnknown || remoteHashUnknown {
            return "Hash Unknown"
        } else if hashesMatch {
            return "ROM Verified"
        } else {
            return "ROM Mismatch"
        }
    }

    private var statusSubtitle: String {
        if localHashUnknown {
            return "Your ROM hash couldn't be determined.\nJoining may result in desync."
        } else if remoteHashUnknown {
            return "The host didn't advertise a ROM hash.\nJoining may result in desync."
        } else if hashesMatch {
            return "Your ROM matches the host's.\nYou're good to go."
        } else {
            return "Your ROM version differs from the host's.\nYou may experience desync during gameplay."
        }
    }

    private var roomInfoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Room Info")
            VStack(spacing: 0) {
                infoRow(icon: "person.fill", label: "Host", value: room.hostName)
                Divider().padding(.leading, 44)
                infoRow(icon: "gamecontroller.fill", label: "Game", value: room.gameName)
                Divider().padding(.leading, 44)
                infoRow(icon: "person.2.fill", label: "Players",
                        value: room.playerCountDisplay)
                if let ping = room.pingMS {
                    Divider().padding(.leading, 44)
                    infoRow(icon: "waveform.path.ecg", label: "Ping",
                            value: "\(ping) ms")
                }
                if room.isPasswordProtected {
                    Divider().padding(.leading, 44)
                    infoRow(icon: "lock.fill", label: "Password", value: "Required")
                }
            }
            #if os(tvOS)
            .background(Color.white.opacity(0.1))
            #elseif canImport(UIKit)
            .background(Color(.secondarySystemGroupedBackground))
            #else
            .background(Color.primary.opacity(0.05))
            #endif
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var hashDetailSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("ROM Verification")
            VStack(spacing: 0) {
                hashRow(label: "Host ROM", hash: room.gameHash)
                Divider().padding(.leading, 44)
                hashRow(label: "Your ROM", hash: localGameHash)
            }
            #if os(tvOS)
            .background(Color.white.opacity(0.1))
            #elseif canImport(UIKit)
            .background(Color(.secondarySystemGroupedBackground))
            #else
            .background(Color.primary.opacity(0.05))
            #endif
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var mismatchWarning: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text("ROM Version Mismatch")
                    .font(.subheadline.bold())
                Text("Different ROM versions can cause the game to desync mid-session. For best results, use the same ROM dump as the host.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        #if os(tvOS)
        .background(Color.orange.opacity(0.15))
        #elseif canImport(UIKit)
        .background(Color.orange.opacity(0.1))
        #else
        .background(Color.orange.opacity(0.1))
        #endif
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            .padding(.bottom, 6)
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    private func hashRow(label: String, hash: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: hash.isEmpty ? "questionmark.circle" : "number")
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            if hash.isEmpty {
                Text("Unknown")
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
            } else {
                Text(String(hash.prefix(8)) + "…")
                    .font(.caption.monospaced())
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Hash Match") {
    NetplayJoinConfirmView(
        room: NetplayRoom(
            hostName: "Alice's iPhone",
            gameName: "Super Mario World",
            gameHash: "abc123def456",
            coreIdentifier: "com.provenance.snes9x",
            maxPlayers: 2,
            currentPlayers: 1,
            pingMS: 14,
            isLAN: true,
            hostAddress: "192.168.1.42",
            port: 55435
        ),
        localGameHash: "abc123def456",
        onConfirm: {},
        onCancel: {}
    )
}

#Preview("Hash Mismatch") {
    NetplayJoinConfirmView(
        room: NetplayRoom(
            hostName: "Bob's iPad",
            gameName: "Super Mario World",
            gameHash: "abc123def456",
            coreIdentifier: "com.provenance.snes9x",
            maxPlayers: 2,
            currentPlayers: 1,
            pingMS: 32,
            isLAN: true,
            hostAddress: "192.168.1.55",
            port: 55435
        ),
        localGameHash: "zzz999aaa000",
        onConfirm: {},
        onCancel: {}
    )
}

#Preview("Unknown Hash") {
    NetplayJoinConfirmView(
        room: NetplayRoom(
            hostName: "Charlie's Apple TV",
            gameName: "Sonic the Hedgehog",
            gameHash: "",
            coreIdentifier: "com.provenance.genesis",
            maxPlayers: 4,
            currentPlayers: 2,
            isLAN: true,
            hostAddress: "192.168.1.10",
            port: 55435
        ),
        localGameHash: "",
        onConfirm: {},
        onCancel: {}
    )
}
#endif

#endif
