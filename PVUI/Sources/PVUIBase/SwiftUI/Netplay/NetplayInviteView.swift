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

    @StateObject private var netplay = ObservableNetplayManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var hostAddress: String = ""
    @State private var port: String = "55435"
    @State private var useRelay: Bool = false
    @State private var relayServer: String = "relay.retroarch.com"
    @State private var showShareSheet = false
    @State private var inviteURL: URL?

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
            #if !os(tvOS)
            .sheet(isPresented: $showShareSheet) {
                if let url = inviteURL {
                    ActivityView(items: [url, "Join me in \(gameName) on Provenance!"])
                }
            }
            #endif
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
            Text("Your public IP or relay address. Leave relay ON if using RA.ME.")
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
            Text("The RA.ME relay (relay.retroarch.com) lets friends connect without port forwarding.")
        }
    }

    private var inviteLinkSection: some View {
        SwiftUI.Section {
            if let url = buildInviteURL() {
                VStack(alignment: .leading, spacing: 8) {
                    Text(url.absoluteString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)

                    Button {
                        inviteURL = url
                        showShareSheet = true
                    } label: {
                        Label("Share Link", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
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
        var components = URLComponents()
        components.scheme = "provenance"
        components.host = "netplay"
        components.path = "/join"
        var items: [URLQueryItem] = [
            URLQueryItem(name: "host", value: hostAddress),
            URLQueryItem(name: "port", value: port.isEmpty ? "55435" : port),
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
            hostAddress = room.hostAddress == "0.0.0.0" ? "" : room.hostAddress
            port = String(room.port)
        }
        // Pre-fill relay from stored defaults
        let stored = UserDefaults.standard.string(forKey: "netplay.relayServer") ?? ""
        if !stored.isEmpty {
            useRelay = true
            relayServer = stored
        }
    }
}

// MARK: - UIActivityViewController wrapper (iOS only)

#if canImport(UIKit) && !os(tvOS)
import UIKit

private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

#if DEBUG
#Preview {
    NetplayInviteView(gameName: "Street Fighter II")
}
#endif
#endif
