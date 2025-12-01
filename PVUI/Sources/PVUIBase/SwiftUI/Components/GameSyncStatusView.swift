//
//  GameSyncStatusView.swift
//  PVUI
//
//  Created on 2025-01-XX.
//

import SwiftUI
import PVLibrary

/// View showing sync status during game launch validation
public struct GameSyncStatusView: View {
    let gameTitle: String
    let statusMessage: String
    let isComplete: Bool
    let hasError: Bool
    let onCancel: (() -> Void)?

    #if os(tvOS)
    @FocusState private var cancelButtonFocused: Bool
    #endif

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
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Game title
                Text(gameTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Status indicator
                if hasError {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 56))
                            .foregroundColor(.red)

                        Text("Sync Failed")
                            .font(.headline)
                            .foregroundColor(.red)
                    }
                } else if isComplete {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 56))
                            .foregroundColor(.green)

                        Text("Ready")
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                } else {
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    }
                }

                // Status message
                Text(statusMessage)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // Cancel button (only show if not complete and not error)
                if !isComplete && !hasError, let cancel = onCancel {
                    #if os(tvOS)
                    TVOSCancelButton(isFocused: cancelButtonFocused, action: cancel)
                        .focused($cancelButtonFocused)
                        .onAppear {
                            // Auto-focus the cancel button when it appears
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                cancelButtonFocused = true
                            }
                        }
                        .padding(.top, 16)
                    #else
                    Button(action: cancel) {
                        Text("Cancel")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(8)
                    }
                    .padding(.top, 8)
                    #endif
                }
            }
            .padding(32)
#if !os(tvOS)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
                    .shadow(radius: 20)
            )
            #endif
            .padding(40)
        }
    }
}

#if os(tvOS)
/// tvOS-specific cancel button with proper focus handling
struct TVOSCancelButton: View {
    let isFocused: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Cancel")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 48)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isFocused ? Color.red : Color.red.opacity(0.5))
                        .shadow(color: isFocused ? Color.red.opacity(0.6) : Color.clear, radius: 10)
                )
                .scaleEffect(isFocused ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isFocused)
        }
        .buttonStyle(.plain)
    }
}
#endif

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
