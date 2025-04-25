//
//  RetroSystemStatsView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/24/25.
//  Copyright 2025 Provenance Emu. All rights reserved.
//

import SwiftUI
import PVThemes
import PVLibrary

/// A retrowave-styled system stats viewer component
public struct RetroSystemStatsView: View {
    // MARK: - Properties
    
    /// View model for handling system stats data and logic
    @StateObject private var viewModel = RetroSystemStatsViewModel()
    
    /// Whether to show the refresh button
    private let showRefreshButton: Bool
    
    /// Whether to reduce motion for accessibility
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    // MARK: - Initialization
    
    public init(showRefreshButton: Bool = true) {
        self.showRefreshButton = showRefreshButton
    }
    
    // MARK: - Body
    
    public var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("SYSTEM STATS")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(RetroTheme.retroPink)
                    .shadow(color: RetroTheme.retroPink.opacity(0.7), radius: 2, x: 0, y: 0)
                
                Spacer()
                
                if showRefreshButton {
                    Button(action: {
                        viewModel.refreshAllStats()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                            .foregroundColor(RetroTheme.retroBlue)
                            .rotationEffect(.degrees(viewModel.isLoading ? 360 : 0))
                            .animation(reduceMotion ? nil : .linear(duration: 1).repeatForever(autoreverses: false), value: viewModel.isLoading)
                    }
                }
            }
            
            // System stats section
            systemStatsSection
            
            // Library stats section
            libraryStatsSection
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [RetroTheme.retroPink, RetroTheme.retroBlue]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: RetroTheme.retroPink.opacity(0.5), radius: 5, x: 0, y: 0)
        )
    }
    
    // MARK: - Subviews
    
    /// System stats section (CPU, Memory)
    private var systemStatsSection: some View {
        VStack(spacing: 8) {
            // CPU usage
            HStack {
                Label {
                    Text("CPU")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(RetroTheme.retroBlue)
                } icon: {
                    Image(systemName: "cpu")
                        .font(.system(size: 10))
                        .foregroundColor(RetroTheme.retroPink)
                }
                
                Spacer()
                
                Text("\(String(format: "%.1f", viewModel.cpuUsage))%")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
            }
            
            // Memory usage
            HStack {
                Label {
                    Text("MEMORY")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(RetroTheme.retroBlue)
                } icon: {
                    Image(systemName: "memorychip")
                        .font(.system(size: 10))
                        .foregroundColor(RetroTheme.retroPink)
                }
                
                Spacer()
                
                Text("\(viewModel.formatBytes(viewModel.memoryUsed))/\(viewModel.formatBytes(viewModel.memoryTotal))")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
            }
            
            // Memory usage bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background bar
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 4)
                    
                    // Usage bar
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [RetroTheme.retroPink, RetroTheme.retroBlue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(Double(viewModel.memoryUsed) / Double(viewModel.memoryTotal)), height: 4)
                }
            }
            .frame(height: 4)
        }
    }
    
    /// Library stats section (Games, Save States, BIOSes)
    private var libraryStatsSection: some View {
        VStack(spacing: 8) {
            Divider()
                .background(RetroTheme.retroBlue.opacity(0.3))
                .padding(.vertical, 4)
            
            // Games count
            HStack {
                Label {
                    Text("GAMES")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(RetroTheme.retroBlue)
                } icon: {
                    Image(systemName: "gamecontroller")
                        .font(.system(size: 10))
                        .foregroundColor(RetroTheme.retroPink)
                }
                
                Spacer()
                
                Text("\(viewModel.gameCount)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
            }
            
            // Save states count
            HStack {
                Label {
                    Text("SAVE STATES")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(RetroTheme.retroBlue)
                } icon: {
                    Image(systemName: "bookmark")
                        .font(.system(size: 10))
                        .foregroundColor(RetroTheme.retroPink)
                }
                
                Spacer()
                
                Text("\(viewModel.saveStateCount)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
            }
            
            // BIOSes count
            HStack {
                Label {
                    Text("BIOSES")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(RetroTheme.retroBlue)
                } icon: {
                    Image(systemName: "cpu.fill")
                        .font(.system(size: 10))
                        .foregroundColor(RetroTheme.retroPink)
                }
                
                Spacer()
                
                Text("\(viewModel.biosCount)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
            }
            
            // Storage usage
            HStack {
                Label {
                    Text("STORAGE")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(RetroTheme.retroBlue)
                } icon: {
                    Image(systemName: "internaldrive")
                        .font(.system(size: 10))
                        .foregroundColor(RetroTheme.retroPink)
                }
                
                Spacer()
                
                Text(viewModel.formatBytes(UInt64(viewModel.storageUsed)))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
            }
            
            // Total playtime
            HStack {
                Label {
                    Text("PLAYTIME")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(RetroTheme.retroBlue)
                } icon: {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                        .foregroundColor(RetroTheme.retroPink)
                }
                
                Spacer()
                
                Text(viewModel.formatPlaytime(viewModel.totalPlaytime))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Preview
#if DEBUG
struct RetroSystemStatsView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            RetroSystemStatsView()
                .frame(width: 300)
        }
        .preferredColorScheme(.dark)
    }
}
#endif
