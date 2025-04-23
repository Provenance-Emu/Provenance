import SwiftUI
import PVPrimitives

/// View for configuring AI enhancements for Delta skins
public struct DeltaSkinAIEnhancementView: View {
    @StateObject private var enhancer = DeltaSkinAIEnhancer.shared
    @State private var showingInfo = false
    @State private var selectedMode: DeltaSkinAIEnhancer.EnhancementMode?

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            // Main content
            ScrollView {
                VStack(spacing: 24) {
                    // Enhancement mode selector
                    enhancementSelector

                    // Info card for selected mode
                    if let mode = selectedMode {
                        infoCard(for: mode)
                    }

                    // Feature showcase
                    featureShowcase
                }
                .padding()
            }
        }
        .background(backgroundStyle)
        .navigationTitle("AI Enhancements")
    }

    private var backgroundStyle: Color {
        #if os(tvOS)
        return Color.retroDarkBlue.opacity(0.9)
        #else
        return Color(.systemGroupedBackground)
        #endif
    }
    
    private var secondaryBackgroundColor: Color {
        #if os(tvOS)
        return Color.retroDarkBlue.opacity(0.7)
        #else
        return Color(.secondarySystemGroupedBackground)
        #endif
    }
    
    private var headerView: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [.blue, .purple]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 16) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 48))
                    .foregroundColor(.white)

                Text("AI-Powered Controller Enhancements")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Enhance your gaming experience with intelligent features")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.vertical, 32)
        }
    }

    private var enhancementSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Enhancement Mode")
                .font(.headline)
                .padding(.leading, 4)

            ForEach(DeltaSkinAIEnhancer.EnhancementMode.allCases) { mode in
                EnhancementModeButton(
                    mode: mode,
                    isSelected: mode == enhancer.enhancementMode,
                    action: {
                        withAnimation {
                            enhancer.enhancementMode = mode
                            selectedMode = mode
                        }
                    }
                )
            }
        }
    }

    private struct EnhancementModeButton: View {
        let mode: DeltaSkinAIEnhancer.EnhancementMode
        let isSelected: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack(spacing: 16) {
                    Image(systemName: mode.iconName)
                        .font(.system(size: 24))
                        .foregroundColor(isSelected ? .white : .accentColor)
                        .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(mode.rawValue)
                            .font(.headline)
                            .foregroundColor(isSelected ? .white : .primary)

                        Text(mode.description)
                            .font(.caption)
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(backgroundGradient)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }

        private var backgroundGradient: AnyShapeStyle {
            if isSelected {
                return AnyShapeStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [.retroPink, .retroPurple]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            } else {
                return AnyShapeStyle(secondaryBackgroundStyle)
            }
        }
        
        private var secondaryBackgroundStyle: Color {
            #if os(tvOS)
            return Color.retroDarkBlue.opacity(0.7)
            #else
            return Color(.secondarySystemGroupedBackground)
            #endif
        }
    }

    private func infoCard(for mode: DeltaSkinAIEnhancer.EnhancementMode) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: mode.iconName)
                    .font(.system(size: 28))
                    .foregroundColor(.accentColor)

                Text(mode.rawValue)
                    .font(.title3)
                    .fontWeight(.bold)

                Spacer()

                Button {
                    showingInfo.toggle()
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 22))
                        .foregroundColor(.secondary)
                }
            }

            Text(modeDetailedDescription(mode))
                .font(.body)
                .foregroundColor(.secondary)

            if mode != .none {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)

                    Text("This is a technology preview and may not work with all games")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(secondaryBackgroundColor)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private var featureShowcase: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Feature Showcase")
                .font(.headline)
                .padding(.leading, 4)

            // Pixel upscaling demo
            demoCard(
                title: "Pixel Perfect Upscaling",
                description: "Neural network-based upscaling preserves pixel art details",
                imageName: "square.on.square",
                gradientColors: [.blue, .cyan]
            )

            // Motion controls demo
            demoCard(
                title: "Motion Controls",
                description: "Use your device's camera to track hand movements",
                imageName: "hand.raised",
                gradientColors: [.purple, .pink]
            )

            // Voice commands demo
            demoCard(
                title: "Voice Commands",
                description: "Control your games with simple voice instructions",
                imageName: "waveform",
                gradientColors: [.green, .mint]
            )
        }
    }

    private func demoCard(title: String, description: String, imageName: String, gradientColors: [Color]) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(
                        gradient: Gradient(colors: gradientColors),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 60, height: 60)

                Image(systemName: imageName)
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(secondaryBackgroundColor)
        .cornerRadius(16)
    }

    private func modeDetailedDescription(_ mode: DeltaSkinAIEnhancer.EnhancementMode) -> String {
        switch mode {
        case .none:
            return "Standard controller experience without any AI enhancements. All buttons and controls function normally as designed in the skin."

        case .pixelUpscale:
            return "Uses machine learning to intelligently upscale pixel art games, preserving the original artistic intent while making them look crisp on modern displays. Particularly effective for 8-bit and 16-bit era games."

        case .motionTracking:
            return "Tracks your hand movements using the device's camera to enable gesture-based controls. Point, swipe, and make hand gestures to control your game without touching the screen. Requires camera permission."

        case .voiceCommands:
            return "Enables voice control for your games with commands like 'jump', 'fire', 'start', and directional controls. The system learns from your gameplay to improve recognition accuracy over time. Requires microphone permission."

        case .adaptiveLayout:
            return "Dynamically adjusts the controller layout based on your gameplay patterns. Frequently used buttons become more prominent, while less used controls are subtly minimized. The layout evolves as you play to match your personal style."

        case .gameAwareness:
            return "Analyzes the game screen in real-time to understand context and optimize controls accordingly. For example, it can detect boss battles and adjust button sensitivity, or recognize platforming sections and optimize jump controls."
        }
    }
}
