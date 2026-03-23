//
//  PVControllerViewController.swift
//  Provenance
//
//  Created by Joe Mattiello on 17/03/2018.
//  Copyright (c) 2018 Joe Mattiello. All rights reserved.
//
// Notes:
// This entire file is one ugly math hack with ordering mattering in parsing.
// TLDR; refactor this to SwiftUI or constraints

#if canImport(UIKit)
import AudioToolbox
import Combine
#if canImport(GameController)
import GameController
#endif
import PVLibrary
import PVSupport
import QuartzCore
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import PVCoreBridge
import PVEmulatorCore
import PVPlists
import PVSettings
import PVUIBase
#if canImport(FreemiumKit)
import FreemiumKit
#endif

private typealias Keys = SystemDictionaryKeys.ControllerLayoutKeys
private let kDPadTopMargin: CGFloat = 48.0
private let gripControl = false

#if os(iOS) && !targetEnvironment(macCatalyst)
let volume = SubtleVolume(style: .roundedLine)
let volumeHeight: CGFloat = 3
#endif

open class PVControllerViewController<T: ResponderClient> : UIViewController, ControllerVC, OSDRecordingObserver, OSDFastForwardObserver {

    public func layoutViews() {}

    open func pressStart(forPlayer _: Int) {
        vibrate()
    }

    open func releaseStart(forPlayer _: Int) {}

    open func pressSelect(forPlayer _: Int) {
        vibrate()
    }

    open func releaseSelect(forPlayer _: Int) {}

    open func pressAnalogMode(forPlayer _: Int) {}

    open func releaseAnalogMode(forPlayer _: Int) {}

    open func pressL3(forPlayer _: Int) {}

    open func releaseL3(forPlayer _: Int) {}

    open func pressR3(forPlayer _: Int) {}

    open func releaseR3(forPlayer _: Int) {}

    public func buttonPressed(_: JSButton) {
        vibrate()
    }

    public func buttonReleased(_: JSButton) {}

    public func dPad(_: JSDPad, didPress _: JSDPadDirection) {
        vibrate()
    }

    public func dPad(_: JSDPad, didRelease _: JSDPadDirection) {
    }

    public func dPad(_: JSDPad, joystick _: JoystickValue) { }
    public func dPad(_: JSDPad, joystick2 _: JoystickValue) { }

    public typealias ResponderType = T
    public var emulatorCore: ResponderType

    public var system: PVSystem
    public var controlLayout: [ControlLayoutEntry]

    public var dPad: JSDPad? {
        didSet {
            dPad?.tag = ControlTag.dpad1.rawValue
        }
    }
    public var dPad2: JSDPad? {
        didSet {
            dPad2?.tag = ControlTag.dpad2.rawValue
        }
    }
    public var joyPad: JSDPad? {
        didSet {
            joyPad?.tag = ControlTag.joypad1.rawValue
        }
    }
    public var joyPad2: JSDPad? {
        didSet {
            joyPad2?.tag = ControlTag.joypad2.rawValue
        }
    }
    public var buttonGroup: MovableButtonView? {
        didSet {
            buttonGroup?.tag = ControlTag.buttonGroup.rawValue
        }
    }
    public var leftShoulderButton: JSButton? {
        didSet {
            leftShoulderButton?.tag = ControlTag.leftShoulder.rawValue
        }
    }
    public var rightShoulderButton: JSButton? {
        didSet {
            rightShoulderButton?.tag = ControlTag.rightShoulder.rawValue
        }
    }
    public var leftShoulderButton2: JSButton? {
        didSet {
            leftShoulderButton2?.tag = ControlTag.leftShoulder2.rawValue
        }
    }
    public var rightShoulderButton2: JSButton? {
        didSet {
            rightShoulderButton2?.tag = ControlTag.rightShoulder2.rawValue
        }
    }
    public var zTriggerButton: JSButton? {
        didSet {
            zTriggerButton?.tag = ControlTag.zTrigger.rawValue
        }
    }

    public var selectButton: JSButton? {
        didSet {
            selectButton?.tag = ControlTag.select.rawValue
        }
    }

    public var startButton: JSButton? {
        didSet {
            startButton?.tag = ControlTag.start.rawValue
        }
    }

    public var leftAnalogButton: JSButton? {
        didSet {
            leftAnalogButton?.tag = ControlTag.leftAnalog.rawValue
        }
    }
    public var rightAnalogButton: JSButton? {
        didSet {
            rightAnalogButton?.tag = ControlTag.rightAnalog.rawValue
        }
    }

    let alpha: CGFloat = .init(Defaults[.controllerOpacity])

    var alwaysRightAlign = false
    var alwaysJoypadOverDpad = false
    var topRightJoyPad2 = false
    var joyPadScale:CGFloat = 0.5
    var joyPad2Scale:CGFloat = 0.5
    var lrAtBottom = false
#if os(iOS)
    private var _feedbackGenerator: AnyObject?
    var feedbackGenerator: UISelectionFeedbackGenerator? {
        get {
            return _feedbackGenerator as? UISelectionFeedbackGenerator
        }
        set {
            _feedbackGenerator = newValue
        }
    }
#endif

    private var toggleButton: UIButton?
    private var buttonsVisible = false

    // MARK: - Hardware Switch Overlay
    private var hardwareSwitchHostingVC: UIHostingController<HardwareSwitchRowView>?

    // MARK: - Quick Action Buttons
    private var quickSaveButton: UIButton?
    private var quickLoadButton: UIButton?
    private var fastForwardButton: UIButton?
    private var isFastForwardActive: Bool = false
    #if os(iOS)
    private var recordButton: UIButton?
    private var recordPulseTimer: Timer?
    #endif
    #if !os(tvOS)
    private var keyboardToggleButton: UIButton?
    private var mouseToggleButton: UIButton?

    /// Combine subscriptions for observing `VirtualInputState` changes.
    /// Keeps the keyboard/mouse toggle button appearance in sync with any code path
    /// that modifies virtual input visibility (user tap, hardware keyboard, pause menu, etc.).
    private var virtualInputCancellables: Set<AnyCancellable> = []
    #endif
    /// Tracks all quick-action HUD buttons so they can be brought to front together
    /// in viewDidLayoutSubviews without a full-screen container view.
    private var quickActionButtons: [UIButton] = []

    // The toggle button is the sole always-on HUD control; hide it only during move mode.
    private var shouldShowToggleButton: Bool {
        return !inMoveMode
    }

    private var coreSupportsStateSaves: Bool {
        return (emulatorCore as? PVEmulatorCore)?.supportsSaveStates == true
    }

    private var coreSupportsVirtualKeyboard: Bool {
        return (emulatorCore as? KeyboardResponder)?.gameSupportsKeyboard == true
    }

    private var coreSupportsVirtualMouse: Bool {
        return (emulatorCore as? MouseResponder)?.gameSupportsMouse == true
    }

    public required init(controlLayout: [ControlLayoutEntry], system: PVSystem, responder: T) {
        emulatorCore = responder
        self.controlLayout = controlLayout
        self.system = system
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        for controller in GCController.controllers() {
            controller.clearPauseHandler()
        }
        #if os(iOS)
        stopRecordPulse()
        #endif
    }

    func updateHideTouchControls() {
        if PVControllerManager.shared.hasControllers {
            if let controller = PVControllerManager.shared.controller(forPlayer: 1) {
                hideTouchControls(for: controller)
            }
        }
    }

    var blurView : UIVisualEffectView?
    var moveLabel : UILabel?
		var resetButton: UIButton?
		private var skipLayoutOnModeChange: Bool = false

    var inMoveMode: Bool = false {
        didSet {
            if let emuCore = emulatorCore as? PVEmulatorCore {
                emuCore.setPauseEmulation(inMoveMode)
            }

            view.subviews.compactMap { subview -> (UIView & Moveable)? in
                if let moveable = subview as? UIView & Moveable {
                    return moveable
                } else if let firstMoveable = subview.subviews.compactMap({ $0 as? UIView & Moveable }).first {
                    subview.isHidden = inMoveMode
                    return firstMoveable
                } else {
                    subview.isHidden = inMoveMode
                    return nil
                }
            }.forEach { moveable in
                moveable.inMoveMode = inMoveMode
            }

            if inMoveMode {
                if blurView == nil {
                    blurView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
                    blurView?.frame = view.bounds
                    blurView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                    view.insertSubview(blurView!, at: 0)
                }

                if moveLabel == nil {
                    moveLabel = UILabel(frame: CGRect(x: 0, y: 88, width: view.bounds.width, height: 44))
                    moveLabel?.text = "Move Mode - Drag buttons to reposition\nTap with 3 fingers 3 times to exit."
                    moveLabel?.numberOfLines = 2
                    moveLabel?.textAlignment = .center
                    moveLabel?.textColor = .white
                    moveLabel?.autoresizingMask = [.flexibleWidth]
                    view.addSubview(moveLabel!)
                }

                if resetButton == nil {
                    resetButton = UIButton(type: .system)
                    resetButton?.frame = CGRect(x: view.bounds.width/2 - 50, y: moveLabel!.frame.maxY + 20, width: 100, height: 44)
                    resetButton?.setTitle("Reset", for: .normal)
                    resetButton?.setTitleColor(.white, for: .normal)
                    resetButton?.backgroundColor = UIColor.red.withAlphaComponent(0.6)
                    resetButton?.layer.cornerRadius = 8
                    resetButton?.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin, .flexibleRightMargin]
                    resetButton?.addTarget(self, action: #selector(resetButtonPositions), for: .touchUpInside)
                    view.addSubview(resetButton!)
                }
            } else if !skipLayoutOnModeChange {
                blurView?.removeFromSuperview()
                blurView = nil
                moveLabel?.removeFromSuperview()
                moveLabel = nil
                resetButton?.removeFromSuperview()
                resetButton = nil
            }
            skipLayoutOnModeChange = false
        }
    }

    private var isResettingLayout: Bool = false
    @objc private func resetButtonPositions() {
        ILOG("Reset button pressed")

        // Clear saved positions from UserDefaults
        for button in allButtons {
            if let movableButton = button as? MovableButtonView {
                ILOG("Clearing position for button: \(type(of: movableButton))")
                UserDefaults.standard.removeObject(forKey: movableButton.positionKey)
                movableButton.isCustomMoved = false
            }
        }

        // Temporarily exit move mode to allow layout
        let wasInMoveMode = inMoveMode
        inMoveMode = false

        // Force layout refresh
        PVControllerManager.shared.hasLayout = false
        setupTouchControls()

        // Restore move mode
        inMoveMode = wasInMoveMode

        // Provide haptic feedback
        #if os(iOS)
        feedbackGenerator?.selectionChanged()
        #endif
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(PVControllerViewController.controllerDidConnect(_:)), name: .GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PVControllerViewController.controllerDidDisconnect(_:)), name: .GCControllerDidDisconnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PVControllerViewController.hideTouchControls(_:)), name:  Notification.Name("HideTouchControls"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PVControllerViewController.showTouchControls(_:)), name: Notification.Name("ShowTouchControls"), object: nil)
#if os(iOS)
        feedbackGenerator = UISelectionFeedbackGenerator()
        feedbackGenerator?.prepare()
        updateHideTouchControls()

