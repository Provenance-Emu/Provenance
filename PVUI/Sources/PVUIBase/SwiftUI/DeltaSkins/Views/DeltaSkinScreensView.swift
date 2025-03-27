import SwiftUI
import PVLogging

/// View that renders a DeltaSkin with its screens and buttons
public struct DeltaSkinScreensView: View {
    let skin: DeltaSkinProtocol
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

    public init(skin: DeltaSkinProtocol, traits: DeltaSkinTraits, containerSize: CGSize) {
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
        }
        .task {
            // Load skin image
            do {
                skinImage = try await skin.image(for: traits)
            } catch {
                loadingError = error
            }

            // Load screen groups
            screenGroups = skin.screenGroups(for: traits)

            // Load button mappings
            buttonMappings = skin.buttonMappings(for: traits)
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
                                    .font(.caption2)
                                    .foregroundColor(.white)
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
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            // Button pressed
                            handleButtonPress(mapping.id)
                        }
                        .onEnded { _ in
                            // Button released
                            handleButtonRelease(mapping.id)
                        }
                )
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
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in handleButtonPress("up") }
                        .onEnded { _ in handleButtonRelease("up") }
                )
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
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in handleButtonPress("down") }
                        .onEnded { _ in handleButtonRelease("down") }
                )
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
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in handleButtonPress("left") }
                        .onEnded { _ in handleButtonRelease("left") }
                )
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
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in handleButtonPress("right") }
                        .onEnded { _ in handleButtonRelease("right") }
                )
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
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    // Calculate normalized position (-1 to 1)
                    let centerX = frame.midX * geometry.size.width
                    let centerY = frame.midY * geometry.size.height
                    let radius = min(frame.width, frame.height) * 0.5 * geometry.size.width

                    var deltaX = (value.location.x - centerX) / radius
                    var deltaY = (value.location.y - centerY) / radius

                    // Clamp to unit circle
                    let length = sqrt(deltaX * deltaX + deltaY * deltaY)
                    if length > 1.0 {
                        deltaX /= length
                        deltaY /= length
                    }

                    // Send analog input
                    handleAnalogInput(
                        isLeftStick ? .analogLeft : .analogRight,
                        x: Float(deltaX),
                        y: Float(deltaY)
                    )
                }
                .onEnded { _ in
                    // Reset to center position
                    handleAnalogInput(
                        isLeftStick ? .analogLeft : .analogRight,
                        x: 0,
                        y: 0
                    )
                }
        )
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
                // Screen frame
                Rectangle()
                    .stroke(showDebug ? .blue : .clear, lineWidth: 2)
                    .frame(
                        width: outputFrame.width * geometry.size.width,
                        height: outputFrame.height * geometry.size.height
                    )

                // Debug info
                if showDebug {
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
                    .background(.white.opacity(0.8))
                    .cornerRadius(4)
                }
            }
            .position(
                x: outputFrame.midX * geometry.size.width,
                y: outputFrame.midY * geometry.size.height
            )
        )
    }

    // Handle button press
    private func handleButtonPress(_ buttonId: String) {
        // Map the button ID to a DeltaSkinButtonInput
        let button = mapButtonIdToButton(buttonId)
        let input = DeltaSkinButtonInput(button: button, isPressed: true)

        print("Button pressed: \(buttonId) -> \(button)")

        // Forward to the input handler
        inputHandler.handleButtonInput(input)
    }

    // Handle button release
    private func handleButtonRelease(_ buttonId: String) {
        // Map the button ID to a DeltaSkinButtonInput
        let button = mapButtonIdToButton(buttonId)
        let input = DeltaSkinButtonInput(button: button, isPressed: false)

        print("Button released: \(buttonId) -> \(button)")

        // Forward to the input handler
        inputHandler.handleButtonInput(input)
    }

    // Map button ID to button type
    private func mapButtonIdToButton(_ buttonId: String) -> DeltaSkinButtonInput.Button {
        switch buttonId.lowercased() {
        case "up", "dpad_up":
            return .dpadUp
        case "down", "dpad_down":
            return .dpadDown
        case "left", "dpad_left":
            return .dpadLeft
        case "right", "dpad_right":
            return .dpadRight
        case "a", "button_a":
            return .buttonA
        case "b", "button_b":
            return .buttonB
        case "x", "button_x":
            return .buttonX
        case "y", "button_y":
            return .buttonY
        case "l", "l1", "button_l", "button_l1":
            return .buttonL
        case "r", "r1", "button_r", "button_r1":
            return .buttonR
        case "l2", "button_l2":
            return .buttonL2
        case "r2", "button_r2":
            return .buttonR2
        case "start", "button_start":
            return .buttonStart
        case "select", "button_select":
            return .buttonSelect
        case "menu", "button_menu":
            return .custom("menu")
        case "togglefastforward", "fastforward":
            return .custom("toggleFastForward")
        default:
            return .custom(buttonId)
        }
    }

    // Handle analog input
    private func handleAnalogInput(_ stick: DeltaSkinButtonInput.Button, x: Float, y: Float) {
        let input = DeltaSkinButtonInput(
            button: stick,
            isPressed: true,
            x: x,
            y: y
        )

        print("Analog input: \(stick), x: \(x), y: \(y)")

        // Forward to the input handler
        inputHandler.handleButtonInput(input)
    }

    private func formatRect(_ rect: CGRect) -> String {
        String(format: "(%.1f, %.1f, %.1f, %.1f)",
               rect.origin.x, rect.origin.y,
               rect.size.width, rect.size.height)
    }
}
