//
//  NetplaySettingsView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/19/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if !os(watchOS)
import SwiftUI

/// Persistent keys for netplay user defaults.
private enum NetplayDefaultsKey {
    static let nickname         = "netplay.nickname"
    static let port             = "netplay.port"
    static let relayServer      = "netplay.relayServer"
    static let frameDelay       = "netplay.frameDelay"
    static let maxPlayers       = "netplay.maxPlayers"
    static let allowSpectators  = "netplay.allowSpectators"
}

/// Full netplay settings form backed by `@AppStorage`.
///
/// Persists: nickname, default port, relay server URL, frame delay,
/// max players, and spectator preference.
@MainActor
public struct NetplaySettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(NetplayDefaultsKey.nickname)        private var nickname: String = ""
    @AppStorage(NetplayDefaultsKey.port)            private var port: Int = 55435
    @AppStorage(NetplayDefaultsKey.relayServer)     private var relayServer: String = ""
    @AppStorage(NetplayDefaultsKey.frameDelay)      private var frameDelay: Int = 0
    @AppStorage(NetplayDefaultsKey.maxPlayers)      private var maxPlayers: Int = 2
    @AppStorage(NetplayDefaultsKey.allowSpectators) private var allowSpectators: Bool = true

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                playerProfileSection
                connectionSection
                performanceSection
                hostingDefaultsSection
            }
            .navigationTitle("Netplay Settings")
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Sections

    private var playerProfileSection: some View {
        Section("Player Profile") {
            TextField("Nickname", text: $nickname)
                .autocorrectionDisabled()
        }
    }

    private var connectionSection: some View {
        Section("Connection") {
            tvOSCompatiblePortField
            TextField("Relay Server (empty for LAN only)", text: $relayServer)
                .autocorrectionDisabled()
                #if !os(tvOS)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                #endif
        }
    }

    @ViewBuilder
    private var tvOSCompatiblePortField: some View {
        #if os(tvOS)
        HStack {
            Text("Default Port")
            Spacer()
            Text("\(port)")
                .foregroundStyle(.secondary)
        }
        #else
        HStack {
            Text("Default Port")
            Spacer()
            TextField("55435", value: $port, format: .number)
                .multilineTextAlignment(.trailing)
                .keyboardType(.numberPad)
                .frame(width: 80)
                .foregroundStyle(.secondary)
        }
        #endif
    }

    private var performanceSection: some View {
        Section {
            tvOSCompatibleStepper("Frame Delay", value: $frameDelay, in: 0...10)
        } header: {
            Text("Performance")
        } footer: {
            Text("Higher frame delay reduces network load but increases input lag. Use 0 for rollback-only mode on fast connections.")
        }
    }

    private var hostingDefaultsSection: some View {
        Section("Hosting Defaults") {
            tvOSCompatibleStepper("Max Players", value: $maxPlayers, in: 2...4)
            Toggle("Allow Spectators", isOn: $allowSpectators)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func tvOSCompatibleStepper(_ label: String, value: Binding<Int>, in range: ClosedRange<Int>) -> some View {
        #if os(tvOS)
        HStack {
            Text("\(label): \(value.wrappedValue)")
            Spacer()
            Button {
                value.wrappedValue = max(range.lowerBound, value.wrappedValue - 1)
            } label: {
                Image(systemName: "minus.circle")
            }
            Button {
                value.wrappedValue = min(range.upperBound, value.wrappedValue + 1)
            } label: {
                Image(systemName: "plus.circle")
            }
        }
        #else
        Stepper("\(label): \(value.wrappedValue)", value: value, in: range)
        #endif
    }
}

#if DEBUG
#Preview {
    NetplaySettingsView()
}
#endif
#endif
