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
    /// Published in the room's LAN advertisement so joiners can find the game.
    let hostedGame: NetplayHostedGame?

    @StateObject private var netplay = ObservableNetplayManager.shared
    @State private var settings = NetplaySettings.fromStoredDefaults()
    @State private var selectedOptionID = ""
    @State private var options: [NetplayGameOption] = []
    @State private var showMetadata = false
    @State private var isStarting = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showWaitingRoom = false
    /// Hosting restarts the running game for this core (PPSSPP ad hoc).
    @State private var hostingRestartsGame = false
    /// Set to true by NetplayWaitingRoomView when the host taps Start Game,
    /// so onDismiss knows NOT to tear down the in-progress session.
    @State private var gameStarted = false

    @Environment(\.dismiss) private var dismiss

    public init(gameName: String, coreIdentifier: String, hostedGame: NetplayHostedGame? = nil) {
        self.gameName = gameName
        self.coreIdentifier = coreIdentifier
        self.hostedGame = hostedGame
    }

    private var selectedOption: NetplayGameOption? { options.first { $0.id == selectedOptionID } ?? options.first }

    private func loadOptions() {
        guard let game = hostedGame,
              let support = NetplayCoreCompatibility.support(coreIdentifier: coreIdentifier, systemIdentifier: game.systemIdentifier, coreVersion: game.coreVersion) else {
            options = []
            return
        }
        let metadata = NetplayMetadataStore.shared.metadata(md5: game.md5, system: game.systemIdentifier, serial: game.serial,
                                                           isPatched: game.isPatched)
        options = NetplayEligibility.evaluate(localFileAvailable: true, metadata: metadata, cores: [support]).options
        if !options.contains(where: { $0.id == selectedOptionID }) { selectedOptionID = options.first?.id ?? "" }
        normalizeSettings()
    }

    private func normalizeSettings() {
        guard let option = selectedOption else { return }
        settings.maxPlayers = min(max(2, settings.maxPlayers), option.maxPlayers)
        if !option.core.supportsSpectators { settings.allowSpectators = false; settings.maxSpectators = 0 }
        if !option.core.supportsFrameDelay { settings.frameDelay = 0 }
    }

    public var body: some View {
        NavigationStack {
            NetplayForm {
                // Game info
                NetplayFormSection("Game") {
                    LabeledContent("Title", value: gameName)
                    if options.isEmpty {
                        Label("Multiplayer details or core support are missing.", systemImage: "questionmark.circle")
                    } else {
                        Picker("Play style", selection: $selectedOptionID) {
                            ForEach(options) { Text($0.mode.title).tag($0.id) }
                        }
                    }
                    if hostedGame != nil { Button("Review Multiplayer Details") { showMetadata = true } }
                }

                // Room settings
                NetplayFormSection("Room Settings") {
                    TextField("Room Name", text: $settings.roomName)
                        .autocorrectionDisabled()

                    NetplayStepperView(label: "Max Players", value: $settings.maxPlayers, in: 2...(selectedOption?.maxPlayers ?? 2))

                    if selectedOption?.core.supportsSpectators == true {
                        Toggle("Allow Spectators", isOn: $settings.allowSpectators)
                    }

                    if settings.allowSpectators && selectedOption?.core.supportsSpectators == true {
                        NetplayStepperView(label: "Max Spectators", value: $settings.maxSpectators, in: 0...11)
                    }
                }

                // Network settings
                NetplayDisclosure("Advanced Network Settings") {
                  NetplayFormSection("Network") {
                    if selectedOption?.core.supportsFrameDelay == true {
                        NetplayStepperView(label: "Frame Delay", value: $settings.frameDelay, in: 0...10)
                    }
                    HStack {
                        Text("Port")
                        Spacer()
                        Text("\(settings.port)")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Relay Server")
                        Spacer()
                        Text(settings.relayServer ?? "None (direct)")
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                }

                // Optional password
                NetplayFormSection("Security") {
                    SecureField("Password (optional)", text: Binding(
                        get: { settings.password ?? "" },
                        set: { settings.password = $0.isEmpty ? nil : $0 }
                    ))
                }

                // Start button
                NetplayFormSection {
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
                    .disabled(isStarting || settings.roomName.isEmpty || selectedOption == nil)
                } footer: {
                    if hostingRestartsGame {
                        Text("Hosting restarts the game so it can use the network. Save first.")
                    }
                }
            }
            .task { hostingRestartsGame = await netplay.hostingRestartsGame(); loadOptions() }
            .onChange(of: selectedOptionID) { _, _ in normalizeSettings() }
            .netplayPresentation(isPresented: $showMetadata, onDismiss: loadOptions) {
                if let game = hostedGame {
                    NetplayMetadataEditor(title: gameName, md5: game.md5, system: game.systemIdentifier, onSave: loadOptions)
                }
            }
            .netplayNavigationTitle("Create Room")
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
            .netplayPresentation(isPresented: $showWaitingRoom, onDismiss: {
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
                loadOptions()
                guard let option = selectedOption else { throw NetplayError.invalidSettings("Confirm a supported multiplayer mode first.") }
                normalizeSettings()
                var game = hostedGame
                game?.option = option
                try await netplay.host(settings: settings, game: game)
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
