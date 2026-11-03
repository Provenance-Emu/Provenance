//
//  CloudSyncIndicatorView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/23/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import SwiftUI
import PVThemes

/// A view that displays the cloud sync status of a game
public struct CloudSyncIndicatorView: View {

    enum CloudStatus: Equatable {
        case available
        case downloading
        case downloaded
        /// Cloud assets exist but sync is disabled — nudge the user
        case syncDisabled
        case none
    }

    private let status: CloudStatus
    private let size: CGFloat

    @ObservedObject private var themeManager = ThemeManager.shared

    public init(isDownloaded: Bool, hasCloudAssets: Bool, isDownloading: Bool = false, syncEnabled: Bool = true, size: CGFloat = 20) {
        self.status = Self.resolveStatus(isDownloaded: isDownloaded, hasCloudAssets: hasCloudAssets,
                                         isDownloading: isDownloading, syncEnabled: syncEnabled)

        self.size = size
    }

    /// Downloaded files stay usable when sync is off; absent cloud records never get a badge.
    static func resolveStatus(isDownloaded: Bool, hasCloudAssets: Bool, isDownloading: Bool, syncEnabled: Bool) -> CloudStatus {
        if !hasCloudAssets {
            return .none
        } else if !syncEnabled && !isDownloaded {
            return .syncDisabled
        } else if isDownloading {
            return .downloading
        } else if isDownloaded {
            return .downloaded
        } else {
            return .available
        }
    }

    public var body: some View {
        switch status {
        case .available:
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.7))
                    .frame(width: size, height: size)

                Image(systemName: "icloud.and.arrow.down")
                    .font(.system(size: size * 0.6))
                    .foregroundColor(.retroBlue)
            }
        case .downloading:
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.7))
                    .frame(width: size, height: size)

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .retroPink))
                    .scaleEffect(0.7)
            }
        case .downloaded:
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.7))
                    .frame(width: size, height: size)

                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.6))
                    .foregroundColor(.green)
            }
        case .syncDisabled:
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.7))
                    .frame(width: size, height: size)

                Image(systemName: "icloud.slash")
                    .font(.system(size: size * 0.6))
                    .foregroundColor(.gray)
            }
        case .none:
            EmptyView()
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        CloudSyncIndicatorView(isDownloaded: false, hasCloudAssets: true)
            .previewDisplayName("Available")

        CloudSyncIndicatorView(isDownloaded: false, hasCloudAssets: true, isDownloading: true)
            .previewDisplayName("Downloading")

        CloudSyncIndicatorView(isDownloaded: true, hasCloudAssets: true)
            .previewDisplayName("Downloaded")

        CloudSyncIndicatorView(isDownloaded: true, hasCloudAssets: false)
            .previewDisplayName("No Cloud Record")

        CloudSyncIndicatorView(isDownloaded: false, hasCloudAssets: true, syncEnabled: false)
            .previewDisplayName("Sync Disabled")
    }
    .padding()
    .background(Color.gray)
}
