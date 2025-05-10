import SwiftUI
import PVLogging

/// View that renders a DeltaSkin with its screens and buttons
public struct DeltaSkinScreensView: View {
    let skin: any DeltaSkinProtocol
    let traits: DeltaSkinTraits
    let containerSize: CGSize

    /// Input handler for the skin
    @EnvironmentObject private var inputHandler: DeltaSkinInputHandler

    /// Whether to show debug overlays
    @Environment(\.debugSkinMappings) private var showDebug: Bool

    /// State for the loaded skin image
    @State private var skinImage: UIImage?
    @State private var loadingError: Error?

    @State private var screenGroups: [DeltaSkinScreenGroup]?
    @State private var buttonMappings: [DeltaSkinButtonMapping]?

    @State private var leftStickPosition: CGPoint = .zero
    @State private var rightStickPosition: CGPoint = .zero

    public init(skin: any DeltaSkinProtocol, traits: DeltaSkinTraits, containerSize: CGSize) {
        self.skin = skin
        self.traits = traits
        self.containerSize = containerSize
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base skin image
                if let skinImage {
                    Image(uiImage: skinImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                        .opacity(0.9) // Make it slightly transparent to see the game screen
                } else if let loadingError = loadingError {
                    Text("Failed to load skin: \(loadingError.localizedDescription)")
                        .foregroundStyle(.red)
                } else {
                    ProgressView()
                }

                // Screen groups overlay
                if let groups = screenGroups {
                    ForEach(groups, id: \.id) { group in
                        screenGroup(group, in: geometry)
                    }
                }

                // Button mappings overlay
                if let mappings = buttonMappings {
                    ForEach(mappings, id: \.id) { mapping in
                        buttonMapping(mapping, in: geometry)
                    }
                }

                // Debug info
                if showDebug {
                    VStack {
                        HStack {
                            Spacer()
                            VStack(alignment: .leading) {
                                Text("Skin: \(skin.name)")
                                    .font(.caption)
                                Text("Device: \(traits.device.rawValue)")
                                    .font(.caption)
                                Text("Orientation: \(traits.orientation.rawValue)")
                                    .font(.caption)
                                if let buttonCount = buttonMappings?.count {
                                    Text("Buttons: \(buttonCount)")
                                        .font(.caption)
                                }
                            }
                            .padding(8)
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .padding()
                        }
                        Spacer()
                    }
                }
            }
            .onAppear {
                print("DeltaSkinScreensView appeared")
            }
            .task {
                // Load skin image
                do {
                    skinImage = try await skin.image(for: traits)
                    print("Loaded skin image: \(skinImage?.size ?? .zero)")
                } catch {
                    loadingError = error
                    print("Error loading skin image: \(error)")
                }

                // Load screen groups
                screenGroups = skin.screenGroups(for: traits)
                print("Loaded screen groups: \(screenGroups?.count ?? 0)")

                // Load button mappings
                buttonMappings = skin.buttonMappings(for: traits)
                print("Loaded button mappings: \(buttonMappings?.count ?? 0)")
            }
        }
    }

    @ViewBuilder
    private func screenGroup(_ group: DeltaSkinScreenGroup, in geometry: GeometryProxy) -> some View {
        ZStack {
            // Translucent background if needed
            if group.translucent ?? false {
                Rectangle()
                    .fill(.black.opacity(0.5))
            }

            // Screens in this group
            ForEach(group.screens, id: \.id) { screen in
                screenView(screen, in: geometry)
            }
        }
    }

    @ViewBuilder
    private func buttonMapping(_ mapping: DeltaSkinButtonMapping, in geometry: GeometryProxy) -> some View {
        if let frame = mapping.frame {
            if mapping.id.lowercased() == "dpad" {
                // Special handling for D-pad
                dpadMapping(frame: frame, in: geometry)
            } else if mapping.id.lowercased().contains("analog") || mapping.id.lowercased().contains("stick") {
                // Analog stick
                analogStickMapping(mapping: mapping, frame: frame, in: geometry)
            } else {
                // Regular button
                Button(action: {
                    // Do nothing here - we'll handle touch events in the gesture
                }) {
                    if showDebug {
                        // Show debug overlay for the button
                        Rectangle()
                            .stroke(Color.red, lineWidth: 2)
                            .background(Color.red.opacity(0.3))
                            .overlay(
                                Text(mapping.id)
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(4)
                            )
                    } else {
                        // Invisible button area in normal mode
                        Color.clear
                    }
                }
                .frame(
                    width: frame.width * geometry.size.width,
                    height: frame.height * geometry.size.height
                )
                .position(
                    x: frame.midX * geometry.size.width,
                    y: frame.midY * geometry.size.height
                )
                #if !os(tvOS)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            handleButtonPress(mapping.id)
                        }
                        .onEnded { _ in
                            handleButtonRelease(mapping.id)
                        }
                )
                #endif
                .accessibility(identifier: "Button-\(mapping.id)")
            }
        }
    }

    @ViewBuilder
    private func dpadMapping(frame: CGRect, in geometry: GeometryProxy) -> some View {
        // Create a view for the D-pad with regions for each direction
        ZStack {
            if showDebug {
                // Debug overlay for the entire D-pad
                Rectangle()
                    .stroke(Color.red, lineWidth: 2)
                    .background(Color.red.opacity(0.1))
                    .overlay(
                        Text("D-Pad")
                            .font(.caption)
                            .foregroundColor(.white)
                    )
            } else {
                Color.clear
            }

            // Up region
            Rectangle()
                .fill(showDebug ? Color.green.opacity(0.3) : Color.clear)
                .frame(
                    width: frame.width * geometry.size.width * 0.33,
                    height: frame.height * geometry.size.height * 0.33
                )
                .position(
                    x: frame.midX * geometry.size.width,
                    y: (frame.minY + frame.height * 0.16) * geometry.size.height
                )
#if !os(tvOS)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in handleButtonPress("up") }
                        .onEnded { _ in handleButtonRelease("up") }
                )
#endif
                .overlay(showDebug ? Text("Up").font(.caption2).foregroundColor(.white) : nil)

            // Down region
            Rectangle()
                .fill(showDebug ? Color.green.opacity(0.3) : Color.clear)
                .frame(
                    width: frame.width * geometry.size.width * 0.33,
                    height: frame.height * geometry.size.height * 0.33
                )
                .position(
                    x: frame.midX * geometry.size.width,
                    y: (frame.maxY - frame.height * 0.16) * geometry.size.height
                )
#if !os(tvOS)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in handleButtonPress("down") }
                        .onEnded { _ in handleButtonRelease("down") }
                )
