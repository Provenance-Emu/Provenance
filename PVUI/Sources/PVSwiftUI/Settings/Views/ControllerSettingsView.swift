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

    /// Keyboard mapping documentation
    private let keyboardMappingDocs = """
    ## Keyboard Controls

    The following keyboard controls are available when a keyboard is connected:

    ### Main Controls
    - **WASD**: D-Pad / Left Stick
    - **Arrow Keys**: D-Pad / Right Stick
    - **Space** or **Return**: A Button
    - **F** or **Escape**: B Button
    - **Q**: X Button
    - **E**: Y Button

    ### Shoulder Buttons
    - **Tab** or **Caps Lock**: L1 (Left Shoulder)
    - **Left Shift**: L2 (Left Trigger)
    - **R**: R1 (Right Shoulder)
    - **V**: R2 (Right Trigger)

    ### Special Buttons
    - **Tilde (~)**: Menu Button
    - **1** or **U**: Options Button
    - **X**: L3 (Left Stick Click)
    - **C**: R3 (Right Stick Click)

    ### Additional Controls
    - **[=]**: Right Stick Up
    - **-**: Right Stick Down
    - **[**: Right Stick Left
    - **]**: Right Stick Right

    ### Alternate Controls
    - **;**: Right Stick Left
    - **K**: Right Stick Left
    - **L**: Right Stick Down
    - **O**: Right Stick Up

    ### Special Functions
    - **/** (Forward Slash): Select Button
    - **Right Shift**: Start Button
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
        guard let controller = controller else { return "gamecontroller.fill.slash" }

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
        themeManager.currentPalette.defaultTintColor?.swiftUIColor ?? .accentColor
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
                                    .fill(hasController(player) ? accentColor : Color.secondary.opacity(0.2))
                                    .frame(width: 36, height: 36)
                                Text("\(player)")
                                    .font(.headline)
                                    .foregroundColor(hasController(player) ? .white : .secondary)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Player \(player)")
                                    .font(.headline)
                                Text(controllerName(controller(for: player)))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            // Controller status icon
                            Image(systemName: controllerIcon(controller(for: player)))
                                .imageScale(.large)
                                .foregroundColor(hasController(player) ? accentColor : .secondary)
                                .opacity(connectionAnimation && hasController(player) ? 0.5 : 1.0)
                                .animation(.easeInOut(duration: 1.0).repeatForever(), value: connectionAnimation)
                        }
                        .contentShape(Rectangle())
                    }
                    #if os(tvOS)
                    .buttonStyle(.card)
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
                            .foregroundColor(accentColor)
                    }
                }
            }

            // Add keyboard mapping documentation as a new section
//            if controllerManager.isKeyboardConnected {
                Section {
                    #if os(tvOS)
                    Button(action: {}) {
                        MarkdownView(text: keyboardMappingDocs)
                            .font(.system(size: 14, weight: .regular), for: .body)
                            .font(.system(size: 24, weight: .bold), for: .h2)
                            .font(.system(size: 18, weight: .semibold), for: .h3)
                            .tint(accentColor)
                    }
                    .buttonStyle(.card)
                    .focusable()
                    #else
                    MarkdownView(text: keyboardMappingDocs)
                        .font(.system(size: 14, weight: .regular), for: .body)
                        .font(.system(size: 24, weight: .bold), for: .h2)
                        .font(.system(size: 18, weight: .semibold), for: .h3)
                        .tint(accentColor)
                    #endif
                } header: {
                    HStack {
                        Image(systemName: "keyboard")
                        Text("Keyboard Controls")
                    }
                    .font(.headline)
                }
//            }
        }
        #if os(tvOS)
        .listStyle(.plain)
        .background(backgroundColor)
        #else
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

#if DEBUG
struct ControllerSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ControllerSettingsView()
        }
    }
}
#endif
