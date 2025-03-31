import UIKit
import PVCoreBridge
import PVLogging
import PVSettings
import GameController
import PVSupport
import PVLibrary

/// A custom menu overlay to replace UIAlertController for game menu options
class PVGameMenuOverlay: UIView {
    
    // MARK: - Properties
    
    weak var emulatorViewController: PVEmulatorViewController?
    private var buttons: [UIButton] = []
    private var containerView: UIView!
    
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
        // Semi-transparent background
        backgroundColor = UIColor.black.withAlphaComponent(0.7)
        
        // Add tap gesture to dismiss when tapping outside the menu
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleBackgroundTap(_:)))
        tapGesture.delegate = self
        addGestureRecognizer(tapGesture)
        
        // Create container for menu items
        setupContainer()
        
        // Add menu items
        setupMenuItems()
    }
    
    private func setupContainer() {
        // Create container view for menu items
        containerView = UIView()
        containerView.backgroundColor = UIColor(white: 0.2, alpha: 0.9)
        containerView.layer.cornerRadius = 16
        containerView.layer.masksToBounds = true
        
        // Add container to view
        addSubview(containerView)
        
        // Position container in center
        containerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 280),
            containerView.heightAnchor.constraint(lessThanOrEqualToConstant: 500)
        ])
        
        // Add title
        let titleLabel = UILabel()
        titleLabel.text = "Game Options"
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.boldSystemFont(ofSize: 20)
        
        containerView.addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16)
        ])
    }
    
    private func setupMenuItems() {
        guard let emulatorVC = emulatorViewController else { return }
        
        // Create a stack view for buttons
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        
        containerView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 70),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20)
        ])
        
        // Add menu buttons
        
        // Player 2 controls (if available)
        if let player2 = PVControllerManager.shared.player2 {
            if player2.extendedGamepad != nil || Defaults[.missingButtonsAlwaysOn] {
                // P2 Start
                let p2StartButton = createMenuButton(title: "P2 Start", action: #selector(handleP2Start))
                stackView.addArrangedSubview(p2StartButton)
                buttons.append(p2StartButton)
                
                // P2 Select
                let p2SelectButton = createMenuButton(title: "P2 Select", action: #selector(handleP2Select))
                stackView.addArrangedSubview(p2SelectButton)
                buttons.append(p2SelectButton)
                
                // P2 Analog Mode
                let p2AnalogButton = createMenuButton(title: "P2 Analog Mode", action: #selector(handleP2AnalogMode))
                stackView.addArrangedSubview(p2AnalogButton)
                buttons.append(p2AnalogButton)
            }
        }
        
        // Swap Disc (if available)
        if let swappableCore = emulatorVC.core as? DiscSwappable, swappableCore.currentGameSupportsMultipleDiscs {
            let swapDiscButton = createMenuButton(title: "Swap Disc", action: #selector(handleSwapDisc))
            stackView.addArrangedSubview(swapDiscButton)
            buttons.append(swapDiscButton)
        }
        
        // Core Actions (if available)
        if let actionableCore = emulatorVC.core as? CoreActions, let actions = actionableCore.coreActions {
            for coreAction in actions {
                let actionButton = createMenuButton(title: coreAction.title, action: #selector(handleCoreAction(_:)))
                actionButton.tag = buttons.count // Use tag to identify which action to trigger
                stackView.addArrangedSubview(actionButton)
                buttons.append(actionButton)
            }
        }
        
        // Save Screenshot
        #if os(iOS) || targetEnvironment(macCatalyst)
        let screenshotButton = createMenuButton(title: "Save Screenshot", action: #selector(handleScreenshot))
        stackView.addArrangedSubview(screenshotButton)
        buttons.append(screenshotButton)
        #endif
        
        // Save State (if supported)
        if emulatorVC.core.supportsSaveStates {
            let saveStateButton = createMenuButton(title: "Save State", action: #selector(handleSaveState))
            stackView.addArrangedSubview(saveStateButton)
            buttons.append(saveStateButton)
            
            // Load State
            let loadStateButton = createMenuButton(title: "Load State", action: #selector(handleLoadState))
            stackView.addArrangedSubview(loadStateButton)
            buttons.append(loadStateButton)
            
            // Save States Menu
            let saveStatesButton = createMenuButton(title: "Save States", action: #selector(handleSaveStatesMenu))
            stackView.addArrangedSubview(saveStatesButton)
            buttons.append(saveStatesButton)
        }
        
        // Cheat Codes (if supported)
        if let gameWithCheat = emulatorVC.core as? GameWithCheat, gameWithCheat.supportsCheatCode {
            let cheatCodesButton = createMenuButton(title: "Cheat Codes", action: #selector(handleCheatCodes))
            stackView.addArrangedSubview(cheatCodesButton)
            buttons.append(cheatCodesButton)
        }
        
        // Game Speed
        let gameSpeedButton = createMenuButton(title: "Game Speed", action: #selector(handleGameSpeed))
        stackView.addArrangedSubview(gameSpeedButton)
        buttons.append(gameSpeedButton)
        
        // Core Options (if available)
        if emulatorVC.core is CoreOptional {
            let coreOptionsButton = createMenuButton(title: "Core Options", action: #selector(handleCoreOptions))
            stackView.addArrangedSubview(coreOptionsButton)
            buttons.append(coreOptionsButton)
        }
        
        // Game Info
        let gameInfoButton = createMenuButton(title: "Game Info", action: #selector(handleGameInfo))
        stackView.addArrangedSubview(gameInfoButton)
        buttons.append(gameInfoButton)
        
        // Reset
        let resetButton = createMenuButton(title: "Reset", action: #selector(handleReset))
        resetButton.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.8)
        stackView.addArrangedSubview(resetButton)
        buttons.append(resetButton)
        
        // Quit
        let quitButton = createMenuButton(title: "Quit", action: #selector(handleQuit))
        quitButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.8)
        stackView.addArrangedSubview(quitButton)
        buttons.append(quitButton)
        
        // Resume
        let resumeButton = createMenuButton(title: "Resume", action: #selector(dismiss))
        resumeButton.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.8)
        stackView.addArrangedSubview(resumeButton)
        buttons.append(resumeButton)
    }
    
    private func createMenuButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18)
        button.backgroundColor = UIColor(white: 0.3, alpha: 0.8)
        button.layer.cornerRadius = 10
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }
    
    // MARK: - Actions
    
    @objc private func handleBackgroundTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        if !containerView.frame.contains(location) {
            dismiss()
        }
    }
    
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
                self.containerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            }, completion: { _ in
                self.removeFromSuperview()
            })
        }
    }
    
    @objc private func handleSaveState() {
        guard let emulatorVC = emulatorViewController else { return }
        
        // Dismiss the menu
        dismiss()
        
        // Create a new save state
        Task {
            let screenshot = emulatorVC.captureScreenshot()
            do {
                try await emulatorVC.createNewSaveState(auto: false, screenshot: screenshot)
            } catch {
                ELOG("Failed to save state: \(error.localizedDescription)")
            }
        }
    }
    
    @objc private func handleLoadState() {
        guard let emulatorVC = emulatorViewController else { return }
        
        // Dismiss the menu
        dismiss()
        
        // Show the save states menu to load a state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            emulatorVC.showSaveStateMenu()
        }
    }
    
    @objc private func handleCoreOptions() {
        guard let emulatorVC = emulatorViewController else { return }
        
        // Dismiss the menu
        dismiss()
        
        // Call the core options method
        if let coreOptional = emulatorVC.core as? CoreOptional {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                emulatorVC.showCoreOptions()
            }
        }
    }
    
    @objc private func handleGameInfo() {
        guard let emulatorVC = emulatorViewController else { return }
        
        // Dismiss the menu
        dismiss()
        
        // Call the game info method
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            emulatorVC.showMoreInfo()
        }
    }
    
    @objc private func handleP2Start() {
        guard let emulatorVC = emulatorViewController else { return }
        
        // Dismiss the menu
        dismiss()
        
        // Press and release P2 Start button
        emulatorVC.core.setPauseEmulation(false)
        emulatorVC.controllerViewController?.pressStart(forPlayer: 1)
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2) {
            emulatorVC.controllerViewController?.releaseStart(forPlayer: 1)
        }
    }
    
    @objc private func handleP2Select() {
        guard let emulatorVC = emulatorViewController else { return }
        
        // Dismiss the menu
        dismiss()
        
        // Press and release P2 Select button
        emulatorVC.core.setPauseEmulation(false)
        emulatorVC.controllerViewController?.pressSelect(forPlayer: 1)
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2) {
            emulatorVC.controllerViewController?.releaseSelect(forPlayer: 1)
        }
    }
    
    @objc private func handleP2AnalogMode() {
        guard let emulatorVC = emulatorViewController else { return }
        
        // Dismiss the menu
        dismiss()
        
        // Press and release P2 Analog Mode button
        emulatorVC.core.setPauseEmulation(false)
        emulatorVC.controllerViewController?.pressAnalogMode(forPlayer: 1)
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2) {
            emulatorVC.controllerViewController?.releaseAnalogMode(forPlayer: 1)
        }
    }
    
    @objc private func handleSwapDisc() {
        guard let emulatorVC = emulatorViewController else { return }
        
        // Dismiss the menu
        dismiss()
        
        // Show the swap discs menu
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            emulatorVC.showSwapDiscsMenu()
        }
    }
    
    @objc private func handleCoreAction(_ sender: UIButton) {
        guard let emulatorVC = emulatorViewController else { return }
        guard let actionableCore = emulatorVC.core as? CoreActions, let actions = actionableCore.coreActions else { return }
        
        // Get the action based on the button tag
        let actionIndex = sender.tag
        if actionIndex < buttons.count, let coreAction = actions.first(where: { $0.title == buttons[actionIndex].title(for: .normal) }) {
            // Dismiss the menu
            dismiss()
            
            // Execute the core action
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                actionableCore.selected(action: coreAction)
                emulatorVC.core.setPauseEmulation(false)
                if coreAction.requiresReset {
                    emulatorVC.core.resetEmulation()
                }
            }
        }
    }
    
    @objc private func handleScreenshot() {
        guard let emulatorVC = emulatorViewController else { return }
        
        // Dismiss the menu
        dismiss()
        
        // Take a screenshot after a short delay
        Task { @MainActor in
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second delay
            emulatorVC.takeScreenshot()
        }
    }
    
    @objc private func handleSaveStatesMenu() {
        guard let emulatorVC = emulatorViewController else { return }
        
        // Dismiss the menu
        dismiss()
        
        // Show the save states menu
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            emulatorVC.showSaveStateMenu()
        }
    }
    
    @objc private func handleCheatCodes() {
        guard let emulatorVC = emulatorViewController else { return }
        
        // Dismiss the menu
        dismiss()
        
        // Show the cheats menu
        if let gameWithCheat = emulatorVC.core as? GameWithCheat, gameWithCheat.supportsCheatCode {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                emulatorVC.showCheatsMenu()
            }
        }
    }
    
    @objc private func handleGameSpeed() {
        guard let emulatorVC = emulatorViewController else { return }
        
        // Dismiss the menu
        dismiss()
        
        // Show the game speed menu
        Task { @MainActor in
            try await Task.sleep(nanoseconds: 1_000)
            emulatorVC.showSpeedMenu()
        }
    }
    
    @objc private func handleReset() {
        guard let emulatorVC = emulatorViewController else { return }
        
        // Dismiss the menu
        dismiss()
        
        // Reset the emulation
        Task {
            if Defaults[.autoSave], emulatorVC.core.supportsSaveStates {
                do {
                    let _ = try await emulatorVC.autoSaveState()
                } catch {
                    ELOG("Auto-save failed \(error.localizedDescription)")
                }
            }
            
            emulatorVC.core.setPauseEmulation(false)
            emulatorVC.core.resetEmulation()
        }
    }
    
    @objc private func handleQuit() {
        guard let emulatorVC = emulatorViewController else { return }
        
        // Dismiss the menu first
        dismiss()
        
        // Then quit after menu is fully dismissed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            Task {
                await emulatorVC.quit(optionallySave: false)
            }
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
        // Start with container scaled down and transparent
        alpha = 0
        containerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        
        // Animate in
        UIView.animate(withDuration: 0.3) {
            self.alpha = 1
            self.containerView.transform = .identity
        }
    }
}

// MARK: - UIGestureRecognizerDelegate

extension PVGameMenuOverlay: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Only handle taps on the background, not on the container or buttons
        let location = touch.location(in: self)
        return !containerView.frame.contains(location)
    }
}
