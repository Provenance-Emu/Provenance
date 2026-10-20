#if os(iOS) || os(tvOS)
import PVLibrarySharing
import SwiftUI

struct AutomaticLibraryCopySettingsView: View {
    @Bindable private var service = NearbyLibraryAutomaticService.shared
    @Bindable private var sharing = LibrarySharingService.shared

    private var peers: [TrustedPeer] { sharing.trustedPeers.filter { $0.app == PeerApp.iCube.rawValue } }

    var body: some View {
        List {
            SwiftUI.Section {
                if peers.isEmpty {
                    Text("Open a nearby iCube library and pair with it first.").foregroundStyle(.secondary)
                }
                ForEach(peers) { peer in
                    Toggle(peer.name, isOn: Binding(
                        get: { service.enabledPeerIDs.contains(peer.id) },
                        set: { service.setEnabled($0, peerID: peer.id) }
                    ))
                }
            } header: {
                Text("Paired iCube Libraries")
            } footer: {
                Text("Keep both apps open on the same network. New games from enabled libraries are copied into Provenance. "
                     + "Saves and BIOS files stay on the other device. Removing a source or a remote game keeps your local copies.")
            }
            SwiftUI.Section {
                Text(status)
                if let problem = service.discoveryProblem { Text(problem).foregroundStyle(.secondary) }
                Button("Check Again") { service.retry() }.disabled(service.enabledPeerIDs.isEmpty)
                Button("Stop Automatic Copies", role: .destructive) { service.stopAll() }.disabled(service.enabledPeerIDs.isEmpty)
            }
        }
        .navigationTitle("Automatic Game Copies")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await sharing.refreshTrust() }
        .settingsSubpageTracking()
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