#if !targetEnvironment(macCatalyst)
        if Defaults[.movableButtons] {
            let tripleTapGesture = UITapGestureRecognizer(target: self, action: #selector(PVControllerViewController.tripleTapRecognized(_:)))

            tripleTapGesture.numberOfTapsRequired = 3
            tripleTapGesture.numberOfTouchesRequired = 3
            view.addGestureRecognizer(tripleTapGesture)
        }
        if Defaults[.volumeHUD] {
            volume.barTintColor = .white
            volume.barBackgroundColor = UIColor.white.withAlphaComponent(0.3)
            volume.animation = .slideDown
            view.addSubview(volume)
        }

        NotificationCenter.default.addObserver(volume, selector: #selector(SubtleVolume.resume), name: UIApplication.didBecomeActiveNotification, object: nil)
#endif // !macCatalyst
#endif // os(iOS)

        // Set up the HUD quick-action strip (toggle button + fast-forward/save/load/record row).
        // Scoped to iOS: the strip is touch-driven and recording is iOS-only.
        // tvOS uses a remote/controller; the pause menu covers save/load/FF there.
        #if os(iOS)
        setupToggleButton()
        setupQuickActionButtons()
        #endif

        // Hardware switch overlay (e.g. Atari difficulty / TV-type switches)
        addHardwareSwitchOverlayIfNeeded()
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        #if os(iOS)
        stopRecordPulse()
        #endif
    }

    @objc func tripleTapRecognized(_ gesture : UITapGestureRecognizer) {
        inMoveMode = !inMoveMode
    }

    // MARK: - VirtualInputState observation

    override public func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        #if !os(tvOS)
        subscribeToVirtualInputStateIfNeeded()
        #endif
        if let superview = view.superview {
            view.frame = superview.bounds
        }
    }

    #if !os(tvOS)
    /// Subscribes to the parent emulator VC's `VirtualInputState` via Combine so that
    /// the keyboard/mouse toggle button appearance stays current regardless of which code
    /// path triggered the visibility change (user tap, hardware keyboard, pause menu, etc.).
    private func subscribeToVirtualInputStateIfNeeded() {
        virtualInputCancellables.removeAll()
        guard let state = (parent as? PVEmulatorViewController)?.virtualInputState else { return }
        state.$isKeyboardVisible
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateKeyboardButtonAppearance() }
            .store(in: &virtualInputCancellables)
        state.$isMouseVisible
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateMouseButtonAppearance() }
            .store(in: &virtualInputCancellables)
    }
    #endif

    // MARK: - GameController Notifications

    @objc func hideTouchControls(_: Notification?) {
#if os(iOS) && !targetEnvironment(macCatalyst)
        buttonsVisible = false
        updateToggleButtonAppearance()
#endif // os(iOS)
    }

    @objc func showTouchControls(_: Notification?) {
#if os(iOS) && !targetEnvironment(macCatalyst)
        buttonsVisible = true
        
        updateToggleButtonAppearance()
#endif
    }

    @objc func controllerDidConnect(_: Notification?) {
#if os(iOS) && !targetEnvironment(macCatalyst)
        if PVControllerManager.shared.hasControllers {
            if let controller = PVControllerManager.shared.controller(forPlayer: 1) {
                hideTouchControls(for: controller)
            }
        } else {
            for button in allButtons {
                button.isHidden = false
                button.alpha = CGFloat(Defaults[.controllerOpacity])
            }
            print("Controller Alpha Set ", CGFloat(Defaults[.controllerOpacity]))
            // Quick-action buttons always show at full opacity regardless of controllerOpacity
            restoreQuickActionButtonAlpha()
            dPad2?.isHidden = traitCollection.verticalSizeClass == .compact
        }
        setupTouchControls()
#endif // os(iOS)
    }

    private var allButtons: [UIView] {
        var views: [UIView?] = [
            dPad, dPad2, joyPad, joyPad2, buttonGroup,
            leftShoulderButton, rightShoulderButton,
            leftShoulderButton2, rightShoulderButton2,
            zTriggerButton, startButton, selectButton,
            leftAnalogButton, rightAnalogButton,
            quickSaveButton, quickLoadButton, fastForwardButton,
        ]
        #if os(iOS)
        views.append(recordButton)
        #endif
        // Note: keyboardToggleButton and mouseToggleButton are intentionally excluded —
        // they are always-on HUD controls like fastForwardButton and must not dim with
        // the controller opacity setting.
        return views.compactMap { $0 }
    }

    @objc func controllerDidDisconnect(_: Notification?) {
#if os(iOS) && !targetEnvironment(macCatalyst)

        if PVControllerManager.shared.hasControllers {
            if let controller = PVControllerManager.shared.controller(forPlayer: 1) {
                hideTouchControls(for: controller)
            }
        } else {
            for button in allButtons {
                button.isHidden = false
                button.alpha = CGFloat(Defaults[.controllerOpacity])
            }
            print("Controller Alpha Set", CGFloat(Defaults[.controllerOpacity]))
            // Quick-action buttons always show at full opacity regardless of controllerOpacity
            restoreQuickActionButtonAlpha()
            dPad2?.isHidden = traitCollection.verticalSizeClass == .compact
        }
        setupTouchControls()
#endif
    }

    public func vibrate() {
#if os(iOS) && !targetEnvironment(macCatalyst)
        if Defaults[.buttonVibration] {
            feedbackGenerator?.selectionChanged()
        }
#endif
    }

#if os(iOS) && !targetEnvironment(macCatalyst)
    override open var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }
#endif

    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if inMoveMode { return }
        PVControllerManager.shared.hasLayout = false

#if os(iOS) && !targetEnvironment(macCatalyst)
        setupTouchControls()
        layoutViews()

        /// Adjust D-Pad position if needed
        adjustDPadPosition()

        if Defaults[.volumeHUD] {
            layoutVolume()
        }
        updateHideTouchControls()
#endif

        /// Update toggle button visibility and keep HUD controls at the top of the z-order.
        /// Bring each quick-action button individually so the full-screen overlay is never
        /// needed — game-button views added by setupTouchControls() sit beneath each HUD
        /// button directly, and touches in the gaps fall through naturally.
        toggleButton?.isHidden = !shouldShowToggleButton
        for btn in quickActionButtons {
            if btn.superview === view {
                view.bringSubviewToFront(btn)
            }
        }
        if let toggleButton = toggleButton {
            view.bringSubviewToFront(toggleButton)
        }
        positionHardwareSwitchOverlay()
    }

    func prelayoutSettings() {}

    // MARK: - Hardware Switch Overlay

    /// Adds a hardware-switch overlay if the current system has any switches
    /// (e.g. Atari difficulty / TV-type switches).  The overlay is positioned
    /// at the top-trailing corner so it doesn't obstruct the controller buttons.
    private func addHardwareSwitchOverlayIfNeeded() {
        guard let switches = system.systemIdentifier.hardwareSwitches, !switches.isEmpty else { return }

        let switchRow = HardwareSwitchRowView(switches: switches) { [weak self] buttonId, _ in
            self?.didReceiveHardwareSwitchInput(buttonId: buttonId, player: 0)
        }

        let hostingVC = UIHostingController(rootView: switchRow)
        hostingVC.view.backgroundColor = .clear
        hostingVC.view.isOpaque = false

        addChild(hostingVC)
        view.addSubview(hostingVC.view)
        hostingVC.didMove(toParent: self)
        hardwareSwitchHostingVC = hostingVC
    }

    private func positionHardwareSwitchOverlay() {
        guard let hostingVC = hardwareSwitchHostingVC else { return }

        let safeFrame = view.safeAreaLayoutGuide.layoutFrame
        let horizontalMargin: CGFloat = 12
        let verticalMargin: CGFloat = 8

        let availableWidth = max(0, safeFrame.width - (horizontalMargin * 2))
        let fittingSize = hostingVC.sizeThatFits(in: CGSize(width: availableWidth, height: .greatestFiniteMagnitude))

        let layoutDirection = view.effectiveUserInterfaceLayoutDirection
        let x: CGFloat
        switch layoutDirection {
        case .rightToLeft:
            x = safeFrame.minX + horizontalMargin
        default:
            x = safeFrame.maxX - horizontalMargin - fittingSize.width
        }

        let y = safeFrame.minY + verticalMargin

        hostingVC.view.frame = CGRect(origin: CGPoint(x: x, y: y), size: fittingSize)
        view.bringSubviewToFront(hostingVC.view)
    }

    /// Override in subclasses to route a hardware-switch button press to the
    /// system-specific responder.  The base implementation is a no-op.
    open func didReceiveHardwareSwitchInput(buttonId: String, player: Int) {}

#if os(iOS) && !targetEnvironment(macCatalyst)

    func layoutVolume() {
        let volumeYPadding: CGFloat = 10
        let volumeXPadding = UIScreen.main.bounds.width * 0.4 / 2

        volume.superview?.bringSubviewToFront(volume)
        volume.layer.cornerRadius = volumeHeight / 2
        volume.frame = CGRect(x: view.safeAreaInsets.left + volumeXPadding, y: view.safeAreaInsets.top + volumeYPadding, width: UIScreen.main.bounds.width - (volumeXPadding * 2) - view.safeAreaInsets.left - view.safeAreaInsets.right, height: volumeHeight)
    }
#endif

    override open func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        if inMoveMode {
            inMoveMode = false
        }
        super.viewWillTransition(to: size, with: coordinator)
    }

    @objc
    func hideTouchControls(for controller: GCController) {
        ILOG("Hiding touch controls")
        guard controller.playerIndex == .index1 else { return }

        // Special handling for select/start/analog buttons if needed
        if !Defaults[.missingButtonsAlwaysOn] {
            selectButton?.isHidden = true
            startButton?.isHidden = true
            leftAnalogButton?.isHidden = true
            rightAnalogButton?.isHidden = true
        } else if controller.supportsThumbstickButtons {
            leftAnalogButton?.isHidden = true
            rightAnalogButton?.isHidden = true
        }

        // Update buttonsVisible state
        buttonsVisible = false
        updateToggleButtonAppearance()

        setupTouchControls()
    }

    // MARK: - Controller Position And Size Editing

#if !os(iOS)
    func setupTouchControls() { }
