//
//  PVDebugAPIRoutes.swift
//  PVUI
//
//  `/api/debug/*` automation handlers — drive a running Provenance over the
//  LAN so App Store screenshots (library + real gameplay with shaders) can be
//  captured unattended from a physical iPhone / iPad / Apple TV. Ported from
//  iFly's `DebugAPIRoutes`; see `Scripts/capture_device_screenshots.py`.
//
//  Gating lives in PVWebServer (`PVDebugAPIPrefs`): the HTTP router only
//  mounts `/api/debug/*` on DEBUG builds or when the hidden Developer toggle
//  is on, and every request passes the Basic-auth check before reaching a
//  handler here. Served by the modern (Hummingbird) server only —
//  `refreshFeatureFlag()` selects it whenever the debug API is enabled.
//
//  Routes:
//    GET  /api/debug                      route index
//    GET  /api/debug/status               bootup state, running game, filter, pixelate
//    GET  /api/debug/library[?q=title]    games (md5, title, system, file)
//    GET  /api/debug/screenshot[?source=window|game]   PNG
//    GET  /api/debug/uitree               key-window UIView tree (UIKit only)
//    POST /api/debug/navigate?url=provenance://screen/...
//    POST /api/debug/dismiss              dismiss presented sheets / alerts
//    POST /api/debug/boot   {md5 | title [, system, core]}
//    POST /api/debug/exit
//    POST /api/debug/pause | /resume
//    POST /api/debug/savestate | /loadstate   (quick-save slot)
//    GET  /api/debug/shader                current + available Metal filters
//    POST /api/debug/shader {filter: none|simpleCRT|complexCRT|lcd|…}
//    POST /api/debug/pixelate {enabled: Bool}
//

import Foundation
import PVLibrary
import PVLogging
import PVSettings
import Defaults
import UIKit
#if canImport(PVWebServer)
import PVWebServer

@MainActor
public enum PVDebugAPIRoutes {

    private static var registered = false

    /// Registers every handler with `PVDebugAPIRegistry`. Idempotent; a no-op
    /// when the debug API is disabled (the router wouldn't mount them anyway).
    public static func registerAll(in registry: PVDebugAPIRegistry = .shared) {
        guard !registered, PVDebugAPIPrefs.isEnabled else { return }
        registered = true

        registry.register("GET", "/api/debug/status") { _ in
            await MainActor.run { .ok(statusPayload()) }
        }

        registry.register("GET", "/api/debug/library") { request in
            let query = request.value("q")
            return await MainActor.run { .ok(libraryPayload(matching: query)) }
        }

        // NOTE: re-renders the key window through a fresh CG context
        // (`drawHierarchy`). `source=game` instead asks the emulator for its
        // own frame capture (`PVEmulatorViewController.captureScreenshot`).
        registry.register("GET", "/api/debug/screenshot") { request in
            let source = request.value("source") ?? "window"
            let png: Data? = await MainActor.run {
                source == "game" ? renderGamePNG() : renderKeyWindowPNG()
            }
            guard let png else { return .error("no window / nothing to capture", status: 503) }
            return .png(png)
        }

        // Walks UIView.subviews, so SwiftUI screens only show their UIKit
        // shell — use the accessibility tree (XCUITest / RocketSim) to find
        // SwiftUI controls.
        registry.register("GET", "/api/debug/uitree") { _ in
            await MainActor.run {
                guard let window = keyWindow() else { return .error("no key window", status: 503) }
                return .ok(["root": describe(window, depth: 0)])
            }
        }

        // Same dispatch order as ProvenanceApp.handle(appURL:) for screen/debug hosts.
        registry.register("POST", "/api/debug/navigate") { request in
            guard let raw = request.value("url"), let url = URL(string: raw) else {
                return .error("missing url (e.g. provenance://screen/settings)")
            }
            let handled = await MainActor.run {
                NavigationRouter.shared.handle(url: url) || ScreenNavigator.shared.handle(url: url)
            }
            return handled ? .ok(["url": raw]) : .error("no route handled \(raw)", status: 404)
        }

        // Clears sheets / alerts (What's New, a stuck picker, Settings) so a capture
        // run starts from a clean screen. Returns the dismissed controllers' classes.
        registry.register("POST", "/api/debug/dismiss") { _ in
            await MainActor.run {
                guard var base = keyWindow()?.rootViewController else { return .error("no key window", status: 503) }
                // Never dismiss the emulator itself (that strands a running core —
                // use /exit); only what is stacked above it.
                var chain: [UIViewController] = []
                var presented = base.presentedViewController
                while let current = presented {
                    chain.append(current)
                    presented = current.presentedViewController
                }
                if let emulatorIndex = chain.lastIndex(where: { $0 is PVEmulatorViewController }) {
                    base = chain[emulatorIndex]
                    chain = Array(chain.suffix(from: emulatorIndex + 1))
                }
                if !chain.isEmpty { base.dismiss(animated: false) }
                return .ok(["dismissed": chain.map { String(describing: type(of: $0)) }])
            }
        }

        registry.register("POST", "/api/debug/boot") { request in
            let md5 = request.value("md5")
            let title = request.value("title")
            let system = request.value("system")
            let coreID = request.value("core")
            return await MainActor.run { boot(md5: md5, title: title, system: system, coreID: coreID) }
        }

        registry.register("POST", "/api/debug/exit") { _ in
            await MainActor.run {
                guard let emulator = AppState.shared.emulationUIState.emulator else {
                    // A launch that never reached the emulator (core / save picker
                    // still up) leaves currentGame set; unwind it the same way.
                    guard AppState.shared.emulationUIState.currentGame != nil else {
                        return .error("no game running", status: 409)
                    }
                    keyWindow()?.rootViewController?.dismiss(animated: false)
                    SceneCoordinator.shared.closeEmulator()
                    return .ok(["accepted": true, "unwoundLaunch": true])
                }
                Task { @MainActor in
                    await emulator.quit(optionallySave: false) {
                        SceneCoordinator.shared.closeEmulator()
                    }
                }
                return .ok(["accepted": true])
            }
        }

        registry.register("POST", "/api/debug/pause") { _ in
            await MainActor.run { setPaused(true) }
        }
        registry.register("POST", "/api/debug/resume") { _ in
            await MainActor.run { setPaused(false) }
        }

        registry.register("POST", "/api/debug/savestate") { _ in
            await saveOrLoad(save: true)
        }
        registry.register("POST", "/api/debug/loadstate") { _ in
            await saveOrLoad(save: false)
        }

        registry.register("GET", "/api/debug/shader") { _ in
            await MainActor.run {
                .ok([
                    "mode": Defaults[.metalFilterMode].rawValue,
                    "available": MetalFilterSelectionOption.allCases.map(\.rawValue),
                ] as [String: Any])
            }
        }

        // Applies live: PVMetalViewController observes Defaults[.metalFilterMode].
        registry.register("POST", "/api/debug/shader") { request in
            let name = request.value("filter") ?? ""
            guard let filter = MetalFilterSelectionOption(rawValue: name) else {
                let names = MetalFilterSelectionOption.allCases.map(\.rawValue).joined(separator: ", ")
                return .error("unknown filter '\(name)' (one of: \(names))")
            }
            return await MainActor.run {
                Defaults[.metalFilterMode] = filter == .none ? .none : .always(filter: filter)
                return .ok(["mode": Defaults[.metalFilterMode].rawValue])
            }
        }

        registry.register("POST", "/api/debug/pixelate") { request in
            guard let raw = request.jsonBody["enabled"] ?? request.query["enabled"] else {
                return .error("missing enabled")
            }
            let enabled = (raw as? Bool) ?? ["1", "true", "yes"].contains("\(raw)".lowercased())
            return await MainActor.run {
                Defaults[.pixelateLibraryArtwork] = enabled
                return .ok(["enabled": enabled])
            }
        }

        ILOG("PVDebugAPIRoutes: registered \(registry.routes.count) debug routes")
    }

