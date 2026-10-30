//
//  PVAlert.swift
//  PVUI
//
//  The one way Provenance shows an alert. SwiftUI-rendered (`PVAlertView`),
//  presented modally from the topmost view controller so it draws above the
//  emulator, sheets and full-screen covers alike. Replaces UIAlertController
//  and the old TVAlertController.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(GameController)
import GameController
#endif
import PVLogging

// MARK: - Model

/// What the user entered when they picked an action.
public struct PVAlertResponse {
    /// Text field values, in the order the fields were declared.
    public let textValues: [String]
    /// The toggle's final value, or `false` when the alert has no toggle.
    public let toggleValue: Bool

    public var text: String { textValues.first ?? "" }
}

public struct PVAlertAction: Identifiable {
    public enum Role {
        case `default`
        case cancel
        case destructive
    }

    public let id = UUID()
    public let title: String
    public let subtitle: String?
    public let role: Role
    let handler: ((PVAlertResponse) -> Void)?

    public init(_ title: String, subtitle: String? = nil, role: Role = .default, handler: (() -> Void)? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.role = role
        self.handler = handler.map { action in { _ in action() } }
    }

    public init(
        _ title: String,
        subtitle: String? = nil,
        role: Role = .default,
        responseHandler: @escaping (PVAlertResponse) -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.role = role
        self.handler = responseHandler
    }

    public static func ok(_ handler: (() -> Void)? = nil) -> PVAlertAction {
        PVAlertAction(NSLocalizedString("OK", comment: "OK"), handler: handler)
    }

    public static func cancel(_ title: String? = nil, handler: (() -> Void)? = nil) -> PVAlertAction {
        PVAlertAction(title ?? NSLocalizedString("Cancel", comment: "Cancel"), role: .cancel, handler: handler)
    }
}

public struct PVAlertTextField {
    public var placeholder: String
    public var text: String
    public var isSecure: Bool

    public init(placeholder: String = "", text: String = "", isSecure: Bool = false) {
        self.placeholder = placeholder
        self.text = text
        self.isSecure = isSecure
    }
}

public struct PVAlertToggle {
    public var title: String
    public var isOn: Bool

    public init(_ title: String, isOn: Bool) {
        self.title = title
        self.isOn = isOn
    }
}

public struct PVAlert: Identifiable {
    public enum Style {
        /// A centered dialog.
        case alert
        /// A list of choices. Renders the same dialog, with the cancel action kept last.
        case actionSheet
    }

    public let id = UUID()
    public var title: String
    public var message: String?
    public var type: RetroAlertType
    public var style: Style
    public var actions: [PVAlertAction]
    public var textFields: [PVAlertTextField]
    public var toggle: PVAlertToggle?
    /// The action focused when the alert appears. Defaults to the first non-cancel action.
    public var preferredActionID: PVAlertAction.ID?
    /// Runs when the alert is taken down without an answer (`PVAlertCenter.dismissCurrent()`).
    var onDismissedWithoutAnswer: (() -> Void)?

    public init(
        title: String,
        message: String? = nil,
        type: RetroAlertType = .standard,
        style: Style = .alert,
        actions: [PVAlertAction] = [],
        textFields: [PVAlertTextField] = [],
        toggle: PVAlertToggle? = nil,
        preferredActionID: PVAlertAction.ID? = nil
    ) {
        self.title = title
        self.message = message
        self.type = type
        self.style = style
        self.actions = actions.isEmpty ? [.ok()] : actions
        self.textFields = textFields
        self.toggle = toggle
        self.preferredActionID = preferredActionID
    }

    /// Menu / B / a background tap only dismiss an alert that offers a way out.
    /// An alert whose only button is e.g. "Return to Library" must be answered.
    public var cancelAction: PVAlertAction? {
        actions.first { $0.role == .cancel }
    }

