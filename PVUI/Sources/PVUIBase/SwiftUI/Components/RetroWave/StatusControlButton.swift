//
//  StatusControlButton.swift
//  PVUIBase
//
//  Created by Joseph Mattiello on 4/26/25.
//  Copyright 2025 Provenance Emu. All rights reserved.
//

import SwiftUI
import PVLogging
import PVThemes
import PVPrimitives
import Combine

/// A button that displays a fullscreen RetroStatusControlView when tapped
public struct StatusControlButton: View {
    // MARK: - Properties
    
    /// The size of the button
    private let size: CGFloat
    
    /// The color of the button
    private let color: Color
    
    /// State to control the sheet presentation
    @State private var showStatusControl = false
    
    /// ViewModel to track progress
    @StateObject private var viewModel = StatusControlButtonViewModel()
    
    // MARK: - Initialization
    
    /// Initialize a new status control button
    /// - Parameters:
    ///   - size: The size of the button (default: 12)
    ///   - color: The color of the button (default: .retroPurple)
    public init(size: CGFloat = 12, color: Color = .retroPurple) {
        self.size = size
        self.color = color
    }
    
    // MARK: - Body
    
    public var body: some View {
        Button(action: {
            DLOG("Status control button tapped")
            showStatusControl = true
        }) {
            // Display different gauge icons based on the cumulative progress
            Image(systemName: viewModel.gaugeIconName)
                .font(.system(size: size))
                .foregroundColor(color)
        }
        .fullScreenCover(isPresented: $showStatusControl) {
            StatusControlFullscreenView(isPresented: $showStatusControl)
        }
    }
}

/// A fullscreen view that displays the RetroStatusControlView
private struct StatusControlFullscreenView: View {
    // MARK: - Properties
    
    /// Binding to control the presentation of the view
    @Binding var isPresented: Bool
    
    // No need to track scroll position
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background with grid pattern for retrowave aesthetic
            RetroTheme.retroBlack
                .edgesIgnoringSafeArea(.all)
                .overlay(
                    RetroTheme.RetroGridView()
                        .opacity(0.2)
                )
            
            // Fixed header and scrollable content container
            VStack(alignment: .leading, spacing: 0) {
                // Fixed header with close button
                HStack {
                    Text("System Status")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(RetroTheme.retroPink)
                        .shadow(color: RetroTheme.retroPink.opacity(0.7), radius: 3, x: 0, y: 0)
                    
                    Spacer()
                    
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(RetroTheme.retroBlue)
                            .shadow(color: RetroTheme.retroBlue.opacity(0.7), radius: 3, x: 0, y: 0)
                    }
                    .buttonStyle(RetroTheme.RetroButtonStyle())
                }
                .padding()
                .background(RetroTheme.retroDarkBlue.opacity(0.7))
                .overlay(
                    Rectangle()
                        .frame(height: 2)
                        .foregroundStyle(RetroTheme.retroGradient)
                        .offset(y: 1),
                    alignment: .bottom
                )
                
                // Scrollable content area
                ScrollView {
                    // Status control view with fixed height to prevent jumping
                    RetroStatusControlView()
                        .padding()
                        .frame(minHeight: 400, alignment: .top) // Fixed minimum height to prevent jumping
                }
            }
        }
    }
}

/// ViewModel for the StatusControlButton to track progress
class StatusControlButtonViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// The cumulative progress of all tracked operations (0-100)
    @Published var cumulativeProgress: Double = 0.0
    
    /// The gauge icon name based on the cumulative progress
    @Published var gaugeIconName: String = "gauge.with.needle"
    
    /// Active progress bars being tracked
    @Published private var activeProgressBars: [ProgressInfo] = []
    
    /// Cancellables for tracking notifications
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        // Subscribe to notifications for progress updates
        setupNotificationObservers()
    }
    
    // MARK: - Private Methods
    
    /// Set up notification observers for progress updates
    private func setupNotificationObservers() {
        // Listen for progress updates from various sources
        NotificationCenter.default.publisher(for: Notification.Name("ProgressUpdate"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self,
                      let progressInfo = notification.object as? ProgressInfo else { return }
                
                // Update the active progress bars
                self.updateProgress(progressInfo: progressInfo)
            }
            .store(in: &cancellables)
        
        // Listen for progress removals
        NotificationCenter.default.publisher(for: Notification.Name("ProgressRemoved"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self,
                      let id = notification.object as? String else { return }
                
                // Remove the progress bar
                self.removeProgress(id: id)
            }
            .store(in: &cancellables)
    }
    
    /// Update the progress for a specific operation
    private func updateProgress(progressInfo: ProgressInfo) {
        // Find if we already have a progress bar with this ID
        if let index = activeProgressBars.firstIndex(where: { $0.id == progressInfo.id }) {
            // Replace the existing progress bar
            activeProgressBars[index] = progressInfo
        } else {
            // Add a new progress bar
            activeProgressBars.append(progressInfo)
        }
        
        // Update the cumulative progress
        updateCumulativeProgress()
    }
    
    /// Remove a progress bar by ID
    private func removeProgress(id: String) {
        // Remove progress bars with matching ID
        activeProgressBars.removeAll(where: { $0.id == id })
        
        // Update the cumulative progress
        updateCumulativeProgress()
    }
    
    /// Update the cumulative progress and gauge icon
    private func updateCumulativeProgress() {
        // Calculate the average progress of all active progress bars
        if activeProgressBars.isEmpty {
            cumulativeProgress = 0.0
        } else {
            let totalProgress = activeProgressBars.reduce(0.0) { $0 + $1.progress }
            cumulativeProgress = totalProgress / Double(activeProgressBars.count) * 100.0
        }
        
        // Update the gauge icon based on the cumulative progress
        updateGaugeIcon()
    }
    
    /// Update the gauge icon based on the cumulative progress
    private func updateGaugeIcon() {
        if activeProgressBars.isEmpty {
            gaugeIconName = "gauge.with.needle"
            return
        }
        
        // Select the appropriate gauge icon based on the progress percentage
        if cumulativeProgress < 1.0 {
            gaugeIconName = "gauge.with.dots.needle.0percent"
        } else if cumulativeProgress < 33.0 {
            gaugeIconName = "gauge.with.dots.needle.33percent"
        } else if cumulativeProgress < 50.0 {
            gaugeIconName = "gauge.with.dots.needle.50percent"
        } else if cumulativeProgress < 67.0 {
            gaugeIconName = "gauge.with.dots.needle.67percent"
        } else {
            gaugeIconName = "gauge.with.dots.needle.100percent"
        }
    }
}

#Preview {
    StatusControlButton()
}
