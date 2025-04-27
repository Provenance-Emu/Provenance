//
//  ImportStatusView.swift
//  PVUI
//
//  Created by David Proskin on 10/31/24.
//

import SwiftUI
import PVLibrary
import PVThemes
import Perception
import PVSystems
import Combine

public protocol ImportStatusDelegate: AnyObject {
    @MainActor
    func dismissAction()
    @MainActor
    func addImportsAction()
    @MainActor
    func forceImportsAction()
    @MainActor
    func didSelectSystem(_ system: SystemIdentifier, for item: ImportQueueItem)
}

public struct ImportStatusView: View {
    @ObservedObject
    public var updatesController: PVGameLibraryUpdatesController
    public var gameImporter: any GameImporting
    public weak var delegate: ImportStatusDelegate?
    public var dismissAction: (() -> Void)? = nil
    
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var messageManager = StatusMessageManager.shared
    var currentPalette: any UXThemePalette { themeManager.currentPalette }
    @Namespace private var namespace  // Add namespace for focus management
    
    // ViewModel to handle state and actor isolation
    @StateObject private var viewModel = ImportStatusViewModel()
    
    // Store for cancellables
    private var cancellables = Set<AnyCancellable>()
    
    public init(updatesController: PVGameLibraryUpdatesController, gameImporter: any GameImporting, delegate: ImportStatusDelegate? = nil, dismissAction: (() -> Void)? = nil) {
        self.updatesController = updatesController
        self.gameImporter = gameImporter
        self.delegate = delegate
        self.dismissAction = dismissAction
    }
    
    private func deleteItems(at offsets: IndexSet) {
        Task {
            await gameImporter.removeImports(at: offsets)
            // Refresh the queue items after deletion
            await viewModel.refreshQueueItems()
        }
    }
    
    // Define the system selection handler
    private func handleSystemSelection(_ system: SystemIdentifier, for item: ImportQueueItem) {
        // Forward to the delegate
        delegate?.didSelectSystem(system, for: item)
    }
    
    /// Calculate the overall progress of all import operations
    private func calculateOverallProgress() -> Double {
        guard !viewModel.queueItems.isEmpty else { return 0.0 }
        
        // If we have active imports with progress, use that
        if messageManager.viewModel.isImportActive, let progress = messageManager.viewModel.downloadProgress {
            return Double(progress.current) / Double(max(1, progress.total))
        }
        
        // If we have CloudKit sync progress, use that
        if let progress = messageManager.viewModel.cloudKitSyncProgress {
            return Double(progress.current) / Double(max(1, progress.total))
        }
        
        // Default to indeterminate progress based on queue position
        let totalItems = Double(viewModel.queueItems.count)
        let processedItems = Double(max(0, Int(totalItems) - viewModel.queueItems.count))
        
        // If we're just starting, show a small amount of progress
        return max(0.05, processedItems / totalItems)
    }
    
    // Animation states for retrowave effects
    @State private var glowOpacity: Double = 0.7
    @State private var scanlineOffset: CGFloat = 0
    
    // MARK: - Helper Methods
    
    /// Determines if the full import view should be shown
    private var shouldShowFullView: Bool {
        return !viewModel.queueItems.isEmpty || messageManager.isImportActive || messageManager.fileRecoveryProgress != nil
    }
    
    public var body: some View {
        WithPerceptionTracking {
            Group {
                if shouldShowFullView {
                    fullImportView
                } else {
                    // Compact status view when no imports are active
                    StatusMessageView()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
            }
        }
        .onAppear {
            // Start retrowave animations
            withAnimation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowOpacity = 1.0
                scanlineOffset = 100
            }
            
            // Load the queue items when the view appears
            Task {
                await viewModel.refreshQueueItems()
            }
        }
        // Observe file recovery progress
        .onReceive(NotificationCenter.default.publisher(for: iCloudSync.iCloudFileRecoveryProgress)) { _ in
            viewModel.isVisible = true
        }
    }
    
    // Compact import view with progress bar instead of detailed list
    private var fullImportView: some View {
        VStack(spacing: 8) {
            // Compact header
            HStack {
                // Title with glow effect
                Text("IMPORT STATUS")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(RetroTheme.retroPink)
                    .shadow(color: RetroTheme.retroPink.opacity(0.7), radius: 2, x: 0, y: 0)
                
                Spacer()
                
                // Queue count indicator
                Text("\(viewModel.queueItems.count) ITEMS")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(RetroTheme.retroBlue)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 4)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(4)
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
            .padding(.bottom, 4)
            
            // Divider with gradient
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(RetroTheme.retroGradient)
                .padding(.horizontal, 6)
                .padding(.bottom, 4)
            
            // Progress section
            VStack(alignment: .leading, spacing: 4) {
                // Overall progress bar
                let progress = calculateOverallProgress()
                let percent = Int(progress * 100)
                
                // Operation label and progress percentage
                HStack(spacing: 4) {
                    // Icon
                    Image(systemName: "square.and.arrow.down.fill")
                        .font(.system(size: 10))
                        .foregroundColor(RetroTheme.retroBlue)
                        .shadow(color: RetroTheme.retroBlue.opacity(0.7), radius: 1, x: 0, y: 0)
                    
                    // Label
                    Text("Importing")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(RetroTheme.retroBlue)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Progress percentage
                    Text("\(percent)%")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(RetroTheme.retroBlue.opacity(0.8))
                }
                
                // Progress bar
                ZStack(alignment: .leading) {
                    // Track
                    Rectangle()
                        .fill(Color.black.opacity(0.5))
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    // Progress fill
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [RetroTheme.retroPink, RetroTheme.retroBlue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(4, CGFloat(progress) * UIScreen.main.bounds.width * 0.8), height: 6)
                        .cornerRadius(3)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(RetroTheme.retroBlue.opacity(0.5), lineWidth: 1)
                )
                
                // Current item text (if any)
                if let currentItem = viewModel.queueItems.first {
                    Text(currentItem.url.lastPathComponent)
                        .font(.system(size: 9))
                        .foregroundColor(RetroTheme.retroPink.opacity(0.8))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.7))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                RetroTheme.retroPink.opacity(0.7), RetroTheme.retroBlue.opacity(0.7),
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .padding(.horizontal, 8)
            
            // Action buttons
            HStack(spacing: 8) {
                Button(action: {
                    delegate?.dismissAction()
                }) {
                    Text("DISMISS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(RetroTheme.retroPink)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(RetroTheme.retroPink.opacity(0.7), lineWidth: 1)
                        )
                }
                
                Spacer()
                
                Button(action: {
                    delegate?.addImportsAction()
                }) {
                    Text("ADD")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(RetroTheme.retroBlue)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(RetroTheme.retroBlue.opacity(0.7), lineWidth: 1)
                        )
                }
                
                Button(action: {
                    delegate?.forceImportsAction()
                }) {
                    Text("BEGIN")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(RetroTheme.retroPurple)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(RetroTheme.retroPurple.opacity(0.7), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
        .padding(.vertical, 8)
        .background(
            ZStack {
                // Dark background
                Color.black.opacity(0.9)
                
                // Subtle grid pattern
                RetroTheme.RetroGridView()
                    .opacity(0.05)
            }
        )
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(LinearGradient(
                    gradient: Gradient(colors: [RetroTheme.retroPink.opacity(0.5), RetroTheme.retroBlue.opacity(0.5)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ), lineWidth: 1)
        )
        .shadow(color: RetroTheme.retroPink.opacity(0.3), radius: 4, x: 0, y: 2)
#if os(tvOS)
        .focusSection()
        .focusScope(namespace)
#endif
    }
}
