//
//  NetplayManualConnectView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/18/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import SwiftUI
import PVNetplay

/// Manual IP + port connection form for joining a netplay room
/// when Bonjour discovery doesn't find the host (e.g. different subnet).
@MainActor
public struct NetplayManualConnectView: View {
    let gameName: String
    let coreIdentifier: String

    @StateObject private var netplay = ObservableNetplayManager.shared
    @State private var hostAddress = ""
    @State private var portString = "55435"
    @State private var frameDelay = 0
    @State private var spectate = false
    @State private var isConnecting = false
    @State private var errorMessage: String?
    @State private var showError = false

    @Environment(\.dismiss) private var dismiss

    public init(gameName: String, coreIdentifier: String) {
        self.gameName = gameName
        self.coreIdentifier = coreIdentifier
    }

    private var port: UInt16 { UInt16(portString) ?? 55435 }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Host Details") {
                    TextField("IP Address or Hostname", text: $hostAddress)
                        .keyboardType(.numbersAndPunctuation)
                        .autocorrectionDisabled()
                        .autocapitalization(.none)

                    TextField("Port", text: $portString)
                        .keyboardType(.numberPad)
                }

                Section("Options") {
                    Stepper("Frame Delay: \(frameDelay)", value: $frameDelay, in: 0...10)
                    Toggle("Connect as Spectator", isOn: $spectate)
                }

                Section {
                    Button {
                        connect()
                    } label: {
                        HStack {
                            Spacer()
                            if isConnecting {
                                ProgressView().padding(.trailing, 8)
                            }
                            Text(isConnecting ? "Connecting…" : "Connect")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(isConnecting || hostAddress.isEmpty)
                }
            }
            .navigationTitle("Manual Connect")
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Connection Error", isPresented: $showError, presenting: errorMessage) { _ in
                Button("OK", role: .cancel) {}
            } message: { msg in
                Text(msg)
            }
        }
    }

    private func connect() {
        isConnecting = true
        Task {
            do {
                let room = NetplayRoom(
                    hostName: hostAddress,
                    gameName: gameName,
                    gameHash: "",
                    coreIdentifier: coreIdentifier,
                    maxPlayers: 2,
                    currentPlayers: 1,
                    isLAN: true,
                    hostAddress: hostAddress,
                    port: port
                )
                var settings = NetplaySettings.defaultLAN
                settings.frameDelay = frameDelay
                if spectate {
                    try await netplay.spectate(room: room)
                } else {
                    try await netplay.join(room: room, settings: settings)
                }
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isConnecting = false
        }
    }
}
