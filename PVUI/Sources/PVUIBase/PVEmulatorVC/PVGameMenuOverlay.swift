import UIKit
import SwiftUI
import PVCoreBridge
import PVLogging
import PVSettings
import GameController
import PVSupport
import PVLibrary

// Menu categories
enum MenuCategory {
    case main, states, options, skins
}

/// A custom menu overlay to replace UIAlertController for game menu options
class PVGameMenuOverlay: UIView {
    
    // MARK: - Properties
    
    weak var emulatorViewController: PVEmulatorViewController?
    private var hostingController: UIHostingController<RetroMenuView>?
    
    // MARK: - Initialization
    
    init(frame: CGRect, emulatorViewController: PVEmulatorViewController) {
        super.init(frame: frame)
        self.emulatorViewController = emulatorViewController
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    // MARK: - Setup
    
    private func setupView() {
        // Make background transparent - the SwiftUI view will handle the background
        backgroundColor = .clear
        
        guard let emulatorVC = emulatorViewController else { return }
        
        // Create the SwiftUI menu view
        let menuView = RetroMenuView(emulatorVC: emulatorVC) { [weak self] in
            self?.dismiss()
        }
        
        // Create and configure the hosting controller
        hostingController = UIHostingController(rootView: menuView)
        hostingController?.view.backgroundColor = .clear
        
        // Add the hosting view to our view hierarchy
        if let hostingView = hostingController?.view {
            addSubview(hostingView)
            hostingView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                hostingView.topAnchor.constraint(equalTo: topAnchor),
                hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
                hostingView.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        }
    }
    
    // MARK: - Actions
    
    @objc func dismiss() {
        DLOG("Dismissing custom game menu")
        
        // Find the view controller that contains this view
        var responder: UIResponder? = self
        while responder != nil && !(responder is UIViewController) {
            responder = responder?.next
        }
        
        // If we found a view controller, dismiss it
        if let viewController = responder as? UIViewController {
            viewController.dismiss(animated: true, completion: nil)
        } else {
            // Fallback if we can't find a view controller
            UIView.animate(withDuration: 0.3, animations: {
                self.alpha = 0
            }, completion: { _ in
                self.removeFromSuperview()
            })
        }
    }
    
    // This method is no longer needed since cleanup is handled by the view controller
    private func cleanup() {
        // Cleanup is now handled by PVEmulatorViewController's cleanupAfterMenuDismissal method
        // when the modal view controller is dismissed
    }
    
    // MARK: - Presentation
    
    // This method is now handled by the view controller presentation
    // but we'll keep it for backward compatibility
    func present(in viewController: UIViewController) {
        // Start with transparent view
        alpha = 0
        
        // Animate in
        UIView.animate(withDuration: 0.3) {
            self.alpha = 1
        }
    }
}



// MARK: - SwiftUI Menu Views

// Main menu view with retrowave styling
struct RetroMenuView: View {
    let emulatorVC: PVEmulatorViewController
    let dismissAction: () -> Void
    
    @State private var selectedCategory: MenuCategory = .main
    
