//
//  RetroLogView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/24/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import SwiftUI
import PVThemes
import PVLogging
import Combine

/// A retrowave-styled log viewer component
public struct RetroLogView: View {
    // MARK: - Properties
    
    /// View model for handling log data and logic
    @StateObject private var viewModel = RetroLogViewModel()
    
    /// Scroll view reader for auto-scrolling
    @Namespace private var scrollSpace
    
    // MARK: - Initialization
    
    public init() {}
    
    public init(viewModel: RetroLogViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    // MARK: - Body
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header with controls
            headerView
            
            // Log list
            ScrollViewReader { scrollView in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(viewModel.filteredLogs) { log in
                            logEntryRow(log)
                                .id(log.id)
                        }
                        
                        // Invisible view at the bottom for auto-scrolling
                        Color.clear
                            .frame(height: 1)
                            .id(scrollSpace)
                    }
                    .padding(.horizontal, 8)
                }
                .onChange(of: viewModel.logs) { _ in
                    if viewModel.autoScroll {
                        withAnimation {
                            scrollView.scrollTo(scrollSpace, anchor: .bottom)
                        }
                    }
                }
            }
        }
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
        )
    }
    
    // MARK: - Subviews
    
    // MARK: - Subviews
    
    /// Header view with controls
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("LOGS")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(RetroTheme.retroPink)
                
                Spacer()
                
                // Log level picker
                Menu {
                    Picker("Log Level", selection: $viewModel.minLogLevel) {
                        Text("Verbose").tag(LogLevel.verbose)
                        Text("Debug").tag(LogLevel.debug)
                        Text("Info").tag(LogLevel.info)
                        Text("Warning").tag(LogLevel.warning)
                        Text("Error").tag(LogLevel.error)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Level: \(viewModel.minLogLevel.name)")
                            .font(.system(size: 12))
                            .foregroundColor(RetroTheme.retroBlue)
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(RetroTheme.retroBlue)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(RetroTheme.retroBlue, lineWidth: 1)
                    )
                }
                
                // Auto-scroll toggle
                Button(action: {
                    viewModel.autoScroll.toggle()
                }) {
                    Image(systemName: viewModel.autoScroll ? "arrow.down.to.line.compact" : "arrow.up.to.line.compact")
                        .font(.system(size: 12))
                        .foregroundColor(viewModel.autoScroll ? RetroTheme.retroBlue : RetroTheme.retroPink.opacity(0.7))
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(viewModel.autoScroll ? RetroTheme.retroBlue : RetroTheme.retroPink.opacity(0.7), lineWidth: 1)
                        )
                }
                
                // Detail toggle
                Button(action: {
                    viewModel.showFullDetails.toggle()
                }) {
                    Image(systemName: viewModel.showFullDetails ? "list.bullet.indent" : "list.bullet")
                        .font(.system(size: 12))
                        .foregroundColor(viewModel.showFullDetails ? RetroTheme.retroBlue : RetroTheme.retroPink.opacity(0.7))
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(viewModel.showFullDetails ? RetroTheme.retroBlue : RetroTheme.retroPink.opacity(0.7), lineWidth: 1)
                        )
                }
                
                // Clear logs button
                Button(action: {
                    viewModel.clearLogs()
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(RetroTheme.retroPink)
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(RetroTheme.retroPink, lineWidth: 1)
                        )
                }
            }
            
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(RetroTheme.retroBlue.opacity(0.7))
                
                TextField("Search logs...", text: $viewModel.searchText)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                
                if !viewModel.searchText.isEmpty {
                    Button(action: {
                        viewModel.searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(RetroTheme.retroPink.opacity(0.7))
                    }
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(RetroTheme.retroBlue.opacity(0.5), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.5))
    }
    
    /// Single log entry row
    private func logEntryRow(_ log: LogEntry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                // Log level indicator
                Circle()
                    .fill(viewModel.logLevelColor(log.level))
                    .frame(width: 8, height: 8)
                
                // Timestamp
                Text(log.formattedTimestamp)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray)
                
                // Message
                Text(log.message)
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                    .lineLimit(viewModel.showFullDetails ? nil : 1)
                
                Spacer()
            }
            
            // Additional details if expanded
            if viewModel.showFullDetails {
                Text("\(log.file):\(log.function):\(log.line)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.7))
                    .padding(.leading, 14)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(viewModel.logLevelColor(log.level).opacity(0.3), lineWidth: 0.5)
                )
        )
        .padding(.vertical, 2)
    }
    

}

// MARK: - Preview

#if DEBUG
struct RetroLogView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            RetroTheme.retroDarkBlue.edgesIgnoringSafeArea(.all)
            
            RetroLogView()
                .frame(width: 500, height: 400)
                .padding()
        }
    }
}
#endif
