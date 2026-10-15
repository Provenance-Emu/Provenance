//
//  LibrarySharingSettingsView.swift
//  PVSwiftUI
//
//  Settings › Library › Nearby Libraries › Share This Library.
//

#if os(iOS) || os(tvOS)
import PVLibrarySharing
import PVSystems
import SwiftUI

struct LibrarySharingSettingsView: View {
    @Bindable private var service = LibrarySharingService.shared

    var body: some View {
        List {
            SwiftUI.Section {
                Toggle("Share This Library", isOn: $service.isEnabled)
                statusRow
            } footer: {
                Text("Nearby devices on this Wi-Fi can browse and copy the games they can play: another Provenance sees every "
                     + "system you share, iFly only Dreamcast and arcade boards, iCube only GameCube and Wii. "
                     + "BIOS files and saves are never shared. "
                     + sharingScope)
            }

            SwiftUI.Section("Systems") {
                ForEach(service.librarySystems, id: \.self) { system in
                    Toggle(system.fullName, isOn: Binding(
                        get: { !service.excludedSystems.contains(system.rawValue) },
                        set: { shared in
                            if shared {
                                service.excludedSystems.remove(system.rawValue)
                            } else {
                                service.excludedSystems.insert(system.rawValue)
                            }
                        }
                    ))
                }
            }

            SwiftUI.Section {
                if service.trustedPeers.isEmpty {
                    Text("No devices yet. A device appears here once you let it browse.")
                        .foregroundStyle(.secondary)
                }
                ForEach(service.trustedPeers) { peer in
                    TrustedPeerRow(peer: peer, grant: service.grants[peer.id] ?? .askPerGame)
                }
            } header: {
                Text("Trusted Devices")
            } footer: {
                Text("Removing a device ends its access at once; it has to ask again.")
            }
        }
        .navigationTitle("Share This Library")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await service.refreshTrust()
            await service.loadLibrarySystems()
        }
        .settingsSubpageTracking()
    }

    private var sharingScope: String {
        #if os(iOS)
        return "Sharing runs while Provenance is open."
        #else
        return "Sharing runs while Provenance is open on this Apple TV."
        #endif
    }

    @ViewBuilder
    private var statusRow: some View {
        switch service.status {
        case .off:
            EmptyView()
        case .starting:
            Label("Starting…", systemImage: "hourglass")
                .foregroundStyle(.secondary)
        case .running:
            Label("Sharing on this network", systemImage: "antenna.radiowaves.left.and.right")
                .foregroundStyle(.green)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
        }
    }
}

private struct TrustedPeerRow: View {
    let peer: TrustedPeer
    let grant: LibraryGrant

    var body: some View {
        let service = LibrarySharingService.shared
        VStack(alignment: .leading, spacing: 6) {
            Text(peer.name)
            Text(PeerApp(rawValue: peer.app)?.displayName ?? peer.app)
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("Access", selection: Binding(get: { grant }, set: { service.setGrant($0, for: peer) })) {
                Text("Everything").tag(LibraryGrant.everything)
                Text("Ask for Each Game").tag(LibraryGrant.askPerGame)
                Text("Nothing").tag(LibraryGrant.denied)
            }
            Button("Remove Device", role: .destructive) { service.remove(peer) }
                #if os(iOS)
                .buttonStyle(.borderless)
                #endif
        }
        .padding(.vertical, 4)
    }
}
#endif