#else
    func setupTouchControls() {
        if inMoveMode { return }
        prelayoutSettings()

        if PVControllerManager.shared.hasLayout { return }
        PVControllerManager.shared.hasLayout = true

        // Only log and reset custom moves during explicit reset
        if isResettingLayout {
            ILOG("Setting up fresh layout")
            for button in allButtons {
                if let movableButton = button as? MovableButtonView {
                    movableButton.isCustomMoved = false
                }
            }
            isResettingLayout = false
        }

        let alpha = self.alpha
        for control in controlLayout {
            let controlType: String = control.PVControlType
            let controlSize: CGSize = NSCoder.cgSize(for: control.PVControlSize)
            let compactVertical: Bool = traitCollection.verticalSizeClass == .compact
            let controlOriginY: CGFloat = compactVertical ? view.bounds.size.height - controlSize.height : view.frame.width + (kDPadTopMargin / 2)
            if controlType == Keys.DPad {
                if let dPad = dPad, dPad.isCustomMoved { continue }
                let xPadding: CGFloat = 0 // safeAreaInsets.left
                let bottomPadding: CGFloat = 16
                let dPadOriginY: CGFloat = min(controlOriginY - bottomPadding, view.frame.height - controlSize.height - bottomPadding)
                var dPadFrame = CGRect(x: xPadding, y: dPadOriginY, width: controlSize.width, height: controlSize.height)
                if dPad2 == nil, control.PVControlTitle == "Y" {
                    dPadFrame.origin.y = dPadOriginY - controlSize.height - bottomPadding
                }
                if dPad2 == nil && (control.PVControlTitle == "Y") {
                    let dPad2 = JSDPad.DPad2(frame: dPadFrame)
                    if let tintColor = control.PVControlTint {
                        dPad2.tintColor = UIColor(hex: tintColor)
                    }
                    self.dPad2 = dPad2
                    dPad2.delegate = self
                    dPad2.alpha = alpha
                    dPad2.autoresizingMask = [.flexibleTopMargin, .flexibleRightMargin]
                    view.addSubview(dPad2)
                    if let movableButton = dPad2 as? MovableButtonView {
                        movableButton.loadSavedPosition()
                    }
                } else if let dPad = dPad {
                    if !dPad.isCustomMoved {
                        dPad.frame = dPadFrame
                    }
                } else {
                    let dPad = JSDPad.DPad1(frame: dPadFrame)
                    if let tintColor = control.PVControlTint {
                        dPad.tintColor = UIColor(hex: tintColor)
                    }
                    self.dPad = dPad
                    dPad.delegate = self
                    dPad.alpha = alpha
                    dPad.autoresizingMask = [.flexibleTopMargin, .flexibleRightMargin]
                    if let movableButton = dPad as? MovableButtonView {
                        movableButton.loadSavedPosition()
                    }
                    view.addSubview(dPad)
                }
                if let dPad = dPad {
                    dPad.transform = .identity
                }
                if let dPad2 = dPad2 {
                    dPad2.isHidden = compactVertical
                }
            } else if controlType == Keys.JoyPad, Defaults[.onscreenJoypad] {
                var xPadding: CGFloat = 0 // view.safeAreaInsets.left
                let bottomPadding: CGFloat = 16
                let joyPadOriginY: CGFloat = min(controlOriginY - bottomPadding, view.frame.height - controlSize.height - bottomPadding)
                var joyPadFrame = CGRect(x: xPadding, y: joyPadOriginY, width: controlSize.width, height: controlSize.height)
                xPadding += 10
                joyPadFrame.origin.y += joyPadFrame.height * joyPadScale + bottomPadding
                joyPadFrame.origin.x += xPadding
                if dPad != nil {
                    let bounds = dPad!.frame
                    joyPadFrame.origin.x = bounds.origin.x + bounds.width / 2 - controlSize.width / 2
                }
                let joyPad: JSDPad = self.joyPad ?? JSDPad.JoyPad(frame: joyPadFrame, scale:joyPadScale)
                if !joyPad.isCustomMoved {
                    joyPad.frame = joyPadFrame
                }

                if let tintColor = control.PVControlTint {
                    joyPad.tintColor = UIColor(hex: tintColor)
                }
                self.joyPad = joyPad
                joyPad.delegate = self
                joyPad.alpha = alpha
                joyPad.autoresizingMask = [.flexibleTopMargin, .flexibleRightMargin]
                if let movableButton = joyPad as? MovableButtonView {
                    movableButton.loadSavedPosition()
                }
                view.addSubview(joyPad)
            } else if controlType == Keys.JoyPad2, Defaults[.onscreenJoypad] {
                var xPadding: CGFloat = 0 // view.safeAreaInsets.left
                let bottomPadding: CGFloat = 16
                let joyPadOriginY: CGFloat = min(controlOriginY - bottomPadding, view.frame.height - controlSize.height - bottomPadding)
                var joyPad2Frame = CGRect(x: view.frame.width - controlSize.width - xPadding, y: joyPadOriginY, width: controlSize.width, height: controlSize.height)
                xPadding += 10
                joyPad2Frame.origin.x -= xPadding
                let joyPad2: JSDPad = self.joyPad2 ?? JSDPad.JoyPad2(frame: joyPad2Frame, scale:joyPad2Scale)
                if !joyPad2.isCustomMoved {
                    joyPad2.frame = joyPad2Frame
                }
                self.joyPad2 = joyPad2
                joyPad2.delegate = self
                joyPad2.alpha = alpha
                joyPad2.autoresizingMask = [.flexibleTopMargin, .flexibleRightMargin]
                view.addSubview(joyPad2)
                if let movableButton = joyPad2 as? MovableButtonView {
                    movableButton.loadSavedPosition()
                }
            } else if controlType == Keys.ButtonGroup {
                let xPadding: CGFloat = view.safeAreaInsets.right + 5
                let bottomPadding: CGFloat = 16
                let buttonsOriginY: CGFloat = min(controlOriginY - bottomPadding, view.frame.height - controlSize.height - bottomPadding)
                let buttonsFrame = CGRect(x: view.bounds.maxX - controlSize.width - xPadding, y: buttonsOriginY, width: controlSize.width, height: controlSize.height)
                if let buttonGroup = buttonGroup {
                    if buttonGroup.isCustomMoved { continue }
                    if let buttonGroup = buttonGroup as? PVButtonGroupOverlayView, buttonGroup.isCustomMoved {
                    } else {
                        buttonGroup.frame = buttonsFrame
                    }
                } else {
                    let buttonGroup = MovableButtonView(frame: buttonsFrame)
                    buttonGroup.tag = ControlTag.buttonGroup.rawValue
                    self.buttonGroup = buttonGroup
                    buttonGroup.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin]

                    var buttons = [JSButton]()

                    let groupedButtons = control.PVGroupedButtons
                    groupedButtons?.forEach { groupedButton in
                        let buttonFrame: CGRect = NSCoder.cgRect(for: groupedButton.PVControlFrame)
                        let button = JSButton(frame: buttonFrame, label: groupedButton.PVControlTitle)

                        button.titleLabel?.text = groupedButton.PVControlTitle

                        if let tintColor = groupedButton.PVControlTint {
                            button.tintColor = UIColor(hex: tintColor)
                        }

                        button.backgroundImage = UIImage(named: "button", in: Bundle.module, with: nil)
                        button.backgroundImagePressed = UIImage(named: "button-pressed", in: Bundle.module, with: nil)
                        button.delegate = self
                        buttonGroup.addSubview(button)
                        buttons.append(button)
                    }

                    let buttonOverlay = PVButtonGroupOverlayView(buttons: buttons)
                    buttonOverlay.setSize(buttonGroup.bounds.size)
                    buttonGroup.addSubview(buttonOverlay)
                    buttonGroup.alpha = alpha
                    if let movableButton = buttonGroup as? MovableButtonView {
                        movableButton.loadSavedPosition()
                    }
                    view.addSubview(buttonGroup)
                }
                if buttonGroup != nil {
                    buttonGroup?.transform = .identity
                }
            } else if controlType == Keys.RightShoulderButton {
                layoutRightShoulderButtons(control: control)
            } else if controlType == Keys.RightShoulderButton2 {
                layoutRightShoulderButtons(control: control)
            } else if controlType == Keys.ZTriggerButton {
                layoutZTriggerButton(control: control)
            } else if controlType == Keys.LeftShoulderButton {
                layoutLeftShoulderButtons(control: control)
            } else if controlType == Keys.LeftShoulderButton2 {
                layoutLeftShoulderButtons(control: control)
            } else if controlType == Keys.SelectButton {
                layoutSelectButton(control: control)
            } else if controlType == Keys.StartButton {
                layoutStartButton(control: control)
            } else if controlType == Keys.LeftAnalogButton {
                layoutLeftAnalogButton(control: control)
            } else if controlType == Keys.RightAnalogButton {
                layoutRightAnalogButton(control: control)
            }
        }
        // Fix overlapping buttons on old/smaller iPhones
        if joyPad == nil, super.view.bounds.size.width < super.view.bounds.size.height {
            if UIScreen.main.bounds.height <= 568 || UIScreen.main.bounds.width <= 320 {
                let scaleDPad = CGFloat(0.85)
                let scaleButtons = CGFloat(0.75)
                if dPad != nil {
                    dPad?.transform = CGAffineTransform(scaleX: scaleDPad, y: scaleDPad)
                    dPad?.frame.origin.x -= 20
                    dPad?.frame.origin.y -= 5
                }
                if buttonGroup != nil {
                    buttonGroup?.transform = CGAffineTransform(scaleX: scaleButtons, y: scaleButtons)
                    buttonGroup?.frame.origin.x += 30
                    buttonGroup?.frame.origin.y += 15
                    if system.shortName == "SG" || system.shortName == "SCD" || system.shortName == "32X" || system.shortName == "SS" || system.shortName == "PCFX" {
                        buttonGroup?.frame.origin.x += 15
                        buttonGroup?.frame.origin.y += 5
                    } else if system.shortName == "N64" {
                        buttonGroup?.frame.origin.x += 33
                    } else {
                        buttonGroup?.frame.origin.y += 4
                    }
                }
                let shoulderYOffset = CGFloat(35)
                if leftShoulderButton != nil {
                    leftShoulderButton?.frame.origin.y += shoulderYOffset
                }
                if leftShoulderButton2 != nil {
                    leftShoulderButton2?.frame.origin.y += shoulderYOffset
                }
                if rightShoulderButton != nil {
                    rightShoulderButton?.frame.origin.y += shoulderYOffset
                }
                if rightShoulderButton2 != nil {
                    rightShoulderButton2?.frame.origin.y += shoulderYOffset
                }
                if zTriggerButton != nil {
                    zTriggerButton?.frame.origin.y += shoulderYOffset
                }
            }
        }
        adjustJoystick()
        if let joyPad2 = joyPad2 {
            view.bringSubviewToFront(joyPad2)
        }
        if let dPad2 = dPad2 {
            view.bringSubviewToFront(dPad2)
        }
        if let buttonGroup = buttonGroup {
            view.bringSubviewToFront(buttonGroup)
        }
        if let joyPad = joyPad {
            view.bringSubviewToFront(joyPad)
        }
        if let dPad = dPad {
            view.bringSubviewToFront(dPad)
        }
        if let startButton = startButton {
            view.bringSubviewToFront(startButton)
        }
        if let selectButton = selectButton {
            view.bringSubviewToFront(selectButton)
        }
        if let leftShoulderButton = leftShoulderButton {
            view.bringSubviewToFront(leftShoulderButton)
        }
        if let rightShoulderButton =  rightShoulderButton{
            view.bringSubviewToFront(rightShoulderButton)
        }
    }
#endif // os(iOS)

