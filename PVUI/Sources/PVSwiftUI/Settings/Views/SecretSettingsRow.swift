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
    @State private var lastInputTime: Date = Date()
    private let inputDebounceInterval: TimeInterval = 0.2
#endif
    
    private let konamiCode: [Direction] = [.up, .up, .down, .down, .left, .right, .left, .right]
    
    var body: some View {
        // On tvOS, we need to ensure the view is ready to receive input
        // even before showDPad becomes true
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
        // Capture physical D-pad button presses from Siri Remote
        .onMoveCommand { direction in
            DLOG("[SecretDPadView] onMoveCommand received: \(direction)")
            switch direction {
            case .up:
                handleInput(.up)
            case .down:
                handleInput(.down)
            case .left:
                handleInput(.left)
            case .right:
                handleInput(.right)
            @unknown default:
                break
            }
        }
        // Note: DragGesture is not available in tvOS, so we rely on:
        // 1. onMoveCommand for physical D-pad button presses
        // 2. GameController framework for all controller input (including touchpad via microGamepad)
        // 3. The setupController() method handles modern Siri Remote input via microGamepad.dpad
        .focusable()
        .focused($isFocused)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Ensure the view has focus to receive remote input
                isFocused = true
                setupController()
                DLOG("[SecretDPadView] View is now focused and ready for input")
            }
        }
        .onLongPressGesture(minimumDuration: 5) {
            DLOG("[SecretDPadView] Long press detected")
            withAnimation(.easeInOut) {
                showDPad = true
                // Ensure the view has focus to receive remote input
                isFocused = true
                setupController()
                DLOG("[SecretDPadView] View is now focused and ready for input")
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
        
        // Find all connected controllers and log them
        let controllers = GCController.controllers()
        DLOG("[SecretDPadView] Found \(controllers.count) controllers")
        
        for (index, ctrl) in controllers.enumerated() {
            DLOG("[SecretDPadView] Controller \(index): \(ctrl.vendorName ?? "Unknown")")
            DLOG("[SecretDPadView] - Has microGamepad: \(ctrl.microGamepad != nil)")
            DLOG("[SecretDPadView] - Has extendedGamepad: \(ctrl.extendedGamepad != nil)")
        }
        
        // Get the first connected controller
        controller = controllers.first
        
        guard let controller = controller else {
            DLOG("[SecretDPadView] No controller found")
            return
        }
        
        DLOG("[SecretDPadView] Using controller: \(controller.vendorName ?? "Unknown")")
        
        // Prioritize extendedGamepad over microGamepad for full controllers
        // This prevents conflicts when a controller supports both profiles
        if let extendedGamepad = controller.extendedGamepad {
            DLOG("[SecretDPadView] Setting up extendedGamepad (full controller)")
            setupExtendedGamepad(extendedGamepad)
        } else if let microGamepad = controller.microGamepad {
            DLOG("[SecretDPadView] Setting up microGamepad (Siri Remote)")
            setupMicroGamepad(microGamepad)
        } else {
            DLOG("[SecretDPadView] Controller has no supported input profile")
        }
    }
    
    private func setupMicroGamepad(_ microGamepad: GCMicroGamepad) {
        microGamepad.reportsAbsoluteDpadValues = false
        
        microGamepad.dpad.valueChangedHandler = { [self] dpad, xValue, yValue in
            DLOG("[SecretDPadView] MicroGamepad dpad input - x: \(xValue), y: \(yValue)")
            
            let threshold: Float = 0.5 // Threshold for detecting directional input
            let resetThreshold: Float = 0.2 // Lower threshold for resetting state
            
            // Handle X-axis (left/right)
            if xValue > threshold && !self.isHandlingX {
                self.isHandlingX = true
                self.handleInput(.right)
                DLOG("[SecretDPadView] MicroGamepad detected RIGHT")
            } else if xValue < -threshold && !self.isHandlingX {
                self.isHandlingX = true
                self.handleInput(.left)
                DLOG("[SecretDPadView] MicroGamepad detected LEFT")
            } else if abs(xValue) < resetThreshold {
                self.isHandlingX = false
            }
            
            // Handle Y-axis (up/down)
            if yValue > threshold && !self.isHandlingY {
                self.isHandlingY = true
                self.handleInput(.up)
                DLOG("[SecretDPadView] MicroGamepad detected UP")
            } else if yValue < -threshold && !self.isHandlingY {
                self.isHandlingY = true
                self.handleInput(.down)
                DLOG("[SecretDPadView] MicroGamepad detected DOWN")
            } else if abs(yValue) < resetThreshold {
                self.isHandlingY = false
            }
        }
    }
    
    private func setupExtendedGamepad(_ extendedGamepad: GCExtendedGamepad) {
        // Handle D-pad input with higher priority
        extendedGamepad.dpad.valueChangedHandler = { [self] dpad, xValue, yValue in
            DLOG("[SecretDPadView] ExtendedGamepad dpad input - x: \(xValue), y: \(yValue)")
            
            let threshold: Float = 0.3 // Lower threshold for game controller D-pads
            let resetThreshold: Float = 0.1 // Lower threshold for resetting state
            
            // Handle X-axis (left/right)
            if xValue > threshold && !self.isHandlingX {
                self.isHandlingX = true
                self.handleInput(.right)
                DLOG("[SecretDPadView] ExtendedGamepad D-pad detected RIGHT")
            } else if xValue < -threshold && !self.isHandlingX {
                self.isHandlingX = true
                self.handleInput(.left)
                DLOG("[SecretDPadView] ExtendedGamepad D-pad detected LEFT")
            } else if abs(xValue) < resetThreshold {
                self.isHandlingX = false
            }
            
            // Handle Y-axis (up/down)
            if yValue > threshold && !self.isHandlingY {
                self.isHandlingY = true
                self.handleInput(.up)
                DLOG("[SecretDPadView] ExtendedGamepad D-pad detected UP")
            } else if yValue < -threshold && !self.isHandlingY {
                self.isHandlingY = true
                self.handleInput(.down)
                DLOG("[SecretDPadView] ExtendedGamepad D-pad detected DOWN")
            } else if abs(yValue) < resetThreshold {
                self.isHandlingY = false
            }
        }
        
        // Handle left joystick input as backup
        extendedGamepad.leftThumbstick.valueChangedHandler = { [self] thumbstick, xValue, yValue in
            let threshold: Float = 0.7 // Higher threshold for joystick to avoid accidental input
            let resetThreshold: Float = 0.3
            
            DLOG("[SecretDPadView] Left thumbstick input - x: \(xValue), y: \(yValue)")
            
            // Handle X-axis (left/right)
            if xValue > threshold && !self.isHandlingX {
                self.isHandlingX = true
                self.handleInput(.right)
                DLOG("[SecretDPadView] ExtendedGamepad joystick detected RIGHT")
            } else if xValue < -threshold && !self.isHandlingX {
                self.isHandlingX = true
                self.handleInput(.left)
                DLOG("[SecretDPadView] ExtendedGamepad joystick detected LEFT")
            } else if abs(xValue) < resetThreshold {
                self.isHandlingX = false
            }
            
            // Handle Y-axis (up/down) - Note: Y is inverted for thumbsticks
            if yValue > threshold && !self.isHandlingY {
                self.isHandlingY = true
                self.handleInput(.up)
                DLOG("[SecretDPadView] ExtendedGamepad joystick detected UP")
            } else if yValue < -threshold && !self.isHandlingY {
                self.isHandlingY = true
                self.handleInput(.down)
                DLOG("[SecretDPadView] ExtendedGamepad joystick detected DOWN")
            } else if abs(yValue) < resetThreshold {
                self.isHandlingY = false
            }
        }
    }
    
    private func removeController() {
        DLOG("[SecretDPadView] Removing controller")
        // Clean up microGamepad handlers
        controller?.microGamepad?.dpad.valueChangedHandler = nil
        
        // Clean up extendedGamepad handlers
        controller?.extendedGamepad?.dpad.valueChangedHandler = nil
        controller?.extendedGamepad?.leftThumbstick.valueChangedHandler = nil
        
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
    
    // Unified input handler for all input sources (Siri Remote, gamepads, touchpad, iOS buttons)
    private func handleInput(_ direction: Direction) {
        let currentTime = Date()
        
#if os(tvOS)
        // Debounce input to prevent duplicate triggers from multiple sources
        guard currentTime.timeIntervalSince(lastInputTime) >= inputDebounceInterval else {
            DLOG("[SecretDPadView] Input debounced: \(direction)")
            return
        }
        lastInputTime = currentTime
#endif
        
        DLOG("[SecretDPadView] Input received: \(direction)")
        
        // Always show the D-pad UI when we receive input (for tvOS)
        if !showDPad {
            withAnimation {
                showDPad = true
#if os(tvOS)
                isFocused = true
#endif
            }
        }
        
        // Add the direction to our sequence
        pressedButtons.append(direction)
        DLOG("[SecretDPadView] Current sequence: \(pressedButtons)")
        
        // Provide audio feedback
#if os(tvOS)
        AudioServicesPlaySystemSound(1519) // Standard system sound for tvOS
#endif
        
        // Check if the sequence matches the Konami code
        if pressedButtons.count >= konamiCode.count {
            let lastEight = Array(pressedButtons.suffix(konamiCode.count))
            DLOG("[SecretDPadView] Checking sequence: \(lastEight) against \(konamiCode)")
            if lastEight == konamiCode {
                DLOG("[SecretDPadView] KONAMI CODE MATCHED!")
#if os(tvOS)
                AudioServicesPlaySystemSound(1104) // Success sound
#endif
                onComplete()
                pressedButtons.removeAll()
                dismiss()
                return
            }
        }
        
        // Limit the stored sequence length to prevent memory bloat
        if pressedButtons.count > 16 {
            pressedButtons.removeFirst(8)
        }
        
        DLOG("[SecretDPadView] Current sequence display: \(sequenceText)")
    }
    
    // iOS button press handler - routes to unified input handler
    private func pressButton(_ direction: Direction) {
        handleInput(direction)
    }
}
