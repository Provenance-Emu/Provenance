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

/// Parsed representation of a `provenance://netplay/join` deep link.
public struct NetplayJoinRequest: Equatable {
    public let host: String
    public let port: UInt16
    public let relay: String?
    public let gameName: String?
}

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
        guard let info = notification.userInfo,
              let host = info["host"] as? String, !host.isEmpty else {
            WLOG("[NetplayDeepLink] Received malformed netplayJoinRequest — missing host")
            return nil
        }

        let portValue: UInt16
        if let portRaw = info["port"] as? String, let parsed = UInt16(portRaw), parsed >= 1 {
            portValue = parsed
        } else if let portInt = info["port"] as? Int, portInt >= 1, portInt <= 65535 {
            portValue = UInt16(portInt)
        } else {
            portValue = 55435
        }

        let relay = info["relay"] as? String
        let gameName = info["game"] as? String
        return NetplayJoinRequest(host: host, port: portValue, relay: relay, gameName: gameName)
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