    /// Actions in display order: an action sheet keeps its cancel action last.
    var orderedActions: [PVAlertAction] {
        guard style == .actionSheet, let cancel = cancelAction else { return actions }
        return actions.filter { $0.id != cancel.id } + [cancel]
    }

    var initialFocusID: PVAlertAction.ID? {
        preferredActionID ?? orderedActions.first { $0.role != .cancel }?.id ?? orderedActions.first?.id
    }
}

// MARK: - Presenter

#if canImport(UIKit)
/// The view controller that hosts a presented `PVAlert`. Code that needs to know
/// whether an alert is on screen checks `presentedViewController is PVAlertHostingController`.
public final class PVAlertHostingController: UIHostingController<PVAlertView> {
    public let alertID: PVAlert.ID

    init(alert: PVAlert, onAction: @escaping (PVAlertAction, PVAlertResponse) -> Void) {
        alertID = alert.id
        super.init(rootView: PVAlertView(alert: alert, onAction: onAction))
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
        view.backgroundColor = .clear
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        PVAlertCenter.shared.hostDidDisappear(self)
    }
}

/// Queues alerts and presents them one at a time.
@MainActor
public final class PVAlertCenter {
    public static let shared = PVAlertCenter()

    private struct Pending {
        let alert: PVAlert
        weak var presenter: UIViewController?
    }

    private var queue: [Pending] = []
    private weak var current: PVAlertHostingController?
    private var currentAlert: PVAlert?
    /// Gamepad routing that was in place before the current alert took focus.
    private var savedManagerFocus: Bool?
    #if os(tvOS)
    private var savedEventVCFocus: (controller: GCEventViewController, wasEnabled: Bool)?
    #endif

    private static let presenterBusyRetryDelay: TimeInterval = 0.3

    public var isPresenting: Bool { current != nil }

    /// Shows `alert` from `presenter` (or the topmost view controller), after any alert already showing.
    public func present(_ alert: PVAlert, from presenter: UIViewController? = nil) {
        DLOG("Queue alert: \(alert.title)")
        queue.append(Pending(alert: alert, presenter: presenter))
        presentNextIfIdle()
    }

