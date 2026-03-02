//
//  ControllerSettingsView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/27/24.
//

import SwiftUI
import PVUIBase
import GameController
import PVThemes
import PVLibrary
import PVRealm
import MarkdownView
#if canImport(PVUI_IOS)
import PVUI_IOS
#endif
#if canImport(PVUI_TV)
import PVUI_TV
#endif

/// A SwiftUI view for managing controller assignments to players
struct ControllerSettingsView: View {
    /// Observed instance of the controller manager
    @ObservedObject private var controllerManager = PVControllerManager.shared
    /// Theme manager for consistent styling
    @ObservedObject private var themeManager = ThemeManager.shared
    /// State for tracking which player's action sheet is being shown
    @State private var selectedPlayer: Int?
    /// State for the action sheet presentation
    @State private var showingActionSheet = false
    /// Animation state for controller connection
    @State private var connectionAnimation = false
    /// Current window for iCade setup
    @State private var window: UIWindow?
    /// Controller selected for button remapping
    @State private var controllerForRemapping: GCController?
    /// Show button remapping view
    @State private var showRemappingView = false

    /// Keyboard mapping documentation
    private let keyboardMappingDocs = """
    # 🎮 Keyboard Controls

    ```
    ┌───────────────────────────────────┐
    │       KEYBOARD MAPPING GUIDE      │
    └───────────────────────────────────┘
    ```

    ## 🕹️ Main Controls

    | Key(s) | Function |
    |:------:|:---------|
    | `W A S D` | 🎮 D-Pad / Left Stick |
    | `↑ ← ↓ →` | 🎮 D-Pad / Right Stick |
    | `Space/Return` | 🔵 A Button |
    | `F/Esc` | 🔴 B Button |
    | `Q` | 🟡 X Button |
    | `E` | 🟢 Y Button |

    ## 🛡️ Shoulder Controls

    ```
    ┌───────┐ ╭─────────╮ ┌───┐
    │  Tab  │-│SHOULDERS│-│ R │  ◀── L1/R1
    │L-Shift│-│TRIGGERS │-│ V │  ◀── L2/R2
    └───────┘ ╰─────────╯ └───┘
    ```

    ## 🎯 Special Buttons

    | Button | Key | Description |
    |:------:|:---:|:-----------|
    | `~` | Tilde | 📱 Menu |
    | `1/U` | One/U | ⚙️ Options |
    | `X` | X | 🕹️ L3 (Left Stick) |
    | `C` | C | 🕹️ R3 (Right Stick) |

    ## 🎮 Right Stick Controls

    ```
    ╭───────────╮
    │     O     │  ◀── Up
    │  [ K L ]  │  ◀── Left/Right
    │     -     │  ◀── Down
    ╰───────────╯
    ```

    ## ⚡ Quick Actions

    | Key | Action |
    |:---:|:-------|
    | `/` | Select |
    | `R-Shift` | Start |

    > 💡 **Pro Tip**: Use the arrow keys for precise D-pad control and WASD for analog stick movement.

    ```
    ┌──────────────────────────────────────┐
    │ HAPPY GAMING! 👾 PRESS START TO PLAY │
    └──────────────────────────────────────┘
    ```
    """

    /// Helper to get player's controller
    private func controller(for player: Int) -> GCController? {
        controllerManager.controller(forPlayer: player)
    }

    /// Helper to find player number for a controller by checking player1-8 properties
    private func playerNumber(for controller: GCController) -> Int? {
        if controller == controllerManager.player1 { return 1 }
        if controller == controllerManager.player2 { return 2 }
        if controller == controllerManager.player3 { return 3 }
        if controller == controllerManager.player4 { return 4 }
        if controller == controllerManager.player5 { return 5 }
        if controller == controllerManager.player6 { return 6 }
        if controller == controllerManager.player7 { return 7 }
        if controller == controllerManager.player8 { return 8 }
        return nil
    }

    /// Helper to get controller name
    private func controllerName(_ controller: GCController?) -> String {
        controller?.vendorName ?? "None Selected"
    }

    /// Helper to determine if a player has a controller
    private func hasController(_ player: Int) -> Bool {
        controller(for: player) != nil
    }

    /// Helper to get appropriate icon for controller type
    private func controllerIcon(_ controller: GCController?) -> String {
        guard let controller = controller else { return "gamecontroller.fill.circle" }

        #if os(tvOS)
        if controller.microGamepad != nil { return "appletv.remote.gen4.fill" }
        #endif

        if controller.extendedGamepad != nil { return "gamecontroller.fill" }
        if controller.microGamepad != nil { return "gamecontroller" }

        return "gamecontroller.fill"
    }

    private var backgroundColor: Color {
        themeManager.currentPalette.tableViewBackgroundColor?.swiftUIColor ??
        themeManager.currentPalette.gameLibraryBackground.swiftUIColor
    }

