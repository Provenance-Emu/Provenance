//
//  TopShelfLogView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/15/25.
//

import SwiftUI
import PVLibrary
import PVSupport
import Combine

/// A view that displays the TopShelf extension log file
struct TopShelfLogView: View {
    // State for the log content
    @State private var logContent: String = "Loading TopShelf log..."
    @State private var isRefreshing: Bool = false
    
    // Timer for auto-refresh
    @State private var timer: AnyCancellable?
    
    var body: some View {
        ZStack {
            // Retrowave background
            Color.black.edgesIgnoringSafeArea(.all)
            
            // Grid background
            RetroGridForSettings()
                .edgesIgnoringSafeArea(.all)
                .opacity(0.5)
            
            VStack {
                // Title with retrowave styling
                Text("TOPSHELF LOG")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.retroPink, .retroPurple, .retroBlue]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                    .shadow(color: .retroPink.opacity(0.5), radius: 10, x: 0, y: 0)
                
                // Log content
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        if logContent.isEmpty {
                            Text("No TopShelf log found.")
                                .foregroundColor(.gray)
                                .padding()
                        } else {
                            Text(logContent)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.white)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.retroBlack.opacity(0.7))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
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
                        }
                    }
                    .padding()
                }
                
                // Action buttons
                HStack(spacing: 20) {
                    // Refresh button
                    Button(action: {
                        refreshLog()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh")
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.retroBlack.opacity(0.7))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
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
                    }
                    .disabled(isRefreshing)
                    
                    // Clear log button
                    Button(action: {
                        clearLog()
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear Log")
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.retroBlack.opacity(0.7))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
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
                    }
                    .disabled(isRefreshing || logContent.isEmpty)
                }
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            refreshLog()
            
            // Set up a timer to refresh the log every 5 seconds
            timer = Timer.publish(every: 5, on: .main, in: .common)
                .autoconnect()
                .sink { _ in
                    refreshLog()
                }
        }
        .onDisappear {
            // Cancel the timer when the view disappears
            timer?.cancel()
            timer = nil
        }
    }
    
    /// Refreshes the log content
    private func refreshLog() {
        isRefreshing = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let logContent = Self.readTopShelfLog()
            
            DispatchQueue.main.async {
                self.logContent = logContent
                self.isRefreshing = false
            }
        }
    }
    
    /// Clears the log file
    private func clearLog() {
        isRefreshing = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            Self.clearTopShelfLog()
            
            DispatchQueue.main.async {
                self.logContent = "Log cleared."
                self.isRefreshing = false
            }
        }
    }
    
    /// Reads the TopShelf log file from the shared container
    static func readTopShelfLog() -> String {
        let fileManager = FileManager.default
        guard let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: PVAppGroupId) else {
            return "Could not access app group container."
        }
        
        let logFileURL = containerURL.appendingPathComponent("topshelf_log.txt")
        
        if !fileManager.fileExists(atPath: logFileURL.path) {
            return "TopShelf log file does not exist."
        }
        
        do {
            let logContent = try String(contentsOf: logFileURL, encoding: .utf8)
            return logContent
        } catch {
            return "Error reading log file: \(error.localizedDescription)"
        }
    }
    
    /// Clears the TopShelf log file
    static func clearTopShelfLog() {
        let fileManager = FileManager.default
        guard let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: PVAppGroupId) else {
            return
        }
        
        let logFileURL = containerURL.appendingPathComponent("topshelf_log.txt")
        
        if fileManager.fileExists(atPath: logFileURL.path) {
            do {
                try "Log cleared at \(Date().description)\n".write(to: logFileURL, atomically: true, encoding: .utf8)
            } catch {
                print("Error clearing log file: \(error.localizedDescription)")
            }
        }
    }
}

#if DEBUG
struct TopShelfLogView_Previews: PreviewProvider {
    static var previews: some View {
        TopShelfLogView()
    }
}
#endif
