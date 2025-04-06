import SwiftUI
import PVCoreAudio
import PVThemes
import AudioToolbox
import PVSettings
import UIKit

// MARK: - Audio Visualizer Button

/// A standalone button view for the audio visualizer with mode selection
public struct AudioVisualizerButton: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    private let emulatorVC: PVEmulatorViewController
    private let dismissAction: () -> Void
    @State private var showingOptions = false
    @State private var selectedMode: VisualizerMode = VisualizerMode.current
    
    public init(emulatorVC: PVEmulatorViewController, dismissAction: @escaping () -> Void) {
        self.emulatorVC = emulatorVC
        self.dismissAction = dismissAction
    }
    
    public var body: some View {
        // Get current state from emulator view controller
        let isEnabled = selectedMode != .off
                
        // Create button with retrowave styling
        Button(action: {
            // Show options sheet
            showingOptions = true
            
            // Play haptic feedback
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }) {
            HStack {
                // Icon with retrowave styling
                Image(systemName: "waveform")
                    .font(.system(size: 18))
                    .foregroundColor(isEnabled ? Color.cyan : .white)
                    .shadow(color: Color.cyan.opacity(isEnabled ? 0.8 : 0), radius: isEnabled ? 4 : 0)
                
                Text("AUDIO VISUALIZER")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Mode indicator
                Text(selectedMode.description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isEnabled ? Color.cyan : Color.gray.opacity(0.7))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isEnabled ? Color.cyan : Color.gray.opacity(0.5),
                                lineWidth: isEnabled ? 1.5 : 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingOptions) {
            visualizerOptionsView
        }
        .onAppear {
            // Update selected mode from current setting
            selectedMode = VisualizerMode.current
        }
    }
    
    private var visualizerOptionsView: some View {
        ZStack {
            // Background with retrowave grid
            VisualizationRetrowaveGrid()
                .opacity(0.15)
                .edgesIgnoringSafeArea(.all)
            
            // Overlay with dark blur
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                Text("Audio Visualizer")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 20)
                
                // Retrowave picker for visualizer mode
                RetrowaveOptionPicker(
                    title: "Visualizer Mode",
                    selection: $selectedMode,
                    options: VisualizerMode.allCases.map { ($0, $0.description) }
                )
                .onChange(of: selectedMode) { newMode in
                    // Update the visualizer mode
                    emulatorVC.setVisualizerMode(newMode)
                    newMode.saveToUserDefaults()
                }
                
                // Preview of the selected visualizer mode
                visualizerPreview
                    .frame(height: 150)
                    .padding(.horizontal, 20)
                
                Spacer()
                
                // Done button
                Button(action: {
                    showingOptions = false
                    dismissAction()
                }) {
                    Text("Done")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 200, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.retroPink, Color.retroPurple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(
                                            LinearGradient(
                                                colors: [Color.retroPink, Color.retroCyan],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ),
                                            lineWidth: 1.5
                                        )
                                )
                                .shadow(color: Color.retroPink.opacity(0.5), radius: 8, x: 0, y: 0)
                        )
                }
                .padding(.bottom, 40)
            }
            .padding()
        }
    }
    
    private var visualizerPreview: some View {
        ZStack {
            // Background with retrowave grid
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.retroPink, Color.retroPurple, Color.retroCyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: Color.retroPink.opacity(0.5), radius: 8, x: 0, y: 0)
            
            VStack {
                // Preview text
                Text("Preview")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.gray)
                    .padding(.top, 8)
                
                Spacer()
                
                // Visualizer preview based on selected mode
                Group {
                    switch selectedMode {
                    case .off:
                        Text("Visualizer Off")
                            .foregroundColor(Color.gray)
                    case .standard:
                        // Simulated standard visualizer
                        simulatedStandardVisualizer
                    case .standardCircular:
                        // Simulated standard circular visualizer
                        simulatedCircularVisualizer
                    case .metal:
                        // Simulated metal visualizer
                        simulatedMetalVisualizer
                    case .metalCircular:
                        // Simulated metal circular visualizer
                        simulatedCircularVisualizer
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .padding()
        }
    }
    
    // Simulated standard visualizer for preview
    private var simulatedStandardVisualizer: some View {
        ZStack {
            // Dynamic Island shape
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.black)
                .frame(width: 126, height: 37)
            
            // Bar visualization below the Dynamic Island
            HStack(spacing: 1) {
                ForEach(0..<32, id: \.self) { index in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.retroPink, Color.retroPurple, Color.retroCyan],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: 2, height: max(2, simulatedAmplitudes()[index % simulatedAmplitudes().count] * 20))
                        .cornerRadius(1)
                }
            }
            .offset(y: 25) // Position below the Dynamic Island
        }
        .frame(height: 60)
    }
    
    // Simulated metal visualizer for preview
    private var simulatedMetalVisualizer: some View {
        ZStack {
            // Background grid
            VisualizationRetrowaveGrid()
                .opacity(0.3)
                .frame(height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 18))
            
            // Dynamic Island shape
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.black)
                .frame(width: 126, height: 37)
            
            // Metal-style waveform with enhanced effects
            HStack(spacing: 1) {
                ForEach(0..<32, id: \.self) { index in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.retroPink, Color.retroPurple, Color.retroCyan],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: 2, height: max(2, simulatedAmplitudes()[index % simulatedAmplitudes().count] * 20))
                        .cornerRadius(1)
                        .shadow(color: Color.retroCyan, radius: 2)
                        .blur(radius: 0.5)
                }
            }
            .offset(y: 25) // Position below the Dynamic Island
            
            // Add extra glow for metal effect
            HStack(spacing: 1) {
                ForEach(0..<16, id: \.self) { index in
                    Rectangle()
                        .fill(Color.retroCyan.opacity(0.3))
                        .frame(width: 4, height: max(2, simulatedAmplitudes()[(index*2) % simulatedAmplitudes().count] * 15))
                        .cornerRadius(2)
                        .blur(radius: 2)
                }
            }
            .offset(y: 25) // Position below the Dynamic Island
        }
        .frame(height: 60)
    }
    
    // Simulated circular visualizer for preview
    private var simulatedCircularVisualizer: some View {
        ZStack {
            // Background grid
            VisualizationRetrowaveGrid()
                .opacity(0.3)
                .frame(height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            
            // Dynamic Island shape
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.black)
                .frame(width: 126, height: 37)
            
            // Dynamic Island shape outline with glow
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.retroPink, Color.retroPurple, Color.retroCyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1.5
                )
                .frame(width: 126, height: 37)
                .shadow(color: Color.retroCyan, radius: 3)
            
            // Simulated waveform bars arranged in a circle around the Dynamic Island
            ForEach(0..<40) { index in
                let angle = 2 * CGFloat.pi * CGFloat(index) / 40.0
                let amplitude = simulatedAmplitudes()[index % simulatedAmplitudes().count] * 8
                
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.retroPink, Color.retroPurple, Color.retroCyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 2, height: max(2, amplitude))
                    .cornerRadius(1)
                    .offset(
                        x: (126/2 + 6) * cos(angle),
                        y: (37/2 + 6) * sin(angle)
                    )
            }
        }
        .frame(height: 70)
    }
    
    // Generate simulated waveform data for preview
    private func simulatedAmplitudes() -> [CGFloat] {
        var amplitudes = [CGFloat]()
        let count = 60
        
        for i in 0..<count {
            let t = Double(i) / Double(count - 1)
            let frequency = 2.0 + Double(i) / 10.0
            let value = sin(t * .pi * frequency) * 0.3 + sin(t * .pi * frequency * 2) * 0.2
            amplitudes.append(CGFloat(value))
        }
        
        return amplitudes
    }
}

// MARK: - RetroMenuView Extension

extension RetroMenuView {
    /// Add the audio visualizer button to the menu
    public func addAudioVisualizerButton() {
        // This is a stub method that will be called from the RetroMenuView
        // The actual implementation is in the AudioVisualizerButton view
    }
}
