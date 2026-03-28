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
import PVThemes

/// A view that displays the TopShelf extension log file
struct TopShelfLogView: View {
    // State for the log content
    @State private var logContent: String = "Loading TopShelf log..."
    @State private var isRefreshing: Bool = false

    // Timer for auto-refresh
    @State private var timer: AnyCancellable?

    @Environment(\.dismiss) private var dismiss

    #if os(tvOS)
    @FocusState private var focusedButton: FocusedButton?
    #endif

    private enum FocusedButton: Hashable {
        case refresh
        case clear
    }

    /// Helper function to get the border gradient based on focus state
    private func focusedBorderGradient(for button: FocusedButton) -> LinearGradient {
        let colors = getButtonColors(for: button)
        #if os(tvOS)
        if focusedButton == button {
            return LinearGradient(
                gradient: Gradient(colors: [colors.0, colors.1, colors.0]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                gradient: Gradient(colors: [colors.2, colors.3]),
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        #else
        return LinearGradient(
            gradient: Gradient(colors: [colors.2, colors.3]),
            startPoint: .leading,
            endPoint: .trailing
        )
        #endif
    }

    /// Helper function to get colors for each button
    private func getButtonColors(for button: FocusedButton) -> (Color, Color, Color, Color) {
        switch button {
        case .refresh:
            // focused colors, unfocused colors
            return (.retroPink, .retroBlue, .retroPink.opacity(0.6), .retroBlue.opacity(0.6))
        case .clear:
            return (.retroPink, .red, .retroPink.opacity(0.6), .red.opacity(0.4))
        }
    }

    /// Helper function to get the border width based on focus state
    private func focusedBorderWidth(for button: FocusedButton) -> CGFloat {
        #if os(tvOS)
        return focusedButton == button ? 3 : 1.5
        #else
        return 1.5
        #endif
    }

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
                            LinearGradient(
                                gradient: Gradient(colors: [.retroBlue, .retroPurple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(
                                    focusedBorderGradient(for: .refresh),
                                    lineWidth: focusedBorderWidth(for: .refresh)
                                )
                        )
                        #if os(tvOS)
                        .scaleEffect(focusedButton == .refresh ? 1.08 : 1.0)
                        .shadow(color: focusedButton == .refresh ? Color.retroPink.opacity(0.9) : .clear, radius: focusedButton == .refresh ? 15 : 5)
                        #endif
                    }
                    #if os(tvOS)
                    .focused($focusedButton, equals: .refresh)
                    .buttonStyle(TVMediaCardButtonStyle())
                    .tvOSDisableFocusEffect()
                    .animation(.easeInOut(duration: 0.15), value: focusedButton)
                    #endif
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
                            LinearGradient(
                                gradient: Gradient(colors: [.retroPink.opacity(0.8), .red.opacity(0.6)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(
                                    focusedBorderGradient(for: .clear),
                                    lineWidth: focusedBorderWidth(for: .clear)
                                )
                        )
                        #if os(tvOS)
                        .scaleEffect(focusedButton == .clear ? 1.08 : 1.0)
                        .shadow(color: focusedButton == .clear ? Color.retroPink.opacity(0.9) : .clear, radius: focusedButton == .clear ? 15 : 5)
                        #endif
                    }
                    #if os(tvOS)
                    .focused($focusedButton, equals: .clear)
                    .buttonStyle(TVMediaCardButtonStyle())
                    .tvOSDisableFocusEffect()
                    .animation(.easeInOut(duration: 0.15), value: focusedButton)
                    #endif
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
        #if os(tvOS)
        .focusSection()
        .onExitCommand { dismiss() }
        #endif
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
