//
//  NetplayGameCenterView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/27/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Provides Game Center matchmaking for netplay. When a GKMatch is formed,
//  player addresses are exchanged via GKMatch data channel so that RetroArch
//  netplay can establish a TCP connection.
//

#if !os(watchOS) && canImport(GameKit)
import SwiftUI
import GameKit
import PVNetplay
import PVLogging

// MARK: - Constants

/// Default RetroArch relay server used for Game Center-brokered sessions.
/// GKMatch does not expose raw IP addresses, so all traffic is routed through
/// a relay rather than direct P2P.
private let kGKRelayServer = "ra.me"

// MARK: - GameKit Authenticator

/// Manages Game Center local player authentication state.
@MainActor
public final class PVGameKitManager: NSObject, ObservableObject {
    public static let shared = PVGameKitManager()

    @Published public private(set) var isAuthenticated = false
    @Published public private(set) var localPlayer: GKLocalPlayer?
    @Published public private(set) var authError: String?

    public override init() {
        super.init()
    }

    /// Authenticate the local player with Game Center.
    /// Safe to call multiple times — Game Center caches the result.
    public func authenticate() {
        let player = GKLocalPlayer.local
        player.authenticateHandler = { [weak self] viewController, error in
            guard let self else { return }
            if let error {
                self.authError = error.localizedDescription
                self.isAuthenticated = false
                ELOG("[GameKit] Auth error: \(error.localizedDescription)")
                return
            }
            if player.isAuthenticated {
                self.localPlayer = player
                self.isAuthenticated = true
                self.authError = nil
                ILOG("[GameKit] Authenticated as \(player.displayName)")
            } else if let vc = viewController {
                self.presentAuthController(vc)
            }
        }
    }

#if canImport(UIKit)
    private func presentAuthController(_ viewController: UIViewController) {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let rootVC = scene.keyWindow?.rootViewController else { return }
        rootVC.topmostPresentedViewController.present(viewController, animated: true)
    }
#else
    private func presentAuthController(_ viewController: NSViewController) {}
#endif
}

#if canImport(UIKit)
private extension UIViewController {
    var topmostPresentedViewController: UIViewController {
        presentedViewController?.topmostPresentedViewController ?? self
    }
}
#endif

// MARK: - Match Coordinator

/// Class-based coordinator that owns the GKMatch lifecycle and drives netplay connection.
/// Used as a `@StateObject` so its `@Published` properties can drive SwiftUI updates.
@MainActor
final class NetplayGKMatchCoordinator: NSObject, ObservableObject {

    @Published var isExchangingAddresses = false
    @Published var connectionError: String?

    var onConnected: (() -> Void)?

    private let gameName: String
    private let coreIdentifier: String
    private let localGameHash: String
    private var activeMatch: GKMatch?

    init(gameName: String, coreIdentifier: String, localGameHash: String) {
        self.gameName = gameName
        self.coreIdentifier = coreIdentifier
        self.localGameHash = localGameHash
    }

    func handleMatch(_ match: GKMatch) {
        activeMatch = match
        match.delegate = self
        isExchangingAddresses = true

        // The player with the lexicographically lower gamePlayerID becomes the host.
        let localID = GKLocalPlayer.local.gamePlayerID
        let remoteIDs = match.players.map(\.gamePlayerID)
        let allIDs = ([localID] + remoteIDs).sorted()
        let iAmHost = allIDs.first == localID

        ILOG("[GameKit] Match established. isHost=\(iAmHost), players=\(allIDs)")

        if iAmHost {
            Task { await startAsHost(match: match) }
        }
        // Clients wait for delegate to fire with the host's port data.
    }

    // MARK: - Host path

    private func startAsHost(match: GKMatch) async {
        do {
            var settings = NetplaySettings.fromStoredDefaults(roomName: gameName)
            settings.relayServer = kGKRelayServer
            try await ObservableNetplayManager.shared.host(settings: settings)
            // Broadcast the port so joining peers can connect.
            let port = settings.port
            let portData = withUnsafeBytes(of: port.bigEndian) { Data($0) }
            try match.sendData(toAllPlayers: portData, with: .reliable)
            ILOG("[GameKit] Sent port \(port) to peers")
            isExchangingAddresses = false
            onConnected?()
        } catch {
            connectionError = error.localizedDescription
            isExchangingAddresses = false
            ELOG("[GameKit] Host start error: \(error)")
        }
    }

