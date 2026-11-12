//
//  NearbyLibrariesView.swift
//  PVSwiftUI
//
//  Settings › Library › Nearby Libraries: iFly and iCube libraries on the
//  local network, a browser for each, and copying a game into the library.
//
//  Rows are buttons and value-based navigation links (see NearbyNavigation.swift),
//  so touch, the tvOS remote and an iOS controller all drive the same controls.
//

#if os(iOS) || os(tvOS)
import PVFeatureFlags
import PVLibrarySharing
import PVSystems
import PVThemes
import SwiftUI

struct NearbyLibrariesView: View {
    @State private var model = NearbyLibrariesModel()
    @State private var showingAddServer = false
    @State private var cursorID: String?
    @ObservedObject private var featureFlags = PVFeatureFlagsManager.shared
    @Environment(NearbyNavigator.self) private var navigator: NearbyNavigator?
    #if os(tvOS)
    @Environment(\.dismiss) private var dismiss
    #endif

    private static let footer = "Turn on Library Sharing in iFly, iCube or Provenance on another device "
        + "on the same Wi-Fi. Copied games are imported into your library; "
        + "BIOS files and saves stay on the other device."

    private var showsOpenSettings: Bool {
        #if os(iOS)
        return model.snapshot.localNetworkDenied
        #else
        return false
        #endif
    }

    private var cursorLayout: TVMediaCursorLayout {
        NearbyCursor.home(
            peerIDs: model.visiblePeers.map(\.id),
            serverPeerIDs: model.contentServers.map { model.contentServerPeer($0).id },
            showsContentServers: featureFlags.contentServerLibraries,
            showsOpenSettings: showsOpenSettings
        )
    }

    var body: some View {
        NearbyScreen(title: "Nearby Libraries", cursorID: cursorID) {
            NearbySection {
                NearbyLinkRow(
                    route: .librarySharing, cursorID: NearbyCursor.librarySharing,
                    title: "Share This Library", systemImage: "square.and.arrow.up.on.square"
                )
                NearbyLinkRow(
                    route: .automaticCopies, cursorID: NearbyCursor.automaticCopies,
                    title: "Automatic Game Copies", systemImage: "arrow.down.circle"
                )
            }

            NearbySection(header: "On This Network", footer: Self.footer) {
                if model.visiblePeers.isEmpty {
                    NearbyNote(text: "Looking for libraries on this network…", showsProgress: true)
                }
                ForEach(model.visiblePeers) { peer in
                    peerRow(peer, summary: model.loadedSummaries[peer.id])
                }
            }

            if featureFlags.contentServerLibraries {
                contentServers
            }

            if model.snapshot.localNetworkDenied {
                localNetworkDenied
            }

            ForEach(model.browseProblems) { problem in
                NearbyNote(text: problem.message, systemImage: "exclamationmark.triangle", tint: .orange)
            }
        }
        .navigationDestination(for: NearbyRoute.self) { route in
            destination(route)
        }
        // Keep the presenter outside the scroll content, which discovery rebuilds as peers come and go.
        .sheet(isPresented: $showingAddServer) {
            AddContentServerView { url, username, password, token in
                model.addContentServer(url: url, username: username, password: password, accessToken: token)
            }
            .environment(navigator)
        }
        .onChange(of: showingAddServer) { _, isShowing in
            navigator?.isSubsheetPresented = isShowing
        }
        .onChange(of: featureFlags.contentServerLibraries) { _, enabled in
            if !enabled { showingAddServer = false }
        }
        .nearbyControllerCursor(cursorLayout, cursor: $cursorID, scope: .screen(nil), onActivate: activate)
        .onAppear { model.start() }
        .onDisappear { model.stop() }
        #if os(tvOS)
        .onExitCommand { dismiss() }
        #endif
        .settingsSubpageTracking()
    }

    private func peerRow(_ peer: DiscoveredPeer, summary: String?) -> some View {
        NearbyLinkRow(
            route: .peer(id: peer.id),
            cursorID: NearbyCursor.peer(peer.id),
            title: peer.serviceName,
            subtitle: summary ?? "\(peer.appDisplayName) · Open to browse",
            systemImage: NearbyPeerSymbol.symbol(for: peer.app),
            badge: peer.appDisplayName
        )
    }

