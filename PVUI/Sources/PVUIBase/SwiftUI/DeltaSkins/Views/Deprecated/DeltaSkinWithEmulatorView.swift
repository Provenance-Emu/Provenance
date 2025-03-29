import SwiftUI
import PVEmulatorCore
import PVLibrary
import PVUIBase
import PVPrimitives
import PVCoreBridge
import GameController

/// A view that positions the emulator screen within a DeltaSkin and handles button inputs
public struct DeltaSkinWithEmulatorView: View {
    let skin: DeltaSkinProtocol
    let traits: DeltaSkinTraits
    let game: PVGame
    let coreInstance: PVEmulatorCore
    let containerSize: CGSize

    @State private var skinImage: UIImage?
    @State private var isLoadingSkin = true

    // Define button constants
    private enum EmulatorButton: Int {
        case up = 1
        case down = 2
        case left = 3
        case right = 4
        case a = 5
        case b = 6
        case x = 7
        case y = 8
        case l = 9
        case r = 10
        case l2 = 11
        case r2 = 12
        case start = 13
        case select = 14
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background skin image
                if let skinImage = skinImage {
                    Image(uiImage: skinImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Emulator screen positioned according to skin's screen frame
                if let screenFrame = calculateScreenFrame() {
                    EmulatorScreenView(game: game, coreInstance: coreInstance)
                        .frame(
                            width: screenFrame.width,
                            height: screenFrame.height
                        )
                        .position(
                            x: screenFrame.midX,
                            y: screenFrame.midY
                        )
                        .clipped()
                }

                // Interactive buttons
                if let buttons = skin.buttons(for: traits),
                   let mappingSize = skin.mappingSize(for: traits) {
                    ForEach(buttons, id: \.id) { button in
                        buttonOverlay(for: button, mappingSize: mappingSize, containerSize: geometry.size)
                    }
                }

                // Loading indicator
                if isLoadingSkin {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.3))
                }
            }
            .onAppear {
                loadSkinImage()
            }
        }
    }

    // Calculate the screen frame based on the skin's configuration
    private func calculateScreenFrame() -> CGRect? {
        guard let mappingSize = skin.mappingSize(for: traits) else {
            return nil
        }

        // Scale factors for the container
        let scale = min(
            containerSize.width / mappingSize.width,
            containerSize.height / mappingSize.height
        )

        // Check if the skin has screen information
        if let screens = skin.screens(for: traits),
           let mainScreen = screens.first(where: { $0.placement == .controller }),
           let outputFrame = mainScreen.outputFrame {

            // Scale the output frame to the container size
            return CGRect(
                x: outputFrame.minX * containerSize.width,
                y: outputFrame.minY * containerSize.height,
                width: outputFrame.width * containerSize.width,
                height: outputFrame.height * containerSize.height
            )
        } else if let screenGroups = skin.screenGroups(for: traits),
                  let mainGroup = screenGroups.first,
                  let mainScreen = mainGroup.screens.first(where: { $0.placement == .controller }),
                  let outputFrame = mainScreen.outputFrame {

            // Scale the output frame to the container size
            return CGRect(
                x: outputFrame.minX * containerSize.width,
                y: outputFrame.minY * containerSize.height,
                width: outputFrame.width * containerSize.width,
                height: outputFrame.height * containerSize.height
            )
        } else {
            // Use default screen frame based on game system
            guard let systemID = game.system?.identifier,
                  let system = SystemIdentifier(rawValue: systemID),
                  let gameType = DeltaSkinGameType(systemIdentifier: system) else {
                return nil
            }

            // Get default screen frame for this game type
            let defaultFrame = DeltaSkinDefaults.defaultScreenFrame(
                for: gameType,
                in: mappingSize
            )

            // Scale the default frame to the container size
            return CGRect(
                x: defaultFrame.minX * scale,
                y: defaultFrame.minY * scale,
                width: defaultFrame.width * scale,
                height: defaultFrame.height * scale
            )
        }
    }

    // Create an interactive button overlay
    private func buttonOverlay(for button: DeltaSkinButton, mappingSize: CGSize, containerSize: CGSize) -> some View {
        let scaledFrame = CGRect(
            x: button.frame.minX * containerSize.width,
            y: button.frame.minY * containerSize.height,
            width: button.frame.width * containerSize.width,
            height: button.frame.height * containerSize.height
        )

        return Rectangle()
            .fill(Color.clear)
            .frame(
                width: scaledFrame.width,
                height: scaledFrame.height
            )
            .position(
                x: scaledFrame.midX,
                y: scaledFrame.midY
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        handleButtonPress(button)
                    }
                    .onEnded { _ in
                        handleButtonRelease(button)
                    }
            )
    }

    // Handle button press events
    private func handleButtonPress(_ button: DeltaSkinButton) {
        switch button.input {
        case .single(let input):
            sendInput(input)
        case .directional(let mapping):
            // For directional inputs, we'd need to determine direction
            // For now, just use the first mapping
            if let firstInput = mapping.values.first {
                sendInput(firstInput)
            }
        }
    }

    // Handle button release events
    private func handleButtonRelease(_ button: DeltaSkinButton) {
        switch button.input {
        case .single(let input):
            releaseInput(input)
        case .directional(let mapping):
            if let firstInput = mapping.values.first {
                releaseInput(firstInput)
            }
        }
    }

    // Send input to the emulator core
    private func sendInput(_ input: String) {
        #if canImport(GameController)
        let controller = coreInstance.controller1?.extendedGamepad

        switch input.lowercased() {
        case "up":
            controller?.dpad.up.setValue(1.0)
        case "down":
            controller?.dpad.down.setValue(1.0)
        case "left":
            controller?.dpad.left.setValue(1.0)
        case "right":
            controller?.dpad.right.setValue(1.0)
        case "a":
            controller?.buttonA.setValue(1.0)
        case "b":
            controller?.buttonB.setValue(1.0)
        case "x":
            controller?.buttonX.setValue(1.0)
        case "y":
            controller?.buttonY.setValue(1.0)
        case "l", "l1":
            controller?.leftShoulder.setValue(1.0)
        case "r", "r1":
            controller?.rightShoulder.setValue(1.0)
        case "l2":
            controller?.leftTrigger.setValue(1.0)
        case "r2":
            controller?.rightTrigger.setValue(1.0)
        case "start":
            controller?.buttonMenu.setValue(1.0)
        case "select":
            controller?.buttonOptions?.setValue(1.0)
        default:
            print("Unknown input: \(input)")
        }
        #endif
    }

    // Release input on the emulator core
    private func releaseInput(_ input: String) {
        #if canImport(GameController)
        let controller = coreInstance.controller1?.extendedGamepad

        switch input.lowercased() {
        case "up":
            controller?.dpad.up.setValue(0.0)
        case "down":
            controller?.dpad.down.setValue(0.0)
        case "left":
            controller?.dpad.left.setValue(0.0)
        case "right":
            controller?.dpad.right.setValue(0.0)
        case "a":
            controller?.buttonA.setValue(0.0)
        case "b":
            controller?.buttonB.setValue(0.0)
        case "x":
            controller?.buttonX.setValue(0.0)
        case "y":
            controller?.buttonY.setValue(0.0)
        case "l", "l1":
            controller?.leftShoulder.setValue(0.0)
        case "r", "r1":
            controller?.rightShoulder.setValue(0.0)
        case "l2":
            controller?.leftTrigger.setValue(0.0)
        case "r2":
            controller?.rightTrigger.setValue(0.0)
        case "start":
            controller?.buttonMenu.setValue(0.0)
        case "select":
            controller?.buttonOptions?.setValue(0.0)
        default:
            print("Unknown input to release: \(input)")
        }
        #endif
    }

    // Load the skin image
    private func loadSkinImage() {
        Task {
            do {
                let image = try await skin.image(for: traits)

                await MainActor.run {
                    self.skinImage = image
                    self.isLoadingSkin = false
                }
            } catch {
                print("Error loading skin image: \(error)")
                await MainActor.run {
                    self.isLoadingSkin = false
                }
            }
        }
    }
}
