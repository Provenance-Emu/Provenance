//
//  CloudKitDownloadProgressView.swift
//  PVUI
//
//  Created by AI Assistant
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import SwiftUI
import Combine
import PVLibrary
import PVUIBase

/// SwiftUI view for displaying CloudKit download progress with cancel option — retrowave restyle.
public struct CloudKitDownloadProgressView: View {
    let gameMD5: String
    let gameTitle: String
    let onCancel: () -> Void
    let onComplete: () -> Void

    @StateObject private var progressTracker = SyncProgressTracker.shared
    @State private var downloadProgress: Double = 0.0
    @State private var isCompleted: Bool = false
    @State private var hasError: Bool = false
    @State private var errorMessage: String = ""
    @State private var cancellables = Set<AnyCancellable>()
    @State private var glowPulse: Bool = false

    public init(
        gameMD5: String,
        gameTitle: String,
        onCancel: @escaping () -> Void,
        onComplete: @escaping () -> Void = {}
    ) {
        self.gameMD5 = gameMD5
        self.gameTitle = gameTitle
        self.onCancel = onCancel
        self.onComplete = onComplete
    }

    public var body: some View {
        VStack(spacing: 22) {
            header

            // Status content
            Group {
                if hasError {
                    errorState
                } else if isCompleted {
                    completedState
                } else {
                    inProgressState
                }
            }
            .frame(maxWidth: .infinity)

            actionButtons
        }
        .padding(22)
        .background(panelBackground)
        .shadow(color: .retroPink.opacity(glowPulse ? 0.6 : 0.3),
                radius: glowPulse ? 16 : 8)
        .onAppear {
            monitorDownloadProgress()
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(LinearGradient(colors: [.retroPink, .retroPurple],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 3, height: 14)
                    .shadow(color: .retroPink.opacity(0.7), radius: 3)

                Text("ICLOUD DOWNLOAD")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.6)
                    .foregroundColor(.retroPink)
                    .shadow(color: .retroPink.opacity(0.5), radius: 3)
            }

            Text(gameTitle)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(
                    LinearGradient(colors: [.white, .retroBlue.opacity(0.9)],
                                   startPoint: .top, endPoint: .bottom)
                )
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
                .lineLimit(3)
        }
    }

    // MARK: - States

    private var inProgressState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 8)
                    .frame(width: 100, height: 100)

                Circle()
                    .trim(from: 0, to: downloadProgress)
                    .stroke(
                        LinearGradient(
                            colors: [.retroPink, .retroPurple, .retroBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: .retroPink.opacity(0.55), radius: 6)
                    .animation(.easeInOut(duration: 0.3), value: downloadProgress)

                VStack(spacing: 2) {
                    Text("\(Int(downloadProgress * 100))")
                        .font(.system(size: 28, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                    Text("%")
                        .font(.system(size: 12, weight: .heavy, design: .monospaced))
                        .foregroundColor(.retroBlue)
                        .tracking(1.2)
                }
            }

            Text("DOWNLOADING FROM ICLOUD…")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(1.4)
                .foregroundColor(.retroBlue)
                .shadow(color: .retroBlue.opacity(0.5), radius: 3)
        }
    }

    private var completedState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56, weight: .bold))
                .foregroundStyle(
                    LinearGradient(colors: [.retroGreen, .retroBlue],
                                   startPoint: .top, endPoint: .bottom)
                )
                .shadow(color: .retroGreen.opacity(0.6), radius: 8)

            Text("DOWNLOAD COMPLETE")
                .font(.system(size: 14, weight: .heavy))
                .tracking(1.4)
                .foregroundColor(.retroGreen)
                .shadow(color: .retroGreen.opacity(0.5), radius: 3)
        }
    }

    private var errorState: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(colors: [.retroOrange, .retroPink],
                                   startPoint: .top, endPoint: .bottom)
                )
                .shadow(color: .retroOrange.opacity(0.6), radius: 8)

            Text("DOWNLOAD FAILED")
                .font(.system(size: 14, weight: .heavy))
                .tracking(1.4)
                .foregroundColor(.retroOrange)
                .shadow(color: .retroOrange.opacity(0.5), radius: 3)

            Text(errorMessage)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
                .lineLimit(4)
        }
    }

    // MARK: - Buttons

    private var actionButtons: some View {
        HStack(spacing: 14) {
            if isCompleted {
                neonButton(title: "CONTINUE",
                           accent: .retroGreen,
                           filled: true) {
                    onComplete()
                }
            } else if hasError {
                neonButton(title: "RETRY",
                           accent: .retroBlue,
                           filled: true) {
                    hasError = false
                    errorMessage = ""
                    downloadProgress = 0.0
                    // The download queue should handle retry logic
                }

                neonButton(title: "EXIT",
                           accent: .retroOrange,
                           filled: false) {
                    CloudKitDownloadQueue.shared.cancelDownload(md5: gameMD5)
                    onCancel()
                }
            } else {
                neonButton(title: "CANCEL",
                           accent: .retroPink,
                           filled: false) {
                    CloudKitDownloadQueue.shared.cancelDownload(md5: gameMD5)
                    onCancel()
                }
            }
        }
    }

    private func neonButton(title: String,
                            accent: Color,
                            filled: Bool,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .heavy))
                .tracking(1.2)
                .foregroundColor(filled ? .white : accent)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .frame(minWidth: 100)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(filled
                              ? AnyShapeStyle(LinearGradient(colors: [accent, accent.opacity(0.7)],
                                                             startPoint: .leading,
                                                             endPoint: .trailing))
                              : AnyShapeStyle(accent.opacity(0.12)))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(accent.opacity(filled ? 0.8 : 0.5), lineWidth: 1.5)
                )
                .shadow(color: accent.opacity(filled ? 0.5 : 0.25), radius: 5)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Background

    private var panelBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.retroBlack.opacity(0.92))

            // subtle grid for retrowave feel
            RetroTheme.RetroGridView()
                .opacity(0.10)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            // scanlines
            RetroScanlineOverlay()
                .opacity(0.05)
                .allowsHitTesting(false)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [.retroPink.opacity(0.6),
                                            .retroPurple.opacity(0.5),
                                            .retroBlue.opacity(0.6)],
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing),
                    lineWidth: 1.5
                )
        }
    }

    /// Monitor download progress for this specific game
    private func monitorDownloadProgress() {
        // Monitor active downloads for progress updates
        progressTracker.$activeDownloads
            .map { downloads in
                downloads.first { $0.matchesROM(md5: gameMD5) }?.progress ?? 0.0
            }
            .receive(on: DispatchQueue.main)
            .sink { progress in
                downloadProgress = progress
            }
            .store(in: &cancellables)

        // Monitor for completion
        progressTracker.$activeDownloads
            .map { downloads in
                !downloads.contains(where: { $0.matchesROM(md5: gameMD5) })
            }
            .filter { $0 } // Only when true (download no longer active)
            .delay(for: 0.5, scheduler: DispatchQueue.main) // Small delay to allow UI update
            .sink { _ in
                // Check if it completed successfully or failed
                if progressTracker.failedDownloads.contains(where: { $0.matchesROM(md5: gameMD5) }) {
                    // Failed - show error and call onCancel to dismiss emulator
                    if let failedDownload = progressTracker.failedDownloads.first(where: { $0.matchesROM(md5: gameMD5) }) {
                        hasError = true
                        errorMessage = "\(failedDownload.error)"
                        // Don't auto-dismiss on error - let user choose to retry or cancel
                    }
                } else {
                    // Completed successfully
                    isCompleted = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        onComplete()
                    }
                }
            }
            .store(in: &cancellables)

        // Monitor for cancellation (when download is removed from queue without completion)
        progressTracker.$queuedDownloads
            .combineLatest(progressTracker.$activeDownloads)
            .map { queued, active in
                // Download is cancelled if it's not in queued or active lists and not failed
                !queued.contains(where: { $0.matchesROM(md5: gameMD5) }) &&
                !active.contains(where: { $0.matchesROM(md5: gameMD5) }) &&
                !progressTracker.failedDownloads.contains(where: { $0.matchesROM(md5: gameMD5) })
            }
            .filter { $0 } // Only when true (cancelled)
            .sink { _ in
                // Download was cancelled - call onCancel to dismiss emulator
                DispatchQueue.main.async {
                    onCancel()
                }
            }
            .store(in: &cancellables)
    }
}
