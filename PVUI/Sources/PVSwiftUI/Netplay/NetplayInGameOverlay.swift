//
//  NetplayInGameOverlay.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/19/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if !os(watchOS)
import SwiftUI
import PVNetplay

// MARK: - NetplayInGameOverlay

/// Compact corner HUD shown during active netplay sessions.
///
/// Displays connection health (ping bars, player count) in a semi-transparent
/// pill anchored to the top-trailing corner of the emulator view. Tapping
/// expands the overlay to show per-peer stats, frame delay, and a disconnect
/// button.
///
/// Usage — add to your emulator container view:
/// ```swift
/// ZStack(alignment: .topTrailing) {
///     EmulatorContentView()
///     NetplayInGameOverlay()
///         .padding(.top, safeAreaInsets.top + 8)
///         .padding(.trailing, 12)
/// }
/// ```
///
/// tvOS: always compact; tap/expand is unavailable (no pointer/touch).
@MainActor
public struct NetplayInGameOverlay: View {
    @StateObject private var netplay = ObservableNetplayManager.shared
    @State private var isExpanded = false

    /// Overrides `ObservableNetplayManager.shared.state` — for previews and tests only.
    private let overrideState: NetplayState?

    public init() { overrideState = nil }

    /// Preview/test-only initializer that bypasses the live singleton.
    init(previewState: NetplayState) { overrideState = previewState }

    private var effectiveState: NetplayState { overrideState ?? netplay.state }

    public var body: some View {
        Group {
            if effectiveState.isActive {
                overlay
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .topTrailing)))
                    .animation(.easeInOut(duration: 0.2), value: effectiveState.isActive)
            }
        }
        .onChange(of: effectiveState.isActive) { active in
            if !active { isExpanded = false }
        }
    }

    // MARK: - Overlay Shell

    @ViewBuilder
    private var overlay: some View {
        VStack(alignment: .trailing, spacing: 0) {
            pill
            if isExpanded {
                detailPanel
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
    }

    // MARK: - Compact Pill

    private var pill: some View {
        HStack(spacing: 6) {
            // Player count
            Label {
                Text("\(playerCount)")
                    .monospacedDigit()
            } icon: {
                Image(systemName: "person.2.fill")
            }
            .font(.caption2.weight(.semibold))

            Divider()
                .frame(height: 12)

            // Ping bar indicator
            PingBarsView(pingMS: representativePingMS)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .foregroundStyle(.white)
        #if !os(tvOS)
        .contentShape(Capsule())
        .onTapGesture {
            isExpanded.toggle()
        }
        #endif
        .accessibilityLabel(pillAccessibilityLabel)
        .accessibilityHint(pillAccessibilityHint)
    }

    // MARK: - Expanded Detail Panel

    private var detailPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Per-peer rows
            if let session = effectiveState.session, !session.peers.isEmpty {
                ForEach(session.peers) { peer in
                    PeerRowView(peer: peer)
                }
                Divider()
                    .background(.white.opacity(0.3))
            }

            // Session stats
            if let session = effectiveState.session {
                sessionStatsRow("Frame Delay", value: "\(session.frameDelay)")
                sessionStatsRow("Rollback", value: session.isRollbackEnabled ? "On" : "Off")
            }

            Divider()
                .background(.white.opacity(0.3))

            // Disconnect button
            Button(role: .destructive) {
                Task { await ObservableNetplayManager.shared.disconnect() }
                isExpanded = false
            } label: {
                Label("Disconnect", systemImage: "wifi.slash")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .foregroundStyle(.white)
        .frame(minWidth: 180)
    }

    // MARK: - Helpers

    private var playerCount: Int {
        switch effectiveState {
        case .connected(let session):
            return session.peers.count + 1
        case .hosting(let room):
            return room.currentPlayers
        case .connecting(let room):
            return room.currentPlayers
        default:
            return 1
        }
    }

    /// Best single ping value to surface in the compact pill.
    /// Uses the maximum peer ping so the indicator reflects the worst link.
    private var representativePingMS: Int? {
        guard let session = effectiveState.session else { return nil }
        return session.peers.compactMap(\.pingMS).max()
    }

    private var pillAccessibilityLabel: String {
        let ping = representativePingMS.map { "\($0)ms" } ?? "unknown ping"
        return "Netplay active — \(playerCount) players, \(ping)"
    }

    private var pillAccessibilityHint: String {
        #if os(tvOS)
        return "Compact view — detailed stats unavailable on this platform"
        #else
        return isExpanded ? "Tap to collapse" : "Tap to expand connection details"
        #endif
    }

    private func sessionStatsRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
    }
}

// MARK: - PingBarsView

/// Three-bar signal-strength indicator coloured by latency bucket.
private struct PingBarsView: View {
    let pingMS: Int?

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            bar(height: 5, filled: filledBars >= 1)
            bar(height: 8, filled: filledBars >= 2)
            bar(height: 11, filled: filledBars >= 3)
        }
        .foregroundStyle(barColor)
    }

    private var filledBars: Int {
        guard let ms = pingMS else { return 0 }
        switch ms {
        case ..<60:   return 3
        case ..<120:  return 2
        default:      return 1
        }
    }

    private var barColor: Color {
        guard let ms = pingMS else { return .gray }
        switch ms {
        case ..<60:   return .green
        case ..<120:  return .yellow
        default:      return .red
        }
    }

    private func bar(height: CGFloat, filled: Bool) -> some View {
        RoundedRectangle(cornerRadius: 1.5)
            .frame(width: 3, height: height)
            .opacity(filled ? 1 : 0.3)
    }
}

