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
import EmulatorContentClient
import PVLibrarySharing
import PVSystems
import PVThemes
import SwiftUI

struct NearbyLibrariesView: View {
    @State private var model: NearbyLibrariesModel
    var onOpenServer: ((String) -> Void)?
    @State private var discovery = ContentServerDiscovery()
    @State private var addServer: AddServerTarget?
    @State private var initialServer: DiscoveredContentServer?
    @State private var addedPeerID: String?
    @State private var cursorID: String?
    @Environment(NearbyNavigator.self) private var navigator: NearbyNavigator?
    #if os(tvOS)
    @Environment(\.dismiss) private var dismiss
    #endif

    init(initialServer: DiscoveredContentServer? = nil, model: NearbyLibrariesModel? = nil, onOpenServer: ((String) -> Void)? = nil) {
        _initialServer = State(initialValue: initialServer)
        _model = State(initialValue: model ?? NearbyLibrariesModel())
        self.onOpenServer = onOpenServer
    }

    private struct AddServerTarget: Identifiable {
        let address: String
        var id: String { address }
    }

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
            peerIDs: model.visiblePeers.map(\.id) + unconfiguredServers.map { $0.id.uuidString },
            serverPeerIDs: model.contentServers.map { model.contentServerPeer($0).id },
            showsContentServers: true,
            showsOpenSettings: showsOpenSettings
        )
    }

    private var unconfiguredServers: [DiscoveredContentServer] {
        discovery.servers.filter { candidate in
            !model.contentServers.contains { $0.url == candidate.origin }
        }
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
                if model.visiblePeers.isEmpty && unconfiguredServers.isEmpty {
                    NearbyNote(text: "Looking for libraries on this network…", showsProgress: true)
                }
                ForEach(model.visiblePeers) { peer in
                    peerRow(peer, summary: model.loadedSummaries[peer.id])
                }
                ForEach(unconfiguredServers) { server in
                    Button {
                        addServer = AddServerTarget(address: server.origin.absoluteString)
                    } label: {
                        NearbyRowLabel(title: server.name, subtitle: "Emulation Server", systemImage: "server.rack")
                    }
                    .buttonStyle(NearbyRowButtonStyle(cursorID: NearbyCursor.peer(server.id.uuidString)))
                }
            }

            contentServers

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
        .sheet(item: $addServer, onDismiss: openAddedServer) { target in
            AddContentServerView(address: target.address) { url, username, password, token in
                model.addContentServer(url: url, username: username, password: password, accessToken: token)
                if let server = model.contentServers.first(where: { $0.url == url }) {
                    addedPeerID = model.contentServerPeer(server).id
                }
            }
            .environment(navigator)
            .nearbySheetBackdrop()
        }
        .onChange(of: addServer?.id) { _, id in
            navigator?.isSubsheetPresented = id != nil
        }
        .nearbyControllerCursor(cursorLayout, cursor: $cursorID, scope: .screen(nil), onActivate: activate)
        .onAppear {
            model.start()
            discovery.start()
            if let target = initialServer {
                initialServer = nil
                if let server = model.contentServers.first(where: { $0.url == target.origin }) {
                    openServer(model.contentServerPeer(server).id)
                } else {
                    addServer = AddServerTarget(address: target.origin.absoluteString)
                }
            }
        }
        .onDisappear {
            model.stop()
            discovery.stop()
        }
        #if os(tvOS)
        .onExitCommand { dismiss() }
        #endif
        .settingsSubpageTracking()
    }

    private func openAddedServer() {
        guard let id = addedPeerID else { return }
        addedPeerID = nil
        openServer(id)
    }

    private func openServer(_ id: String) {
        if let onOpenServer {
            onOpenServer(id)
        } else {
            navigator?.push(.peer(id: id))
        }
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
                addServer = AddServerTarget(address: "")
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
            addServer = AddServerTarget(address: "")
        case NearbyCursor.openSettings:
            openSystemSettings()
        default:
            let peers = model.visiblePeers + model.contentServers.map(model.contentServerPeer)
            if let peer = peers.first(where: { NearbyCursor.peer($0.id) == item }) {
                navigator?.push(.peer(id: peer.id))
            } else if let server = unconfiguredServers.first(where: { NearbyCursor.peer($0.id.uuidString) == item }) {
                addServer = AddServerTarget(address: server.origin.absoluteString)
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
    var initialServer: DiscoveredContentServer? = nil
    var model: NearbyLibrariesModel? = nil
    var onOpenServer: ((String) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var navigator = NearbyNavigator()

    var body: some View {
        NavigationStack(path: $navigator.path) {
            NearbyLibrariesView(initialServer: initialServer, model: model, onOpenServer: onOpenServer)
                #if os(iOS)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
                #endif
        }
        .environment(navigator)
        .nearbySheetBackdrop()
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
    @State private var allowPairingHTTP = false
    @State private var pairing: PairingTarget?
    @State private var paired = false
    #if os(iOS)
    @State private var showingInvitationScanner = false
    #endif
    @State private var pairingError: String?

    private struct PairingTarget: Identifiable {
        let origin: URL
        let client: DevicePairingClient
        var id: URL { origin }
    }
    @State private var cursorID: String?
    @FocusState private var editingField: String?

    init(address: String, onAdd: @escaping (URL, String, String, String?) -> Void) {
        _address = State(initialValue: address)
        self.onAdd = onAdd
    }

    private var url: URL? { try? ECSConnection.origin(for: address) }

    private var canAdd: Bool {
        url != nil && (useToken ? !accessToken.isEmpty : username.isEmpty == password.isEmpty)
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
                NearbySection {
                    #if os(iOS)
                    Button("Scan Server QR", systemImage: "qrcode.viewfinder") {
                        showingInvitationScanner = true
                    }
                    .buttonStyle(NearbyChipButtonStyle(cursorID: NearbyCursor.scanServerQR))
                    #endif
                    if url?.scheme == "http" {
                        NearbySwitchRow(title: "Allow pairing over local HTTP", cursorID: NearbyCursor.allowPairingHTTP, isOn: $allowPairingHTTP)
                    }
                    Button("Request Access", action: requestAccess)
                        .buttonStyle(NearbyChipButtonStyle(cursorID: NearbyCursor.requestAccess))
                        .disabled(url == nil)
                    if let pairingError { NearbyNote(text: pairingError) }
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
        .sheet(item: $pairing, onDismiss: { if paired { dismiss() } }) { target in
            DevicePairingView(client: target.client, name: "Provenance", legacyApprovalURL: { pin in
                DevicePairingClient.legacyApprovalURL(origin: target.origin, pin: pin)
            }) { token in
                onAdd(target.origin, "", "", token)
                paired = true
            }
            // The PIN is the sheet's only text field. The package asks for the number pad on iOS only.
            .keyboardType(.numberPad)
            .nearbySheetBackdrop()
        }
        #if os(iOS)
        .sheet(isPresented: $showingInvitationScanner, onDismiss: { if paired { dismiss() } }) {
            DevicePairingInvitationView(deviceName: "Provenance") { origin, token in
                onAdd(origin, "", "", token)
                paired = true
            }
        }
        #endif
        .onChange(of: address) { allowPairingHTTP = false; pairingError = nil }
        .nearbyControllerCursor(
            NearbyCursor.addServer(usesToken: useToken, showsHTTPConsent: url?.scheme == "http"),
            cursor: $cursorID,
            scope: .subsheet,
            isEditingText: editingField != nil,
            onBack: back,
            onActivate: activate
        )
    }

    private func requestAccess() {
        guard let url else { return }
        guard url.scheme == "https" || allowPairingHTTP else {
            pairingError = "Enable pairing over HTTP only on a trusted network."
            return
        }
        do {
            pairing = PairingTarget(origin: url, client: try DevicePairingClient(origin: url, allowHTTP: allowPairingHTTP))
            pairingError = nil
        } catch {
            pairingError = error.localizedDescription
        }
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
        case NearbyCursor.allowPairingHTTP: allowPairingHTTP.toggle()
        case NearbyCursor.requestAccess: requestAccess()
        #if os(iOS)
        case NearbyCursor.scanServerQR: showingInvitationScanner = true
        #endif
        case NearbyCursor.cancel: dismiss()
        case NearbyCursor.add: if canAdd { add() }
        default: editingField = item
        }
    }
}
#endif