    // MARK: - Client path (called from GKMatchDelegate on main thread)

    fileprivate func receiveHostPort(_ port: UInt16, from hostPlayer: GKPlayer) {
        ILOG("[GameKit] Received host port: \(port)")
        let hostDisplayName = hostPlayer.displayName
        // TODO: GKMatch does not expose raw IP addresses — all traffic is routed through
        // Apple's Game Center relay. The RA.ME relay (set below) will handle the actual
        // TCP routing using the relay traversal code rather than a direct IP connection.
        // A future phase should exchange a relay traversal code (e.g. RA.ME session token)
        // instead of relying on the display name as a placeholder hostAddress.
        let room = NetplayRoom(
            hostName: hostDisplayName,
            gameName: gameName,
            gameHash: localGameHash,
            coreIdentifier: coreIdentifier,
            maxPlayers: 2,
            currentPlayers: 1,
            isLAN: false,
            hostAddress: hostDisplayName,
            port: port,
            discoverySource: .manual
        )
        var settings = NetplaySettings.fromStoredDefaults()
        settings.relayServer = kGKRelayServer
        Task {
            do {
                try await ObservableNetplayManager.shared.join(room: room, settings: settings)
                isExchangingAddresses = false
                onConnected?()
            } catch {
                connectionError = error.localizedDescription
                isExchangingAddresses = false
                ELOG("[GameKit] Client join error: \(error)")
            }
        }
    }
}

// MARK: - GKMatchDelegate

extension NetplayGKMatchCoordinator: GKMatchDelegate {
    nonisolated func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        guard data.count == 2 else { return }
        let port = data.withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
        Task { @MainActor in
            self.receiveHostPort(port, from: player)
        }
    }
}

// MARK: - GKMatchmakerViewController wrapper

#if !os(tvOS)
/// SwiftUI wrapper around `GKMatchmakerViewController`.
@MainActor
struct GKMatchmakerRepresentable: UIViewControllerRepresentable {

    let request: GKMatchRequest
    let onMatchFound: (GKMatch) -> Void
    let onCancelled: () -> Void
    let onError: (Error) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onMatchFound: onMatchFound, onCancelled: onCancelled, onError: onError)
    }

    func makeUIViewController(context: Context) -> GKMatchmakerViewController {
        guard let vc = GKMatchmakerViewController(matchRequest: request) else {
            // GKMatchmakerViewController(matchRequest:) returns nil for invalid requests
            // (e.g. minPlayers < 2). Fire the cancel callback so the sheet is dismissed.
            ELOG("[GameKit] GKMatchmakerViewController init returned nil — invalid GKMatchRequest")
            onCancelled()
            // Return a minimal placeholder to satisfy the non-optional return type;
            // the sheet will be dismissed on the next run-loop tick via onCancelled above.
            let fallbackRequest = GKMatchRequest()
            fallbackRequest.minPlayers = 2
            fallbackRequest.maxPlayers = 4
            guard let placeholder = GKMatchmakerViewController(matchRequest: fallbackRequest) else {
                fatalError("[GameKit] Could not create fallback GKMatchmakerViewController with valid GKMatchRequest")
            }
            return placeholder
        }
        vc.matchmakerDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: GKMatchmakerViewController, context: Context) {}

    final class Coordinator: NSObject, GKMatchmakerViewControllerDelegate {
        let onMatchFound: (GKMatch) -> Void
        let onCancelled: () -> Void
        let onError: (Error) -> Void

        init(onMatchFound: @escaping (GKMatch) -> Void,
             onCancelled: @escaping () -> Void,
             onError: @escaping (Error) -> Void) {
            self.onMatchFound = onMatchFound
            self.onCancelled = onCancelled
            self.onError = onError
        }

        func matchmakerViewControllerWasCancelled(_ viewController: GKMatchmakerViewController) {
            viewController.dismiss(animated: true)
            onCancelled()
        }

        func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFailWithError error: Error) {
            viewController.dismiss(animated: true)
            onError(error)
            ELOG("[GameKit] Matchmaking error: \(error.localizedDescription)")
        }

        func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFind match: GKMatch) {
            viewController.dismiss(animated: true)
            onMatchFound(match)
            ILOG("[GameKit] Match found with \(match.players.count) player(s)")
        }
    }
}
#endif // !os(tvOS)

