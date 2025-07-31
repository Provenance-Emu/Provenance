//
//  FileCopyProgressView.swift
//  PVUI
//
//  Created by Cascade on 7/31/25.
//

import SwiftUI
import PVLibrary
import PVThemes
import Combine

/// SwiftUI view for displaying file copy progress operations
public struct FileCopyProgressView: View {
    @StateObject private var progressTracker = FileCopyProgressObserver()
    @ObservedObject private var themeManager = ThemeManager.shared
    
    // Animation states for retrowave effects
    @State private var glowOpacity: Double = 0.7
    
    var currentPalette: any UXThemePalette { themeManager.currentPalette }
    
    public init() {}
    
    public var body: some View {
        if !progressTracker.operations.isEmpty {
            VStack(spacing: 12) {
                // Header
                HStack {
                    Text("FILE TRANSFERS")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(RetroTheme.retroPink)
                        .shadow(color: RetroTheme.retroPink.opacity(glowOpacity), radius: 2, x: 0, y: 0)
                    
                    Spacer()
                    
                    // Clear completed button
                    Button(action: {
                        Task {
                            await FileCopyProgressTracker.shared.clearCompleted()
                        }
                    }) {
                        Text("CLEAR")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(RetroTheme.retroBlue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(RetroTheme.retroBlue, lineWidth: 1)
                            )
                    }
                }
                
                // File copy operations list
                LazyVStack(spacing: 8) {
                    ForEach(progressTracker.operations, id: \.id) { operation in
                        FileCopyOperationRow(operation: operation)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                themeManager.currentPalette.defaultTintColor.swiftUIColor ?? RetroTheme.retroPink,
                                RetroTheme.retroPurple,
                                RetroTheme.retroBlue
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [RetroTheme.retroPink, RetroTheme.retroBlue]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ), lineWidth: 1.5
                            )
                            .shadow(color: RetroTheme.retroPink.opacity(glowOpacity), radius: 3, x: 0, y: 0)
                    )
            )
            .onAppear {
                // Start retrowave animations
                withAnimation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    glowOpacity = 1.0
                }
            }
        }
    }
}

/// Individual file copy operation row
private struct FileCopyOperationRow: View {
    let operation: FileCopyProgressTracker.FileCopyOperation
    @State private var pulseOpacity: Double = 0.7
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // File name and source type
            HStack {
                Text(operation.filename)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
                
                // Source type badge
                Text(operation.sourceType.displayName)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(sourceTypeColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(sourceTypeColor.opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(sourceTypeColor, lineWidth: 1)
                            )
                    )
            }
            
            // Progress bar and status
            HStack {
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 4)
                        
                        // Progress fill
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [RetroTheme.retroBlue, RetroTheme.retroPurple]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * operation.progress, height: 4)
                            .shadow(color: RetroTheme.retroBlue.opacity(pulseOpacity), radius: 2, x: 0, y: 0)
                    }
                }
                .frame(height: 4)
                
                // Status text
                Text(operation.status.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(statusColor)
                    .frame(width: 70, alignment: .trailing)
            }
            
            // Progress text and file size
            HStack {
                Text(operation.progressText)
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                
                Spacer()
                
                if let error = operation.error {
                    Text("Error: \(error.localizedDescription)")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                        .lineLimit(1)
                } else {
                    Text("\(Int(operation.progress * 100))%")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .onAppear {
            // Pulse animation for active operations
            if operation.status == .downloading || operation.status == .copying {
                withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseOpacity = 1.0
                }
            }
        }
    }
    
    private var sourceTypeColor: Color {
        switch operation.sourceType {
        case .iCloud:
            return RetroTheme.retroBlue
        case .ubiquityContainer:
            return RetroTheme.retroPurple
        case .local:
            return RetroTheme.retroGreen
        case .unknown:
            return .gray
        }
    }
    
    private var statusColor: Color {
        switch operation.status {
        case .pending:
            return .yellow
        case .downloading:
            return RetroTheme.retroBlue
        case .copying:
            return RetroTheme.retroPurple
        case .completed:
            return RetroTheme.retroGreen
        case .failed:
            return .red
        }
    }
}

/// Observable wrapper for FileCopyProgressTracker
@MainActor
private class FileCopyProgressObserver: ObservableObject {
    @Published var operations: [FileCopyProgressTracker.FileCopyOperation] = []
    private var cancellable: AnyCancellable?
    
    init() {
        // Subscribe to progress updates
        cancellable = FileCopyProgressTracker.shared.progressPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] operations in
                self?.operations = operations
            }
    }
    
    deinit {
        cancellable?.cancel()
    }
}
