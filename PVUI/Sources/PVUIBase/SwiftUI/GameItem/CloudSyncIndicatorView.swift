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
    
    enum CloudStatus {
        case available
        case downloading
        case downloaded
        case none
    }
    
    private let status: CloudStatus
    private let size: CGFloat
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    public init(isDownloaded: Bool, hasCloudRecord: Bool, isDownloading: Bool = false, size: CGFloat = 20) {
        if !hasCloudRecord {
            self.status = .none
        } else if isDownloading {
            self.status = .downloading
        } else if isDownloaded {
            self.status = .downloaded
        } else {
            self.status = .available
        }
        
        self.size = size
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
        case .none:
            EmptyView()
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        CloudSyncIndicatorView(isDownloaded: false, hasCloudRecord: true)
            .previewDisplayName("Available")
        
        CloudSyncIndicatorView(isDownloaded: false, hasCloudRecord: true, isDownloading: true)
            .previewDisplayName("Downloading")
        
        CloudSyncIndicatorView(isDownloaded: true, hasCloudRecord: true)
            .previewDisplayName("Downloaded")
        
        CloudSyncIndicatorView(isDownloaded: true, hasCloudRecord: false)
            .previewDisplayName("No Cloud Record")
    }
    .padding()
    .background(Color.gray)
}
