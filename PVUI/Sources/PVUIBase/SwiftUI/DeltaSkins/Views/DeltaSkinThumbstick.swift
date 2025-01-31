import SwiftUI
import AudioToolbox

struct DeltaSkinThumbstick: View {
    let frame: CGRect
    let thumbstickImage: UIImage
    let thumbstickSize: CGSize
    let mappingSize: CGSize

    @State private var dragOffset: CGSize = .zero
    @GestureState private var isDragging = false

    // Use softer haptics for thumbstick
    #if !os(tvOS)
    private let impactGenerator = UIImpactFeedbackGenerator(style: .soft)
    private let edgeGenerator = UIImpactFeedbackGenerator(style: .medium)
    #endif
    
    private let maxDistance: CGFloat = 20  // Maximum distance thumbstick can move

    @State private var lastHapticDistance: CGFloat = 0
    private let hapticDistanceThreshold: CGFloat = 5  // Minimum movement distance for new haptic

    private func generateHapticFeedback(distance: CGFloat, isEdge: Bool = false) {
        // Only trigger if we've moved significantly from last haptic position
        let distanceDelta = abs(distance - lastHapticDistance)
        guard distanceDelta >= hapticDistanceThreshold else { return }

        #if !os(tvOS)
        if isEdge {
            edgeGenerator.impactOccurred(intensity: 0.7)
        } else {
            // Softer feedback during normal movement
            impactGenerator.impactOccurred(intensity: min(distance/maxDistance * 0.5, 0.5))
        }
        #endif
        lastHapticDistance = distance
    }

    var body: some View {
        GeometryReader { geometry in
            let scale = min(
                geometry.size.width / mappingSize.width,
                geometry.size.height / mappingSize.height
            )

            let scaledSkinWidth = mappingSize.width * scale
            let scaledSkinHeight = mappingSize.height * scale
            let xOffset = (geometry.size.width - scaledSkinWidth) / 2

            // Use same coordinate system as hit test
            let hasScreenPosition = true // Since this is for effects, we want centered
            let yOffset: CGFloat = hasScreenPosition ?
                ((geometry.size.height - scaledSkinHeight) / 2) :
                (geometry.size.height - scaledSkinHeight)

            let scaledFrame = CGRect(
                x: frame.minX * scale + xOffset,
                y: yOffset + (frame.minY * scale),
                width: frame.width * scale,
                height: frame.height * scale
            )

            ZStack {
                // Base position (optional - might be part of main skin image)
                Circle()
                    .stroke(.gray.opacity(0.3))
                    .frame(width: scaledFrame.width, height: scaledFrame.height)

                // Movable thumbstick
                Image(uiImage: thumbstickImage)
                    .resizable()
                    .frame(width: scaledFrame.width, height: scaledFrame.height)
                    .offset(dragOffset)
                #if !os(tvOS)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let delta = CGSize(
                                    width: value.translation.width,
                                    height: value.translation.height
                                )

                                let distance = sqrt(pow(delta.width, 2) + pow(delta.height, 2))
                                if distance > maxDistance {
                                    let scale = maxDistance / distance
                                    dragOffset = CGSize(
                                        width: delta.width * scale,
                                        height: delta.height * scale
                                    )
                                    generateHapticFeedback(distance: distance, isEdge: true)
                                } else {
                                    dragOffset = delta
                                    generateHapticFeedback(distance: distance)
                                }
                            }
                            .onEnded { _ in
                                withAnimation(.spring()) {
                                    dragOffset = .zero
                                }
                                // Play springy release sound with centered pan
                                if let releaseSound = DeltaSkinView.buttonSounds["thumbstick_release"] {
                                    AudioEngine.shared.playSound(buffer: releaseSound, pan: 0)
                                }
                            }
                    )
                #endif
            }
            .position(x: scaledFrame.midX, y: scaledFrame.midY)
            .onAppear {
                #if !os(tvOS)
                // Prepare haptics
                impactGenerator.prepare()
                edgeGenerator.prepare()
                #endif
            }
        }
    }
}