#if os(iOS)
    func layoutRightShoulderButtons(control: ControlLayoutEntry) {
        let controlSize: CGSize = NSCoder.cgSize(for: control.PVControlSize)
        let xPadding: CGFloat = view.safeAreaInsets.right + 10
        let yPadding: CGFloat = view.safeAreaInsets.bottom + 10
        var rightShoulderFrame: CGRect!
        if buttonGroup != nil, !(buttonGroup?.isHidden)! {
            rightShoulderFrame = CGRect(x: view.frame.size.width - controlSize.width - xPadding, y: (buttonGroup?.frame.minY)!, width: controlSize.width, height: controlSize.height)
            if dPad != nil, !(dPad?.isHidden)! {
                rightShoulderFrame.origin.y = (dPad?.frame.minY)! < (buttonGroup?.frame.minY)! ? (dPad?.frame.minY)! : (buttonGroup?.frame.minY)!
            }
            if Defaults[.allRightShoulders], (system.shortName == "GBA" || system.shortName == "VB") || system.shortName == "SNES" {
                rightShoulderFrame.origin.y += ((buttonGroup?.frame.height)! / 2 - controlSize.height)
            }
        } else {
            rightShoulderFrame = CGRect(x: view.frame.size.width - controlSize.width - xPadding, y: view.frame.size.height - (controlSize.height * 2) - yPadding, width: controlSize.width, height: controlSize.height)
        }
        rightShoulderFrame.origin.y -= controlSize.height
        if leftShoulderButton != nil {
            rightShoulderFrame.origin.y = (leftShoulderButton?.frame)!.origin.y
        }
        if rightShoulderButton == nil {
            let rightShoulderButton = JSButton(frame: rightShoulderFrame, label: control.PVControlTitle)
            rightShoulderButton.tag = ControlTag.rightShoulder.rawValue
            if let tintColor = control.PVControlTint {
                rightShoulderButton.tintColor = UIColor(hex: tintColor)
            }
            self.rightShoulderButton = rightShoulderButton
            rightShoulderButton.titleLabel?.text = control.PVControlTitle
            rightShoulderButton.titleLabel?.font = UIFont.systemFont(ofSize: 9)
            rightShoulderButton.backgroundImage = UIImage(named: "button-thin", in: Bundle.module, with: nil)
            rightShoulderButton.backgroundImagePressed = UIImage(named: "button-thin-pressed", in: Bundle.module, with: nil)
            rightShoulderButton.delegate = self
            rightShoulderButton.titleEdgeInsets = UIEdgeInsets(top: 2, left: 2, bottom: 4, right: 2)
            rightShoulderButton.alpha = alpha
            rightShoulderButton.autoresizingMask = [.flexibleBottomMargin, .flexibleLeftMargin]
            view.addSubview(rightShoulderButton)
            if let movableButton = rightShoulderButton as? MovableButtonView {
                movableButton.loadSavedPosition()
            }
        } else {
            if let rightShoulderButton = rightShoulderButton {
                if rightShoulderButton.isCustomMoved { return }
                rightShoulderButton.frame = rightShoulderFrame
            }
        }
        if rightShoulderButton2 == nil, control.PVControlType == Keys.RightShoulderButton2 || control.PVControlTitle == "R2" {
            var rightShoulderFrame2 = rightShoulderFrame
            rightShoulderFrame2!.origin.y -= controlSize.height
            let rightShoulderButton2 = JSButton(frame: rightShoulderFrame2!, label: control.PVControlTitle)
            rightShoulderButton2.tag = ControlTag.rightShoulder2.rawValue
            if let tintColor = control.PVControlTint {
                rightShoulderButton2.tintColor = UIColor(hex: tintColor)
            }
            self.rightShoulderButton2 = rightShoulderButton2
            rightShoulderButton2.titleLabel?.text = control.PVControlTitle
            rightShoulderButton2.titleLabel?.font = UIFont.systemFont(ofSize: 9)
            rightShoulderButton2.backgroundImage = UIImage(named: "button-thin", in: Bundle.module, with: nil)
            rightShoulderButton2.backgroundImagePressed = UIImage(named: "button-thin-pressed", in: Bundle.module, with: nil)
            rightShoulderButton2.delegate = self
            rightShoulderButton2.titleEdgeInsets = UIEdgeInsets(top: 2, left: 2, bottom: 4, right: 2)
            rightShoulderButton2.alpha = alpha
            rightShoulderButton2.autoresizingMask = [.flexibleBottomMargin, .flexibleLeftMargin]
            rightShoulderFrame.origin.y += controlSize.height
            if let movableButton = rightShoulderButton2 as? MovableButtonView {
                movableButton.loadSavedPosition()
            }
            view.addSubview(rightShoulderButton2)
        } else {
            if let rightShoulderButton2 = rightShoulderButton2 {
                if rightShoulderButton2.isCustomMoved { return }
                var rightShoulderFrame2 = rightShoulderFrame
                rightShoulderFrame2!.origin.y -= controlSize.height
                rightShoulderButton2.frame = rightShoulderFrame2!
            }
        }
    }

    func layoutZTriggerButton(control: ControlLayoutEntry) {
        let controlSize: CGSize = NSCoder.cgSize(for: control.PVControlSize)
        let xPadding: CGFloat = view.safeAreaInsets.right + 10
        let yPadding: CGFloat = view.safeAreaInsets.bottom + 10
        var zTriggerFrame: CGRect!

        if rightShoulderButton != nil {
            zTriggerFrame = CGRect(x: (rightShoulderButton?.frame.minX)! - controlSize.width, y: (rightShoulderButton?.frame.minY)!, width: controlSize.width, height: controlSize.height)
        } else {
            let x: CGFloat = view.frame.size.width - (controlSize.width * 2) - xPadding
            let y: CGFloat = view.frame.size.height - (controlSize.height * 2) - yPadding
            zTriggerFrame = CGRect(x: x, y: y, width: controlSize.width, height: controlSize.height)
        }

        if let zTriggerButton = zTriggerButton {
            if !zTriggerButton.isCustomMoved {
                zTriggerButton.frame = zTriggerFrame
            }
        } else {
            let zTriggerButton = JSButton(frame: zTriggerFrame, label: control.PVControlTitle)
            zTriggerButton.tag = ControlTag.zTrigger.rawValue
            if let tintColor = control.PVControlTint {
                zTriggerButton.tintColor = UIColor(hex: tintColor)
            }
            self.zTriggerButton = zTriggerButton
            zTriggerButton.titleLabel?.text = control.PVControlTitle
            zTriggerButton.titleLabel?.font = UIFont.systemFont(ofSize: 9)
            zTriggerButton.backgroundImage = UIImage(named: "button-thin", in: Bundle.module, with: nil)
            zTriggerButton.backgroundImagePressed = UIImage(named: "button-thin-pressed", in: Bundle.module, with: nil)
            zTriggerButton.delegate = self
            zTriggerButton.titleEdgeInsets = UIEdgeInsets(top: 2, left: 2, bottom: 4, right: 2)
            zTriggerButton.alpha = alpha
            zTriggerButton.autoresizingMask = [.flexibleBottomMargin, .flexibleLeftMargin]
            view.addSubview(zTriggerButton)
            if let movableButton = zTriggerButton as? MovableButtonView {
                movableButton.loadSavedPosition()
            }
        }
    }

    func layoutLeftShoulderButtons(control: ControlLayoutEntry) {
        let controlSize: CGSize = NSCoder.cgSize(for: control.PVControlSize)
        let xPadding: CGFloat = view.safeAreaInsets.left + 10
        var leftShoulderFrame: CGRect!
        if dPad != nil {
            leftShoulderFrame = CGRect(x: xPadding, y: (dPad?.frame.minY)!, width: controlSize.width, height: controlSize.height)
            if buttonGroup != nil, !(buttonGroup?.isHidden)! {
                leftShoulderFrame.origin.y = (dPad?.frame.minY)! < (buttonGroup?.frame.minY)! ? (dPad?.frame.minY)! : (buttonGroup?.frame.minY)!
            }
        } else {
            leftShoulderFrame = CGRect(x: xPadding, y: view.frame.size.height - (controlSize.height * 10), width: controlSize.width, height: controlSize.height)
        }
        if Defaults[.allRightShoulders] || alwaysRightAlign {
            if zTriggerButton != nil {
                leftShoulderFrame.origin.x = (zTriggerButton?.frame.origin.x)! - controlSize.width
            } else if zTriggerButton == nil, rightShoulderButton != nil {
                leftShoulderFrame.origin.x = (rightShoulderButton?.frame.origin.x)! - controlSize.width
                if system.shortName == "GBA" || system.shortName == "VB" {
                    leftShoulderFrame.origin.y += ((buttonGroup?.frame.height)! / 2 - controlSize.height)
                }
            }
        }
        leftShoulderFrame.origin.y -= controlSize.height
        if leftShoulderButton == nil {
            let leftShoulderButton = JSButton(frame: leftShoulderFrame, label: control.PVControlTitle)
            leftShoulderButton.tag = ControlTag.leftShoulder.rawValue
            self.leftShoulderButton = leftShoulderButton
            leftShoulderButton.titleLabel?.text = control.PVControlTitle
            leftShoulderButton.titleLabel?.font = UIFont.systemFont(ofSize: 8)
            if let tintColor = control.PVControlTint {
                leftShoulderButton.tintColor = UIColor(hex: tintColor)
            }
            leftShoulderButton.backgroundImage = UIImage(named: "button-thin", in: Bundle.module, with: nil)
            leftShoulderButton.backgroundImagePressed = UIImage(named: "button-thin-pressed", in: Bundle.module, with: nil)
            leftShoulderButton.delegate = self
            leftShoulderButton.titleEdgeInsets = UIEdgeInsets(top: 2, left: 2, bottom: 4, right: 2)
            leftShoulderButton.alpha = alpha
            leftShoulderButton.autoresizingMask = [.flexibleBottomMargin, .flexibleRightMargin]
            view.addSubview(leftShoulderButton)
            if let movableButton = leftShoulderButton as? MovableButtonView {
                movableButton.loadSavedPosition()
            }
        } else {
            if let leftShoulderButton = leftShoulderButton, !leftShoulderButton.isCustomMoved {
                leftShoulderButton.frame = leftShoulderFrame
            }
        }
        if leftShoulderButton2 == nil, control.PVControlType == Keys.LeftShoulderButton2 || control.PVControlTitle == "L2" {
            var leftShoulderFrame2 = leftShoulderFrame
            leftShoulderFrame2!.origin.y -= controlSize.height
            let leftShoulderButton2 = JSButton(frame: leftShoulderFrame2!, label: control.PVControlTitle)
            leftShoulderButton2.tag = ControlTag.leftShoulder2.rawValue
            if let tintColor = control.PVControlTint {
                leftShoulderButton2.tintColor = UIColor(hex: tintColor)
            }
            self.leftShoulderButton2 = leftShoulderButton2
            leftShoulderButton2.titleLabel?.text = control.PVControlTitle
            leftShoulderButton2.titleLabel?.font = UIFont.systemFont(ofSize: 8)
            leftShoulderButton2.backgroundImage = UIImage(named: "button-thin")
            leftShoulderButton2.backgroundImagePressed = UIImage(named: "button-thin-pressed", in: Bundle.module, with: nil)
            leftShoulderButton2.delegate = self
            leftShoulderButton2.titleEdgeInsets = UIEdgeInsets(top: 2, left: 2, bottom: 4, right: 2)
            leftShoulderButton2.alpha = alpha
            leftShoulderButton2.autoresizingMask = [.flexibleBottomMargin, .flexibleRightMargin]
            view.addSubview(leftShoulderButton2)
            if let movableButton = leftShoulderButton2 as? MovableButtonView {
                movableButton.loadSavedPosition()
            }
        } else {
            if let leftShoulderButton2 = leftShoulderButton2, !leftShoulderButton2.isCustomMoved {
                leftShoulderFrame.origin.y -= leftShoulderButton!.frame.size.height
                leftShoulderButton2.frame = leftShoulderFrame
            }
        }
    }