    private var accentColor: Color {
        themeManager.currentPalette.defaultTintColor.swiftUIColor ?? .accentColor
    }

    var body: some View {
        List {
            Section {
                ForEach(1...8, id: \.self) { player in
                    Button(action: {
                        selectedPlayer = player
                        showingActionSheet = true
                    }) {
                        HStack(spacing: 16) {
                            // Player number with background
                            ZStack {
                                Circle()
                                    #if os(tvOS)
                                    .fill(hasController(player) ?
                                        LinearGradient(
                                            gradient: Gradient(colors: [RetroTheme.retroBlue, RetroTheme.retroPurple]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ) :
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.secondary.opacity(0.2), Color.secondary.opacity(0.1)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    #else
                                    .fill(hasController(player) ? accentColor : Color.secondary.opacity(0.2))
                                    #endif
                                    .frame(width: 36, height: 36)
                                Text("\(player)")
                                    .font(.headline)
                                    .foregroundColor(hasController(player) ? .white : .secondary)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Player \(player)")
                                    .font(.headline)
                                    #if os(tvOS)
                                    .foregroundColor(.white)
                                    #endif
                                Text(controllerName(controller(for: player)))
                                    .font(.subheadline)
                                    #if os(tvOS)
                                    .foregroundColor(hasController(player) ? RetroTheme.retroBlue : .secondary)
                                    #else
                                    .foregroundColor(.secondary)
                                    #endif
                            }

                            Spacer()

                            // Controller status icon
                            Image(systemName: controllerIcon(controller(for: player)))
                                .imageScale(.large)
                                #if os(tvOS)
                                .foregroundColor(hasController(player) ? RetroTheme.retroPink : .secondary)
                                #else
                                .foregroundColor(hasController(player) ? accentColor : .secondary)
                                #endif
                                .opacity(connectionAnimation && hasController(player) ? 0.5 : 1.0)
                                .animation(.easeInOut(duration: 1.0).repeatForever(), value: connectionAnimation)
                        }
                        .contentShape(Rectangle())
                        #if os(tvOS)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.3))
                        )
                        #endif
                    }
                    #if os(tvOS)
                    .buttonStyle(.card)
                    .retroThemedFocus(cornerRadius: 12)
                    #else
                    .buttonStyle(.plain)
                    #endif
                }
            } header: {
                HStack {
                    Image(systemName: "gamecontroller.fill")
                    Text("Controller Assignments")
                }
                .font(.headline)
                #if os(tvOS)
                .foregroundColor(.retroPink)
                #endif
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Controllers must be paired with device.")
                        .font(.footnote)
                        .foregroundColor(.secondary)

                    if controllerManager.controllers.isEmpty {
                        Text("No controllers detected")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Available controllers: \(controllerManager.controllers.count)")
                            .font(.footnote)
                            #if os(tvOS)
                            .foregroundColor(.retroBlue)
                            #else
                            .foregroundColor(accentColor)
                            #endif
                    }
                }
            }

            // Update the markdown view styling
//            if controllerManager.isKeyboardConnected {
                Section {
                    #if os(tvOS)
                    Button(action: {}) {
                        MarkdownView(text: keyboardMappingDocs)
                            .font(.custom("Menlo", size: 14), for: .body)
                            .font(.custom("Menlo", size: 24), for: .h1)
                            .font(.custom("Menlo", size: 20), for: .h2)
                            .font(.custom("Menlo", size: 16), for: .h3)
                            .font(.custom("Menlo", size: 14), for: .codeBlock)
                            .tint(accentColor)
                    }
                    .buttonStyle(.card)
                    .focusable()
                    #else
                    MarkdownView(text: keyboardMappingDocs)
                        .font(.custom("Menlo", size: 14), for: .body)
                        .font(.custom("Menlo", size: 24), for: .h1)
                        .font(.custom("Menlo", size: 20), for: .h2)
                        .font(.custom("Menlo", size: 16), for: .h3)
                        .font(.custom("Menlo", size: 14), for: .codeBlock)
                        .tint(accentColor)
                    #endif
            } header: {
                HStack {
                    Image(systemName: "keyboard")
                    Text("⌨️ Keyboard Controls")
                }
                .font(.headline)
                #if os(tvOS)
                .foregroundColor(.retroPink)
                #endif
            }
//            }

            /// Button Remapping Section
            if !controllerManager.controllers.isEmpty {
                Section {
                    ForEach(controllerManager.controllers, id: \.self) { controller in
                        NavigationLink(destination: ButtonRemappingView(controller: controller)) {
                            HStack(spacing: 16) {
                                Image(systemName: controllerIcon(controller))
                                    .imageScale(.large)
                                    .foregroundColor(accentColor)
                                    .frame(width: 30)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(controller.vendorName ?? "Unknown Controller")
                                        .font(.headline)
                                    Text("Remap buttons")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if let playerIndex = playerNumber(for: controller) {
                                    Text("P\(playerIndex)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.secondary.opacity(0.2))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                        Text("Button Remapping")
                    }
                    .font(.headline)
                    #if os(tvOS)
                    .foregroundColor(.retroPink)
                    #endif
                } footer: {
                    Text("Customize button mappings for each controller. Joy-Con controllers are automatically fixed.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
        #if os(tvOS)
        .listStyle(.plain)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black,
                    RetroTheme.retroPurple.opacity(0.1),
                    RetroTheme.retroPink.opacity(0.05)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        #else
//        .scrollContentBackground(.hidden)
        .listStyle(.insetGrouped)
        #endif
        .navigationTitle("Controller Settings")
        .confirmationDialog(
            "Select a controller for Player \(selectedPlayer ?? 0)",
            isPresented: $showingActionSheet,
            titleVisibility: .visible
        ) {
            // Show available controllers
            ForEach(controllerManager.controllers, id: \.self) { controller in
                Button(controllerDisplayName(for: controller)) {
                    if let player = selectedPlayer {
                        withAnimation {
                            controllerManager.setController(controller, toPlayer: player)
                        }
                    }
                }
            }

            // Not Playing option
            Button("Not Playing", role: .destructive) {
                if let player = selectedPlayer {
                    withAnimation {
                        controllerManager.setController(nil, toPlayer: player)
                    }
                }
            }

            Button("Cancel", role: .cancel) {
                selectedPlayer = nil
            }
        } message: {
            Text("or press a button on your iCade controller")
        }
        .onAppear {
            #if canImport(UIKit)
            // Start listening for iCade controllers
            controllerManager.listenForICadeControllers(window: window)
            #endif
            // Start connection animation
            withAnimation {
                connectionAnimation = true
            }
        }
        .onDisappear {
            #if canImport(UIKit)
            // Stop listening when view disappears
            controllerManager.stopListeningForICadeControllers()
            #endif
            connectionAnimation = false
        }
    }

    /// Helper to format controller display name with player assignment
    private func controllerDisplayName(for controller: GCController) -> String {
        var title = controller.vendorName ?? "Unknown Controller"

        // Add current player assignment if any
        if let playerIndex = playerNumber(for: controller) {
            title += " (Player \(playerIndex))"
        }

        return title
    }
}

/// View for remapping controller buttons
struct ButtonRemappingView: View {
    let controller: GCController
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var currentMappings: [ButtonIdentifier: ButtonIdentifier] = [:]
    @State private var selectedButton: ButtonIdentifier?
    @State private var showingDestinationPicker = false

    // Profile management
    @State private var activeProfileName: String?
    @State private var showSaveProfileAlert = false
    @State private var newProfileName = ""
    @State private var showSaveProfileError = false
    @State private var saveProfileErrorMessage = ""

    private var remappableController: PVRemappableController {
        getRemappableControllerWrapper(for: controller)
    }

    private var accentColor: Color {
        themeManager.currentPalette.defaultTintColor.swiftUIColor ?? .accentColor
    }

    /// Standard buttons to show for remapping
    private let standardButtons: [ButtonIdentifier] = [
        .buttonA, .buttonB, .buttonX, .buttonY,
        .leftShoulder, .rightShoulder,
        .leftTrigger, .rightTrigger,
        .dpadUp, .dpadDown, .dpadLeft, .dpadRight,
        .menu, .options
    ]

    var body: some View {
        List {
            // MARK: Profiles section
            Section {
                HStack {
                    Label("Active Profile", systemImage: "person.crop.rectangle")
                    Spacer()
                    Text(activeProfileName ?? "None")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                NavigationLink(destination: ControllerProfilesView(controller: controller)
                    .onDisappear { loadActiveProfileName() }
                ) {
                    Label("Manage Profiles", systemImage: "list.bullet.rectangle.portrait")
                        .foregroundColor(accentColor)
                }

                Button(action: { showSaveProfileAlert = true }) {
                    Label("Save Current Mappings\u{2026}", systemImage: "square.and.arrow.down")
                        .foregroundColor(accentColor)
                }
            } header: {
                Text("Profiles")
            } footer: {
                Text("Profiles let you save and switch between different button layouts.")
                    .font(.caption)
            }

            Section {
                ForEach(standardButtons, id: \.self) { button in
                    Button(action: {
                        selectedButton = button
                        showingDestinationPicker = true
                    }) {
                        HStack {
                            Text(buttonDisplayName(button))
                                .foregroundColor(.primary)
                            Spacer()
                            if let mappedTo = currentMappings[button] {
                                Text("→ \(buttonDisplayName(mappedTo))")
                                    .font(.subheadline)
                                    .foregroundColor(accentColor)
                            } else {
                                Text("Default")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                Text("Button Mappings")
            } footer: {
                Text("Tap a button to remap it. Select the button you want it to trigger.")
            }

            Section {
                Button(action: {
                    clearAllMappings()
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset All Mappings")
                    }
                    .foregroundColor(.red)
                }

                Button(action: {
                    swapABButtons()
                }) {
                    HStack {
                        Image(systemName: "arrow.left.arrow.right")
                        Text("Swap A ↔ B")
                    }
                    .foregroundColor(accentColor)
                }

                Button(action: {
                    swapXYButtons()
                }) {
                    HStack {
                        Image(systemName: "arrow.left.arrow.right")
                        Text("Swap X ↔ Y")
                    }
                    .foregroundColor(accentColor)
                }
            } header: {
                Text("Quick Actions")
            }
        }
        .navigationTitle(controller.vendorName ?? "Remap Buttons")
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            loadCurrentMappings()
            loadActiveProfileName()
        }
        .alert("Save Profile", isPresented: $showSaveProfileAlert) {
            TextField("Profile name", text: $newProfileName)
            Button("Save") {
                let name = newProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
                newProfileName = ""
                guard !name.isEmpty else { return }
                if remappableController.saveCurrentMappingsAsProfile(name: name, makeActive: true) != nil {
                    loadActiveProfileName()
                } else {
                    saveProfileErrorMessage = "No button mappings are configured. Remap at least one button before saving a profile."
                    showSaveProfileError = true
                }
            }
            Button("Cancel", role: .cancel) { newProfileName = "" }
        } message: {
            Text("Save your current button mappings as a named profile.")
        }
        .alert("Save Failed", isPresented: $showSaveProfileError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveProfileErrorMessage)
        }
        .confirmationDialog(
            "Map \(selectedButton.map { buttonDisplayName($0) } ?? "button") to:",
            isPresented: $showingDestinationPicker,
            titleVisibility: .visible
        ) {
            ForEach(standardButtons, id: \.self) { destination in
                Button(buttonDisplayName(destination)) {
                    if let source = selectedButton {
                        remapButton(source, to: destination)
                    }
                }
            }
            Button("Remove Mapping", role: .destructive) {
                if let source = selectedButton {
                    clearMapping(for: source)
                }
            }
            Button("Cancel", role: .cancel) {
                selectedButton = nil
            }
        }
    }

    /// Refresh the active profile name label from Realm.
    private func loadActiveProfileName() {
        guard let vendorName = controller.vendorName else { return }
        let db = RomDatabase.sharedInstance
        activeProfileName = db.activeControllerProfile(forVendor: vendorName)?.name
    }

    private func loadCurrentMappings() {
        var mappings: [ButtonIdentifier: ButtonIdentifier] = [:]
        for button in standardButtons {
            if let mapped = remappableController.mappedButton(for: button) {
                mappings[button] = mapped
            }
        }
        currentMappings = mappings
    }

    private func remapButton(_ source: ButtonIdentifier, to destination: ButtonIdentifier) {
        remappableController.remap(button: source, to: destination)
        remappableController.saveMappings()
        loadCurrentMappings()
    }

    private func clearMapping(for button: ButtonIdentifier) {
        remappableController.clearMapping(for: button)
        remappableController.saveMappings()
        loadCurrentMappings()
    }

    private func clearAllMappings() {
        remappableController.clearAllMappings()
        remappableController.saveMappings()
        loadCurrentMappings()
    }

    private func swapABButtons() {
        remappableController.swapButtons(.buttonA, .buttonB)
        remappableController.saveMappings()
        loadCurrentMappings()
    }

    private func swapXYButtons() {
        remappableController.swapButtons(.buttonX, .buttonY)
        remappableController.saveMappings()
        loadCurrentMappings()
    }

    private func buttonDisplayName(_ button: ButtonIdentifier) -> String {
        switch button {
        case .buttonA: return "A Button"
        case .buttonB: return "B Button"
        case .buttonX: return "X Button"
        case .buttonY: return "Y Button"
        case .leftShoulder: return "Left Shoulder (L1)"
        case .rightShoulder: return "Right Shoulder (R1)"
        case .leftTrigger: return "Left Trigger (L2)"
        case .rightTrigger: return "Right Trigger (R2)"
        case .dpadUp: return "D-Pad Up"
        case .dpadDown: return "D-Pad Down"
        case .dpadLeft: return "D-Pad Left"
        case .dpadRight: return "D-Pad Right"
        case .menu: return "Menu"
        case .options: return "Options"
        default: return button.rawValue
        }
    }
}

#if DEBUG
struct ControllerSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ControllerSettingsView()
        }
    }
}
#endif
