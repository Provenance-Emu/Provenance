//
//  ImportProgressView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 11/22/24.
//

import SwiftUI
import PVLibrary
import PVThemes
import Perception
import Combine

/// A view that displays the progress of importing games
/// Auto-hides when all items are completed or errored
public struct ImportProgressView: View {
    // MARK: - Properties
    
    /// The game importer to track
    public var gameImporter: any GameImporting
    
    /// The updates controller for accessing the import queue
    @ObservedObject public var updatesController: PVGameLibraryUpdatesController
    
    /// Callback when the view is tapped
    public var onTap: (() -> Void)?
    
    /// State to hold the import queue items
    @State private var importQueueItems: [ImportQueueItem] = []
    
    /// State to track if the view should be visible
    @State private var isVisible: Bool = false
    
    /// Timer for auto-hiding the view
    @State private var hideTimer: AnyCancellable?
    
    /// Animation states for retrowave effects
    @State private var glowOpacity: Double = 0.7
    
    // MARK: - Initialization
    
    public init(
        gameImporter: any GameImporting,
        updatesController: PVGameLibraryUpdatesController,
        onTap: (() -> Void)? = nil
    ) {
        self.gameImporter = gameImporter
        self.updatesController = updatesController
        self.onTap = onTap
    }
    
    // MARK: - Body
    
    public var body: some View {
        WithPerceptionTracking {
            if isVisible && !importQueueItems.isEmpty {
                contentView
                    .onAppear {
                        // Start a timer to refresh the queue status
                        setupImportQueueRefreshTimer()
                        
                        // Initial refresh
                        Task {
                            await refreshImportQueue()
                        }
                    }
                    .onDisappear {
                        // Cancel the timer when the view disappears
                        hideTimer?.cancel()
                    }
                    .onTapGesture {
                        onTap?()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Content Views
    
    private var contentView: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header with count of imports
            HStack {
                Text("IMPORTING \(importQueueItems.count) FILES")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.retroBlue)
                
                Spacer()
                
                // Show processing status if any item is processing
                if importQueueItems.contains(where: { $0.status == .processing }) {
                    Text("PROCESSING")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.retroPink)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.retroBlack.opacity(0.7))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .strokeBorder(Color.retroPink, lineWidth: 1)
                                )
                        )
                }
            }
            
            // Progress bar with retrowave styling
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.retroBlack.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(
                                LinearGradient(
                                    gradient: Gradient(colors: [.retroPink, .retroBlue]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .frame(height: 12)
                
                // Progress fill - count both completed and failed items for progress
                let processedCount = importQueueItems.filter { $0.status == .success || $0.status == .failure }.count
                let progress = importQueueItems.isEmpty ? 0.0 : Double(processedCount) / Double(importQueueItems.count)
                
                // Create a GeometryReader to get the actual width of the container
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [.retroPink, .retroBlue]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    // Calculate width as a percentage of the available width
                    // Use max to ensure a minimum visible width
                    .frame(width: max(12, progress * geometry.size.width), height: 8)
                    .cornerRadius(4)
                    .padding(2)
                }
                // Set a fixed height for the GeometryReader
                .frame(height: 12)
            }
            
            // Status details
            HStack(spacing: 12) {
                statusCountView(count: importQueueItems.filter { $0.status == .queued }.count, label: "QUEUED", color: .gray)
                statusCountView(count: importQueueItems.filter { $0.status == .processing }.count, label: "PROCESSING", color: .retroBlue)
                statusCountView(count: importQueueItems.filter { $0.status == .success }.count, label: "COMPLETED", color: .retroYellow)
                statusCountView(count: importQueueItems.filter { $0.status == .failure }.count, label: "FAILED", color: .retroPink)
                
                Spacer()
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.retroBlack.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroPink, .retroBlue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: Color.retroPink.opacity(0.3), radius: 5, x: 0, y: 0)
    }
    
    /// Helper view for status counts
    @ViewBuilder
    private func statusCountView(count: Int, label: String, color: Color) -> some View {
        if count > 0 {
            HStack(spacing: 4) {
                Text("\(count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(color)
                
                Text(label)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(color.opacity(0.7))
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Set up a timer to refresh the import queue status
    private func setupImportQueueRefreshTimer() {
        // Cancel any existing timer
        hideTimer?.cancel()
        
        // Create a new timer that fires every second
        hideTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                Task {
                    await self.refreshImportQueue()
                }
            }
    }
    
    /// Refresh the import queue items and update visibility
    @MainActor
    private func refreshImportQueue() async {
        // Get the current import queue
        let queue = await gameImporter.importQueue
        
        // Update the import queue items
        importQueueItems = queue
        
        // Check if we should show or hide the view
        if queue.isEmpty {
            // Hide the view if there are no items
            withAnimation(.easeInOut(duration: 0.3)) {
                isVisible = false
            }
        } else {
            // Show the view if there are items
            withAnimation(.easeInOut(duration: 0.3)) {
                isVisible = true
            }
            
            // Check if all items are completed or errored
            let allDone = queue.allSatisfy { $0.status == .success || $0.status == .failure }
            
            if allDone {
                // If all items are done, schedule auto-hide after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.isVisible = false
                    }
                }
            }
        }
    }
}
