//
//  NetplaySettingsView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/19/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if !os(watchOS)
import SwiftUI
import PVNetplay
import PVFeatureFlags

/// Persistent keys for netplay user defaults.
private enum NetplayDefaultsKey {
    static let nickname         = "netplay.nickname"
    static let port             = "netplay.port"
    static let relayServer      = "netplay.relayServer"
    static let frameDelay       = "netplay.frameDelay"
    static let maxPlayers       = "netplay.maxPlayers"
    static let allowSpectators  = "netplay.allowSpectators"
}

/// Valid port range: 0 = OS-assigned, 1–65535 = explicit port.
private let netplayPortRange: ClosedRange<Int> = 0...65535

/// Full netplay settings form backed by `@AppStorage`.
///
/// Persists: nickname, default port, relay server URL, frame delay,
/// max players, and spectator preference. Values are applied to newly
/// created `NetplaySettings` via `NetplaySettings.fromStoredDefaults()`.
/// Access is gated behind the `netplayEnabled` feature flag.
@MainActor
public struct NetplaySettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(NetplayDefaultsKey.nickname)        private var nickname: String = ""
    @AppStorage(NetplayDefaultsKey.port)            private var port: Int = 55435
    @AppStorage(NetplayDefaultsKey.relayServer)     private var relayServer: String = ""
    @AppStorage(NetplayDefaultsKey.frameDelay)      private var frameDelay: Int = 0
    @AppStorage(NetplayDefaultsKey.maxPlayers)      private var maxPlayers: Int = 2
    @AppStorage(NetplayDefaultsKey.allowSpectators) private var allowSpectators: Bool = true

    private var isNetplayEnabled: Bool {
        PVFeatureFlagsManager.shared.netplayEnabled
    }

    /// Port clamped to valid range (0 = OS-assigned, 1–65535 = explicit).
    private var validatedPortBinding: Binding<Int> {
        Binding(
            get: { max(netplayPortRange.lowerBound, min(netplayPortRange.upperBound, port)) },
            set: { port = max(netplayPortRange.lowerBound, min(netplayPortRange.upperBound, $0)) }
        )
    }

    /// Normalizes a stored port that may be out of range (e.g. from an older build).
    private func normalizeStoredPort() {
        port = max(netplayPortRange.lowerBound, min(netplayPortRange.upperBound, port))
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            if isNetplayEnabled {
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
                .onAppear { normalizeStoredPort() }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            } else {
                featureDisabledView
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
        Section {
            portRow
            TextField("Relay Server (empty for LAN only)", text: $relayServer)
                .autocorrectionDisabled()
                #if canImport(UIKit)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                #endif
        } header: {
            Text("Connection")
        } footer: {
            if port < netplayPortRange.lowerBound || port > netplayPortRange.upperBound {
                Text("Port must be between 0 and 65535 (0 = OS-assigned).")
                    .foregroundStyle(.red)
            } else if port == 0 {
                Text("Port 0: the OS will assign an available port automatically.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var portRow: some View {
        #if os(tvOS)
        NetplayStepperView(label: "Default Port", value: validatedPortBinding, in: netplayPortRange)
        #else
        HStack {
            Text("Default Port")
            Spacer()
            TextField("55435", value: validatedPortBinding, format: .number)
                .multilineTextAlignment(.trailing)
                #if canImport(UIKit)
                .keyboardType(.numberPad)
                #endif
                .frame(width: 80)
                .foregroundStyle(.secondary)
        }
        #endif
    }

    private var performanceSection: some View {
        Section {
            NetplayStepperView(label: "Frame Delay", value: $frameDelay, in: 0...10)
        } header: {
            Text("Performance")
        } footer: {
            Text("Higher frame delay reduces network load but increases input lag. Use 0 for rollback-only mode on fast connections.")
        }
    }

    private var hostingDefaultsSection: some View {
        Section("Hosting Defaults") {
            NetplayStepperView(label: "Max Players", value: $maxPlayers, in: 2...4)
            Toggle("Allow Spectators", isOn: $allowSpectators)
        }
    }

    private var featureDisabledView: some View {
        VStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Netplay Unavailable")
                .font(.headline)
            Text("Enable Netplay in Settings > Advanced > Feature Flags to access netplay settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

// MARK: - NetplaySettings integration

extension NetplaySettings {
    /// Builds a `NetplaySettings` pre-populated from the values the user stored
    /// in `NetplaySettingsView`. Call this when creating a new room or join request
    /// so that the stored preferences take effect. Internal to PVUI — not part of
    /// the PVNetplay public API.
    ///
    /// Port semantics: a stored value of `0` is preserved as-is (OS-assigned port).
    /// Values outside `0...65535` are clamped to the nearest bound.
    internal static func fromStoredDefaults(roomName: String = "") -> NetplaySettings {
        let defaults      = UserDefaults.standard
        let storedPort    = defaults.integer(forKey: NetplayDefaultsKey.port)
        // Clamp to UInt16 range; preserve 0 (OS-assigned).
        let clampedPort   = UInt16(clamping: max(0, min(65535, storedPort)))
        let relayRaw      = defaults.string(forKey: NetplayDefaultsKey.relayServer) ?? ""
        let storedPlayers = defaults.integer(forKey: NetplayDefaultsKey.maxPlayers)

        return NetplaySettings(
            frameDelay:      max(0, min(10, defaults.integer(forKey: NetplayDefaultsKey.frameDelay))),
            maxSpectators:   4,
            allowSpectators: defaults.object(forKey: NetplayDefaultsKey.allowSpectators) as? Bool ?? true,
            relayServer:     relayRaw.isEmpty ? nil : relayRaw,
            roomName:        roomName,
            maxPlayers:      max(2, min(4, storedPlayers == 0 ? 2 : storedPlayers)),
            playerIndex:     0,
            port:            clampedPort,
            nickname:        defaults.string(forKey: NetplayDefaultsKey.nickname) ?? ""
        )
    }
}

#if DEBUG
#Preview {
    NetplaySettingsView()
}
#endif
#endif