    // MARK: - Payloads

    private static func statusPayload() -> [String: Any] {
        let state = AppState.shared
        var payload: [String: Any] = [
            "bootupState": state.bootupState.localizedDescription,
            "bootupCompleted": state.bootupState == .completed,
            "shader": Defaults[.metalFilterMode].rawValue,
            "pixelateLibraryArtwork": Defaults[.pixelateLibraryArtwork],
            "authEnabled": PVDebugAPIPrefs.authEnabled,
            "debugBuild": PVDebugAPIPrefs.isDebugBuild,
        ]
        if let game = state.emulationUIState.currentGame, !game.isInvalidated {
            payload["game"] = [
                "md5": game.md5Hash,
                "title": game.title,
                "system": game.systemIdentifier,
            ]
        }
        if let core = state.emulationUIState.core {
            payload["core"] = [
                "class": String(describing: type(of: core)),
                "running": core.isOn,
                "paused": core.isEmulationPaused,
            ] as [String: Any]
        }
        return payload
    }

    private static func libraryPayload(matching query: String?) -> [String: Any] {
        guard state(isReady: AppState.shared) else { return ["count": 0, "games": [], "ready": false] }
        var games = Array(RomDatabase.sharedInstance.allGames.sorted(byKeyPath: "title"))
        if let query, !query.isEmpty {
            games = games.filter { $0.title.localizedCaseInsensitiveContains(query) }
        }
        let rows: [[String: Any]] = games.map { game in
            [
                "md5": game.md5Hash,
                "title": game.title,
                "system": game.systemIdentifier,
                "file": (game.romPath as NSString).lastPathComponent,
            ]
        }
        return ["count": rows.count, "games": rows, "ready": true]
    }

    private static func state(isReady state: AppState) -> Bool {
        state.bootupState == .completed
    }

    // MARK: - Actions

