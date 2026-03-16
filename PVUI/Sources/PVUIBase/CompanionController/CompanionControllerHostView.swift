// CompanionControllerHostView.swift
// PVUI
//
// Root SwiftUI view for the Companion Controller feature (iOS only).
// Renders the appropriate overlay layout when connected, or a pairing UI
// when disconnected / errored.
//
// Present this view modally or as a full-screen sheet from the emulator
// pause menu or OSD when the user taps "Use as Companion Controller".
//
// Copyright © 2026 Provenance Emu. All rights reserved.

#if !os(tvOS)
import SwiftUI

// MARK: - CompanionControllerHostView

/// Full-screen host for the companion controller session.
///
/// Binds to a `CompanionControllerSession` and switches between:
/// - Pairing screen (disconnected)
/// - Connecting spinner
/// - Layout overlay (connected)
/// - Error screen with retry button
public struct CompanionControllerHostView: View {

    // MARK: - State

    @ObservedObject private var session: CompanionControllerSession
    @State private var hostInput: String = ""
    @State private var portInput: String = "26760"
    @Environment(\.dismiss) private var dismiss

    // MARK: - Init

    public init(session: CompanionControllerSession) {
        self.session = session
    }

    // MARK: - Body

    public var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                switch session.connectionState {
                case .disconnected:
                    pairingView

                case .connecting(let host, let port):
                    connectingView(host: host, port: port)

                case .connected:
                    connectedView

                case .error(let reason):
                    errorView(reason: reason)
                }
            }
            .navigationTitle("Companion Controller")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.white)
                }
                if session.connectionState.isConnected {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Disconnect") { session.disconnect() }
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Pairing screen

    @ViewBuilder
    private var pairingView: some View {
        VStack(spacing: 24) {
            Image(systemName: "gamecontroller")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text("Connect to Provenance")
                .font(.title2.bold())
                .foregroundColor(.white)

            Text("Enter the IP address of the device running Provenance that will receive your controller input.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(spacing: 12) {
                TextField("Host IP (e.g. 192.168.1.5)", text: $hostInput)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                    .autocorrectionDisabled()

                TextField("Port", text: $portInput)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
            }
            .padding(.horizontal)

            Button {
                let port = UInt16(portInput) ?? 26760
                session.connect(host: hostInput, port: port)
            } label: {
                Label("Connect", systemImage: "wifi")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(hostInput.isEmpty)
            .padding(.horizontal)
        }
        .padding()
    }

    // MARK: - Connecting screen

    @ViewBuilder
    private func connectingView(host: String, port: UInt16) -> some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.5)
                .tint(.white)

            Text("Connecting to \(host):\(port)…")
                .foregroundColor(.secondary)

            Button("Cancel") { session.disconnect() }
                .foregroundColor(.red)
        }
    }

    // MARK: - Connected overlay

    @ViewBuilder
    private var connectedView: some View {
        let layout = CompanionLayoutFactory.makeLayout(
            systemID: session.activeSystemID,
            router: session.inputRouter
        )
        AnyView(layout)
    }

    // MARK: - Error screen

    @ViewBuilder
    private func errorView(reason: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)

            Text("Connection Failed")
                .font(.title2.bold())
                .foregroundColor(.white)

            Text(reason)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Retry") { session.retry() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Disconnected") {
    CompanionControllerHostView(session: CompanionControllerSession())
}

#Preview("Connected") {
    let s = CompanionControllerSession()
    // Simulate connected state for preview
    Task { @MainActor in
        s.activeSystemID = ""
    }
    return CompanionControllerHostView(session: s)
}
#endif

#endif // !os(tvOS)
