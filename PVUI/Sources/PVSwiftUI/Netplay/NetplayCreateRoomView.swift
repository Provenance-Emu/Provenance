//
//  NetplayCreateRoomView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/18/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

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
    @State private var settings = NetplaySettings.defaultLAN
    @State private var isStarting = false
    @State private var errorMessage: String?
    @State private var showError = false

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

                    Stepper("Max Players: \(settings.maxPlayers)", value: $settings.maxPlayers, in: 2...4)

                    Toggle("Allow Spectators", isOn: $settings.allowSpectators)

                    if settings.allowSpectators {
                        Stepper("Max Spectators: \(settings.maxSpectators)", value: $settings.maxSpectators, in: 0...11)
                    }
                }

                // Network settings
                Section("Network") {
                    Stepper("Frame Delay: \(settings.frameDelay)", value: $settings.frameDelay, in: 0...10)
                    HStack {
                        Text("Port")
                        Spacer()
                        Text("\(settings.port)")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Network")
                        Spacer()
                        Text("LAN Only")
                            .foregroundStyle(.secondary)
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
            .onAppear {
                if settings.roomName.isEmpty {
                    #if os(tvOS)
                    settings.roomName = "Provenance Room"
                    #else
                    settings.roomName = "\(UIDevice.current.name)'s Room"
                    #endif
                }
            }
        }
    }

    // MARK: - Actions

    private func startHosting() {
        isStarting = true
        Task {
            do {
                try await netplay.host(settings: settings)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isStarting = false
        }
    }
}
