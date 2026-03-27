//
//  NetplayDeepLinkHandler.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/27/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if !os(watchOS)
import SwiftUI
import PVNetplay
import PVLogging

/// View modifier that listens for `Notification.Name.netplayJoinRequest` and
/// presents a confirmation alert so the user can accept or decline the invite.
///
/// Attach to any long-lived view (e.g. the root ContentView):
/// ```swift
/// ContentView()
///     .netplayJoinHandler()
/// ```
public struct NetplayDeepLinkHandlerModifier: ViewModifier {

    @StateObject private var netplay = ObservableNetplayManager.shared
    @State private var pendingRequest: NetplayJoinRequest?
    @State private var showConfirmAlert = false
    @State private var joinError: String?
    @State private var showError = false

    public init() {}

    public func body(content: Content) -> some View {
        content
            .onReceive(
                NotificationCenter.default.publisher(for: .netplayJoinRequest)
            ) { notification in
                guard let request = parseNotification(notification) else { return }
                pendingRequest = request
                showConfirmAlert = true
            }
            .alert(
                "Netplay Invite",
                isPresented: $showConfirmAlert,
                presenting: pendingRequest
            ) { request in
                Button("Join") {
                    Task { await handleJoin(request) }
                }
                Button("Decline", role: .cancel) {
                    pendingRequest = nil
                }
            } message: { request in
                if let game = request.gameName {
                    Text("Join \"\(game)\" hosted at \(request.host)?")
                } else {
                    Text("Join the netplay session at \(request.host)?")
                }
            }
            .alert("Join Failed", isPresented: $showError, presenting: joinError) { _ in
                Button("OK", role: .cancel) {}
            } message: { msg in
                Text(msg)
            }
    }

    // MARK: - Helpers

    private func parseNotification(_ notification: Notification) -> NetplayJoinRequest? {
        guard let info = notification.userInfo else {
            WLOG("[NetplayDeepLink] Received netplayJoinRequest with no userInfo")
            return nil
        }
        let request = NetplayJoinRequest.from(notificationUserInfo: info)
        if request == nil {
            WLOG("[NetplayDeepLink] Received malformed netplayJoinRequest — missing host")
        }
        return request
    }

    @MainActor
    private func handleJoin(_ request: NetplayJoinRequest) async {
        let room = NetplayRoom(
            hostName: request.host,
            gameName: request.gameName ?? "",
            gameHash: "",
            coreIdentifier: "",
            maxPlayers: 2,
            currentPlayers: 1,
            isLAN: request.relay == nil,
            hostAddress: request.host,
            port: request.port,
            traversalCode: request.relay,
            discoverySource: .manual
        )
        var settings = NetplaySettings.fromStoredDefaults()
        settings.relayServer = request.relay

        do {
            try await netplay.join(room: room, settings: settings)
        } catch {
            joinError = error.localizedDescription
            showError = true
        }
        pendingRequest = nil
    }
}

public extension View {
    /// Attaches the netplay deep-link join handler to this view.
    ///
    /// When a `provenance://netplay/join` URL is opened, an alert is shown
    /// asking the user to confirm before connecting.
    func netplayJoinHandler() -> some View {
        modifier(NetplayDeepLinkHandlerModifier())
    }
}
#endif