#endif

#if os(iOS)
    func layoutSelectButton( control: ControlLayoutEntry ) {
        let controlSize: CGSize = NSCoder.cgSize(for: control.PVControlSize)
        let yPadding: CGFloat = view.safeAreaInsets.bottom
        let xPadding: CGFloat = view.safeAreaInsets.left + 10
        let spacing: CGFloat = 20
        var selectFrame = CGRect(x: xPadding, y: view.frame.height - yPadding - controlSize.height, width: controlSize.width, height: controlSize.height)

        if super.view.bounds.size.width > super.view.bounds.size.height || UIDevice.current.orientation.isLandscape || UIDevice.current.userInterfaceIdiom == .pad {
            if dPad != nil, !(dPad?.isHidden)! {
                selectFrame = CGRect(x: (dPad?.frame.origin.x)! + (dPad?.frame.size.width)! - (controlSize.width / 3), y: view.frame.height - yPadding - controlSize.height, width: controlSize.width, height: controlSize.height)
            } else if dPad != nil, (dPad?.isHidden)! {
                selectFrame = CGRect(x: xPadding, y: view.frame.height - yPadding - controlSize.height, width: controlSize.width, height: controlSize.height)
                if gripControl {
                    selectFrame.origin.y = (UIScreen.main.bounds.height / 2)
                }
            }
        } else if super.view.bounds.size.width < super.view.bounds.size.height || UIDevice.current.orientation.isPortrait {
            let x: CGFloat = (view.frame.size.width / 2) - controlSize.width - (spacing / 2)
            let y: CGFloat = view.frame.height - yPadding - controlSize.height
            selectFrame = CGRect(x: x, y: y, width: controlSize.width, height: controlSize.height)
        }

        if selectFrame.maxY >= view.frame.size.height {
            selectFrame.origin.y -= (selectFrame.maxY - view.frame.size.height) + yPadding
        }

        if view.frame.width > view.frame.height {
            selectFrame.origin.x = (view.frame.size.width / 2) - controlSize.width - (spacing / 2)
        }
        if alwaysRightAlign {
            selectFrame.origin.x += 80
            if let dPad = dPad {
                selectFrame.origin.x = dPad.frame.maxX + (xPadding * 2)
            }
        }

        if let selectButton = selectButton {
            if !selectButton.isCustomMoved {
                selectButton.frame = selectFrame
            }
        } else {
            let selectButton = JSButton(frame: selectFrame, label: control.PVControlTitle)
            selectButton.tag = ControlTag.select.rawValue
            if let tintColor = control.PVControlTint {
                selectButton.tintColor = UIColor(hex: tintColor)
            }
            self.selectButton = selectButton
            selectButton.titleLabel?.text = control.PVControlTitle
            selectButton.titleLabel?.font = UIFont.systemFont(ofSize: 9)
            selectButton.backgroundImage = UIImage(named: "button-thin", in: Bundle.module, with: nil)
            selectButton.backgroundImagePressed = UIImage(named: "button-thin-pressed", in: Bundle.module, with: nil)
            selectButton.delegate = self
            selectButton.titleEdgeInsets = UIEdgeInsets(top: 2, left: 2, bottom: 4, right: 2)
            selectButton.alpha = alpha
            selectButton.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin, .flexibleRightMargin]
            view.addSubview(selectButton)
            if let movableButton = selectButton as? MovableButtonView {
                movableButton.loadSavedPosition()
            }
        }
    }

    func layoutStartButton(control: ControlLayoutEntry) {
        let controlSize: CGSize = NSCoder.cgSize(for: control.PVControlSize)
        let yPadding: CGFloat = view.safeAreaInsets.bottom
        let spacing: CGFloat = 20
        var startFrame = CGRect(x: (view.frame.size.width / 2) + controlSize.width + (spacing / 2),
                                y: view.frame.height - yPadding - controlSize.height,
                                width: controlSize.width,
                                height: controlSize.height)

        if super.view.bounds.size.width > super.view.bounds.size.height || UIDevice.current.orientation.isLandscape || UIDevice.current.userInterfaceIdiom == .pad {
            if let selectButton = selectButton {
                startFrame = CGRect(x: selectButton.frame.maxX + spacing,
                                    y: selectButton.frame.origin.y,
                                    width: controlSize.width,
                                    height: controlSize.height)
            } else if let buttonGroup = buttonGroup {
                if buttonGroup.isHidden {
                    startFrame = CGRect(x: (view.frame.size.width / 2) + controlSize.width + (spacing / 2), y: view.frame.height - yPadding - controlSize.height, width: controlSize.width, height: controlSize.height)
                    if gripControl {
                        startFrame.origin.y = (UIScreen.main.bounds.height / 2)
                    }
                } else {
                    startFrame = CGRect(x: buttonGroup.frame.origin.x - controlSize.width + (controlSize.width / 3),
                                        y: view.frame.height - yPadding - controlSize.height,
                                        width: controlSize.width,
                                        height: controlSize.height)
                    if ["SG", "SCD", "32X", "SS", "PCFX"].contains(system.shortName.uppercased()) {
                        startFrame.origin.x -= (controlSize.width / 2)
                    }
                }
            }
        } else if super.view.bounds.size.width < super.view.bounds.size.height || UIDevice.current.orientation.isPortrait {
            startFrame = CGRect(x: (view.frame.size.width / 2) + controlSize.width + (spacing / 2),
                                y: view.frame.height - yPadding - controlSize.height,
                                width: controlSize.width,
                                height: controlSize.height)
            if selectButton != nil {
                startFrame.origin.x = (selectButton?.frame.maxX)! + spacing
            }
        }
        if startFrame.maxY >= view.frame.size.height {
            startFrame.origin.y -= (startFrame.maxY - view.frame.size.height) + yPadding
        }
        if let startButton = startButton {
            if !startButton.isCustomMoved {
                startButton.frame = startFrame
            }
        } else {
            let startButton = JSButton(frame: startFrame, label: control.PVControlTitle)
            startButton.tag = ControlTag.start.rawValue
            if let tintColor = control.PVControlTint {
                startButton.tintColor = UIColor(hex: tintColor)
            }
            self.startButton = startButton
            startButton.titleLabel?.text = control.PVControlTitle
            startButton.titleLabel?.font = UIFont.systemFont(ofSize: 9)
            startButton.backgroundImage = UIImage(named: "button-thin", in: Bundle.module, with: nil)
            startButton.backgroundImagePressed = UIImage(named: "button-thin-pressed", in: Bundle.module, with: nil)
            startButton.delegate = self
            startButton.titleEdgeInsets = UIEdgeInsets(top: 2, left: 2, bottom: 4, right: 2)
            startButton.alpha = alpha
            startButton.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin, .flexibleRightMargin]
            view.addSubview(startButton)
            if let movableButton = startButton as? MovableButtonView {
                movableButton.loadSavedPosition()
            }
        }
    }

    func layoutLeftAnalogButton(control: ControlLayoutEntry) {
        let controlSize: CGSize = NSCoder.cgSize(for: control.PVControlSize)
        let xPadding: CGFloat = view.safeAreaInsets.left + 10
        let yPadding: CGFloat = view.safeAreaInsets.bottom + 10
        let spacing: CGFloat = 10
        var layoutIsLandscape = false
        var leftAnalogFrame = CGRect(x: xPadding, y: view.frame.height - yPadding - controlSize.height, width: controlSize.width, height: controlSize.height)
        if super.view.bounds.size.width > super.view.bounds.size.height || UIDevice.current.orientation.isLandscape || UIDevice.current.userInterfaceIdiom == .pad {
            layoutIsLandscape = true
        }

        if !layoutIsLandscape {
            if let selectButton = selectButton {
                leftAnalogFrame = selectButton.frame.offsetBy(dx: 0, dy: controlSize.height + spacing / 2)
            }
        } else if buttonGroup?.isHidden ?? true, Defaults[.missingButtonsAlwaysOn] {
            if let selectButton = selectButton {
                leftAnalogFrame = selectButton.frame.offsetBy(dx: 0, dy: -(controlSize.height + spacing / 2))
                var selectButtonFrame = selectButton.frame
                swap(&leftAnalogFrame, &selectButtonFrame)
                selectButton.frame = selectButtonFrame
            }
        } else {
            leftAnalogFrame = (selectButton?.frame.offsetBy(dx: controlSize.width + spacing, dy: 0))!
        }
        if dPad != nil, !(dPad?.isHidden)! {
            leftAnalogFrame = CGRect(x: xPadding, y: (dPad?.frame.minY)!, width: controlSize.width, height: controlSize.height)
            if buttonGroup != nil, !(buttonGroup?.isHidden)! {
                leftAnalogFrame.origin.y = (dPad?.frame.minY)! < (buttonGroup?.frame.minY)! ? (dPad?.frame.minY)! : (buttonGroup?.frame.minY)!
            }
        }
        if Defaults[.allRightShoulders] || alwaysRightAlign {
            if zTriggerButton != nil {
                leftAnalogFrame.origin.x = (zTriggerButton?.frame.origin.x)! - controlSize.width
            } else if zTriggerButton == nil, rightShoulderButton != nil {
                leftAnalogFrame.origin.x = (rightShoulderButton?.frame.origin.x)! - controlSize.width
            }
        }
        leftAnalogFrame.origin.y -= controlSize.height * 3
        if let leftAnalogButton = leftAnalogButton {
            if !leftAnalogButton.isCustomMoved {
                leftAnalogButton.frame = leftAnalogFrame
            }
        } else {
            let leftAnalogButton = JSButton(frame: leftAnalogFrame, label: control.PVControlTitle)
            leftAnalogButton.tag = ControlTag.leftAnalog.rawValue
            if let tintColor = control.PVControlTint {
                leftAnalogButton.tintColor = UIColor(hex: tintColor)
            }
            self.leftAnalogButton = leftAnalogButton
            leftAnalogButton.titleLabel?.text = control.PVControlTitle
            leftAnalogButton.titleLabel?.font = UIFont.systemFont(ofSize: 9)
            leftAnalogButton.backgroundImage = UIImage(named: "button-thin", in: Bundle.module, with: nil)
            leftAnalogButton.backgroundImagePressed = UIImage(named: "button-thin-pressed", in: Bundle.module, with: nil)
            leftAnalogButton.delegate = self
            leftAnalogButton.titleEdgeInsets = UIEdgeInsets(top: 2, left: 2, bottom: 4, right: 2)
            leftAnalogButton.alpha = alpha
            leftAnalogButton.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin, .flexibleRightMargin]
            view.addSubview(leftAnalogButton)
            if let movableButton = leftAnalogButton as? MovableButtonView {
                movableButton.loadSavedPosition()
            }
        }
    }

    func layoutRightAnalogButton(control: ControlLayoutEntry) {
        let controlSize: CGSize = NSCoder.cgSize(for: control.PVControlSize)
        let xPadding: CGFloat = view.safeAreaInsets.left + 10
        let yPadding: CGFloat = view.safeAreaInsets.bottom + 10
        let spacing: CGFloat = 10
        var layoutIsLandscape = false
        var rightAnalogFrame = CGRect(x: view.frame.size.width - controlSize.width - xPadding, y: view.frame.height - yPadding - controlSize.height, width: controlSize.width, height: controlSize.height)
        if super.view.bounds.size.width > super.view.bounds.size.height || UIDevice.current.orientation.isLandscape || UIDevice.current.userInterfaceIdiom == .pad {
            layoutIsLandscape = true
        }
        if !layoutIsLandscape {
            rightAnalogFrame = (startButton?.frame.offsetBy(dx: 0, dy: controlSize.height + spacing / 2))!
        } else if buttonGroup?.isHidden ?? true, Defaults[.missingButtonsAlwaysOn] {
            if let startButton = startButton {
                rightAnalogFrame = startButton.frame.offsetBy(dx: 0, dy: -(controlSize.height + spacing / 2))
                var startButtonFrame = startButton.frame
                swap(&rightAnalogFrame, &startButtonFrame)
                startButton.frame = startButtonFrame
            } else {
                ELOG("startButton is nil")
            }
        } else {
            rightAnalogFrame = (startButton?.frame.offsetBy(dx: -(controlSize.width + spacing), dy: 0))!
        }
        if buttonGroup != nil, !(buttonGroup?.isHidden)! {
            rightAnalogFrame = CGRect(x: view.frame.size.width - controlSize.width - xPadding, y: (buttonGroup?.frame.minY)!, width: controlSize.width, height: controlSize.height)
            if dPad != nil, !(dPad?.isHidden)! {
                rightAnalogFrame.origin.y = (dPad?.frame.minY)! < (buttonGroup?.frame.minY)! ? (dPad?.frame.minY)! : (buttonGroup?.frame.minY)!
            }
        }
        rightAnalogFrame.origin.y -= controlSize.height * 3
        if leftShoulderButton != nil, !(leftShoulderButton?.isHidden)! {
            rightAnalogFrame.origin.y = (leftShoulderButton?.frame)!.origin.y - controlSize.height * 2
        }
        if let rightAnalogButton = rightAnalogButton {
            if !rightAnalogButton.isCustomMoved {
                rightAnalogButton.frame = rightAnalogFrame
            }
        } else {
            let rightAnalogButton = JSButton(frame: rightAnalogFrame, label: control.PVControlTitle)
            rightAnalogButton.tag = ControlTag.rightAnalog.rawValue
            if let tintColor = control.PVControlTint {
                rightAnalogButton.tintColor = UIColor(hex: tintColor)
            }
            self.rightAnalogButton = rightAnalogButton
            rightAnalogButton.titleLabel?.text = control.PVControlTitle
            rightAnalogButton.titleLabel?.font = UIFont.systemFont(ofSize: 9)
            rightAnalogButton.backgroundImage = UIImage(named: "button-thin", in: Bundle.module, with: nil)
            rightAnalogButton.backgroundImagePressed = UIImage(named: "button-thin-pressed", in: Bundle.module, with: nil)
            rightAnalogButton.delegate = self
            rightAnalogButton.titleEdgeInsets = UIEdgeInsets(top: 2, left: 2, bottom: 4, right: 2)
            rightAnalogButton.alpha = alpha
            rightAnalogButton.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin, .flexibleRightMargin]
            view.addSubview(rightAnalogButton)
            if let movableButton = rightAnalogButton as? MovableButtonView {
                movableButton.loadSavedPosition()
            }
        }
    }

    fileprivate func adjustJoystick() {
        guard let joyPad = joyPad else {
            return
        }

        // Deterministically set joypad visibility each call so hiding is
        // always reversed when the keyboard disconnects or the setting changes.
        let hideForKeyboard = PVControllerManager.shared.isKeyboardConnected
            && !Defaults[.onscreenJoypadWithKeyboard]
        joyPad.isHidden = hideForKeyboard
        joyPad2?.isHidden = hideForKeyboard
        if hideForKeyboard {
            DLOG("isKeyboardConnected=true, onscreenJoypadWithKeyboard=false — joypads hidden")
            return
        }

        guard let dPad = dPad, !dPad.isCustomMoved, !joyPad.isCustomMoved else {
            return
        }
        var joyPadFrame = joyPad.frame
        var dPadFrame = dPad.frame
        var minY = dPad.frame.minY
        var minX = dPad.frame.minX
        let spacing:CGFloat = 10
        let joystickOverDPad = alwaysJoypadOverDpad
        let overlap = (dPadFrame.maxY + joyPadFrame.height) - view.frame.height
        if overlap > 1 {
            dPadFrame.origin.y -= overlap
        }
        joyPadFrame.origin.y = dPadFrame.maxY
        // landscape joystick settings
        if view.frame.width > view.frame.height {
            if buttonGroup != nil {
                if joystickOverDPad {
                    dPadFrame.origin.y = view.frame.height - dPadFrame.size.height
                    joyPadFrame.origin.y = view.frame.height - dPadFrame.size.height - joyPadFrame.size.height * joyPadScale
                    minY = joyPadFrame.origin.y
                } else {
                    // Place DPad little more than halfway above JoyPad at the bottom
                    dPadFrame.origin.y = view.frame.height - dPadFrame.size.height - joyPadFrame.size.height * joyPadScale / 2 - spacing * 6
                    minY = dPadFrame.origin.y
                    if buttonGroup != nil, let buttonGroup = buttonGroup {
                        var buttonGroupFrame = buttonGroup.frame
                        // Place Button at the Bottom
                        buttonGroupFrame.origin.y = view.frame.height - buttonGroupFrame.size.height
                        // If Buttons are below DPad, Align with Dpad
                        if buttonGroupFrame.origin.y >= dPadFrame.origin.y {
                            buttonGroupFrame.origin.y = dPadFrame.origin.y
                        } else {
                            // If DPads are below Buttons, Align with Buttons
                            dPadFrame.origin.y = buttonGroupFrame.origin.y
                            joyPadFrame.origin.y = dPadFrame.maxY + spacing
                            minY = buttonGroupFrame.origin.y
                        }
                        if !(buttonGroup.isCustomMoved) { buttonGroup.frame = buttonGroupFrame }
                    }
                }
            }
            // Align Joypad Little more than halfway of Dpad Horizontally
            joyPadFrame.origin.x = dPad.frame.maxX - joyPadFrame.size.width * joyPadScale + spacing * 6
            joyPadFrame.origin.y -= spacing * 2
        } else {
            // portrait joystick settings
            if joystickOverDPad {
                joyPadFrame.origin.y = (buttonGroup?.frame.minY)! - joyPadFrame.size.height
                joyPadFrame.origin.x = dPad.frame.origin.x + spacing * 3
                minY = joyPadFrame.origin.y
            } else {
                joyPadFrame.origin.y = view.frame.height - joyPadFrame.size.height
                // if active control at bottom, provide smaller spacing
                if lrAtBottom {
                    joyPadFrame.origin.y -= spacing * 3
                } else {
                    // large bottom space
                    joyPadFrame.origin.y -= spacing * 10
                }
                // Center Align JoyPad w/ DPad
                joyPadFrame.origin.x = dPad.frame.origin.x + dPadFrame.size.width / 2 - (joyPadFrame.size.width) / 2
                // Place DPad 1 spacing above JoyPad
                dPadFrame.origin.y =  joyPadFrame.origin.y - dPadFrame.size.height - spacing
                // Store TopMost Y Coordinate to place rest of the buttons
                minY = dPadFrame.origin.y
                if buttonGroup != nil, let buttonGroup = buttonGroup {
                    var buttonGroupFrame = buttonGroup.frame
                    // Place Buttons 1 spacing above JoyPad
                    buttonGroupFrame.origin.y = joyPadFrame.origin.y - buttonGroupFrame.size.height - spacing
                    minY = buttonGroupFrame.origin.y < dPadFrame.origin.y ? buttonGroupFrame.origin.y : dPadFrame.origin.y
                    // If Buttons are above Dpad, move up Dpad to Button Position
                    if buttonGroupFrame.origin.y <= dPadFrame.origin.y {
                        dPadFrame.origin.y = buttonGroupFrame.origin.y
                        // Place JoyPad 2 spacing below DPad that was aligned with buttons
                        joyPadFrame.origin.y = dPadFrame.maxY + spacing * 2
                        minY = buttonGroupFrame.origin.y
                    }
                    if !(buttonGroup.isCustomMoved) { buttonGroup.frame = buttonGroupFrame }
                }
            }
        }
        // Keep layout the same for rest of the buttons
        if !dPad.isCustomMoved { dPad.frame = dPadFrame }
        if !joyPad.isCustomMoved { joyPad.frame = joyPadFrame }
        if leftShoulderButton != nil, !(leftShoulderButton?.isCustomMoved)! {
            if lrAtBottom {
                minY = view.frame.height
            }
            leftShoulderButton?.frame.origin.y = minY - (leftShoulderButton?.frame.size.height)!
            minX = (leftShoulderButton?.frame.origin.x)!
        }
        if leftShoulderButton2 != nil, !(leftShoulderButton2?.isCustomMoved)! {
            leftShoulderButton2?.frame.origin.y = minY - (leftShoulderButton?.frame.size.height)! - (leftShoulderButton2?.frame.size.height)!
            leftShoulderButton2?.frame.origin.x = minX
        }
        if leftAnalogButton != nil, !(leftAnalogButton?.isCustomMoved)! {
            leftAnalogButton?.frame.origin.y = minY  - (leftShoulderButton?.frame.size.height)! - (leftShoulderButton2?.frame.size.height)! - (leftAnalogButton?.frame.size.height)!
            leftAnalogButton?.frame.origin.x = minX
        }
        if selectButton != nil, !(selectButton?.isCustomMoved)! {
            selectButton?.frame.origin.y = view.frame.size.height - (selectButton?.frame.size.height)! * 2
            selectButton?.frame.origin.x = minX
        }
        if rightShoulderButton != nil, !(rightShoulderButton?.isCustomMoved)! {
            if lrAtBottom {
                minY = view.frame.height
            }
            rightShoulderButton?.frame.origin.y = minY - (rightShoulderButton?.frame.size.height)!
            minX = (rightShoulderButton?.frame.origin.x)!
        }
        if rightShoulderButton2 != nil, !(rightShoulderButton2?.isCustomMoved)! {
            rightShoulderButton2?.frame.origin.y = minY - (rightShoulderButton?.frame.size.height)! - (rightShoulderButton2?.frame.size.height)!
            rightShoulderButton2?.frame.origin.x = minX
        }
        if rightAnalogButton != nil, !(rightAnalogButton?.isCustomMoved)! {
            rightAnalogButton?.frame.origin.y = minY - (rightShoulderButton?.frame.size.height)! - (rightShoulderButton2?.frame.size.height)! - (rightAnalogButton?.frame.size.height)!
            rightAnalogButton?.frame.origin.x = minX
        }
        if startButton != nil, !(startButton?.isCustomMoved)! {
            startButton?.frame.origin.y = view.frame.size.height - (startButton?.frame.size.height)! * 2
            if selectButton == nil {
                if lrAtBottom {
                    startButton?.frame.origin.y = view.frame.size.height - (startButton?.frame.size.height)!
                }
                startButton?.frame.origin.x = view.frame.size.width / 2 - (startButton?.frame.size.width)! / 2
            } else {
                startButton?.frame.origin.x = view.frame.size.width - (startButton?.frame.size.width)!
            }
        }
        guard let joyPad2 = joyPad2, !joyPad2.isCustomMoved else {
            return
        }
        var joyPad2Frame = joyPad2.frame
        if buttonGroup != nil {
            let xPadding = CGFloat(10)
            joyPad2Frame = CGRect(x: view.frame.size.width -  joyPad2.frame.width - xPadding, y: (buttonGroup?.frame.minY)!, width:  joyPad2.frame.width, height:  joyPad2.frame.height)
            joyPad2Frame.origin.y = joyPad.frame.origin.y
            if view.frame.width > view.frame.height {
                if joystickOverDPad {
                    joyPad2Frame.origin.x = (buttonGroup?.frame.minX)! - joyPad2Frame.size.width * joyPad2Scale
                } else {
                    joyPad2Frame.origin.x = (buttonGroup?.frame.minX)! - joyPad2Frame.size.width * joyPad2Scale - spacing * 6
                    if buttonGroup != nil, let buttonGroup = buttonGroup {
                        var buttonGroupFrame = buttonGroup.frame
                        buttonGroupFrame.origin.y = view.frame.height - buttonGroupFrame.size.height - joyPad2Frame.size.height * joyPad2Scale / 2 - spacing * 6
                        if !(buttonGroup.isCustomMoved) { buttonGroup.frame = buttonGroupFrame }
                    }
                }
                if topRightJoyPad2 {
                    joyPad2Frame.origin.x = view.frame.width - joyPad2Frame.size.width
                    var minY: CGFloat = (buttonGroup?.frame.minY)!
                    if rightShoulderButton != nil { minY = (rightShoulderButton?.frame.minY)! }
                    if rightShoulderButton2 != nil { minY = (rightShoulderButton2?.frame.minY)! }
                    if rightAnalogButton != nil { minY = (rightAnalogButton?.frame.minY)! }
                    joyPad2Frame.origin.y = minY - joyPad2Frame.size.height + spacing * 3
                }
            } else {
                if joystickOverDPad {
                    joyPad2Frame.origin.x = (buttonGroup?.frame.minX)! + (buttonGroup?.frame.size.width)!/2 - (joyPad2Frame.size.width * joyPad2Scale) - spacing
                } else {
                    joyPad2Frame.origin.x = (buttonGroup?.frame.minX)! + (buttonGroup?.frame.size.width)!/2 - (joyPad2Frame.size.width * joyPad2Scale)
                }
            }
        }
        if !joyPad2.isCustomMoved { joyPad2.frame = joyPad2Frame }
    }