    var body: some View {
        ZStack {
            // Background with retrowave styling
            Color.clear
                .modifier(RetrowaveBackgroundModifier())
                .ignoresSafeArea()
                .onTapGesture {
                    dismissAction()
                }
            
            // Menu container
            VStack(spacing: 0) {
                // Title with neon glow effect
                Text("GAME OPTIONS")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.retroPink)
                    .padding(.top, 24)
                    .padding(.bottom, 16)
                    .shadow(color: .retroPink.opacity(0.8), radius: 10, x: 0, y: 0)
                
                // Category selector
                HStack(spacing: 16) {
                    Button(action: { selectedCategory = .main }) {
                        Text("MAIN")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(selectedCategory == .main ? .white : .white.opacity(0.6))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedCategory == .main ? Color.retroPurple.opacity(0.6) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(selectedCategory == .main ? Color.retroPink : Color.white.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: { selectedCategory = .states }) {
                        Text("STATES")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(selectedCategory == .states ? .white : .white.opacity(0.6))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedCategory == .states ? Color.retroPurple.opacity(0.6) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(selectedCategory == .states ? Color.retroPink : Color.white.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: { selectedCategory = .options }) {
                        Text("OPTIONS")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(selectedCategory == .options ? .white : .white.opacity(0.6))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedCategory == .options ? Color.retroPurple.opacity(0.6) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(selectedCategory == .options ? Color.retroPink : Color.white.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: { selectedCategory = .skins }) {
                        Text("SKINS")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(selectedCategory == .skins ? .white : .white.opacity(0.6))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedCategory == .skins ? Color.retroPurple.opacity(0.6) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(selectedCategory == .skins ? Color.retroPink : Color.white.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
                
                // Menu content based on selected category
                ScrollView {
                    VStack(spacing: 12) {
                        switch selectedCategory {
                        case .main:
                            mainMenuButtons
                        case .states:
                            stateMenuButtons
                        case .options:
                            optionsMenuButtons
                        case .skins:
                            skinsMenuButtons
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
                .frame(maxWidth: 320)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.retroBlack.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color.retroNeon, lineWidth: 2)
                    )
            )
            .frame(maxWidth: 320, maxHeight: 500)
        }
    }
    
    // Main menu buttons
    private var mainMenuButtons: some View {
        VStack(spacing: 12) {
            // Resume game button
            menuButton(title: "RESUME GAME", icon: "play.fill", color: .retroBlue) {
                dismissAction()
            }
            
            // Reset game button
            menuButton(title: "RESET GAME", icon: "arrow.counterclockwise", color: .retroOrange) {
                dismissAction()
                emulatorVC.core.resetEmulation()
            }
            
            // Game info button
            menuButton(title: "GAME INFO", icon: "info.circle", color: .retroPurple) {
                dismissAction()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    emulatorVC.showMoreInfo()
                }
            }
            
            // Quit game button
            menuButton(title: "QUIT GAME", icon: "xmark.circle", color: .retroPink) {
                dismissAction()
                Task {
                    await emulatorVC.quit()
                }
            }
        }
    }
    
    // Save state related buttons
    private var stateMenuButtons: some View {
        VStack(spacing: 12) {
            if emulatorVC.core.supportsSaveStates {
                // Save state button
                menuButton(title: "SAVE STATE", icon: "square.and.arrow.down", color: .retroBlue) {
                    dismissAction()
                    Task {
                        let screenshot = emulatorVC.captureScreenshot()
                        do {
                            try await emulatorVC.createNewSaveState(auto: false, screenshot: screenshot)
                        } catch {
                            ELOG("Failed to save state: \(error.localizedDescription)")
                        }
                    }
                }
                
                // Load state button
                menuButton(title: "LOAD STATE", icon: "square.and.arrow.up", color: .retroPurple) {
                    dismissAction()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        emulatorVC.showSaveStateMenu()
                    }
                }
                
                // Save states menu button
                menuButton(title: "SAVE STATES", icon: "list.bullet", color: .retroYellow) {
                    dismissAction()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        emulatorVC.showSaveStateMenu()
                    }
                }
            } else {
                Text("Save states not supported")
                    .foregroundColor(.gray)
                    .padding()
            }
            
            // Screenshot button
#if os(iOS) || targetEnvironment(macCatalyst)
            menuButton(title: "SAVE SCREENSHOT", icon: "camera", color: .retroOrange) {
                dismissAction()
                emulatorVC.takeScreenshot()
            }
#endif
        }
    }
    
    // Options related buttons
    private var optionsMenuButtons: some View {
        VStack(spacing: 12) {
            // Game speed button
            menuButton(title: "GAME SPEED", icon: "speedometer", color: .retroBlue) {
                dismissAction()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    emulatorVC.showSpeedMenu()
                }
            }
            
            // Core options button (if available)
            if emulatorVC.core is CoreOptional {
                menuButton(title: "CORE OPTIONS", icon: "gearshape", color: .retroPurple) {
                    dismissAction()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        emulatorVC.showCoreOptions()
                    }
                }
            }
            
            // Cheat codes button (if supported)
            if let gameWithCheat = emulatorVC.core as? GameWithCheat, gameWithCheat.supportsCheatCode {
                menuButton(title: "CHEAT CODES", icon: "wand.and.stars", color: .retroPink) {
                    dismissAction()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        emulatorVC.showCheatsMenu()
                    }
                }
            }
            
            let wantsStartSelectInMenu: Bool = PVEmulatorConfiguration.systemIDWantsStartAndSelectInMenu(emulatorVC.game.system?.identifier ?? SystemIdentifier.RetroArch.rawValue)
            
            if let player1 = PVControllerManager.shared.player1 {
#if os(iOS)
                if Defaults[.missingButtonsAlwaysOn] || (player1.extendedGamepad != nil || wantsStartSelectInMenu) {
                    menuButton(title: "P1 CONTROLS", icon: "gamecontroller", color: .retroYellow) {
                        // Show P1 controls submenu
                        dismissAction()
                    }
                }
#else
                if player1.extendedGamepad != nil || wantsStartSelectInMenu {
                    menuButton(title: "P1 CONTROLS", icon: "gamecontroller", color: .retroYellow) {
                        // Show P1 controls submenu
                        dismissAction()
                    }
                }
#endif
                
            }
            
            
            // P2 controls (if available)
            if let player2 = PVControllerManager.shared.player2 {
                if player2.extendedGamepad != nil || wantsStartSelectInMenu {
                    menuButton(title: "P2 CONTROLS", icon: "gamecontroller", color: .retroYellow) {
                        // Show P2 controls submenu
                        dismissAction()
                    }
                }
            }
            
            // Core action buttons (if available)
            if let actionableCore = emulatorVC.core as? CoreActions, let actions = actionableCore.coreActions {
                ForEach(actions) { coreAction in
                    menuButton(title: coreAction.title, icon: "bolt", color: .retroOrange) {
                        dismissAction()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            actionableCore.selected(action: coreAction)
                            self.emulatorVC.core.setPauseEmulation(false)
                            if coreAction.requiresReset {
                                self.emulatorVC.core.resetEmulation()
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Skins and filters related buttons
    @State private var selectedSkin: String = "Default"
    @State private var selectedFilter: String = "None"
    @State private var availableSkins: [String] = ["Default"]
    @State private var showingSkinPicker = false
    @State private var showingFilterPicker = false
    
    private var skinsMenuButtons: some View {
        VStack(spacing: 12) {
            // Current skin selection
            VStack(alignment: .leading, spacing: 4) {
                Text("CURRENT SKIN")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gray)
                
                Button(action: {
                    // Show skin picker
                    showingSkinPicker = true
                }) {
                    HStack {
                        Text(selectedSkin)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.retroBlue)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.retroBlack.opacity(0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.retroBlue, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .sheet(isPresented: $showingSkinPicker) {
                    skinPickerView
                }
            }
            
            // Screen filter selection
            VStack(alignment: .leading, spacing: 4) {
                Text("SCREEN FILTER")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gray)
                
                Button(action: {
                    // Show filter picker
                    showingFilterPicker = true
                }) {
                    HStack {
                        Text(selectedFilter)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.retroPink)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.retroBlack.opacity(0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.retroPink, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .sheet(isPresented: $showingFilterPicker) {
                    filterPickerView
                }
            }
            
            // Apply button
            menuButton(title: "APPLY CHANGES", icon: "checkmark.circle", color: .retroBlue) {
                dismissAction()
                // Apply the selected skin and filter
                Task {
                    await applySkinAndFilterChanges()
                }
            }
        }
    }
    
    // Skin picker sheet view
    private var skinPickerView: some View {
        NavigationView {
            List {
                ForEach(availableSkins, id: \.self) { skin in
                    Button(action: {
                        selectedSkin = skin
                        showingSkinPicker = false
                    }) {
                        HStack {
                            Text(skin)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            if skin == selectedSkin {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.retroBlue)
                            }
                        }
                    }
                    .listRowBackground(Color.retroBlack.opacity(0.8))
                }
            }
            .listStyle(InsetGroupedListStyle())
            .background(Color.black)
            .navigationTitle("Select Skin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingSkinPicker = false
                    }
                }
            }
            .onAppear {
                // Load available skins
                Task {
                    await loadAvailableSkins()
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // Filter picker sheet view
    private var filterPickerView: some View {
        NavigationView {
            List {
                // Standard filter options
                ForEach(["None", "CRT", "LCD", "Scanlines", "Game Boy", "GBA"], id: \.self) { filter in
                    Button(action: {
                        selectedFilter = filter
                        showingFilterPicker = false
                    }) {
                        HStack {
                            Text(filter)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            if filter == selectedFilter {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.retroPink)
                            }
                        }
                    }
                    .listRowBackground(Color.retroBlack.opacity(0.8))
                }
            }
            .listStyle(InsetGroupedListStyle())
            .background(Color.black)
            .navigationTitle("Select Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingFilterPicker = false
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // Load available skins for the current system
    private func loadAvailableSkins() async {
        guard let systemId = emulatorVC.game.system?.systemIdentifier else { return }
        
        do {
            // Get skins from DeltaSkinManager
            let skins = try await DeltaSkinManager.shared.skins(for: systemId)
            
            // Update the available skins list on the main thread
            await MainActor.run {
                // Always include Default as the first option
                var skinNames = ["Default"]
                
                // Add names of available skins
                skinNames.append(contentsOf: skins.map { $0.name })
                
                // Update state
                self.availableSkins = skinNames
                
                // Set current selection if not already set
                if self.selectedSkin == "Default" && !skins.isEmpty {
                    // Try to find the currently selected skin
                    Task {
                        if let selectedSkin = try? await DeltaSkinManager.shared.selectedSkin(for: systemId) {
                            await MainActor.run {
                                self.selectedSkin = selectedSkin.name
                            }
                        }
                    }
                }
            }
        } catch {
            print("Error loading skins: \(error)")
        }
    }
    
    // Apply the selected skin and filter changes
    private func applySkinAndFilterChanges() async {
        guard let systemId = emulatorVC.game.system?.systemIdentifier else { return }
        
        // Apply skin change
        if selectedSkin != "Default" {
            do {
                // Find the selected skin
                let skins = try await DeltaSkinManager.shared.skins(for: systemId)
                if let skin = skins.first(where: { $0.name == selectedSkin }) {
                    // Apply the skin by recreating the skin view
                    // This is a simplified approach - in a real implementation, you would
                    // need to properly handle the skin application through the emulator view controller
                    Task { @MainActor in
                        // Store the selected skin in preferences
                        DeltaSkinPreferences.shared.setSelectedSkin(skin.identifier, for: systemId)
                        
                        // Notify the emulator to refresh its skin
                        NotificationCenter.default.post(
                            name: NSNotification.Name("RefreshDeltaSkin"),
                            object: nil,
                            userInfo: ["systemId": systemId.rawValue]
                        )
                    }
                }
            } catch {
                print("Error applying skin: \(error)")
            }
        } else {
            // Apply default skin (or remove custom skin)
            // This would need implementation in DeltaSkinManager
        }
        
        // Apply filter change
        switch selectedFilter {
        case "None":
            // Remove any filter
            emulatorVC.applyScreenFilter(nil)
        case "CRT":
            // Apply CRT filter (pixellated look)
            // Create a filter info dictionary with the proper parameters
            let filterParams: [String: Any] = ["inputScale": 8.0]
            let filterInfo = createFilterInfo(name: "CIPixellate", parameters: filterParams)
            if let filter = DeltaSkinScreenFilter(filterInfo: filterInfo) {
                emulatorVC.applyScreenFilter(filter)
            }
        case "LCD":
            // Apply LCD filter (slight blur)
            // Create a filter info dictionary with the proper parameters
            let filterParams: [String: Any] = ["inputRadius": 2.0]
            let filterInfo = createFilterInfo(name: "CIGaussianBlur", parameters: filterParams)
            if let filter = DeltaSkinScreenFilter(filterInfo: filterInfo) {
                emulatorVC.applyScreenFilter(filter)
            }
        case "Scanlines":
            // Apply scanlines filter
            // Create a filter info dictionary with the proper parameters
            let filterParams: [String: Any] = [
                "inputWidth": 2.0,
                "inputSharpness": 0.7,
                "inputAngle": 0.0
            ]
            let filterInfo = createFilterInfo(name: "CILineScreen", parameters: filterParams)
            if let filter = DeltaSkinScreenFilter(filterInfo: filterInfo) {
                emulatorVC.applyScreenFilter(filter)
            }
        case "Game Boy":
            // Apply Game Boy filter (green tint)
            // Create a filter info dictionary with the proper parameters
            let filterParams: [String: Any] = [
                "inputColor0": CIColor(red: 0.0, green: 0.3, blue: 0.0),
                "inputColor1": CIColor(red: 0.2, green: 0.8, blue: 0.2)
            ]
            let filterInfo = createFilterInfo(name: "CIFalseColor", parameters: filterParams)
            if let filter = DeltaSkinScreenFilter(filterInfo: filterInfo) {
                emulatorVC.applyScreenFilter(filter)
            }
        case "GBA":
            // Apply GBA filter (slight color adjustment)
            // Create a filter info dictionary with the proper parameters
            let filterParams: [String: Any] = [
                "inputSaturation": 1.2,
                "inputBrightness": 0.1,
                "inputContrast": 1.1
            ]
            let filterInfo = createFilterInfo(name: "CIColorControls", parameters: filterParams)
            if let filter = DeltaSkinScreenFilter(filterInfo: filterInfo) {
                emulatorVC.applyScreenFilter(filter)
            }
        default:
            break
        }
    }
    
    // Helper function to create menu buttons
    private func menuButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(color)
                    .frame(width: 30)
                
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.retroBlack.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(color, lineWidth: 2)
                    )
            )
            .shadow(color: color.opacity(0.5), radius: 5, x: 0, y: 0)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // Helper method to create a FilterInfo object from parameters
   private func createFilterInfo(name: String, parameters: [String: Any]) -> DeltaSkin.FilterInfo {
       // Convert the parameters to the format expected by DeltaSkinScreenFilter
       var filterParameters: [String: FilterParameter] = [:]
       
       for (key, value) in parameters {
           if let numberValue = value as? Float {
               filterParameters[key] = .number(numberValue)
           } else if let numberValue = value as? Double {
               filterParameters[key] = .number(Float(numberValue))
           } else if let numberValue = value as? Int {
               filterParameters[key] = .number(Float(numberValue))
           } else if let colorValue = value as? CIColor {
               filterParameters[key] = .color(r: Float(colorValue.red), g: Float(colorValue.green), b: Float(colorValue.blue))
           } else if let vectorValue = value as? CGPoint {
               filterParameters[key] = .vector(x: Float(vectorValue.x), y: Float(vectorValue.y))
           }
       }
       
       return DeltaSkin.FilterInfo(name: name, parameters: filterParameters)
   }
}