    /// Shows `alert` and waits for the user's answer. Returns the chosen action's index in
    /// `alert.actions`, or nil when the alert was taken down without an answer.
    public func presentAndWait(_ alert: PVAlert, from presenter: UIViewController? = nil) async -> Int? {
        await withCheckedContinuation { continuation in
            var resumed = false
            let resume: (Int?) -> Void = { index in
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: index)
            }
            var wrapped = alert
            wrapped.actions = alert.actions.enumerated().map { index, action in
                PVAlertAction(action.title, subtitle: action.subtitle, role: action.role) { response in
                    action.handler?(response)
                    resume(index)
                }
            }
            wrapped.onDismissedWithoutAnswer = { resume(nil) }
            if let preferred = alert.preferredActionID,
               let index = alert.actions.firstIndex(where: { $0.id == preferred }) {
                wrapped.preferredActionID = wrapped.actions[index].id
            }
            present(wrapped, from: presenter)
        }
    }

    private func presentNextIfIdle() {
        guard current == nil, let next = queue.first else { return }
        guard let presenter = Self.resolvePresenter(next.presenter) else {
            DLOG("No view controller to present alert \"\(next.alert.title)\" from; retrying")
            retryLater()
            return
        }
        if presenter.isBeingDismissed || presenter.isBeingPresented || presenter.presentedViewController != nil {
            retryLater()
            return
        }
        queue.removeFirst()

        let host = PVAlertHostingController(alert: next.alert) { [weak self] action, response in
            self?.finish(action: action, response: response)
        }
        current = host
        currentAlert = next.alert
        takeControllerFocus(for: presenter)
        presenter.present(host, animated: true)
    }

    private func retryLater() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.presenterBusyRetryDelay) { [weak self] in
            self?.presentNextIfIdle()
        }
    }

    /// Takes the showing alert down without running any of its actions.
    public func dismissCurrent() {
        guard current != nil else { return }
        let onDismissed = currentAlert?.onDismissedWithoutAnswer
        finish { onDismissed?() }
    }

    /// Takes down (or unqueues) one alert without running any of its actions.
    public func dismiss(alertID: PVAlert.ID) {
        if currentAlert?.id == alertID {
            dismissCurrent()
        } else if let index = queue.firstIndex(where: { $0.alert.id == alertID }) {
            let pending = queue.remove(at: index)
            pending.alert.onDismissedWithoutAnswer?()
        }
    }

    private func finish(action: PVAlertAction, response: PVAlertResponse) {
        finish { action.handler?(response) }
    }

    /// Dismisses the host, then runs `then` once the presenter is free again.
    private func finish(then: @escaping () -> Void) {
        guard let host = current else { return }
        current = nil
        currentAlert = nil
        let done = { [weak self] in
            guard let self else { return }
            self.restoreControllerFocus()
            then()
            self.presentNextIfIdle()
        }
        if host.presentingViewController != nil {
            host.dismiss(animated: true, completion: done)
        } else {
            done()
        }
    }

    /// The host went away without an answer, e.g. its presenter was torn down underneath it.
    fileprivate func hostDidDisappear(_ host: PVAlertHostingController) {
        guard current === host else { return }
        let onDismissed = currentAlert?.onDismissedWithoutAnswer
        current = nil
        currentAlert = nil
        restoreControllerFocus()
        onDismissed?()
        presentNextIfIdle()
    }

    /// The explicit presenter when it is on screen, else the top of the foreground key window.
    private static func resolvePresenter(_ preferred: UIViewController?) -> UIViewController? {
        var presenter: UIViewController?
        if let preferred, preferred.viewIfLoaded?.window != nil {
            presenter = preferred
        } else {
            presenter = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }?
                .keyWindow?.rootViewController
        }
        while let presented = presenter?.presentedViewController, !presented.isBeingDismissed {
            presenter = presented
        }
        return presenter
    }

    // MARK: Game controller focus

    /// `PVControllerManager` routes gamepad input to the game while one is running, which
    /// leaves an alert over the emulator unanswerable. Hand input to the focus engine while
    /// the alert is up and put it back afterwards.
    private func takeControllerFocus(for presenter: UIViewController) {
        let manager = PVControllerManager.shared
        savedManagerFocus = manager.controllerUserInteractionEnabled
        manager.controllerUserInteractionEnabled = true
        #if os(tvOS)
        if let eventController = Self.eventViewController(in: presenter) {
            savedEventVCFocus = (eventController, eventController.controllerUserInteractionEnabled)
            eventController.controllerUserInteractionEnabled = true
        }
        #endif
    }

    private func restoreControllerFocus() {
        if let saved = savedManagerFocus {
            PVControllerManager.shared.controllerUserInteractionEnabled = saved
            savedManagerFocus = nil
        }
        #if os(tvOS)
        if let saved = savedEventVCFocus {
            saved.controller.controllerUserInteractionEnabled = saved.wasEnabled
            savedEventVCFocus = nil
        }
        #endif
    }

    #if os(tvOS)
    private static func eventViewController(in presenter: UIViewController) -> GCEventViewController? {
        var controller: UIViewController? = presenter
        while let candidate = controller {
            if let eventController = candidate as? GCEventViewController { return eventController }
            controller = candidate.presentingViewController ?? candidate.parent
        }
        return nil
    }
    #endif
}

public extension UIViewController {
    /// Shows `alert` above this view controller (or whatever it is presenting).
    func present(_ alert: PVAlert) {
        PVAlertCenter.shared.present(alert, from: self)
    }

    /// True while a `PVAlert` is presented from this view controller.
    var isPresentingPVAlert: Bool {
        guard let presented = presentedViewController else { return false }
        return presented is PVAlertHostingController && !presented.isBeingDismissed
    }
}
#endif
