///
/// ImportProgressView.swift
/// PVUI
///
/// Created by Joseph Mattiello on 11/22/24.
///

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
    
    /// Task for monitoring the import queue
    @State private var monitorTask: Task<Void, Never>?
    
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
            contentView
                .onAppear {
                    ILOG("ImportProgressView: View appeared")
                    // Start monitoring the import queue
                    startMonitoringImportQueue()
                }
                .onDisappear {
                    ILOG("ImportProgressView: View disappeared")
                    // Cancel the monitoring task when the view disappears
                    monitorTask?.cancel()
                    monitorTask = nil
                }
                .onTapGesture {
                    onTap?()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
    
    // MARK: - Content Views
    
    @ViewBuilder
    private var contentView: some View {
        Group {
            if !importQueueItems.isEmpty {
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
                .opacity(!importQueueItems.isEmpty ? 1 : 0)
                .frame(height: !importQueueItems.isEmpty ? nil : 0)
            }
        }
    }
    
    // MARK: - Helper Methods
    
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
    
    /// Start monitoring the import queue using Swift's structured concurrency
    private func startMonitoringImportQueue() {
        // Cancel any existing task first
        monitorTask?.cancel()
        
        // Create a new task to monitor the queue
        monitorTask = Task {
            ILOG("ImportProgressView: Started monitoring import queue")
            
            // Run until the task is cancelled
            while !Task.isCancelled {
                do {
                    // Get the current queue state
                    let queue = await gameImporter.importQueue
                    
                    // Update the UI on the main thread
                    await MainActor.run {
                        // Log the current queue state if it's not empty
                        if !queue.isEmpty {
                            let statuses = queue.map { $0.status.description }.joined(separator: ", ")
                            ILOG("""
                                 ImportProgressView: Queue has \(queue.count) items
                                 Active items: \(queue.filter { $0.status != .failure }.count)
                                 Statuses: \(statuses)
                                 """)
                        } else {
                            VLOG("ImportProgressView: Queue is empty")
                        }
                        
                        // Update the import queue items with animation if they've changed
                        if importQueueItems != queue {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                importQueueItems = queue
                            }
                            
                            // Always set isVisible to true - we'll control visibility through opacity and frame height
                            isVisible = true
                        }
                    }
                    
                    // Wait a short time before checking again
                    // This prevents excessive CPU usage while still being responsive
                    try await Task.sleep(for: .milliseconds(200))
                } catch {
                    // Handle cancellation or other errors
                    if error is CancellationError {
                        VLOG("ImportProgressView: Monitoring task cancelled")
                        break
                    } else {
                        ELOG("ImportProgressView: Error monitoring queue - \(error)")
                        try? await Task.sleep(for: .milliseconds(500))
                    }
                }
            }
        }
    }
}
