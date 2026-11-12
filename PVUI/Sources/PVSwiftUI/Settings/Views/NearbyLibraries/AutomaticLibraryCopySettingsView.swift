#if os(iOS) || os(tvOS)
import PVLibrarySharing
import SwiftUI

struct AutomaticLibraryCopySettingsView: View {
    @Bindable private var service = NearbyLibraryAutomaticService.shared
    @Bindable private var sharing = LibrarySharingService.shared
    @State private var cursorID: String?

    private var peers: [TrustedPeer] { sharing.trustedPeers.filter { $0.app == PeerApp.iCube.rawValue } }

    private var hasEnabledSources: Bool { !service.enabledPeerIDs.isEmpty }

    var body: some View {
        NearbyScreen(title: "Automatic Game Copies", cursorID: cursorID) {
            NearbySection(
                header: "Paired iCube Libraries",
                footer: "Keep both apps open on the same network. New games from enabled libraries are copied "
                    + "into Provenance. Saves and BIOS files stay on the other device. "
                    + "Removing a source or a remote game keeps your local copies."
            ) {
                if peers.isEmpty {
                    NearbyNote(text: "Open a nearby iCube library and pair with it first.")
                }
                ForEach(peers) { peer in
                    NearbySwitchRow(
                        title: peer.name, cursorID: NearbyCursor.source(peer.id), isOn: enabledBinding(peer)
                    )
                }
            }
            NearbySection {
                NearbyNote(text: status)
                if let problem = service.discoveryProblem {
                    NearbyNote(text: problem)
                }
                if hasEnabledSources {
                    Button { service.retry() } label: {
                        NearbyRowLabel(title: "Check Again", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(NearbyRowButtonStyle(cursorID: NearbyCursor.checkAgain))
                    Button(role: .destructive) { service.stopAll() } label: {
                        NearbyRowLabel(title: "Stop Automatic Copies", systemImage: "stop.circle")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(NearbyRowButtonStyle(cursorID: NearbyCursor.stopAll))
                }
            }
        }
        .nearbyControllerCursor(
            NearbyCursor.automaticCopies(peerIDs: peers.map(\.id), hasEnabledSources: hasEnabledSources),
            cursor: $cursorID,
            scope: .screen(.automaticCopies),
            onActivate: activate
        )
        .task { await sharing.refreshTrust() }
        .settingsSubpageTracking()
    }

    private func enabledBinding(_ peer: TrustedPeer) -> Binding<Bool> {
        Binding(
            get: { service.enabledPeerIDs.contains(peer.id) },
            set: { service.setEnabled($0, peerID: peer.id) }
        )
    }

    private func activate(_ id: String) {
        switch id {
        case NearbyCursor.checkAgain: service.retry()
        case NearbyCursor.stopAll: service.stopAll()
        default:
            if let peer = peers.first(where: { NearbyCursor.source($0.id) == id }) {
                enabledBinding(peer).wrappedValue.toggle()
            }
        }
    }

    private var status: String {
        switch service.state {
        case .disabled: return "Automatic copies are off."
        case .waiting: return "Waiting for a paired source nearby. Copying pauses during games and while this app is inactive."
        case .checking: return "Checking a nearby library…"
        case .copying: return "Copying and importing a game…"
        case .upToDate: return "All offered games have verified local copies."
        case .failed(_, let message): return message
        }
    }
}
#endif
