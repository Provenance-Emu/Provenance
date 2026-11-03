//
//  EmulatorQuickActionBar.swift
//  PVUIBase
//
//  The row of quick-action buttons shown in desktop input mode (Mac, and iPad opted in to
//  keyboard/gamepad navigation), where no skin or touch overlay is on screen: fast-forward,
//  quick save/load, recording, and the virtual keyboard and mouse toggles.
//

#if os(iOS) && !targetEnvironment(macCatalyst)
import Combine
import Defaults
import PVEmulatorCore
import PVLogging
import PVSettings
import UIKit
#if canImport(FreemiumKit)
import FreemiumKit
#endif

/// Quick-action buttons for desktop input mode, added straight to the emulator view.
///
/// Trailing edge: record, quick save, quick load, fast-forward. Leading edge (past the menu
/// button): virtual keyboard and mouse toggles. The row fades out after a few seconds; a
/// click on the top strip brings it back.
@MainActor
final class EmulatorQuickActionBar: NSObject {
    private enum Layout {
        static let buttonSize: CGFloat = 44
        static let spacing: CGFloat = 8
        static let topInset: CGFloat = 4
        static let trailingInset: CGFloat = 8
        /// Clears the menu button at the top-leading corner.
        static let leadingInset: CGFloat = 108
        /// Height of the invisible top strip that reveals the row.
        static let tapZoneHeight: CGFloat = 60
    }

    private enum Timing {
        static let autoHideDelay: TimeInterval = 3
        static let fadeDuration: TimeInterval = 0.25
        static let recordPulseInterval: TimeInterval = 0.8
        static let recordPulseHalfDuration: TimeInterval = 0.4
    }

    private weak var host: PVEmulatorViewController?
    private let tapZone = UIView()
    private let trailingRow = UIStackView()
    private let leadingRow = UIStackView()
    private var fastForwardButton: UIButton?
    private var recordButton: UIButton?
    private var keyboardButton: UIButton?
    private var mouseButton: UIButton?
    private var autoHideTimer: Timer?
    private var recordPulseTimer: Timer?
    private var isVisible = true
    private var cancellables: Set<AnyCancellable> = []
    private let feedbackGenerator = UISelectionFeedbackGenerator()

    /// One quick-action button.
    enum Action: Equatable {
        case record, quickSave, quickLoad, fastForward, keyboard, mouse

        var systemImage: String {
            switch self {
            case .record: "record.circle"
            case .quickSave: "square.and.arrow.down"
            case .quickLoad: "arrow.counterclockwise"
            case .fastForward: "forward.fill"
            case .keyboard: "keyboard"
            case .mouse: "cursorarrow"
            }
        }

        var label: String {
            switch self {
            case .record: "Record"
            case .quickSave: "Quick Save"
            case .quickLoad: "Quick Load"
            case .fastForward: "Fast Forward"
            case .keyboard: "Toggle Virtual Keyboard"
            case .mouse: "Toggle Virtual Mouse"
            }
        }
    }

    /// What the running core and app support, which decides the buttons.
    struct Capabilities {
        var supportsSaveStates: Bool
        var supportsKeyboard: Bool
        var supportsMouse: Bool
        var recordingAvailable: Bool
    }

    /// The buttons in each row, left to right. Fast-forward is always there.
    nonisolated static func rows(for capabilities: Capabilities) -> (leading: [Action], trailing: [Action]) {
        var trailing: [Action] = []
        if capabilities.recordingAvailable { trailing.append(.record) }
        if capabilities.supportsSaveStates { trailing += [.quickSave, .quickLoad] }
        trailing.append(.fastForward)
        var leading: [Action] = []
        if capabilities.supportsKeyboard { leading.append(.keyboard) }
        if capabilities.supportsMouse { leading.append(.mouse) }
        return (leading, trailing)
    }

    /// Views `radicalCleanup()` must keep.
    var views: [UIView] { [tapZone, trailingRow, leadingRow] }

    init(host: PVEmulatorViewController) {
        self.host = host
        super.init()
        install(in: host.view, core: host.core)
        observeVirtualInputState(host.virtualInputState)
        scheduleAutoHide()
    }

