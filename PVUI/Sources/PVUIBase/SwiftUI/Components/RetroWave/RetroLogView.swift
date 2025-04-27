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
import PVPrimitives
import Defaults
import Perception

/// A retrowave-styled log viewer component
public struct RetroLogView: View {
    // MARK: - Properties
    
    /// View model for handling log data and logic
    @StateObject private var viewModel = RetroLogViewModel()
    
    /// Scroll view reader for auto-scrolling
    @Namespace private var scrollSpace
    
    /// Controls whether the view is presented in fullscreen mode
    @Binding private var isFullscreen: Bool
    
    // MARK: - Initialization
    
    public init() {
        self._isFullscreen = .constant(false)
    }
    
    public init(isFullscreen: Binding<Bool> = .constant(false)) {
        self._isFullscreen = isFullscreen
    }
    
    public init(viewModel: RetroLogViewModel, isFullscreen: Binding<Bool> = .constant(false)) {
        self._viewModel = StateObject(wrappedValue: viewModel)
        self._isFullscreen = isFullscreen
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
        .frame(maxWidth: isFullscreen ? .infinity : nil, maxHeight: isFullscreen ? .infinity : nil)
    }
    
    // MARK: - Subviews
    
    /// Header view with controls
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("LOGS")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(RetroTheme.retroPink)
                    .shadow(color: RetroTheme.retroPink.opacity(0.7), radius: 2, x: 0, y: 0)
                
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
                        .foregroundColor(RetroTheme.retroPink.opacity(0.7))
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(RetroTheme.retroPink.opacity(0.7), lineWidth: 1)
                        )
                }
                
                Spacer()
                
                // Fullscreen toggle button
                if isFullscreen {
                    // Close fullscreen button
                    Button {
                        isFullscreen = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12))
                            .foregroundColor(RetroTheme.retroPink)
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(RetroTheme.retroPink, lineWidth: 1)
                            )
                    }
                } else {
                    // Expand to fullscreen button
                    Button {
                        isFullscreen = true
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 12))
                            .foregroundColor(RetroTheme.retroBlue)
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(RetroTheme.retroBlue, lineWidth: 1)
                            )
                    }
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
        LogEntryRowContent(log: log, viewModel: viewModel)
    }
    
    /// Content view for a log entry row with copy functionality
    private struct LogEntryRowContent: View {
        let log: LogEntry
        let viewModel: RetroLogViewModel
        
        @State private var isCopying = false
        
        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                // Header with timestamp and level
                HStack {
                    Text(log.formattedTimestamp)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(viewModel.logLevelColor(log.level).opacity(0.8))
                    
                    Spacer()
                    
                    Text(log.level.name.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(viewModel.logLevelColor(log.level))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(
                                    viewModel.logLevelColor(log.level).opacity(0.7),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: viewModel.logLevelColor(log.level).opacity(0.5), radius: 2, x: 0, y: 0)
                }
                
                // Message with glow effect based on log level
                Text(log.message)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .shadow(color: viewModel.logLevelColor(log.level).opacity(0.3), radius: 1, x: 0, y: 0)
                    .lineLimit(viewModel.showFullDetails ? nil : 3)
                
                // File and line if showing full details
                if viewModel.showFullDetails {
                    let file = log.file
                    let line = log.line
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 8))
                            .foregroundColor(RetroTheme.retroBlue.opacity(0.7))
                        
                        Text("\(file):\(line)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(RetroTheme.retroBlue.opacity(0.7))
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        isCopying ? RetroTheme.retroPink : viewModel.logLevelColor(log.level).opacity(0.3),
                                        isCopying ? RetroTheme.retroBlue : RetroTheme.retroDarkBlue.opacity(0.1)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: isCopying ? 2 : 1
                            )
                    )
            )
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            // Add long press gesture to copy log entry
            .onLongPressGesture(minimumDuration: 0.5) {
                // Create a full log string with all details
                var logText = ""
                
                // Include timestamp and level
                logText += "[\(log.formattedTimestamp)] [\(log.level.name.uppercased())] "
                
                // Add message
                logText += log.message
                
                // Add file and line if available
                if viewModel.showFullDetails {
                    logText += "\n\(log.file):\(log.line)"
                }
                
                // Copy to clipboard
                UIPasteboard.general.string = logText
                
                // Show visual feedback
                withAnimation(.easeInOut(duration: 0.3)) {
                    isCopying = true
                }
                
                // Reset after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation {
                        isCopying = false
                    }
                }
                
                // Provide haptic feedback
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                
                // Log the action
                DLOG("Copied log entry to clipboard: \(log.id)")
            }
        }
        
        
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
