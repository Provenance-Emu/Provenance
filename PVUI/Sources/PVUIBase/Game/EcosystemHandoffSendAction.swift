//
//  EcosystemHandoffSendAction.swift
//  PVUIBase
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
import PVLibrary
import PVLogging
import PVRealm
import PVSystems
#if canImport(UIKit)
import UIKit
#endif

/// "Send to iCube" in a game's context menu: hands a GameCube or Wii disc image
/// straight to iCube through the shared App Group drop box
/// (`EcosystemHandoffSender`), then opens iCube to import it.
///
/// The row exists only when the direct route does. Provenance has no per-game
/// share sheet, so without the route (iCube missing, an iCube build that does
/// not receive, a game kept as an archive or `.m3u`, a file not on this device)
/// the menu is what it was before. Works the same on iOS and tvOS.
@MainActor
public enum EcosystemHandoffSendAction {
    /// A send the menu can offer.
    public struct Offer: Equatable, Sendable {
        public let game: EcosystemHandoffSender.Game
        public let route: EcosystemHandoffSender.Route

        public var app: EcosystemApp { route.target.app }
        public var title: String { "Send to \(app.displayName)" }
        public var symbolName: String { app.symbolName }
    }

    private enum Message {
        static func sending(_ title: String, to app: EcosystemApp) -> String {
            "Sending “\(title)” to \(app.displayName)…"
        }
        static func waiting(_ title: String, for app: EcosystemApp) -> String {
            "“\(title)” is waiting for \(app.displayName). Open \(app.displayName) to finish."
        }
        static func failed(_ title: String, to app: EcosystemApp, _ error: Error) -> String {
            "Couldn't send “\(title)” to \(app.displayName): \(error.localizedDescription)"
        }
    }

    /// The direct send for `game` (frozen), or nil. Reads the sibling's
    /// presence entry and stats the file off the main thread.
    public static func offer(for game: PVGame) async -> Offer? {
        guard !game.isInvalidated, !game.contentless, game.isDownloaded,
              let system = SystemIdentifier(rawValue: game.systemIdentifier),
              let target = EcosystemHandoffSender.target(for: system),
              canOpen(target.app),
              let file = game.file?.url
        else { return nil }

        let candidate = EcosystemHandoffSender.Game(title: game.title, system: system, md5: game.md5Hash, file: file)
        let route = await Task.detached(priority: .utility) {
            EcosystemHandoffSender.route(for: candidate, isInstalled: { _ in true }, root: EcosystemHandoff.sharedRoot)
        }.value
        return route.map { Offer(game: candidate, route: $0) }
    }

    /// Stages the game off the main thread (a full copy when the library sits on
    /// another volume), then opens the sibling. If it cannot be opened the
    /// hand-off stays in the drop box and the user is told it is waiting.
    public static func send(_ offer: Offer) {
        let app = offer.app
        let title = offer.game.title
        PVToastManager.shared.show(Message.sending(title, to: app), type: .info)

        Task {
            let result = await Task.detached(priority: .userInitiated) { () -> Result<EcosystemHandoffSender.Sent, Error> in
                guard let root = EcosystemHandoff.sharedRoot else {
                    return .failure(CocoaError(.fileNoSuchFile))
                }
                return Result { try EcosystemHandoffSender.send(offer.game, via: offer.route, root: root) }
            }.value

            switch result {
            case let .success(sent):
                ILOG("Ecosystem: staged '\(title)' for \(app.urlScheme):// as \(sent.manifest.id)")
                wake(app, with: sent.wakeURL, title: title)
            case let .failure(error):
                ELOG("Ecosystem: couldn't send '\(title)' to \(app.urlScheme)://: \(error.localizedDescription)")
                PVToastManager.shared.show(Message.failed(title, to: app, error), type: .error)
            }
        }
    }

    // MARK: - Private

    /// Is `app` installed? `canOpenURL` on iOS and tvOS alike (unlike
    /// `EcosystemApp.isInstalled`, which is iOS only); needs the scheme in
    /// `LSApplicationQueriesSchemes`.
    private static func canOpen(_ app: EcosystemApp) -> Bool {
        #if canImport(UIKit) && !os(watchOS)
        guard let url = URL(string: "\(app.urlScheme)://") else { return false }
        return UIApplication.shared.canOpenURL(url)
        #else
        return false
        #endif
    }

    private static func wake(_ app: EcosystemApp, with url: URL?, title: String) {
        #if canImport(UIKit) && !os(watchOS)
        guard let url else {
            PVToastManager.shared.show(Message.waiting(title, for: app), type: .warning)
            return
        }
        UIApplication.shared.open(url, options: [:]) { opened in
            guard !opened else { return }
            WLOG("Ecosystem: \(app.urlScheme):// did not open; the hand-off waits in the drop box")
            Task { @MainActor in
                PVToastManager.shared.show(Message.waiting(title, for: app), type: .warning)
            }
        }
        #else
        PVToastManager.shared.show(Message.waiting(title, for: app), type: .warning)
        #endif
    }
}