#endif
                .overlay(showDebug ? Text("Down").font(.caption2).foregroundColor(.white) : nil)

            // Left region
            Rectangle()
                .fill(showDebug ? Color.green.opacity(0.3) : Color.clear)
                .frame(
                    width: frame.width * geometry.size.width * 0.33,
                    height: frame.height * geometry.size.height * 0.33
                )
                .position(
                    x: (frame.minX + frame.width * 0.16) * geometry.size.width,
                    y: frame.midY * geometry.size.height
                )
#if !os(tvOS)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in handleButtonPress("left") }
                        .onEnded { _ in handleButtonRelease("left") }
                )
#endif
                .overlay(showDebug ? Text("Left").font(.caption2).foregroundColor(.white) : nil)

            // Right region
            Rectangle()
                .fill(showDebug ? Color.green.opacity(0.3) : Color.clear)
                .frame(
                    width: frame.width * geometry.size.width * 0.33,
                    height: frame.height * geometry.size.height * 0.33
                )
                .position(
                    x: (frame.maxX - frame.width * 0.16) * geometry.size.width,
                    y: frame.midY * geometry.size.height
                )
#if !os(tvOS)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in handleButtonPress("right") }
                        .onEnded { _ in handleButtonRelease("right") }
                )
#endif
                .overlay(showDebug ? Text("Right").font(.caption2).foregroundColor(.white) : nil)
        }
        .frame(
            width: frame.width * geometry.size.width,
            height: frame.height * geometry.size.height
        )
        .position(
            x: frame.midX * geometry.size.width,
            y: frame.midY * geometry.size.height
        )
    }

    @ViewBuilder
    private func analogStickMapping(mapping: DeltaSkinButtonMapping, frame: CGRect, in geometry: GeometryProxy) -> some View {
        // Determine if this is left or right analog stick
        let isLeftStick = mapping.id.lowercased().contains("left")

        // Create a draggable analog stick
        ZStack {
            if showDebug {
                // Debug overlay
                Circle()
                    .stroke(Color.blue, lineWidth: 2)
                    .background(Color.blue.opacity(0.1))
            } else {
                Color.clear
            }

            // Stick handle
            Circle()
                .fill(showDebug ? Color.white.opacity(0.5) : Color.clear)
                .frame(
                    width: frame.width * geometry.size.width * 0.5,
                    height: frame.height * geometry.size.height * 0.5
                )
        }
        .frame(
            width: frame.width * geometry.size.width,
            height: frame.height * geometry.size.height
        )
        .position(
            x: frame.midX * geometry.size.width,
            y: frame.midY * geometry.size.height
        )
#if !os(tvOS)
        .gesture(
            DragGesture()
                .onChanged { value in
                    let position = normalizePosition(value.location, in: frame)
                    handleAnalogStick(position: position, isLeftStick: isLeftStick)
                }
                .onEnded { _ in
                    // Reset to center position
                    handleAnalogStick(position: .zero, isLeftStick: isLeftStick)
                }
        )
#endif
        .overlay(
            showDebug ?
                Text(isLeftStick ? "Left Analog" : "Right Analog")
                    .font(.caption2)
                    .foregroundColor(.white)
                : nil
        )
    }

    @ViewBuilder
    private func screenView(_ screen: DeltaSkinScreen, in geometry: GeometryProxy) -> some View {
        guard let outputFrame = screen.outputFrame else {
            return AnyView(EmptyView())
        }

        return AnyView(
            ZStack {
                // Screen frame - make it transparent to show the game screen underneath
                Rectangle()
                    .fill(Color.clear)
                    .frame(
                        width: (outputFrame.width ?? 1.0) * geometry.size.width,
                        height: (outputFrame.height ?? 1.0) * geometry.size.height
                    )
                    .overlay(
                        // Always show a border for debugging
                        Rectangle()
                            .stroke(Color.purple, lineWidth: 3)
                            .overlay(
                                showDebug ?
                                    VStack(alignment: .leading) {
                                        Text(screen.id)
                                            .font(.caption)
                                        if let inputFrame = screen.inputFrame {
                                            Text("In: \(formatRect(inputFrame))")
                                                .font(.caption2)
                                        }
                                        Text("Out: \(formatRect(outputFrame))")
                                            .font(.caption2)
                                        Text("Place: \(screen.placement.rawValue)")
                                            .font(.caption2)
                                    }
                                    .foregroundColor(.blue)
                                    .padding(4)
                                    .background(Color.white.opacity(0.8))
                                    .cornerRadius(4)
                                : nil
                            )
                    )
                    // Add a tag to help identify this view for debugging
                    .accessibility(identifier: "ScreenView-\(screen.id)")
            }
            .position(
                x: (outputFrame.midX ?? 0.5) * geometry.size.width,
                y: (outputFrame.midY ?? 0.5) * geometry.size.height
            )
        )
    }

    // Handle button press
    private func handleButtonPress(_ buttonId: String) {
        // Send button press to input handler
        inputHandler.buttonPressed(buttonId)
    }

    // Handle button release
    private func handleButtonRelease(_ buttonId: String) {
        // Send button release to input handler
        inputHandler.buttonReleased(buttonId)
    }

    // Update the analog stick handling
    private func handleAnalogStick(position: CGPoint, isLeftStick: Bool) {
        // Normalize position to -1...1 range
        let normalizedX = Float(position.x)
        let normalizedY = Float(position.y)

        // Clamp values to -1...1 range
        let clampedX = max(-1, min(1, normalizedX))
        let clampedY = max(-1, min(1, normalizedY))

        // Send the input to the handler
        let stickId = isLeftStick ? "analog_left" : "analog_right"
        inputHandler.analogStickMoved(stickId, x: clampedX, y: clampedY)
    }

    // Add a helper method to calculate normalized values
    private func normalizePosition(_ position: CGPoint, in frame: CGRect) -> CGPoint {
        // Convert position to center-relative coordinates (-1 to 1)
        let centerX = frame.midX
        let centerY = frame.midY
        let radius = min(frame.width, frame.height) / 2

        let relativeX = (position.x - centerX) / radius
        let relativeY = (position.y - centerY) / radius

        // Clamp to a circle with radius 1
        let length = sqrt(relativeX * relativeX + relativeY * relativeY)
        if length > 1 {
            return CGPoint(x: relativeX / length, y: relativeY / length)
        } else {
            return CGPoint(x: relativeX, y: relativeY)
        }
    }

    private func formatRect(_ rect: CGRect) -> String {
        String(format: "(%.1f, %.1f, %.1f, %.1f)",
               rect.origin.x, rect.origin.y,
               rect.size.width, rect.size.height)
    }
}
