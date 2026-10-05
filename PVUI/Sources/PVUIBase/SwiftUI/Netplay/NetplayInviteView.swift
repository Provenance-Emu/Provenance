//
//  NetplayInviteView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/21/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if !os(watchOS)
import SwiftUI
import PVNetplay

/// Sheet that builds and shares a `provenance://netplay/join` deep-link invite.
///
/// The host's IP and port are read from the currently active netplay session
/// (if hosting). If no session is active, the user can enter them manually.
@MainActor
public struct NetplayInviteView: View {
    let gameName: String

    @ObservedObject private var netplay = ObservableNetplayManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var hostAddress: String = ""
    @State private var port: String = String(NetplayJoinRequest.defaultPort)
    @State private var useRelay: Bool = false
    @State private var relayServer: String = ""

    public init(gameName: String) {
        self.gameName = gameName
    }

    public var body: some View {
        NavigationStack {
            Form {
                connectionSection
                relaySection
                inviteLinkSection
            }
            .navigationTitle("Share Invite Link")
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { prefillFromActiveSession() }
        }
    }

    // MARK: - Sections

    private var connectionSection: some View {
        SwiftUI.Section {
            TextField("Host IP or Hostname", text: $hostAddress)
                .autocorrectionDisabled()
                #if canImport(UIKit)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                #endif
            TextField("Port", text: $port)
                #if canImport(UIKit)
                .keyboardType(.numberPad)
                #endif
        } header: {
            Text("Connection")
        } footer: {
            Text("An address the other player can reach. Over the internet, forward this port to the host.")
        }
    }

    private var relaySection: some View {
        SwiftUI.Section {
            Toggle("Use Relay Server", isOn: $useRelay)
            if useRelay {
                TextField("Relay Server", text: $relayServer)
                    .autocorrectionDisabled()
                    #if canImport(UIKit)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    #endif
            }
        } header: {
            Text("Relay")
        } footer: {
            Text("Only PPSSPP (adhoc server address) and Dolphin (traversal code) use a relay. Leave it off otherwise.")
        }
    }

    private var inviteLinkSection: some View {
        SwiftUI.Section {
            if let url = buildInviteURL() {
                VStack(alignment: .leading, spacing: 8) {
                    Text(url.absoluteString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    #if !os(tvOS)
                        .textSelection(.enabled)
                    #endif

                    #if os(tvOS)
                    // tvOS has no share sheet — show a QR code instead.
                    // Viewers can scan this with any phone camera to open the invite.
                    PVQRCodeView(
                        url.absoluteString,
                        correctionLevel: .quarter,
                        label: "Scan with your phone to join"
                    )
                    .frame(width: 180, height: 200)
                    .padding(.top, 8)
                    #else
                    ShareLink(
                        item: url,
                        subject: Text("Netplay Invite"),
                        message: Text("Join me in \(gameName) on Provenance!")
                    ) {
                        Label("Share Link", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    #endif
                }
                .padding(.vertical, 4)
            } else {
                Text("Enter a host address to generate an invite link.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Invite Link")
        }
    }

    // MARK: - Helpers

    private func buildInviteURL() -> URL? {
        guard !hostAddress.isEmpty else { return nil }
        // Treat empty port as the default. Port 0 is not a valid connection target.
        let resolvedPort = port.isEmpty ? Int(NetplayJoinRequest.defaultPort) : (Int(port) ?? -1)
        guard resolvedPort >= 1, resolvedPort <= 65535 else { return nil }
        var components = URLComponents()
        components.scheme = "provenance"
        components.host = "netplay"
        components.path = "/join"
        var items: [URLQueryItem] = [
            URLQueryItem(name: "host", value: hostAddress),
            URLQueryItem(name: "port", value: "\(resolvedPort)"),
            URLQueryItem(name: "game", value: gameName)
        ]
        if useRelay && !relayServer.isEmpty {
            items.append(URLQueryItem(name: "relay", value: relayServer))
        }
        components.queryItems = items
        return components.url
    }

    private func prefillFromActiveSession() {
        if case .hosting(let room) = netplay.state {
            // Cores publish a wildcard or loopback address while hosting;
            // share this device's own address instead.
            let unusable: Set<String> = ["", "0.0.0.0", "127.0.0.1"]
            hostAddress = unusable.contains(room.hostAddress)
                ? (NetplayLocalAddresses.current().first ?? "")
                : room.hostAddress
            if room.port != 0 {
                port = String(room.port)
            }
        }
        // Pre-fill the relay the user set in Netplay settings, if any.
        if let stored = NetplayDefaultsKey.storedRelayServer() {
            useRelay = true
            relayServer = stored
        }
    }
}

#if DEBUG
#Preview {
    NetplayInviteView(gameName: "Street Fighter II")
}
#endif
#endif