    private var contentServers: some View {
        NearbySection(
            header: "Content Servers",
            footer: "An emulator-content-server on your network or at home. "
                + "Provenance keeps a sign-in token in the Keychain, never your password."
        ) {
            ForEach(Array(model.contentServers.enumerated()), id: \.element.id) { index, server in
                let peer = model.contentServerPeer(server)
                HStack(spacing: NearbyMetrics.rowSpacing) {
                    peerRow(peer, summary: model.loadedSummaries[peer.id] ?? server.username)
                    Button(role: .destructive) {
                        model.removeContentServers(at: IndexSet(integer: index))
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                    .buttonStyle(NearbyChipButtonStyle(cursorID: NearbyCursor.removeServer(peer.id)))
                }
            }
            Button {
                showingAddServer = true
            } label: {
                NearbyRowLabel(title: "Add Content Server…", systemImage: "plus.circle")
            }
            .buttonStyle(NearbyRowButtonStyle(cursorID: NearbyCursor.addServer))
        }
    }

    private var localNetworkDenied: some View {
        NearbySection(
            footer: "Allow Local Network access for Provenance in Settings › Privacy & Security › Local Network."
        ) {
            NearbyNote(
                text: "Provenance can't see the local network.", systemImage: "wifi.exclamationmark", tint: .orange
            )
            #if os(iOS)
            Button(action: openSystemSettings) {
                NearbyRowLabel(title: "Open Settings", systemImage: "gear")
            }
            .buttonStyle(NearbyRowButtonStyle(cursorID: NearbyCursor.openSettings))
            #endif
        }
    }

    @ViewBuilder
    private func destination(_ route: NearbyRoute) -> some View {
        switch route {
        case .librarySharing:
            LibrarySharingSettingsView()
        case .automaticCopies:
            AutomaticLibraryCopySettingsView()
        case .peer(let id):
            if let peerModel = model.peerModel(forPeerID: id) {
                NearbyPeerLibraryView(model: peerModel)
            } else {
                ContentUnavailableView("This library is no longer on the network", systemImage: "wifi.slash")
                    .nearbyControllerCursor(.empty, cursor: .constant(nil), scope: .screen(route)) { _ in }
            }
        }
    }

    private func activate(_ item: String) {
        switch item {
        case NearbyCursor.librarySharing:
            navigator?.push(.librarySharing)
        case NearbyCursor.automaticCopies:
            navigator?.push(.automaticCopies)
        case NearbyCursor.addServer:
            showingAddServer = true
        case NearbyCursor.openSettings:
            openSystemSettings()
        default:
            let peers = model.visiblePeers + model.contentServers.map(model.contentServerPeer)
            if let peer = peers.first(where: { NearbyCursor.peer($0.id) == item }) {
                navigator?.push(.peer(id: peer.id))
            } else if let index = model.contentServers.firstIndex(where: {
                NearbyCursor.removeServer(model.contentServerPeer($0).id) == item
            }) {
                model.removeContentServers(at: IndexSet(integer: index))
            }
        }
    }

    private func openSystemSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}

/// Nearby Libraries presented from the library itself (side menu on iOS, the
/// TV sidebar rail), not pushed from Settings: it owns its navigation path, so
/// a controller can push and pop its screens.
struct NearbyLibrariesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var navigator = NearbyNavigator()

    var body: some View {
        NavigationStack(path: $navigator.path) {
            NearbyLibrariesView()
                #if os(iOS)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
                #endif
        }
        .environment(navigator)
        .onAppear {
            navigator.onClose = { dismiss() }
        }
    }
}

enum NearbyPeerSymbol {
    static func symbol(for app: PeerApp) -> String {
        switch app {
        case .iFly: return "opticaldisc"
        case .iCube: return "cube"
        case .pvLibrary: return "books.vertical"
        case .contentServer: return "server.rack"
        }
    }
}

/// URL, username and password for a content server. The password is used
/// once to sign in and is not stored.
private struct AddContentServerView: View {
    let onAdd: (URL, String, String, String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var username = ""
    @State private var password = ""
    @State private var accessToken = ""
    @State private var useToken = true
    @State private var cursorID: String?
    @FocusState private var editingField: String?

    private var url: URL? { try? ECSConnection.origin(for: address) }

    private var canAdd: Bool {
        url != nil && (useToken ? !accessToken.isEmpty : !(username.isEmpty || password.isEmpty))
    }

    var body: some View {
        NavigationStack {
            NearbyScreen(title: "Add Content Server", cursorID: cursorID) {
                NearbySection {
                    NearbyTextFieldRow(
                        placeholder: "Address (192.168.1.10:8473)", text: $address,
                        cursorID: NearbyCursor.address, editing: $editingField
                    )
                    #if os(iOS)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    #endif
                    NearbySwitchRow(title: "Use access token", cursorID: NearbyCursor.useToken, isOn: $useToken)
                    if useToken {
                        NearbyTextFieldRow(
                            placeholder: "Read access token", text: $accessToken,
                            cursorID: NearbyCursor.token, isSecure: true, editing: $editingField
                        )
                    } else {
                        NearbyTextFieldRow(
                            placeholder: "Username", text: $username,
                            cursorID: NearbyCursor.username, editing: $editingField
                        )
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        NearbyTextFieldRow(
                            placeholder: "Password", text: $password,
                            cursorID: NearbyCursor.password, isSecure: true, editing: $editingField
                        )
                    }
                }
                HStack(spacing: NearbyMetrics.rowSpacing) {
                    Spacer()
                    Button("Cancel", role: .cancel) { dismiss() }
                        .buttonStyle(NearbyChipButtonStyle(cursorID: NearbyCursor.cancel))
                    Button("Add", action: add)
                        .buttonStyle(NearbyChipButtonStyle(cursorID: NearbyCursor.add, isSelected: true))
                        .disabled(!canAdd)
                }
            }
        }
        .nearbyControllerCursor(
            NearbyCursor.addServer(usesToken: useToken),
            cursor: $cursorID,
            scope: .subsheet,
            isEditingText: editingField != nil,
            onBack: back,
            onActivate: activate
        )
    }

    private func add() {
        guard let url else { return }
        onAdd(url, useToken ? "" : username, useToken ? "" : password, useToken ? accessToken : nil)
        dismiss()
    }

    /// B: leave the field being typed in first, then close.
    private func back() {
        if editingField != nil {
            editingField = nil
        } else {
            dismiss()
        }
    }

    private func activate(_ item: String) {
        switch item {
        case NearbyCursor.useToken: useToken.toggle()
        case NearbyCursor.cancel: dismiss()
        case NearbyCursor.add: if canAdd { add() }
        default: editingField = item
        }
    }
}
#endif
