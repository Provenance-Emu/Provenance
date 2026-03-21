//
//  NetplayCreateRoomView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/18/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if !os(watchOS)
import SwiftUI
import PVNetplay
#if canImport(UIKit)
import UIKit
#endif

/// Form for configuring and starting a new netplay room.
///
/// Presents room name, player count, frame delay, spectator settings, and
/// optional password. Calls `PVNetplayManager.host()` on submit.
@MainActor
public struct NetplayCreateRoomView: View {
    let gameName: String
    let coreIdentifier: String

    @StateObject private var netplay = ObservableNetplayManager.shared
    @State private var settings = NetplaySettings.fromStoredDefaults()
    @State private var isStarting = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showWaitingRoom = false
    /// Set to true by NetplayWaitingRoomView when the host taps Start Game,
    /// so onDismiss knows NOT to tear down the in-progress session.
    @State private var gameStarted = false

    @Environment(\.dismiss) private var dismiss

    public init(gameName: String, coreIdentifier: String) {
        self.gameName = gameName
        self.coreIdentifier = coreIdentifier
    }

    public var body: some View {
        NavigationStack {
            Form {
                // Game info
                Section("Game") {
                    LabeledContent("Title", value: gameName)
                    LabeledContent("Core", value: coreIdentifier)
                }

                // Room settings
                Section("Room Settings") {
                    TextField("Room Name", text: $settings.roomName)
                        .autocorrectionDisabled()

                    NetplayStepperView(label: "Max Players", value: $settings.maxPlayers, in: 2...4)

                    Toggle("Allow Spectators", isOn: $settings.allowSpectators)

                    if settings.allowSpectators {
                        NetplayStepperView(label: "Max Spectators", value: $settings.maxSpectators, in: 0...11)
                    }
                }

                // Network settings
                Section("Network") {
                    NetplayStepperView(label: "Frame Delay", value: $settings.frameDelay, in: 0...10)
                    HStack {
                        Text("Port")
                        Spacer()
                        Text("\(settings.port)")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Relay Server")
                        Spacer()
                        Text(settings.relayServer ?? "LAN Only")
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                // Optional password
                Section("Security") {
                    SecureField("Password (optional)", text: Binding(
                        get: { settings.password ?? "" },
                        set: { settings.password = $0.isEmpty ? nil : $0 }
                    ))
                }

                // Start button
                Section {
                    Button {
                        startHosting()
                    } label: {
                        HStack {
                            Spacer()
                            if isStarting {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Text(isStarting ? "Starting…" : "Start Hosting")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(isStarting || settings.roomName.isEmpty)
                }
            }
            .navigationTitle("Create Room")
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Error", isPresented: $showError, presenting: errorMessage) { _ in
                Button("OK", role: .cancel) {}
            } message: { msg in
                Text(msg)
            }
            // After hosting starts successfully, navigate to the waiting room.
            // When the waiting room is dismissed, also dismiss this sheet so the user
            // returns to the lobby. Only disconnect if the game was NOT started.
            .sheet(isPresented: $showWaitingRoom, onDismiss: {
                if !gameStarted {
                    Task { @MainActor in await netplay.disconnect() }
                }
                dismiss()
            }) {
                NetplayWaitingRoomView(gameName: gameName, coreIdentifier: coreIdentifier, settings: settings, gameStarted: $gameStarted)
                    .interactiveDismissDisabled()
            }
            .onAppear {
                if settings.roomName.isEmpty {
                    #if os(tvOS)
                    settings.roomName = "Provenance Room"
                    #elseif canImport(UIKit)
                    settings.roomName = "\(UIDevice.current.name)'s Room"
                    #else
                    settings.roomName = "Provenance Room"
                    #endif
                }
            }
        }
    }

    // MARK: - Actions

    private func startHosting() {
        isStarting = true
        Task { @MainActor in
            do {
                try await netplay.host(settings: settings)
                // Navigate to waiting room — do not dismiss yet.
                showWaitingRoom = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isStarting = false
        }
    }
}
#endif
