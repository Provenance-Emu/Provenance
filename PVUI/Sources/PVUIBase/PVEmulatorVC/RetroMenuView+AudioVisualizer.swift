import SwiftUI
import PVCoreAudio
import PVThemes
import AudioToolbox
import PVSettings
import UIKit

// MARK: - Audio Visualizer Button

/// A standalone button view for the audio visualizer toggle
public struct AudioVisualizerButton: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    private let emulatorVC: PVEmulatorViewController
    private let dismissAction: () -> Void
    
    public init(emulatorVC: PVEmulatorViewController, dismissAction: @escaping () -> Void) {
        self.emulatorVC = emulatorVC
        self.dismissAction = dismissAction
    }
    
    public var body: some View {
        // Get current state from emulator view controller
        let isEnabled = emulatorVC.isAudioVisualizerEnabled
                
                // Create toggle button with retrowave styling
                Button(action: {
                    // Toggle audio visualizer
                    emulatorVC.toggleAudioVisualizer()
                    
                    // Play haptic feedback
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    
                    // Play sound
                    AudioServicesPlaySystemSound(1519) // Standard button click sound
                    
                    // Dismiss menu
                    dismissAction()
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
                        
                        // Toggle indicator
                        Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isEnabled ? Color.cyan : Color.gray.opacity(0.7))
                            .font(.system(size: 18))
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