#endif // os(iOS)

    // Add a method to toggle button visibility
    @objc private func toggleButtonVisibility() {
        buttonsVisible = !buttonsVisible

        // Update visibility for all control elements
        allButtons.forEach { $0.isHidden = !buttonsVisible }

        // Update toggle button appearance
        updateToggleButtonAppearance()
    }

    // Add a method to update toggle button appearance
    private func updateToggleButtonAppearance() {
        // Button is now at the top: "down" = hide buttons (send them away from top), "up" = show
        toggleButton?.setImage(UIImage(systemName: buttonsVisible ? "chevron.down.circle" : "chevron.up.circle"), for: .normal)
    }

    // Add a method to setup the toggle button
    private func setupToggleButton() {
        guard toggleButton == nil else { return }
        /// Create and configure the toggle button
        let toggleButton = MenuButton(type: .custom)
        toggleButton.setImage(UIImage(systemName: "chevron.down.circle"), for: .normal)
        toggleButton.tintColor = .white
        toggleButton.backgroundColor = UIColor.black.withAlphaComponent(0.4) /// More transparent
        toggleButton.layer.cornerRadius = 25
        toggleButton.layer.masksToBounds = true
        toggleButton.addTarget(self, action: #selector(toggleButtons), for: .touchUpInside)
        // The toggle button is the only always-on HUD control; never hide it.
        toggleButton.isHidden = false
        #if !os(tvOS)
        toggleButton.isPointerInteractionEnabled = true
        #endif

        /// Anchor to the top-right safe area corner.
        /// The bottom strip is occupied by skin buttons (D-pad, face, Start/Select);
        /// the top strip is reliably free of skin controls on every layout.
        toggleButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toggleButton)
        NSLayoutConstraint.activate([
            toggleButton.widthAnchor.constraint(equalToConstant: 50),
            toggleButton.heightAnchor.constraint(equalToConstant: 50),
            toggleButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
            toggleButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
        ])

        /// Keep the toggle button above all other subviews at all times
        view.bringSubviewToFront(toggleButton)
        self.toggleButton = toggleButton
    }

    // Add this method to adjust D-Pad position
    private func adjustDPadPosition() {
        guard let dPad = dPad, !dPad.isCustomMoved else { return }
        guard let toggleButton = toggleButton else { return }

        /// Only adjust when the D-Pad frame actually intersects the toggle button area.
        /// Previous code had an operator-precedence bug (`?? 0 - minSpacing` instead of
        /// `(?? 0) - minSpacing`) that made the condition always true, pushing the D-Pad
        /// off to safeAreaInsets.left on every layout pass.
        let toggleMinX = toggleButton.frame.minX
        let minSpacing: CGFloat = 16
        let dPadFrame = dPad.frame

        guard dPadFrame.maxX > toggleMinX - minSpacing else { return }

        /// Shift D-Pad right so it clears the toggle button with the required spacing.
        var newFrame = dPadFrame
        newFrame.origin.x = toggleMinX - minSpacing - dPadFrame.width

        /// Clamp to safe area so we never push the D-Pad fully off screen.
        if newFrame.origin.x < view.safeAreaInsets.left {
            newFrame.origin.x = view.safeAreaInsets.left
        }
        dPad.frame = newFrame
    }

    // Update the toggleButtons method
    @objc private func toggleButtons() {
        buttonsVisible.toggle()

        /// Animate the visibility change
        UIView.animate(withDuration: 0.3) {
            for button in self.allButtons {
                button.alpha = self.buttonsVisible ? 1.0 : 0.0
                // Also set isHidden to properly hide the controls, especially joypads
                button.isHidden = !self.buttonsVisible
                // Disable user interaction when hidden to prevent ghost touches
                button.isUserInteractionEnabled = self.buttonsVisible
            }
            self.toggleButton?.setImage(
                UIImage(systemName: self.buttonsVisible ? "chevron.up.circle" : "chevron.down.circle"),
                for: .normal
            )
        }
    }

    // MARK: - Quick Action Buttons Setup

    private func setupQuickActionButtons() {
        guard fastForwardButton == nil else { return }

        let buttonSize: CGFloat = 44
        let spacing: CGFloat = 8
        // All quick-action buttons live in the TOP strip, chained left from the toggle button.
        // Skin control buttons (D-pad, face, Start/Select, shoulder) occupy the bottom/sides;
        // the top safe-area edge is reliably free on every skin layout.
        let safeTop = view.safeAreaLayoutGuide.topAnchor
        let topInset: CGFloat = 4

        // Fast Forward — top row, immediately left of the toggle button
        let ffButton = makeQuickActionButton(
            systemImage: "forward.fill",
            accessibilityLabel: "Fast Forward"
        )
        ffButton.addTarget(self, action: #selector(fastForwardTapped), for: .touchUpInside)
        ffButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(ffButton)
        // If a toggle button exists, chain left of it; otherwise fall back to trailing safe area.
        let ffTrailingAnchor: NSLayoutXAxisAnchor = toggleButton.map { $0.leadingAnchor } ?? view.safeAreaLayoutGuide.trailingAnchor
        let ffTrailingConstant: CGFloat = toggleButton != nil ? -spacing : -8
        NSLayoutConstraint.activate([
            ffButton.widthAnchor.constraint(equalToConstant: buttonSize),
            ffButton.heightAnchor.constraint(equalToConstant: buttonSize),
            ffButton.trailingAnchor.constraint(equalTo: ffTrailingAnchor, constant: ffTrailingConstant),
            ffButton.topAnchor.constraint(equalTo: safeTop, constant: topInset),
        ])
        self.fastForwardButton = ffButton
        quickActionButtons.append(ffButton)

        // Quick Save / Load — top row, stacked left of FF
        if coreSupportsStateSaves {
            let qlButton = makeQuickActionButton(
                systemImage: "arrow.counterclockwise",
                accessibilityLabel: "Quick Load"
            )
            qlButton.addTarget(self, action: #selector(quickLoadTapped), for: .touchUpInside)
            qlButton.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(qlButton)
            NSLayoutConstraint.activate([
                qlButton.widthAnchor.constraint(equalToConstant: buttonSize),
                qlButton.heightAnchor.constraint(equalToConstant: buttonSize),
                qlButton.trailingAnchor.constraint(equalTo: ffButton.leadingAnchor, constant: -spacing),
                qlButton.topAnchor.constraint(equalTo: safeTop, constant: topInset),
            ])
            self.quickLoadButton = qlButton
            quickActionButtons.append(qlButton)

            let qsButton = makeQuickActionButton(
                systemImage: "square.and.arrow.down",
                accessibilityLabel: "Quick Save"
            )
            qsButton.addTarget(self, action: #selector(quickSaveTapped), for: .touchUpInside)
            qsButton.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(qsButton)
            NSLayoutConstraint.activate([
                qsButton.widthAnchor.constraint(equalToConstant: buttonSize),
                qsButton.heightAnchor.constraint(equalToConstant: buttonSize),
                qsButton.trailingAnchor.constraint(equalTo: qlButton.leadingAnchor, constant: -spacing),
                qsButton.topAnchor.constraint(equalTo: safeTop, constant: topInset),
            ])
            self.quickSaveButton = qsButton
            quickActionButtons.append(qsButton)
        }

        // Virtual Keyboard/Mouse toggles — top-left, anchored to safeArea leading.
        // Placed on the opposite (left) side from the main action cluster so they don't
        // crowd the right-side row and stay clear of the JIT indicator at top-left leading.
        #if !os(tvOS)
        if coreSupportsVirtualKeyboard {
            let kbButton = makeQuickActionButton(
                systemImage: "keyboard",
                accessibilityLabel: "Toggle Virtual Keyboard"
            )
            kbButton.addTarget(self, action: #selector(keyboardToggleTapped), for: .touchUpInside)
            kbButton.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(kbButton)
            // Offset enough from leading to clear the JIT status pill (~100 pt wide at most).
            NSLayoutConstraint.activate([
                kbButton.widthAnchor.constraint(equalToConstant: buttonSize),
                kbButton.heightAnchor.constraint(equalToConstant: buttonSize),
                kbButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 108),
                kbButton.topAnchor.constraint(equalTo: safeTop, constant: topInset),
            ])
            self.keyboardToggleButton = kbButton
            quickActionButtons.append(kbButton)
        }

        if coreSupportsVirtualMouse {
            let mouseButton = makeQuickActionButton(
                systemImage: "cursorarrow",
                accessibilityLabel: "Toggle Virtual Mouse"
            )
            mouseButton.addTarget(self, action: #selector(mouseToggleTapped), for: .touchUpInside)
            mouseButton.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(mouseButton)
            let mouseLeadingAnchor: NSLayoutXAxisAnchor = keyboardToggleButton.map {
                $0.trailingAnchor
            } ?? view.safeAreaLayoutGuide.leadingAnchor
            let mouseLeadingConstant: CGFloat = keyboardToggleButton != nil ? spacing : 108
            NSLayoutConstraint.activate([
                mouseButton.widthAnchor.constraint(equalToConstant: buttonSize),
                mouseButton.heightAnchor.constraint(equalToConstant: buttonSize),
                mouseButton.leadingAnchor.constraint(equalTo: mouseLeadingAnchor, constant: mouseLeadingConstant),
                mouseButton.topAnchor.constraint(equalTo: safeTop, constant: topInset),
            ])
            self.mouseToggleButton = mouseButton
            quickActionButtons.append(mouseButton)
        }
        #endif // !os(tvOS)

        // Record button — iOS only (ReplayKit not available on tvOS in the same way)
        #if os(iOS)
        setupRecordButton(buttonSize: buttonSize, spacing: spacing, safeTop: safeTop, topInset: topInset)
        #endif
    }

    #if os(iOS)
    private func setupRecordButton(buttonSize: CGFloat, spacing: CGFloat, safeTop: NSLayoutYAxisAnchor, topInset: CGFloat) {
        guard PVRecordingManager.shared.isAvailable else { return }

        let recButton = makeQuickActionButton(
            systemImage: "record.circle",
            accessibilityLabel: "Record"
        )
        recButton.addTarget(self, action: #selector(recordTapped), for: .touchUpInside)
        recButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(recButton)

        // Place left of quick-save (if it exists), else left of quick-load, else left of FF.
        let recTrailingButton: UIButton? = quickSaveButton ?? quickLoadButton ?? fastForwardButton
        let recTrailingAnchor: NSLayoutXAxisAnchor = recTrailingButton.map { $0.leadingAnchor } ?? view.safeAreaLayoutGuide.trailingAnchor
        let recTrailingConstant: CGFloat = recTrailingButton != nil ? -spacing : -8

        NSLayoutConstraint.activate([
            recButton.widthAnchor.constraint(equalToConstant: buttonSize),
            recButton.heightAnchor.constraint(equalToConstant: buttonSize),
            recButton.trailingAnchor.constraint(equalTo: recTrailingAnchor, constant: recTrailingConstant),
            recButton.topAnchor.constraint(equalTo: safeTop, constant: topInset),
        ])
        self.recordButton = recButton
        quickActionButtons.append(recButton)
        updateRecordButtonAppearance()
    }
    #endif

    /// Resets the alpha of quick-action buttons to 1.0 after controller opacity has been
    /// applied globally.  Game-controller buttons dim with `controllerOpacity`, but the
    /// quick-action strip should remain fully opaque at all times.
    private func restoreQuickActionButtonAlpha() {
        var buttons: [UIButton?] = [fastForwardButton, quickSaveButton, quickLoadButton]
        #if os(iOS)
        buttons.append(recordButton)
        #endif
        #if !os(tvOS)
        buttons += [keyboardToggleButton, mouseToggleButton]
        #endif
        buttons.compactMap { $0 }.forEach { $0.alpha = 1.0 }
    }

    private func makeQuickActionButton(systemImage: String, accessibilityLabel: String) -> UIButton {
        let button = MenuButton(type: .custom)
        button.setImage(UIImage(systemName: systemImage), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        button.layer.cornerRadius = 22
        button.layer.masksToBounds = true
        button.accessibilityLabel = accessibilityLabel
        #if !os(tvOS)
        button.isPointerInteractionEnabled = true
        #endif
        return button
    }

    @objc private func quickSaveTapped() {
        vibrate()
        guard let emulatorController = parent as? (any PVEmualatorControllerProtocol) else {
            ELOG("QuickSave: parent is not PVEmualatorControllerProtocol")
            return
        }
        Task { @MainActor in
            do {
                try await emulatorController.quicksave()
            } catch {
                ELOG("QuickSave failed: \(error)")
            }
        }
    }

    @objc private func quickLoadTapped() {
        vibrate()
        guard let emulatorController = parent as? (any PVEmualatorControllerProtocol) else {
            ELOG("QuickLoad: parent is not PVEmualatorControllerProtocol")
            return
        }
        Task { @MainActor in
            do {
                try await emulatorController.quickload()
            } catch {
                ELOG("QuickLoad failed: \(error)")
            }
        }
    }

    @objc private func fastForwardTapped() {
        guard let core = emulatorCore as? PVEmulatorCore else { return }

        // Sync isFastForwardActive from core.gameSpeed in case another code path
        // changed the speed without going through this toggle (e.g. speed menu,
        // or a hardcore reset from PVEmulatorViewController+Achievements).
        isFastForwardActive = (core.gameSpeed == .fast || core.gameSpeed == .veryFast)
        let willEnableFastForward = !isFastForwardActive

        // RetroAchievements hardcore mode disallows entering fast-forward,
        // but should still allow returning to normal speed.
        if willEnableFastForward,
           let emulatorViewController = parent as? PVEmulatorViewController,
           emulatorViewController.achievementsBlocksFastForward() {
            presentError(
                "Fast-forward is disabled in RetroAchievements Hardcore Mode.",
                source: view
            )
            return
        }

        isFastForwardActive.toggle()
        core.gameSpeed = isFastForwardActive ? .fast : .normal
        updateFastForwardButtonAppearance()
    }

    private func updateFastForwardButtonAppearance() {
        fastForwardButton?.setImage(UIImage(systemName: "forward.fill"), for: .normal)
        fastForwardButton?.tintColor = isFastForwardActive ? .systemYellow : .white
        fastForwardButton?.backgroundColor = isFastForwardActive
            ? UIColor.systemOrange.withAlphaComponent(0.6)
            : UIColor.black.withAlphaComponent(0.4)
    }

    /// Syncs the fast-forward button visual state with the emulator core's current speed.
    /// Called externally (e.g. when hardcore mode resets the core to `.normal`) so the
    /// button does not remain highlighted after a speed change from outside this VC.
    public func syncFastForwardDisplay() {
        guard let core = emulatorCore as? PVEmulatorCore else { return }
        isFastForwardActive = (core.gameSpeed == .fast || core.gameSpeed == .veryFast)
        updateFastForwardButtonAppearance()
    }

    #if !os(tvOS)
    @objc private func keyboardToggleTapped() {
        vibrate()
        guard let emulatorVC = parent as? PVEmulatorViewController else { return }
        emulatorVC.toggleVirtualKeyboard()
        updateKeyboardButtonAppearance()
    }

    @objc private func mouseToggleTapped() {
        vibrate()
        guard let emulatorVC = parent as? PVEmulatorViewController else { return }
        emulatorVC.toggleVirtualMouse()
        updateMouseButtonAppearance()
    }

    private func updateKeyboardButtonAppearance() {
        // Read from VirtualInputState (single source of truth) so the button
        // stays accurate regardless of which code path toggled the overlay.
        let isActive = (parent as? PVEmulatorViewController)?.virtualInputState.isKeyboardVisible ?? false
        keyboardToggleButton?.tintColor = isActive ? .systemYellow : .white
        keyboardToggleButton?.backgroundColor = isActive
            ? UIColor.systemBlue.withAlphaComponent(0.6)
            : UIColor.black.withAlphaComponent(0.4)
    }

    private func updateMouseButtonAppearance() {
        let isActive = (parent as? PVEmulatorViewController)?.virtualInputState.isMouseVisible ?? false
        mouseToggleButton?.tintColor = isActive ? .systemYellow : .white
        mouseToggleButton?.backgroundColor = isActive
            ? UIColor.systemBlue.withAlphaComponent(0.6)
            : UIColor.black.withAlphaComponent(0.4)
    }
    #endif // !os(tvOS)

    // MARK: - Record Button

    #if os(iOS)
    @objc private func recordTapped() {
        vibrate()
        #if canImport(FreemiumKit)
        // Non-AppStore builds (dev / TestFlight / sideloaded) are treated as premium.
        if AppState.shared.isAppStore {
            guard FreemiumKit.shared.purchasedTier != nil else {
                // Recording is a Plus feature; direct the user to the pause menu where
                // the paywall is presented via PaidFeatureView.
                let alert = UIAlertController(
                    title: "Provenance Plus Required",
                    message: "Gameplay recording is a Provenance Plus feature. Open the pause menu to upgrade.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
                return
            }
        }
        #endif
        guard let emulatorVC = parent as? PVEmulatorViewController else {
            ELOG("Record: parent is not PVEmulatorViewController")
            return
        }
        emulatorVC.toggleScreenRecording()
        // Appearance is driven by the async recording-state notifications from the VC;
        // no local delay needed here.
    }

    public func updateRecordButtonAppearance() {
        let isRecording = AppState.shared.emulationUIState.isRecording
        let image = isRecording ? "stop.circle.fill" : "record.circle"
        recordButton?.setImage(UIImage(systemName: image), for: .normal)
        recordButton?.tintColor = isRecording ? .systemRed : .white
        recordButton?.backgroundColor = isRecording
            ? UIColor.systemRed.withAlphaComponent(0.3)
            : UIColor.black.withAlphaComponent(0.4)

        // Update accessibility so VoiceOver reflects current recording state.
        recordButton?.accessibilityLabel = isRecording ? "Stop Recording" : "Record"
        recordButton?.accessibilityValue = isRecording ? "Recording" : "Not Recording"

        if isRecording {
            startRecordPulse()
        } else {
            stopRecordPulse()
        }
    }

    private func startRecordPulse() {
        stopRecordPulse()
        recordPulseTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            guard let btn = self?.recordButton else { return }
            UIView.animate(withDuration: 0.4, animations: {
                btn.alpha = 0.4
            }) { _ in
                UIView.animate(withDuration: 0.4) {
                    btn.alpha = 1.0
                }
            }
        }
    }

    private func stopRecordPulse() {
        recordPulseTimer?.invalidate()
        recordPulseTimer = nil
        recordButton?.alpha = 1.0
        recordButton?.layer.removeAllAnimations()
    }
    #endif // os(iOS)

    #if !os(iOS)
    // OSDRecordingObserver stub — recording is iOS-only; no-op satisfies the protocol on all other platforms.
    public func updateRecordButtonAppearance() {}
    #endif
}

#endif // UIKit
