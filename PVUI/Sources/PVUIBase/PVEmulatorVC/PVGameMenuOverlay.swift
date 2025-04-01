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
    case main, states, options
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
            
            // P2 controls (if available)
            if let player2 = PVControllerManager.shared.player2 {
                if player2.extendedGamepad != nil || Defaults[.missingButtonsAlwaysOn] {
                    menuButton(title: "P2 CONTROLS", icon: "gamecontroller", color: .retroYellow) {
                        // Show P2 controls submenu
                        dismissAction()
                    }
                }
            }
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
}


