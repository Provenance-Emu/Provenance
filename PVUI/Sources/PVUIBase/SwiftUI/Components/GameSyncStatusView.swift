//
//  GameSyncStatusView.swift
//  PVUI
//
//  Created on 2025-01-XX.
//

import SwiftUI
import PVLibrary
import PVThemes

/// View showing sync status during game launch validation with RetroWave styling
public struct GameSyncStatusView: View {
    let gameTitle: String
    let statusMessage: String
    let isComplete: Bool
    let hasError: Bool
    let onCancel: (() -> Void)?

    #if os(tvOS)
    @FocusState private var cancelButtonFocused: Bool
    #endif

    /// Animation state for glow effect
    @State private var glowOpacity: Double = 0.7

    /// Animation state for spinner rotation
    @State private var spinnerRotation: Double = 0

    public init(
        gameTitle: String,
        statusMessage: String,
        isComplete: Bool = false,
        hasError: Bool = false,
        onCancel: (() -> Void)? = nil
    ) {
        self.gameTitle = gameTitle
        self.statusMessage = statusMessage
        self.isComplete = isComplete
        self.hasError = hasError
        self.onCancel = onCancel
    }

    public var body: some View {
        ZStack {
            // Background overlay with gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.9),
                    Color.retroBlack.opacity(0.85)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                // Game title with neon glow
                Text(gameTitle)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .shadow(color: Color.retroBlue.opacity(0.8), radius: 10, x: 0, y: 0)

                // Status indicator
                statusIndicatorView
                    .padding(.vertical, 8)

                // Status message
                Text(statusMessage)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .lineSpacing(4)

                // Cancel button (only show if not complete and not error)
                if !isComplete && !hasError, let cancel = onCancel {
                    #if os(tvOS)
                    RetroTVOSCancelButton(isFocused: cancelButtonFocused, action: cancel)
                        .focused($cancelButtonFocused)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                cancelButtonFocused = true
                            }
                        }
                        .padding(.top, 16)
                    #else
                    RetroSyncCancelButton(action: cancel)
                        .padding(.top, 16)
                    #endif
                }
            }
            .padding(40)
            .background(
                ZStack {
                    // Base background
                    Color.retroBlack

                    // Grid pattern
                    RetroSyncGridPattern()
                        .opacity(0.2)

                    // Scanline effect
                    RetroSyncScanlines()
                        .opacity(0.03)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(colors: borderColors),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
            .shadow(color: glowColor.opacity(glowOpacity), radius: 25, x: 0, y: 0)
            .padding(40)
            .onAppear {
                // Animate glow
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    glowOpacity = 0.3
                }

                // Animate spinner
                if !isComplete && !hasError {
                    withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                        spinnerRotation = 360
                    }
                }
            }
        }
    }

    // MARK: - Status Indicator

    @ViewBuilder
    private var statusIndicatorView: some View {
        if hasError {
            // Error state
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.2))
                    .frame(width: 80, height: 80)

                Circle()
                    .stroke(Color.red, lineWidth: 3)
                    .frame(width: 80, height: 80)

                Image(systemName: "xmark")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.red)
            }
            .shadow(color: Color.red.opacity(0.6), radius: 15)

        } else if isComplete {
            // Success state
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 80, height: 80)

                Circle()
                    .stroke(Color.green, lineWidth: 3)
                    .frame(width: 80, height: 80)

                Image(systemName: "checkmark")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.green)
            }
            .shadow(color: Color.green.opacity(0.6), radius: 15)

        } else {
            // Loading state - RetroWave spinner
            ZStack {
                // Outer glow ring
                Circle()
                    .stroke(Color.retroBlue.opacity(0.3), lineWidth: 4)
                    .frame(width: 70, height: 70)

                // Middle ring
                Circle()
                    .stroke(Color.retroPink.opacity(0.2), lineWidth: 2)
                    .frame(width: 50, height: 50)

                // Spinning arc
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [.retroBlue, .retroPink, .retroPurple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .frame(width: 70, height: 70)
                    .rotationEffect(.degrees(spinnerRotation))

                // Inner dot
                Circle()
                    .fill(Color.retroBlue)
                    .frame(width: 8, height: 8)
                    .shadow(color: Color.retroBlue.opacity(0.8), radius: 5)
            }
            .shadow(color: Color.retroBlue.opacity(0.5), radius: 15)
        }
    }

    // MARK: - Computed Properties

    private var borderColors: [Color] {
        if hasError {
            return [.red, .retroPink]
        } else if isComplete {
            return [.green, .retroBlue]
        } else {
            return [.retroPink, .retroBlue]
        }
    }

    private var glowColor: Color {
        if hasError {
            return .red
        } else if isComplete {
            return .green
        } else {
            return .retroPink
        }
    }
}

