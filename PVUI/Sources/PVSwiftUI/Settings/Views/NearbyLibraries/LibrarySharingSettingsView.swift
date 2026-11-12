//
//  LibrarySharingSettingsView.swift
//  PVSwiftUI
//
//  Settings › Library › Nearby Libraries › Share This Library.
//

#if os(iOS) || os(tvOS)
import PVLibrarySharing
import PVSystems
import PVThemes
import SwiftUI

struct LibrarySharingSettingsView: View {
    @Bindable private var service = LibrarySharingService.shared
    @State private var cursorID: String?
    @ObservedObject private var themeManager = ThemeManager.shared

    /// Access levels in the order their buttons are drawn.
    static let grants: [LibraryGrant] = [.everything, .askPerGame, .denied]

    var body: some View {
        NearbyScreen(title: "Share This Library", cursorID: cursorID) {
            NearbySection(
                footer: "Nearby devices on this Wi-Fi can browse and copy the games they can play: "
                    + "another Provenance sees every system you share, iFly only Dreamcast and arcade boards, "
                    + "iCube only GameCube and Wii. "
                    + "BIOS files and saves are never shared. " + sharingScope
            ) {
                NearbySwitchRow(
                    title: "Share This Library", cursorID: NearbyCursor.sharingSwitch, isOn: $service.isEnabled
                )
                statusRow
            }

            if !service.librarySystems.isEmpty {
                NearbySection(header: "Systems") {
                    ForEach(service.librarySystems, id: \.self) { system in
                        NearbySwitchRow(
                            title: system.fullName,
                            cursorID: NearbyCursor.system(system.rawValue),
                            isOn: sharedBinding(system)
                        )
                    }
                }
            }

            NearbySection(
                header: "Trusted Devices",
                footer: "Removing a device ends its access at once; it has to ask again."
            ) {
                if service.trustedPeers.isEmpty {
                    NearbyNote(text: "No devices yet. A device appears here once you let it browse.")
                }
                ForEach(service.trustedPeers) { peer in
                    TrustedPeerRow(peer: peer, grant: service.grants[peer.id] ?? .askPerGame)
                }
            }
        }
        .nearbyControllerCursor(
            cursorLayout, cursor: $cursorID, scope: .screen(.librarySharing), onActivate: activate
        )
        .task {
            await service.refreshTrust()
            await service.loadLibrarySystems()
        }
        .settingsSubpageTracking()
    }

    private var cursorLayout: TVMediaCursorLayout {
        NearbyCursor.librarySharing(
            systems: service.librarySystems.map(\.rawValue),
            trustedPeerIDs: service.trustedPeers.map(\.id),
            grants: Self.grants.map(\.rawValue)
        )
    }

    private func sharedBinding(_ system: SystemIdentifier) -> Binding<Bool> {
        Binding(
            get: { !service.excludedSystems.contains(system.rawValue) },
            set: { shared in
                if shared {
                    service.excludedSystems.remove(system.rawValue)
                } else {
                    service.excludedSystems.insert(system.rawValue)
                }
            }
        )
    }

    private func activate(_ id: String) {
        if id == NearbyCursor.sharingSwitch {
            service.isEnabled.toggle()
            return
        }
        if let system = service.librarySystems.first(where: { NearbyCursor.system($0.rawValue) == id }) {
            sharedBinding(system).wrappedValue.toggle()
            return
        }
        for peer in service.trustedPeers {
            if id == NearbyCursor.removePeer(peer.id) {
                service.remove(peer)
                return
            }
            if let grant = Self.grants.first(where: { NearbyCursor.grant($0.rawValue, peer: peer.id) == id }) {
                service.setGrant(grant, for: peer)
                return
            }
        }
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
            NearbyNote(text: "Starting…", systemImage: "hourglass")
        case .running:
            NearbyNote(text: "Sharing on this network", systemImage: "antenna.radiowaves.left.and.right", tint: .green)
        case .failed(let message):
            NearbyNote(text: message, systemImage: "exclamationmark.triangle", tint: .orange)
        }
    }
}

/// A trusted device: its access level as three buttons, and Remove. Every control is a
/// button of its own, so the TV remote and a controller can reach each one.
private struct TrustedPeerRow: View {
    let peer: TrustedPeer
    let grant: LibraryGrant
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        let service = LibrarySharingService.shared
        VStack(alignment: .leading, spacing: NearbyMetrics.rowSpacing) {
            NearbyRowLabel(title: peer.name, subtitle: PeerApp(rawValue: peer.app)?.displayName ?? peer.app)
                .padding(.horizontal, NearbyMetrics.rowPadding.leading)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: NearbyMetrics.rowSpacing) {
                    ForEach(LibrarySharingSettingsView.grants, id: \.self) { choice in
                        Button(Self.title(for: choice)) { service.setGrant(choice, for: peer) }
                            .buttonStyle(NearbyChipButtonStyle(
                                cursorID: NearbyCursor.grant(choice.rawValue, peer: peer.id),
                                isSelected: choice == grant
                            ))
                    }
                    Button("Remove Device", role: .destructive) { service.remove(peer) }
                        .buttonStyle(NearbyChipButtonStyle(cursorID: NearbyCursor.removePeer(peer.id)))
                }
                .padding(NearbyMetrics.highlightBorderWidth * 4)
            }
        }
        .padding(.vertical, NearbyMetrics.rowSpacing)
        .background(
            RoundedRectangle(cornerRadius: NearbyMetrics.cornerRadius, style: .continuous)
                .fill(Color.white.opacity(NearbyMetrics.restingFillOpacity))
        )
    }

    static func title(for grant: LibraryGrant) -> String {
        switch grant {
        case .everything: return "Everything"
        case .askPerGame: return "Ask for Each Game"
        case .denied: return "Nothing"
        }
    }
}
#endif