    func invalidate() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
        stopRecordPulse()
        cancellables.removeAll()
        views.forEach { $0.removeFromSuperview() }
    }

    func bringToFront() {
        guard let superview = trailingRow.superview else { return }
        superview.bringSubviewToFront(tapZone)
        superview.bringSubviewToFront(trailingRow)
        superview.bringSubviewToFront(leadingRow)
    }

    // MARK: - Setup

    private func install(in view: UIView, core: PVEmulatorCore) {
        tapZone.backgroundColor = .clear
        tapZone.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(toggleVisibility)))

        for row in [trailingRow, leadingRow] {
            row.axis = .horizontal
            row.spacing = Layout.spacing
        }

        let rows = Self.rows(for: Capabilities(
            supportsSaveStates: core.supportsSaveStates,
            supportsKeyboard: (core as? KeyboardResponder)?.gameSupportsKeyboard == true,
            supportsMouse: (core as? MouseResponder)?.gameSupportsMouse == true,
            recordingAvailable: PVRecordingManager.shared.isAvailable
        ))
        rows.trailing.map(makeButton).forEach(trailingRow.addArrangedSubview)
        rows.leading.map(makeButton).forEach(leadingRow.addArrangedSubview)

        // The strip goes in first so a click on a button reaches the button.
        for subview in views {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }
        let safeArea = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            tapZone.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tapZone.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tapZone.topAnchor.constraint(equalTo: view.topAnchor),
            tapZone.heightAnchor.constraint(equalToConstant: Layout.tapZoneHeight),
            trailingRow.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -Layout.trailingInset),
            trailingRow.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: Layout.topInset),
            leadingRow.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: Layout.leadingInset),
            leadingRow.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: Layout.topInset)
        ])

        syncFastForwardDisplay()
        updateRecordButtonAppearance()
    }

    private func makeButton(_ action: Action) -> UIButton {
        let button = makeButton(systemImage: action.systemImage, label: action.label, action: selector(for: action))
        switch action {
        case .record: recordButton = button
        case .fastForward: fastForwardButton = button
        case .keyboard: keyboardButton = button
        case .mouse: mouseButton = button
        case .quickSave, .quickLoad: break
        }
        return button
    }

    private func selector(for action: Action) -> Selector {
        switch action {
        case .record: #selector(recordTapped)
        case .quickSave: #selector(quickSaveTapped)
        case .quickLoad: #selector(quickLoadTapped)
        case .fastForward: #selector(fastForwardTapped)
        case .keyboard: #selector(keyboardTapped)
        case .mouse: #selector(mouseTapped)
        }
    }

    private func makeButton(systemImage: String, label: String, action: Selector) -> UIButton {
        let button = MenuButton(type: .custom)
        button.setImage(UIImage(systemName: systemImage), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        button.layer.cornerRadius = Layout.buttonSize / 2
        button.layer.masksToBounds = true
        button.accessibilityLabel = label
        button.isPointerInteractionEnabled = true
        button.addTarget(self, action: action, for: .touchUpInside)
        // Any interaction restarts the auto-hide countdown, so the row never fades mid-use.
        button.addTarget(self, action: #selector(keepAlive), for: .touchDown)
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: Layout.buttonSize),
            button.heightAnchor.constraint(equalToConstant: Layout.buttonSize)
        ])
        return button
    }

    private func observeVirtualInputState(_ state: VirtualInputState) {
        state.$isKeyboardVisible
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isActive in self?.keyboardButton.map { Self.style($0, active: isActive) } }
            .store(in: &cancellables)
        state.$isMouseVisible
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isActive in self?.mouseButton.map { Self.style($0, active: isActive) } }
            .store(in: &cancellables)
    }

    private static func style(_ button: UIButton, active: Bool) {
        button.tintColor = active ? .systemYellow : .white
        button.backgroundColor = active ? UIColor.systemBlue.withAlphaComponent(0.6) : UIColor.black.withAlphaComponent(0.4)
    }

    // MARK: - Visibility

    @objc private func toggleVisibility() {
        setVisible(!isVisible)
    }

    @objc private func keepAlive() {
        guard isVisible else { return }
        scheduleAutoHide()
    }

    private func setVisible(_ visible: Bool) {
        isVisible = visible
        let rows = [trailingRow, leadingRow]
        UIView.animate(withDuration: Timing.fadeDuration) {
            rows.forEach { $0.alpha = visible ? 1 : 0 }
        }
        rows.forEach { $0.isUserInteractionEnabled = visible }
        if visible {
            scheduleAutoHide()
        } else {
            autoHideTimer?.invalidate()
            autoHideTimer = nil
        }
    }

    private func scheduleAutoHide() {
        autoHideTimer?.invalidate()
        autoHideTimer = Timer.scheduledTimer(withTimeInterval: Timing.autoHideDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.setVisible(false) }
        }
    }

    // MARK: - Actions

    private func vibrate() {
        if Defaults[.buttonVibration] {
            feedbackGenerator.selectionChanged()
        }
    }

    @objc private func quickSaveTapped() {
        vibrate()
        guard let host else { return }
        Task { @MainActor in
            do {
                _ = try await host.quicksave()
            } catch {
                ELOG("QuickSave failed: \(error)")
            }
        }
    }

    @objc private func quickLoadTapped() {
        vibrate()
        guard let host else { return }
        Task { @MainActor in
            do {
                _ = try await host.quickload()
            } catch {
                ELOG("QuickLoad failed: \(error)")
            }
        }
    }

    @objc private func fastForwardTapped() {
        guard let host else { return }
        // Read the speed from the core, since the pause menu or hardcore mode can change it too.
        let isFast = host.core.gameSpeed == .fast || host.core.gameSpeed == .veryFast
        // Hardcore mode blocks entering fast-forward but still allows leaving it.
        host.setGameSpeedRespectingAchievements(isFast ? .normal : .fast)
    }

    /// Matches the fast-forward button to the core's speed after any speed change.
    func syncFastForwardDisplay() {
        guard let host, let button = fastForwardButton else { return }
        let isFast = host.core.gameSpeed == .fast || host.core.gameSpeed == .veryFast
        button.tintColor = isFast ? .systemYellow : .white
        button.backgroundColor = isFast ? UIColor.systemOrange.withAlphaComponent(0.6) : UIColor.black.withAlphaComponent(0.4)
    }

    @objc private func keyboardTapped() {
        vibrate()
        host?.toggleVirtualKeyboard()
    }

    @objc private func mouseTapped() {
        vibrate()
        host?.toggleVirtualMouse()
    }

    // MARK: - Recording

    @objc private func recordTapped() {
        vibrate()
        guard let host else { return }
        #if canImport(FreemiumKit)
        // Non-App Store builds (dev, TestFlight, sideloaded) count as Plus.
        if AppState.shared.isAppStore, !PlusEntitlement.isUnlocked {
            host.present(PVAlert(
                title: "Provenance Plus Required",
                message: "Gameplay recording is a Provenance Plus feature. Open the pause menu to upgrade."
            ))
            return
        }
        #endif
        // The appearance follows the recording-state notifications the host posts.
        host.toggleScreenRecording()
    }

    func updateRecordButtonAppearance() {
        guard let button = recordButton else { return }
        let isRecording = AppState.shared.emulationUIState.isRecording
        button.setImage(UIImage(systemName: isRecording ? "stop.circle.fill" : "record.circle"), for: .normal)
        button.tintColor = isRecording ? .systemRed : .white
        button.backgroundColor = isRecording ? UIColor.systemRed.withAlphaComponent(0.3) : UIColor.black.withAlphaComponent(0.4)
        button.accessibilityLabel = isRecording ? "Stop Recording" : "Record"
        button.accessibilityValue = isRecording ? "Recording" : "Not Recording"
        if isRecording {
            startRecordPulse()
        } else {
            stopRecordPulse()
        }
    }

    private func startRecordPulse() {
        stopRecordPulse()
        recordPulseTimer = Timer.scheduledTimer(withTimeInterval: Timing.recordPulseInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let button = self?.recordButton else { return }
                // `.allowUserInteraction` keeps the button (and every other touch) live: without it
                // the back-to-back fades ignore interaction for as long as recording runs, and a
                // second click to stop recording does nothing.
                UIView.animate(withDuration: Timing.recordPulseHalfDuration, delay: 0, options: [.allowUserInteraction], animations: {
                    button.alpha = 0.4
                }, completion: { _ in
                    UIView.animate(withDuration: Timing.recordPulseHalfDuration, delay: 0, options: [.allowUserInteraction]) {
                        button.alpha = 1
                    }
                })
            }
        }
    }

    private func stopRecordPulse() {
        recordPulseTimer?.invalidate()
        recordPulseTimer = nil
        recordButton?.alpha = 1
        recordButton?.layer.removeAllAnimations()
    }
}
#endif
