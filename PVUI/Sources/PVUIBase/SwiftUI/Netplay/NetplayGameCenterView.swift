//
//  NetplayGameCenterView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/27/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Provides Game Center matchmaking for netplay. Game Center pairs the
//  players but never reveals their IP addresses, so once a GKMatch forms the
//  host sends its own addresses and port over the match (`NetplayJoinInfo`)
//  and the other player connects to them directly. That works on the same
//  network, or across the internet when the host's port is reachable.
//

#if !os(watchOS) && canImport(GameKit)
import SwiftUI
import GameKit
import PVNetplay
import PVLogging

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
            // The other player connects to our addresses directly.
            settings.relayServer = nil
            // "Any free port" can't be shared before hosting starts.
            if settings.port == 0 {
                settings.port = NetplayJoinRequest.defaultPort
            }
            try await ObservableNetplayManager.shared.host(settings: settings)
            let addresses = NetplayLocalAddresses.current()
            guard !addresses.isEmpty else {
                throw NetplayError.connectionFailed("This device has no network address to share.")
            }
            let info = NetplayJoinInfo(port: settings.port, addresses: addresses)
            try match.sendData(toAllPlayers: info.encoded(), with: .reliable)
            ILOG("[GameKit] Sent join info: \(addresses.joined(separator: ", ")) port \(settings.port)")
            isExchangingAddresses = false
            onConnected?()
        } catch {
            connectionError = error.localizedDescription
            isExchangingAddresses = false
            ELOG("[GameKit] Host start error: \(error)")
        }
    }

    // MARK: - Client path (called from GKMatchDelegate on main thread)

    fileprivate func receiveJoinInfo(_ info: NetplayJoinInfo, from hostPlayer: GKPlayer) {
        ILOG("[GameKit] Host \(hostPlayer.displayName) is at \(info.addresses.joined(separator: ", ")) port \(info.port)")
        var settings = NetplaySettings.fromStoredDefaults()
        settings.relayServer = nil
        Task {
            // Try each address the host has, same-network ones first.
            var lastError: Error = NetplayError.connectionFailed("The host shared no addresses.")
            for address in info.addresses {
                let room = NetplayRoom(
                    hostName: hostPlayer.displayName,
                    gameName: gameName,
                    gameHash: localGameHash,
                    coreIdentifier: coreIdentifier,
                    maxPlayers: 2,
                    currentPlayers: 1,
                    isLAN: false,
                    hostAddress: address,
                    port: info.port,
                    discoverySource: .manual
                )
                do {
                    try await ObservableNetplayManager.shared.join(room: room, settings: settings)
                    isExchangingAddresses = false
                    onConnected?()
                    return
                } catch {
                    WLOG("[GameKit] Couldn't join \(address):\(info.port): \(error.localizedDescription)")
                    lastError = error
                }
            }
            connectionError = lastError.localizedDescription
            isExchangingAddresses = false
        }
    }
}

// MARK: - GKMatchDelegate

extension NetplayGKMatchCoordinator: GKMatchDelegate {
    nonisolated func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        guard let info = NetplayJoinInfo.decode(data) else {
            WLOG("[GameKit] Unreadable join info (\(data.count) bytes) from \(player.displayName)")
            Task { @MainActor in
                self.connectionError = "\(player.displayName) is running a different version of Provenance. Update both devices and try again."
                self.isExchangingAddresses = false
            }
            return
        }
        Task { @MainActor in
            self.receiveJoinInfo(info, from: player)
        }
    }

    nonisolated func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        switch state {
        case .disconnected:
            WLOG("[GameKit] Player '\(player.displayName)' disconnected from match")
            Task { @MainActor in
                self.connectionError = "\(player.displayName) disconnected"
                self.isExchangingAddresses = false
            }
        case .connected:
            ILOG("[GameKit] Player '\(player.displayName)' connected to match")
        case .unknown:
            WLOG("[GameKit] Player '\(player.displayName)' connection state unknown")
        @unknown default:
            break
        }
    }

    nonisolated func match(_ match: GKMatch, didFailWithError error: Error?) {
        let message = error?.localizedDescription ?? "Unknown match error"
        ELOG("[GameKit] Match failed: \(message)")
        Task { @MainActor in
            self.connectionError = message
            self.isExchangingAddresses = false
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
            // (e.g. minPlayers < 2). Fire the cancel callback so the sheet is dismissed,
            // then return a valid placeholder — it will never be shown.
            // Deferred via Task to avoid mutating @State during a SwiftUI rendering pass.
            ELOG("[GameKit] GKMatchmakerViewController init returned nil — invalid GKMatchRequest")
            let cancel = onCancelled
            Task { @MainActor in cancel() }
            let fallbackRequest = GKMatchRequest()
            fallbackRequest.minPlayers = 2
            fallbackRequest.maxPlayers = 4
            // Force-unwrap is safe: hardcoded minPlayers=2/maxPlayers=4 always produce a
            // valid GKMatchmakerViewController. The returned controller is never displayed
            // because onCancelled() above already dismissed the presenting sheet.
            return GKMatchmakerViewController(matchRequest: fallbackRequest)!
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
/// 4. On match, the host starts hosting and sends its addresses and port; the
///    other player connects to them directly.
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

                #if !os(tvOS)
                Button {
                    showMatchmaker = true
                } label: {
                    Label("Find Match via Game Center", systemImage: "person.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!gkManager.isAuthenticated || coordinator.isExchangingAddresses)
                #else
                Text("Game Center matchmaking requires the iOS or visionOS version of Provenance.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                #endif

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
            Text("Game Center pairs two players, then Provenance connects them directly. This works on the same Wi-Fi, or over the internet if the host's netplay port is reachable.")
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
