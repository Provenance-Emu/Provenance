//
//  NetplayManualConnectView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/18/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if !os(watchOS)
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
    @State private var spectate: Bool
    @State private var isConnecting = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var portError: String?

    @Environment(\.dismiss) private var dismiss

    public init(gameName: String, coreIdentifier: String, defaultSpectate: Bool = false) {
        self.gameName = gameName
        self.coreIdentifier = coreIdentifier
        self._spectate = State(initialValue: defaultSpectate)
    }

    /// Validates portString and returns the parsed port, or nil if invalid.
    private var validatedPort: UInt16? {
        guard let value = UInt16(portString), value >= 1 else { return nil }
        return value
    }

    private var portIsValid: Bool { validatedPort != nil }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Host Details") {
                    TextField("IP Address or Hostname", text: $hostAddress)
                        .autocorrectionDisabled()
                        #if canImport(UIKit)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        #endif

                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Port", text: $portString)
                            #if canImport(UIKit)
                            .keyboardType(.numberPad)
                            #endif
                            .onChange(of: portString) { _, _ in
                                portError = portIsValid ? nil : "Port must be a number between 1 and 65535."
                            }
                        if let portError {
                            Text(portError)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }

                Section("Options") {
                    #if os(tvOS)
                    HStack {
                        Text("Frame Delay: \(frameDelay)")
                        Spacer()
                        Button {
                            frameDelay = max(0, frameDelay - 1)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .disabled(frameDelay <= 0)
                        .accessibilityLabel("Decrease frame delay")
                        .accessibilityHint("Minimum frame delay is zero frames")
                        Button {
                            frameDelay = min(10, frameDelay + 1)
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                        .disabled(frameDelay >= 10)
                        .accessibilityLabel("Increase frame delay")
                        .accessibilityHint("Maximum frame delay is ten frames")
                    }
                    #else
                    Stepper("Frame Delay: \(frameDelay)", value: $frameDelay, in: 0...10)
                    #endif
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
                    .disabled(isConnecting || hostAddress.isEmpty || !portIsValid)
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
        guard let port = validatedPort else {
            portError = "Port must be a number between 1 and 65535."
            return
        }
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
                    port: port,
                    discoverySource: .manual
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
#endif