// MARK: - PeerRowView

private struct PeerRowView: View {
    let peer: NetplayPeer

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: peer.isSpectator ? "eye.fill" : "person.fill")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))

            Text(peer.nickname)
                .font(.caption)
                .lineLimit(1)

            Spacer()

            if let ms = peer.pingMS {
                Text("\(ms)ms")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(pingColor(ms))
            } else {
                Text("—")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    private func pingColor(_ ms: Int) -> Color {
        switch ms {
        case ..<60:   return .green
        case ..<120:  return .yellow
        default:      return .red
        }
    }
}

// MARK: - Preview

#if DEBUG
private extension NetplayRoom {
    static let preview = NetplayRoom(
        hostName: "Player 1",
        gameName: "Street Fighter II",
        gameHash: "abc123",
        coreIdentifier: "com.provenance.snes9x",
        maxPlayers: 2,
        currentPlayers: 2,
        isLAN: true,
        hostAddress: "192.168.1.2",
        port: 55435
    )
}

private extension NetplaySession {
    static let preview = NetplaySession(
        room: .preview,
        role: .client(host: "192.168.1.2", port: 55435),
        peers: [
            NetplayPeer(nickname: "Player 1", playerIndex: 0, pingMS: 42),
            NetplayPeer(nickname: "Spectator", playerIndex: 2, pingMS: 88, isSpectator: true)
        ],
        frameDelay: 3,
        isRollbackEnabled: true
    )
}

#Preview("Idle — not shown") {
    NetplayInGameOverlay(previewState: .idle)
}

#Preview("Connected — compact") {
    ZStack(alignment: .topTrailing) {
        Color.black.ignoresSafeArea()
        NetplayInGameOverlay(previewState: .connected(session: .preview))
            .padding()
    }
}

#Preview("Connected — expanded") {
    ZStack(alignment: .topTrailing) {
        Color.black.ignoresSafeArea()
        NetplayInGameOverlay(previewState: .connected(session: .preview))
            .padding()
    }
}

#Preview("High ping — warning state") {
    ZStack(alignment: .topTrailing) {
        Color.black.ignoresSafeArea()
        NetplayInGameOverlay(previewState: .connected(session: NetplaySession(
            room: .preview,
            role: .client(host: "192.168.1.2", port: 55435),
            peers: [NetplayPeer(nickname: "Player 1", playerIndex: 0, pingMS: 145)],
            frameDelay: 5,
            isRollbackEnabled: false
        )))
        .padding()
    }
}
#endif
#endif