    private static func boot(md5: String?, title: String?, system: String?, coreID: String?) -> PVDebugAPIResponse {
        let state = AppState.shared
        guard self.state(isReady: state) else { return .error("library not ready (bootup in progress)", status: 409) }
        if let current = state.emulationUIState.currentGame, !current.isInvalidated {
            return .error("'\(current.title)' is running — POST /api/debug/exit first", status: 409)
        }

        let database = RomDatabase.sharedInstance
        var game: PVGame?
        if let md5, !md5.isEmpty {
            game = database.game(withMD5: md5)
        } else if let title, !title.isEmpty {
            game = database.allGames.sorted(byKeyPath: "title").first { candidate in
                candidate.title.localizedCaseInsensitiveContains(title)
                    && (system.map { candidate.systemIdentifier.localizedCaseInsensitiveContains($0) } ?? true)
            }
        } else {
            return .error("pass md5 or title")
        }
        guard let game else { return .error("no matching game", status: 404) }

        var core: PVCore?
        if let coreID, !coreID.isEmpty {
            core = database.object(ofType: PVCore.self, wherePrimaryKeyEquals: coreID)
            if core == nil { return .error("unknown core '\(coreID)'", status: 404) }
        } else {
            // Unattended: never stop at the multi-core picker.
            core = defaultCore(for: game)
        }

        let row: [String: Any] = ["md5": game.md5Hash, "title": game.title, "system": game.systemIdentifier]
        ILOG("PVDebugAPIRoutes: boot \(game.title) [\(game.systemIdentifier)] core=\(coreID ?? "default")")
        SceneCoordinator.shared.launchGame(game, core: core, bypassDefaultPatch: false)
        return .ok(["accepted": true, "game": row])
    }

    /// The user's preferred core, else the first core the launcher's picker would
    /// list (same filter and `corePickerOrder` as `GameLaunchingViewController`).
    private static func defaultCore(for game: PVGame) -> PVCore? {
        guard let system = game.system else { return nil }
        let unsupportedCores = Defaults[.unsupportedCores]
        let cores = system.cores.filter {
            (!$0.disabled || unsupportedCores) && $0.hasCoreClass && !(AppState.shared.isAppStore && $0.appStoreDisabled)
        }
        if let preferred = game.userPreferredCoreID ?? system.userPreferredCoreID,
           let core = cores.first(where: { $0.identifier == preferred }) {
            return core
        }
        return cores.sorted { a, b in
            if a.isDeprecated != b.isDeprecated { return !a.isDeprecated }
            if a.isLibretroCore != b.isLibretroCore { return !a.isLibretroCore }
            return a.projectName.localizedCaseInsensitiveCompare(b.projectName) == .orderedAscending
        }.first
    }

    private static func setPaused(_ paused: Bool) -> PVDebugAPIResponse {
        guard let core = AppState.shared.emulationUIState.core else { return .error("no game running", status: 409) }
        core.setPauseEmulation(paused)
        return .ok(["paused": core.isEmulationPaused])
    }

    private static func saveOrLoad(save: Bool) async -> PVDebugAPIResponse {
        guard let emulator = await MainActor.run(body: { AppState.shared.emulationUIState.emulator }) else {
            return .error("no game running", status: 409)
        }
        do {
            let ok = try await Task { @MainActor in
                save ? try await emulator.quicksave() : try await emulator.quickload()
            }.value
            return ok ? .ok(["slot": "quick"]) : .error(save ? "quicksave failed" : "no quick save to load", status: 500)
        } catch {
            return .error(error.localizedDescription, status: 500)
        }
    }

    // MARK: - Window capture

    /// Key window of the foreground-active scene (the app has separate main
    /// and emulator scenes), falling back to any visible window.
    private static func keyWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let active = scenes.filter { $0.activationState == .foregroundActive }
        for scene in active + scenes {
            if let key = scene.windows.first(where: \.isKeyWindow) { return key }
        }
        return (active + scenes).flatMap(\.windows).first { !$0.isHidden && $0.bounds.width > 0 }
    }

    private static func renderKeyWindowPNG() -> Data? {
        guard let window = keyWindow(), window.bounds.width > 0 else { return nil }
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        let image = renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        return image.pngData()
    }

    private static func renderGamePNG() -> Data? {
        AppState.shared.emulationUIState.emulator?.captureScreenshot()?.pngData()
    }

    private static func describe(_ view: UIView, depth: Int) -> [String: Any] {
        var node: [String: Any] = [
            "class": String(describing: type(of: view)),
            "frame": ["x": view.frame.origin.x, "y": view.frame.origin.y,
                      "w": view.frame.size.width, "h": view.frame.size.height] as [String: Any],
            "hidden": view.isHidden,
            "alpha": view.alpha,
        ]
        if let label = view.accessibilityLabel {
            node["label"] = label
        }
        if let id = view.accessibilityIdentifier {
            node["id"] = id
        }
        // Cap depth to keep the payload bounded for deep SwiftUI hierarchies.
        if depth < 24, !view.subviews.isEmpty {
            node["subviews"] = view.subviews.map { describe($0, depth: depth + 1) }
        }
        return node
    }
}
#endif
