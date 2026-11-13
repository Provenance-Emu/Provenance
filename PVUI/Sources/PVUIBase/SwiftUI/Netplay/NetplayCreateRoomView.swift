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
    @State private var showAdvanced = false
    /// The iOS controller cursor (plain state: iOS has no focus engine for buttons).
    @State private var cursor: String?
    @FocusState private var focusedField: NetplayCreateRoomCursor.Field?

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
                        NetplayChoiceRow(title: "Play style", choices: options.map { ($0.id, $0.mode.title) },
                                         selection: selectedOptionBinding, cursorPrefix: NetplayCreateRoomCursor.optionPrefix, cursor: cursor)
                    }
                    if hostedGame != nil {
                        Button("Review Multiplayer Details") { showMetadata = true }
                            .netplayCursorItem(NetplayCreateRoomCursor.metadata, cursor: cursor)
                    }
                }

                // Room settings
                NetplayFormSection("Room Settings") {
                    TextField("Room Name", text: $settings.roomName)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .roomName)
                        .netplayCursorItem(NetplayCreateRoomCursor.roomName, cursor: cursor)

                    NetplayStepperView(label: "Max Players", value: $settings.maxPlayers, in: playerRange,
                                       cursorID: NetplayCreateRoomCursor.maxPlayers, cursor: cursor)

                    if selectedOption?.core.supportsSpectators == true {
                        Toggle("Allow Spectators", isOn: $settings.allowSpectators)
                            .netplayCursorItem(NetplayCreateRoomCursor.spectators, cursor: cursor)
                    }

                    if showsSpectatorLimit {
                        NetplayStepperView(label: "Max Spectators", value: $settings.maxSpectators, in: NetplayCreateRoomCursor.spectatorRange,
                                           cursorID: NetplayCreateRoomCursor.maxSpectators, cursor: cursor)
                    }
                }

                // Network settings
                NetplayDisclosure("Advanced Network Settings", isExpanded: $showAdvanced,
                                  cursorID: NetplayCreateRoomCursor.advanced, cursor: cursor) {
                  NetplayFormSection("Network") {
                    if selectedOption?.core.supportsFrameDelay == true {
                        NetplayStepperView(label: "Frame Delay", value: $settings.frameDelay, in: NetplayCreateRoomCursor.frameDelayRange,
                                           cursorID: NetplayCreateRoomCursor.frameDelay, cursor: cursor)
                    }
                    HStack {
                        Text("Port")
                        Spacer()
                        Text(verbatim: String(settings.port))
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
                    .focused($focusedField, equals: .password)
                    .netplayCursorItem(NetplayCreateRoomCursor.password, cursor: cursor)
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
                    .disabled(!canStart)
                    .netplayCursorItem(NetplayCreateRoomCursor.start, cursor: cursor)
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            #endif
            .netplayControllerNavigation(cursorRows, cursor: $cursor, isCovered: showError) {
                if focusedField != nil { focusedField = nil } else { dismiss() }
            }
            .pvAlert(isPresented: $showError) {
                PVAlert(title: "Error", message: errorMessage, type: .error)
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

    // MARK: - Controller

    private var playerRange: ClosedRange<Int> { 2...(selectedOption?.maxPlayers ?? 2) }

    private var showsSpectatorLimit: Bool {
        settings.allowSpectators && selectedOption?.core.supportsSpectators == true
    }

    private var canStart: Bool { !isStarting && !settings.roomName.isEmpty && selectedOption != nil }

    /// The chosen play style; with none chosen yet, the first one (what hosting would use).
    private var selectedOptionBinding: Binding<String> {
        Binding(get: { selectedOption?.id ?? "" }, set: { selectedOptionID = $0 })
    }

    /// What the iOS controller cursor can reach, in the order it is drawn. Everything above
    /// Start Hosting is a header row, so the cursor starts on Start Hosting.
    private var cursorRows: [NetplayCursorRow] {
        var rows: [NetplayCursorRow] = []
        if !options.isEmpty {
            rows.append(NetplayChoiceRow.cursorRow(NetplayCreateRoomCursor.optionPrefix, choices: options.map(\.id),
                                                   selection: selectedOptionBinding))
        }
        if hostedGame != nil {
            rows.append(.single(NetplayCursorTarget(id: NetplayCreateRoomCursor.metadata) { showMetadata = true }, isHeader: true))
        }
        rows.append(.single(NetplayCursorTarget(id: NetplayCreateRoomCursor.roomName) { focusedField = .roomName }, isHeader: true))
        var players = NetplayStepperView.cursorRow(NetplayCreateRoomCursor.maxPlayers, value: $settings.maxPlayers, in: playerRange)
        players.isHeader = true
        rows.append(players)
        if selectedOption?.core.supportsSpectators == true {
            rows.append(.single(NetplayCursorTarget(id: NetplayCreateRoomCursor.spectators) { settings.allowSpectators.toggle() }, isHeader: true))
        }
        if showsSpectatorLimit {
            var spectators = NetplayStepperView.cursorRow(NetplayCreateRoomCursor.maxSpectators, value: $settings.maxSpectators,
                                                          in: NetplayCreateRoomCursor.spectatorRange)
            spectators.isHeader = true
            rows.append(spectators)
        }
        rows.append(.single(NetplayCursorTarget(id: NetplayCreateRoomCursor.advanced) { showAdvanced.toggle() }, isHeader: true))
        if showAdvanced && selectedOption?.core.supportsFrameDelay == true {
            var delay = NetplayStepperView.cursorRow(NetplayCreateRoomCursor.frameDelay, value: $settings.frameDelay,
                                                     in: NetplayCreateRoomCursor.frameDelayRange)
            delay.isHeader = true
            rows.append(delay)
        }
        rows.append(.single(NetplayCursorTarget(id: NetplayCreateRoomCursor.password) { focusedField = .password }, isHeader: true))
        rows.append(.single(NetplayCursorTarget(id: NetplayCreateRoomCursor.start, isEnabled: canStart, action: startHosting)))
        return rows
    }

    // MARK: - Actions

    private func startHosting() {
        guard canStart else { return }
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

/// Cursor IDs and fixed values of the Create Room screen.
enum NetplayCreateRoomCursor {
    enum Field: Hashable { case roomName, password }

    static let optionPrefix = "option"
    static let metadata = "metadata"
    static let roomName = "roomName"
    static let maxPlayers = "maxPlayers"
    static let spectators = "spectators"
    static let maxSpectators = "maxSpectators"
    static let advanced = "advanced"
    static let frameDelay = "frameDelay"
    static let password = "password"
    static let start = "start"

    static let spectatorRange = 0...11
    static let frameDelayRange = 0...10
}
#endif
