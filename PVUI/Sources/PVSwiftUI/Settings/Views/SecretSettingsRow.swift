//
//  SecretSettingsRow.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/3/25.
//

import SwiftUI
import MarkdownView
import AudioToolbox

internal struct SecretSettingsRow: View {
    @State private var showSecretView = false
    @AppStorage("showFeatureFlagsDebug") private var showFeatureFlagsDebug = false

    var body: some View {
        Group {
            #if DEBUG
            NavigationLink(destination: FeatureFlagsDebugView()) {
                SettingsRow(title: "Feature Flags Debug",
                           subtitle: "Override feature flags for testing",
                           icon: .sfSymbol("flag.fill"))
                
            }
            Button {
                showSecretView = true
            } label: {
                SettingsRow(title: "About",
                           subtitle: "Version information",
                           icon: .sfSymbol("info.circle"))
            }
            .buttonStyle(.plain)
            #else
            if showFeatureFlagsDebug {
                NavigationLink(destination: FeatureFlagsDebugView()) {
                    SettingsRow(title: "Feature Flags Debug",
                               subtitle: "Override feature flags for testing",
                               icon: .sfSymbol("flag.fill"))
                }
            } else {
                Button {
                    showSecretView = true
                } label: {
                    SettingsRow(title: "About",
                               subtitle: "Version information",
                               icon: .sfSymbol("info.circle"))
                }
                .buttonStyle(.plain)
            }
            #endif
        }
        .sheet(isPresented: $showSecretView) {
            SecretDPadView {
                showFeatureFlagsDebug = true
            }
        }
    }
}

private struct SecretDPadView: View {
    enum Direction {
        case up, down, left, right
    }

    let onComplete: () -> Void
    @State private var pressedButtons: [Direction] = []
    @State private var showDPad = false
    @FocusState private var isFocused: Bool
    @Environment(\.dismiss) private var dismiss
    #if os(tvOS)
    @State private var controller: GCController?
    @State private var isHandlingX = false
    @State private var isHandlingY = false
    #endif

    private let konamiCode: [Direction] = [.up, .up, .down, .down, .left, .right, .left, .right]

    var body: some View {
        VStack {
            if showDPad {
                #if os(tvOS)
                // tvOS: Show instructions and handle Siri Remote gestures
                VStack {
                    Text("Use Siri Remote to enter the code")
                        .font(.headline)
                        .padding()

                    // Show current sequence with better visibility
                    Text(sequenceText.isEmpty ? "No input yet" : sequenceText)
                        .font(.title)
                        .foregroundColor(.primary)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.2))
                        )
                        .padding()

                    // Show hint about remaining inputs needed
                    Text("\(konamiCode.count - (pressedButtons.count % konamiCode.count)) more inputs needed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                #else
                // iOS: Show D-Pad buttons
                VStack(spacing: 0) {
                    Button(action: { pressButton(.up) }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .resizable()
                            .frame(width: 60, height: 60)
                    }

                    HStack(spacing: 60) {
                        Button(action: { pressButton(.left) }) {
                            Image(systemName: "arrow.left.circle.fill")
                                .resizable()
                                .frame(width: 60, height: 60)
                        }

                        Button(action: { pressButton(.right) }) {
                            Image(systemName: "arrow.right.circle.fill")
                                .resizable()
                                .frame(width: 60, height: 60)
                        }
                    }

                    Button(action: { pressButton(.down) }) {
                        Image(systemName: "arrow.down.circle.fill")
                            .resizable()
                            .frame(width: 60, height: 60)
                    }
                }
                .foregroundColor(.accentColor)

                Text(sequenceText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top)
                #endif
            } else {
                ScrollView {
                    if let markdownPath = Bundle.main.path(forResource: "CONTRIBUTORS", ofType: "md"),
                       let markdown = FileManager.default.contents(atPath: markdownPath) {
                        MarkdownView(text: String(data: markdown, encoding: .utf8) ?? "# CONTRIBUTORS\n\nNo CONTRIBUTORS file found.", baseURL: nil)
                    } else {
                        MarkdownView(text: "# CONTRIBUTORS\n\nNo CONTRIBUTORS file found.", baseURL: nil)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        #if os(tvOS)
        .focusable()
        .focused($isFocused)
        .onLongPressGesture(minimumDuration: 5) {
            DLOG("[SecretDPadView] Long press detected")
            withAnimation(.easeInOut) {
                showDPad = true
                isFocused = true
                setupController()
            }
        }
        .onChange(of: showDPad) { newValue in
            DLOG("[SecretDPadView] showDPad changed to: \(newValue)")
            if newValue {
                setupController()
            }
        }
        .onChange(of: isFocused) { focused in
            DLOG("[SecretDPadView] Focus changed to: \(focused)")
            if !focused {
                pressedButtons.removeAll()
                removeController()
            } else if showDPad {
                setupController()
            }
        }
        .onDisappear {
            removeController()
        }
        #else
        // iOS: Handle long press gesture
        .onLongPressGesture(minimumDuration: 5) {
            withAnimation {
                showDPad = true
            }
        }
        #endif
    }

    #if os(tvOS)
    private func setupController() {
        DLOG("[SecretDPadView] Setting up controller")
        // Get the first connected controller (Siri Remote)
        controller = GCController.controllers().first

        controller?.microGamepad?.dpad.valueChangedHandler = { [self] dpad, xValue, yValue in
            DLOG("[SecretDPadView] Dpad input - x: \(xValue), y: \(yValue)")

            // Handle X-axis (left/right)
            if xValue == 1.0 && !isHandlingX {
                isHandlingX = true
                pressButton(.right)
            } else if xValue == -1.0 && !isHandlingX {
                isHandlingX = true
                pressButton(.left)
            } else if xValue == 0 {
                isHandlingX = false
            }

            // Handle Y-axis (up/down)
            if yValue == 1.0 && !isHandlingY {
                isHandlingY = true
                pressButton(.up)
            } else if yValue == -1.0 && !isHandlingY {
                isHandlingY = true
                pressButton(.down)
            } else if yValue == 0 {
                isHandlingY = false
            }
        }

        // Enable basic gamepad input profile for Siri Remote
        controller?.microGamepad?.reportsAbsoluteDpadValues = false
    }

    private func removeController() {
        DLOG("[SecretDPadView] Removing controller")
        controller?.microGamepad?.dpad.valueChangedHandler = nil
        controller = nil
        isHandlingX = false
        isHandlingY = false
    }
    #endif

    private var sequenceText: String {
        pressedButtons.map { direction in
            switch direction {
            case .up: return "↑"
            case .down: return "↓"
            case .left: return "←"
            case .right: return "→"
            }
        }.joined(separator: " ")
    }

    private func pressButton(_ direction: Direction) {
        DLOG("[SecretDPadView] Button pressed: \(direction)")
        pressedButtons.append(direction)

        #if os(tvOS)
        // Use AudioServicesPlaySystemSound for tvOS feedback
        AudioServicesPlaySystemSound(1519) // Standard system sound
        #endif

        // Check if the sequence matches the Konami code
        if pressedButtons.count >= konamiCode.count {
            let lastEight = Array(pressedButtons.suffix(konamiCode.count))
            DLOG("[SecretDPadView] Checking sequence: \(lastEight) against \(konamiCode)")
            if lastEight == konamiCode {
                DLOG("[SecretDPadView] Konami code matched!")
                onComplete()
                dismiss()
            }
        }

        // Limit the stored sequence length
        if pressedButtons.count > 16 {
            pressedButtons.removeFirst(8)
        }

        DLOG("[SecretDPadView] Current sequence: \(sequenceText)")
    }
}
