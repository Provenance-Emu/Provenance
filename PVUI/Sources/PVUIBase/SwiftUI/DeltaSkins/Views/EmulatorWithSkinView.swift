import SwiftUI
import PVEmulatorCore
import PVLibrary
import PVUIBase
import PVPrimitives
import GameController

/// A view that combines the emulator screen with a DeltaSkin controller overlay
public struct EmulatorWithSkinView: View {
    let game: PVGame
    let coreInstance: PVEmulatorCore

    @State private var skinTraits: DeltaSkinTraits
    @State private var selectedSkin: DeltaSkinProtocol?
    @State private var isLoadingSkin = true
    @State private var skinError: Error?
    @State private var showSkinSelector = false

    @StateObject private var skinManager = DeltaSkinManager.shared

    public init(game: PVGame, coreInstance: PVEmulatorCore) {
        self.game = game
        self.coreInstance = coreInstance

        // Determine initial orientation based on device
        let orientation: DeltaSkinOrientation = UIDevice.current.orientation.isLandscape ? .landscape : .portrait

        // Initialize with default traits
        _skinTraits = State(initialValue: DeltaSkinTraits(
            device: UIDevice.current.userInterfaceIdiom == .pad ? .ipad : .iphone,
            displayType: .standard,
            orientation: orientation
        ))
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black.edgesIgnoringSafeArea(.all)

                if let skin = selectedSkin {
                    // Skin with emulator view
                    DeltaSkinWithEmulatorView(
                        skin: skin,
                        traits: skinTraits,
                        game: game,
                        coreInstance: coreInstance,
                        containerSize: geometry.size
                    )
                } else if isLoadingSkin {
                    // Loading indicator
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)

                        Text("Loading controller skin...")
                            .foregroundColor(.white)
                            .padding(.top)
                    }
                } else {
                    // Fallback to standard emulator view if no skin is available
                    VStack {
                        // Emulator view takes most of the space
                        EmulatorScreenView(game: game, coreInstance: coreInstance)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        // Controls at the bottom
                        fallbackControlsView
                    }
                }

                // Overlay buttons for skin management
                VStack {
                    HStack {
                        Spacer()

                        Button(action: {
                            showSkinSelector = true
                        }) {
                            Image(systemName: "gamecontroller")
                                .font(.system(size: 20))
                                .padding(12)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                                .foregroundColor(.white)
                        }
                        .padding()
                    }

                    Spacer()
                }
            }
            .onAppear {
                loadSkinForGame()
            }
            .onChange(of: UIDevice.current.orientation.isLandscape) { isLandscape in
                updateOrientation(isLandscape: isLandscape)
            }
            .sheet(isPresented: $showSkinSelector) {
                skinSelectorView
            }
        }
    }

    // Fallback controls when no skin is available
    private var fallbackControlsView: some View {
        VStack {
            Text("No controller skin available")
                .foregroundColor(.white)
                .padding(.bottom, 8)

            HStack(spacing: 20) {
                // D-Pad
                VStack {
                    Button(action: { sendInput(.up) }) {
                        Image(systemName: "arrow.up")
                            .padding()
                            .background(Color.gray.opacity(0.5))
                            .clipShape(Circle())
                    }

                    HStack {
                        Button(action: { sendInput(.left) }) {
                            Image(systemName: "arrow.left")
                                .padding()
                                .background(Color.gray.opacity(0.5))
                                .clipShape(Circle())
                        }

                        Spacer().frame(width: 50)

                        Button(action: { sendInput(.right) }) {
                            Image(systemName: "arrow.right")
                                .padding()
                                .background(Color.gray.opacity(0.5))
                                .clipShape(Circle())
                        }
                    }

                    Button(action: { sendInput(.down) }) {
                        Image(systemName: "arrow.down")
                            .padding()
                            .background(Color.gray.opacity(0.5))
                            .clipShape(Circle())
                    }
                }

                Spacer()

                // Action buttons
                VStack {
                    HStack {
                        Button(action: { sendInput(.y) }) {
                            Text("Y")
                                .font(.headline)
                                .padding()
                                .background(Color.yellow.opacity(0.7))
                                .clipShape(Circle())
                        }

                        Button(action: { sendInput(.x) }) {
                            Text("X")
                                .font(.headline)
                                .padding()
                                .background(Color.blue.opacity(0.7))
                                .clipShape(Circle())
                        }
                    }

                    HStack {
                        Button(action: { sendInput(.b) }) {
                            Text("B")
                                .font(.headline)
                                .padding()
                                .background(Color.red.opacity(0.7))
                                .clipShape(Circle())
                        }

                        Button(action: { sendInput(.a) }) {
                            Text("A")
                                .font(.headline)
                                .padding()
                                .background(Color.green.opacity(0.7))
                                .clipShape(Circle())
                        }
                    }
                }
            }

            // Start/Select buttons
            HStack(spacing: 50) {
                Button(action: { sendInput(.select) }) {
                    Text("Select")
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.7))
                        .cornerRadius(8)
                }

                Button(action: { sendInput(.start) }) {
                    Text("Start")
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.7))
                        .cornerRadius(8)
                }
            }
            .padding(.top)
            .padding(.bottom, 30)
        }
        .padding()
        .background(Color.black.opacity(0.8))
    }

    // Skin selector view
    private var skinSelectorView: some View {
        NavigationView {
            VStack {
                if let systemID = game.system?.identifier {
                    SystemSkinSelectionView(system: SystemIdentifier(rawValue: systemID) ?? .Unknown)
                } else {
                    Text("No system associated with this game")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Select Controller Skin")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showSkinSelector = false
                        loadSkinForGame() // Reload skin in case it changed
                    }
                }
            }
        }
    }

    // Load the appropriate skin for the current game
    private func loadSkinForGame() {
        guard let systemID = game.system?.identifier,
              let system = SystemIdentifier(rawValue: systemID) else {
            isLoadingSkin = false
            return
        }

        Task {
            isLoadingSkin = true

            do {
                // Try to get the selected skin for this system
                let skin = try await DeltaSkinManager.shared.skinToUse(for: system)

                await MainActor.run {
                    self.selectedSkin = skin
                    self.isLoadingSkin = false
                }
            } catch {
                await MainActor.run {
                    self.skinError = error
                    self.isLoadingSkin = false
                }
            }
        }
    }

    // Update orientation when device rotates
    private func updateOrientation(isLandscape: Bool) {
        skinTraits = DeltaSkinTraits(
            device: skinTraits.device,
            displayType: skinTraits.displayType,
            orientation: isLandscape ? .landscape : .portrait
        )
    }

    // Send input to the emulator core
    private func sendInput(_ input: EmulatorInput) {
        #if canImport(GameController)
        let controller = coreInstance.controller1?.extendedGamepad

        switch input {
        case .up:
            controller?.dpad.up.setValue(1.0)
        case .down:
            controller?.dpad.down.setValue(1.0)
        case .left:
            controller?.dpad.left.setValue(1.0)
        case .right:
            controller?.dpad.right.setValue(1.0)
        case .a:
            controller?.buttonA.setValue(1.0)
        case .b:
            controller?.buttonB.setValue(1.0)
        case .x:
            controller?.buttonX.setValue(1.0)
        case .y:
            controller?.buttonY.setValue(1.0)
        case .l:
            controller?.leftShoulder.setValue(1.0)
        case .r:
            controller?.rightShoulder.setValue(1.0)
        case .start:
            controller?.buttonMenu.setValue(1.0)
        case .select:
            controller?.buttonOptions?.setValue(1.0)
        }
        #endif
    }

    // Input types for the emulator
    enum EmulatorInput {
        case up, down, left, right
        case a, b, x, y
        case l, r
        case start, select
    }
}
