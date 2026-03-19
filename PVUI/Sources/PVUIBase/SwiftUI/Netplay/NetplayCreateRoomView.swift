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

                    tvOSCompatibleStepper("Max Players", value: $settings.maxPlayers, in: 2...4)

                    Toggle("Allow Spectators", isOn: $settings.allowSpectators)

                    if settings.allowSpectators {
                        tvOSCompatibleStepper("Max Spectators", value: $settings.maxSpectators, in: 0...11)
                    }
                }

                // Network settings
                Section("Network") {
                    tvOSCompatibleStepper("Frame Delay", value: $settings.frameDelay, in: 0...10)
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

    @ViewBuilder
    private func tvOSCompatibleStepper(_ label: String, value: Binding<Int>, in range: ClosedRange<Int>) -> some View {
        #if os(tvOS)
        HStack {
            Text("\(label): \(value.wrappedValue)")
            Spacer()
            Button { value.wrappedValue = max(range.lowerBound, value.wrappedValue - 1) } label: {
                Image(systemName: "minus.circle")
            }
            Button { value.wrappedValue = min(range.upperBound, value.wrappedValue + 1) } label: {
                Image(systemName: "plus.circle")
            }
        }
        #else
        Stepper("\(label): \(value.wrappedValue)", value: value, in: range)
        #endif
    }

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
#endif