// MARK: - Supporting Views

/// RetroWave styled cancel button for iOS
private struct RetroSyncCancelButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Cancel")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [.red.opacity(0.8), .red.opacity(0.6)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [.red, .retroPink]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: Color.red.opacity(0.5), radius: 8)
        }
    }
}

#if os(tvOS)
/// tvOS-specific cancel button with RetroWave styling and proper focus handling
private struct RetroTVOSCancelButton: View {
    let isFocused: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Cancel")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 56)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    isFocused ? Color.red : Color.red.opacity(0.6),
                                    isFocused ? Color.red.opacity(0.8) : Color.red.opacity(0.4)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [.red, .retroPink]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: isFocused ? 3 : 1.5
                        )
                )
                .shadow(
                    color: isFocused ? Color.red.opacity(0.8) : Color.red.opacity(0.3),
                    radius: isFocused ? 15 : 5
                )
                .scaleEffect(isFocused ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isFocused)
        }
        .buttonStyle(.plain)
    }
}
#endif

/// Grid pattern for sync status view
private struct RetroSyncGridPattern: View {
    var body: some View {
        Canvas { context, size in
            // Horizontal lines
            let hSpacing: CGFloat = 25
            var y: CGFloat = 0
            while y < size.height {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(Color.retroBlue.opacity(0.4)), lineWidth: 1)
                y += hSpacing
            }

            // Vertical lines
            let vSpacing: CGFloat = 25
            var x: CGFloat = 0
            while x < size.width {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(Color.retroBlue.opacity(0.4)), lineWidth: 1)
                x += vSpacing
            }
        }
    }
}

/// Scanline effect overlay
private struct RetroSyncScanlines: View {
    var body: some View {
        Canvas { context, size in
            let lineSpacing: CGFloat = 2
            var y: CGFloat = 0
            while y < size.height {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(Color.black), lineWidth: 1)
                y += lineSpacing
            }
        }
    }
}

/// Observable object for managing sync status during game launch
@MainActor
public class GameSyncStatusManager: ObservableObject {
    @Published public var isVisible: Bool = false
    @Published public var gameTitle: String = ""
    @Published public var statusMessage: String = ""
    @Published public var isComplete: Bool = false
    @Published public var hasError: Bool = false

    public var onCancel: (() -> Void)?

    public func show(
        gameTitle: String,
        statusMessage: String = "Preparing game...",
        onCancel: (() -> Void)? = nil
    ) {
        self.gameTitle = gameTitle
        self.statusMessage = statusMessage
        self.isComplete = false
        self.hasError = false
        self.onCancel = onCancel
        self.isVisible = true
    }

    public func update(statusMessage: String) {
        self.statusMessage = statusMessage
    }

    public func complete() {
        self.isComplete = true
        self.statusMessage = "Game ready"
        // Auto-hide after a brief delay
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            self.hide()
        }
    }

    public func error(_ message: String) {
        self.hasError = true
        self.statusMessage = message
    }

    public func hide() {
        self.isVisible = false
        self.gameTitle = ""
        self.statusMessage = ""
        self.isComplete = false
        self.hasError = false
        self.onCancel = nil
    }
}

// MARK: - Preview

#if DEBUG
struct GameSyncStatusView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Loading state
            GameSyncStatusView(
                gameTitle: "Super Mario Bros.",
                statusMessage: "Downloading game file...",
                onCancel: {}
            )
            .previewDisplayName("Loading")

            // Complete state
            GameSyncStatusView(
                gameTitle: "The Legend of Zelda",
                statusMessage: "Game ready",
                isComplete: true
            )
            .previewDisplayName("Complete")

            // Error state
            GameSyncStatusView(
                gameTitle: "Metroid",
                statusMessage: "Failed to sync game file",
                hasError: true
            )
            .previewDisplayName("Error")
        }
    }
}
#endif