// MARK: - NetplayGameCenterView

/// A view that orchestrates Game Center matchmaking then hands off to netplay.
///
/// Flow:
/// 1. Authenticate with Game Center (auto-triggers on appear).
/// 2. User taps "Find Match via Game Center".
/// 3. GKMatchmakerViewController is presented (iOS/visionOS).
/// 4. On match, the host player broadcasts their port; the joining player receives
///    it and initiates a RetroArch netplay join.
@MainActor
public struct NetplayGameCenterView: View {

    let gameName: String
    let coreIdentifier: String
    let localGameHash: String

    @ObservedObject private var gkManager = PVGameKitManager.shared
    @StateObject private var coordinator: NetplayGKMatchCoordinator
    @Environment(\.dismiss) private var dismiss

    @State private var showMatchmaker = false

    public init(gameName: String, coreIdentifier: String, localGameHash: String = "") {
        self.gameName = gameName
        self.coreIdentifier = coreIdentifier
        self.localGameHash = localGameHash
        self._coordinator = StateObject(
            wrappedValue: NetplayGKMatchCoordinator(
                gameName: gameName,
                coreIdentifier: coreIdentifier,
                localGameHash: localGameHash
            )
        )
    }

    public var body: some View {
        NavigationStack {
            Form {
                authSection
                matchmakingSection
            }
            .navigationTitle("Game Center Match")
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                coordinator.onConnected = { dismiss() }
                if !gkManager.isAuthenticated {
                    gkManager.authenticate()
                }
            }
            .alert(
                "Connection Error",
                isPresented: Binding(
                    get: { coordinator.connectionError != nil },
                    set: { if !$0 { coordinator.connectionError = nil } }
                ),
                presenting: coordinator.connectionError
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { msg in
                Text(msg)
            }
        }
#if !os(tvOS)
        .sheet(isPresented: $showMatchmaker) {
            if gkManager.isAuthenticated {
                GKMatchmakerRepresentable(
                    request: makeMatchRequest(),
                    onMatchFound: { match in
                        showMatchmaker = false
                        coordinator.handleMatch(match)
                    },
                    onCancelled: { showMatchmaker = false },
                    onError: { error in
                        showMatchmaker = false
                        coordinator.connectionError = error.localizedDescription
                    }
                )
                .ignoresSafeArea()
            }
        }
#endif
    }

    // MARK: - Sections

    private var authSection: some View {
        SwiftUI.Section("Game Center") {
            HStack {
                Image(systemName: gkManager.isAuthenticated
                      ? "checkmark.circle.fill"
                      : "person.crop.circle.badge.questionmark")
                    .foregroundStyle(gkManager.isAuthenticated ? .green : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    if gkManager.isAuthenticated, let player = gkManager.localPlayer {
                        Text(player.displayName)
                            .font(.headline)
                        Text("Signed in to Game Center")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Not signed in")
                            .font(.headline)
                        if let error = gkManager.authError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        } else {
                            Text("Sign in to use Game Center matchmaking")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
                if !gkManager.isAuthenticated {
                    Button("Sign In") {
                        gkManager.authenticate()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var matchmakingSection: some View {
        SwiftUI.Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Find a partner via Game Center to play \"\(gameName)\" together.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    showMatchmaker = true
                } label: {
                    Label("Find Match via Game Center", systemImage: "person.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!gkManager.isAuthenticated || coordinator.isExchangingAddresses)

                if coordinator.isExchangingAddresses {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Establishing connection…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Matchmaking")
        } footer: {
            Text("Game Center pairs two players, then Provenance connects them automatically via RetroArch netplay over the RA.ME relay.")
        }
    }

    // MARK: - Helpers

    private func makeMatchRequest() -> GKMatchRequest {
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 2
        request.inviteMessage = "Join me for \(gameName) on Provenance!"
        return request
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NetplayGameCenterView(gameName: "Super Mario World", coreIdentifier: "com.provenance.snes9x")
}
#endif

#endif // canImport(GameKit)
