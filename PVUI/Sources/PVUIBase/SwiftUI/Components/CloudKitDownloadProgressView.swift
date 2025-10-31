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

/// SwiftUI view for displaying CloudKit download progress with cancel option
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
        VStack(spacing: 20) {
            // Game title
            Text(gameTitle)
                .font(.headline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Progress indicator
            if hasError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.red)

                    Text("Download Failed")
                        .font(.title2)
                        .foregroundColor(.red)

                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else if isCompleted {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)

                    Text("Download Complete")
                        .font(.title2)
                        .foregroundColor(.green)
                }
            } else {
                VStack(spacing: 16) {
                    // Progress circle
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                            .frame(width: 80, height: 80)

                        Circle()
                            .trim(from: 0, to: downloadProgress)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [.blue, .purple]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.3), value: downloadProgress)

                        Text("\(Int(downloadProgress * 100))%")
                            .font(.caption)
                            .fontWeight(.bold)
                    }

                    Text("Downloading from iCloud...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            // Action buttons
            HStack(spacing: 20) {
                if isCompleted {
                    Button("Continue") {
                        onComplete()
                    }
                    .buttonStyle(.borderedProminent)
                } else if hasError {
                    Button("Retry") {
                        // Reset error state and retry
                        hasError = false
                        errorMessage = ""
                        downloadProgress = 0.0
                        // The download queue should handle retry logic
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Cancel") {
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Cancel") {
                        // Cancel the download
                        CloudKitDownloadQueue.shared.cancelDownload(md5: gameMD5)
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.top)
        }
        .padding()
        .background(backgroundColorForPlatform)
        .cornerRadius(12)
        .shadow(radius: 10)
        .onAppear {
            monitorDownloadProgress()
        }
    }

        /// Monitor download progress for this specific game
    private func monitorDownloadProgress() {
        // Monitor active downloads for progress updates
        progressTracker.$activeDownloads
            .map { downloads in
                downloads.first { $0.md5 == gameMD5 }?.progress ?? 0.0
            }
            .receive(on: DispatchQueue.main)
            .sink { progress in
                downloadProgress = progress
            }
            .store(in: &cancellables)

        // Monitor for completion
        progressTracker.$activeDownloads
            .map { downloads in
                !downloads.contains { $0.md5 == gameMD5 }
            }
            .filter { $0 } // Only when true (download no longer active)
            .delay(for: 0.5, scheduler: DispatchQueue.main) // Small delay to allow UI update
            .sink { _ in
                // Check if it completed successfully or failed
                if progressTracker.failedDownloads.contains(where: { $0.md5 == gameMD5 }) {
                    // Failed - show error and call onCancel to dismiss emulator
                    if let failedDownload = progressTracker.failedDownloads.first(where: { $0.md5 == gameMD5 }) {
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
                !queued.contains { $0.md5 == gameMD5 } &&
                !active.contains { $0.md5 == gameMD5 } &&
                !progressTracker.failedDownloads.contains { $0.md5 == gameMD5 }
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

    @State private var cancellables = Set<AnyCancellable>()

    /// Platform-appropriate background color
    private var backgroundColorForPlatform: Color {
        #if os(tvOS)
        return Color.black.opacity(0.8)
        #else
        return Color(.systemBackground)
        #endif
    }
}
