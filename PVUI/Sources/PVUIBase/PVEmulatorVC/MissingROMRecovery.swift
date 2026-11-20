//
//  MissingROMRecovery.swift
//  PVUIBase
//
//  The seam a launch uses to get a missing ROM back. PVUIBase cannot see the library
//  sharing code (PVSwiftUI), so the app registers a recoverer at startup.
//

import UIKit

public enum MissingROMRecoveryOutcome: Sendable, Equatable {
    /// The file is in place; the launch can go on.
    case restored
    /// The user said no or cancelled. Nothing changed.
    case declined
    /// No source has the game. The lists are source names for the final alert.
    case notFound(asked: [String], unreachable: [String], needsSignIn: [String])
    case failed(message: String)
}

public enum MissingROMRecoveryPrompt: Sendable, Equatable {
    /// The same game was found on `source`.
    case copy(title: String, source: String)
    /// A same-name file that may be another version was found on `source`.
    case standIn(title: String, fileName: String, source: String)
}

public enum MissingROMRecoveryAnswer: Sendable, Equatable {
    case allow
    /// Allow, and stop asking for games that match exactly.
    case alwaysAllow
    case cancel
}

@MainActor
public protocol MissingROMRecovering: AnyObject {
    /// Looks for the game's missing file on known libraries and servers and puts it back.
    /// `status` receives short progress lines; `ask` is awaited before any copy starts.
    func recover(
        gameMD5: String,
        status: @escaping @MainActor (String) -> Void,
        ask: @escaping @MainActor (MissingROMRecoveryPrompt) async -> MissingROMRecoveryAnswer
    ) async -> MissingROMRecoveryOutcome
}

@MainActor
public enum MissingROMRecovery {
    /// Set once at app startup. Nil means a missing file fails the launch as before.
    public static var recoverer: (any MissingROMRecovering)?

    /// Runs a recovery with its alerts on `host`. True when the file is back.
    public static func run(gameMD5: String, title: String, on host: UIViewController) async -> Bool {
        guard let recoverer, !gameMD5.isEmpty else { return false }
        let presenter = MissingROMRecoveryPresenter(host: host, title: title)
        let work = Task { @MainActor in
            await recoverer.recover(
                gameMD5: gameMD5,
                status: { presenter.setStatus($0) },
                ask: { await presenter.ask($0) }
            )
        }
        presenter.onCancel = { work.cancel() }
        presenter.setStatus("Searching nearby libraries and servers…")
        let outcome = await work.value
        await presenter.hideStatus()
        switch outcome {
        case .restored:
            return true
        case .declined:
            return false
        case let .notFound(asked, unreachable, needsSignIn):
            await presenter.report(Self.notFoundMessage(asked: asked, unreachable: unreachable, needsSignIn: needsSignIn))
            return false
        case .failed(let message):
            await presenter.report("The copy did not finish.\n\n\(message)")
            return false
        }
    }

    /// The same, with its alerts on the frontmost view controller. For menus.
    @discardableResult
    public static func run(gameMD5: String, title: String) async -> Bool {
        let window = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first
        var host = window?.rootViewController
        while let presented = host?.presentedViewController, !presented.isBeingDismissed { host = presented }
        guard let host else { return false }
        return await run(gameMD5: gameMD5, title: title, on: host)
    }

    static func notFoundMessage(asked: [String], unreachable: [String], needsSignIn: [String]) -> String {
        var lines = ["No nearby library or server has it."]
        if asked.isEmpty, unreachable.isEmpty, needsSignIn.isEmpty {
            lines.append("No paired device or saved server was found. Open Nearby Libraries on a device that has the game.")
        }
        if !asked.isEmpty { lines.append("Asked: " + asked.joined(separator: ", ")) }
        if !unreachable.isEmpty { lines.append("Could not reach: " + unreachable.joined(separator: ", ")) }
        if !needsSignIn.isEmpty { lines.append("Needs sign-in: " + needsSignIn.joined(separator: ", ")) }
        return lines.joined(separator: "\n\n")
    }
}

/// The alerts of one recovery: a status alert with Cancel, the questions, and the result.
/// One alert at a time; the status alert comes back after a question.
@MainActor
final class MissingROMRecoveryPresenter {
    private weak var host: UIViewController?
    private let title: String
    private var statusAlert: UIAlertController?
    private var lastStatus = ""
    private var asking = false
    private var cancelled = false
    var onCancel: (() -> Void)?

    init(host: UIViewController, title: String) {
        self.host = host
        self.title = title
    }

    /// The host can show an alert: it is on screen, staying there, and showing nothing else.
    private var presentableHost: UIViewController? {
        guard let host, host.viewIfLoaded?.window != nil, !host.isBeingDismissed,
              host.presentedViewController == nil else { return nil }
        return host
    }

    func setStatus(_ text: String) {
        lastStatus = text
        guard !asking, !cancelled else { return }
        if let statusAlert, statusAlert.presentingViewController != nil {
            statusAlert.message = text
            return
        }
        guard let host = presentableHost else { return }
        let alert = UIAlertController(title: "Looking for \(title) on your network", message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.cancelled = true
            self?.onCancel?()
        })
        statusAlert = alert
        host.present(alert, animated: false)
    }

    func hideStatus() async {
        guard let alert = statusAlert else { return }
        statusAlert = nil
        guard alert.presentingViewController != nil else { return }
        await withCheckedContinuation { continuation in
            alert.dismiss(animated: false) { continuation.resume() }
        }
    }

    func ask(_ prompt: MissingROMRecoveryPrompt) async -> MissingROMRecoveryAnswer {
        asking = true
        await hideStatus()
        let alert: PVAlert
        var answers: [MissingROMRecoveryAnswer]
        switch prompt {
        case let .copy(title, source):
            alert = PVAlert(
                title: "\(title)'s file is missing", message: "Copy it from \(source)?",
                actions: [PVAlertAction("Copy"), PVAlertAction("Always Allow"), .cancel()]
            )
            answers = [.allow, .alwaysAllow, .cancel]
        case let .standIn(_, fileName, source):
            alert = PVAlert(
                title: "A different version was found",
                message: "\(source) has \(fileName), which may be a different version. Use it? Save states may not load.",
                actions: [PVAlertAction("Use It"), .cancel()]
            )
            answers = [.allow, .cancel]
        }
        // An alert taken down without an answer (its host went away) counts as Cancel.
        let index = await PVAlertCenter.shared.presentAndWait(alert, from: host)
        let answer = index.map { answers[$0] } ?? .cancel
        asking = false
        if answer == .cancel { cancelled = true } else { setStatus(lastStatus) }
        return answer
    }

    func report(_ message: String) async {
        let alert = PVAlert(title: "\(title)'s file is missing", message: message, actions: [.ok()])
        _ = await PVAlertCenter.shared.presentAndWait(alert, from: host)
    }
}
