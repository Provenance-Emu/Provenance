#if os(iOS) || os(tvOS)
import Foundation
import UIKit
import PVDevHarnessKit
import PVLibrary
import PVLogging
import PVUIBase

/// Launch-argument harness for the Tuist focused apps (`-PVHarnessROM <path>` …): imports the
/// ROM if needed, launches it through the normal emulator-scene path, waits, writes
/// screenshot.png / frames.json / log.txt (or error.txt) and exits.
@MainActor
public enum DevHarness {
    enum HarnessError: Error, CustomStringConvertible {
        case bootTimedOut
        case bootFailed(String)
        case romNotFound(String)
        case importTimedOut(String)
        case coreNotFound(String)
        case noCoreForSystem(String)
        case coreDidNotStart(String)
        case screenshotFailed

        var description: String {
            switch self {
            case .bootTimedOut: return "app bootup did not complete"
            case let .bootFailed(reason): return "app bootup failed: \(reason)"
            case let .romNotFound(path): return "ROM not found: \(path)"
            case let .importTimedOut(name): return "import of \(name) did not finish"
            case let .coreNotFound(id): return "no registered core \(id)"
            case let .noCoreForSystem(id): return "no enabled core for system \(id)"
            case let .coreDidNotStart(id): return "core \(id) did not start running"
            case .screenshotFailed: return "could not snapshot a window"
            }
        }
    }

    static let bootTimeout: TimeInterval = 120
    static let importTimeout: TimeInterval = 180
    static let coreStartTimeout: TimeInterval = 60
    static let pollNanoseconds: UInt64 = 250_000_000
    static let frameCountSource = "estimated"

    private static var started = false

    public static func start(appState: AppState, arguments: [String] = ProcessInfo.processInfo.arguments) {
        guard !started, let args = HarnessArguments.parse(arguments) else { return }
        started = true
        // File logging is otherwise only started from the log browser; log.txt needs a session file.
        PVLogFileManager.shared.startLogging()
        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        let output = args.outputDirectory(home: home, documents: URL.documentsPath, now: Date())
        ILOG("DevHarness: ROM \(args.romPath), \(args.frames) frames, output \(output.path)")
        Task { @MainActor in
            let began = Date()
            do {
                try HarnessOutput.prepare(output)
                let report = try await run(args, appState: appState, home: home, began: began)
                guard let png = screenshotPNG() else { throw HarnessError.screenshotFailed }
                try HarnessOutput.writeScreenshot(png, to: output)
                try HarnessOutput.writeReport(report, to: output)
                finish(args, output: output, status: 0)
            } catch {
                ELOG("DevHarness: \(error)")
                try? HarnessOutput.writeError(String(describing: error), to: output)
                finish(args, output: output, status: 1)
            }
        }
    }

    private static func run(_ args: HarnessArguments, appState: AppState, home: URL, began: Date) async throws -> HarnessReport {
        let booted = await waitUntil(bootTimeout) {
            if case .completed = appState.bootupState { return true }
            return false
        }
        if case let .error(error) = appState.bootupState { throw HarnessError.bootFailed(String(describing: error)) }
        guard booted else { throw HarnessError.bootTimedOut }

        let game = try await importIfNeeded(args.romURL(home: home))
        let core = try resolveCore(args.coreIdentifier, for: game)
        ILOG("DevHarness: launching \(game.title) with \(core.identifier)")

        // Same path as ProvenanceApp.openEmulatorSceneIfNeeded(): the scene reads these.
        appState.emulationUIState.currentCore = core
        appState.emulationUIState.currentGame = game
        SceneCoordinator.shared.openEmulatorScene()

        let coreID = core.identifier
        guard await waitUntil(coreStartTimeout, { appState.emulationUIState.core?.isRunning == true }) else {
            throw HarnessError.coreDidNotStart(coreID)
        }
        let frameInterval = appState.emulationUIState.core?.frameInterval ?? 0
        let wait = HarnessOutput.waitSeconds(frames: args.frames, frameInterval: frameInterval)
        let waitStart = Date()
        try await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
        let waited = Date().timeIntervalSince(waitStart)
        return HarnessReport(
            core: coreID,
            game: game.title,
            frames: args.frames,
            frameCountSource: frameCountSource,
            frameInterval: frameInterval,
            fps: waited > 0 ? Double(args.frames) / waited : 0,
            waitedSeconds: waited,
            elapsedSeconds: Date().timeIntervalSince(began)
        )
    }

    // MARK: Import

    private static func findGame(named fileName: String) -> PVGame? {
        let database = RomDatabase.sharedInstance
        database.realm.refresh()
        return database.all(PVGame.self).filter("romPath ENDSWITH[c] %@", fileName).first
    }

    private static func importIfNeeded(_ romURL: URL) async throws -> PVGame {
        let fileName = romURL.lastPathComponent
        if let game = findGame(named: fileName) { return game }
        guard FileManager.default.fileExists(atPath: romURL.path) else { throw HarnessError.romNotFound(romURL.path) }

        let importDirectory = Paths.romsImportPath
        try FileManager.default.createDirectory(at: importDirectory, withIntermediateDirectories: true)
        let staged = importDirectory.appendingPathComponent(fileName)
        if !FileManager.default.fileExists(atPath: staged.path) {
            try FileManager.default.copyItem(at: romURL, to: staged)
        }
        await GameImporter.shared.addImports(forPaths: [staged])
        GameImporter.shared.startProcessing()

        var found: PVGame?
        _ = await waitUntil(importTimeout) {
            found = findGame(named: fileName)
            return found != nil
        }
        guard let game = found else { throw HarnessError.importTimedOut(fileName) }
        return game
    }

    // MARK: Core choice: explicit, else the game's, else the system's preference, else the first enabled core.

    private static func resolveCore(_ explicit: String?, for game: PVGame) throws -> PVCore {
        let realm = RomDatabase.sharedInstance.realm
        func core(_ identifier: String?) -> PVCore? {
            identifier.flatMap { realm.object(ofType: PVCore.self, forPrimaryKey: $0) }
        }
        if let explicit {
            guard let chosen = core(explicit) else { throw HarnessError.coreNotFound(explicit) }
            return chosen
        }
        if let preferred = core(game.userPreferredCoreID) ?? core(game.system?.userPreferredCoreID) {
            return preferred
        }
        guard let first = game.system?.cores.filter("disabled == false").sorted(byKeyPath: "identifier").first else {
            throw HarnessError.noCoreForSystem(game.systemIdentifier)
        }
        return first
    }

    // MARK: Output

    private static func screenshotPNG() -> Data? {
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        guard let window = windows.first(where: \.isKeyWindow) ?? windows.first else { return nil }
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        return renderer.pngData { _ in
            _ = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
    }

    private static func finish(_ args: HarnessArguments, output: URL, status: Int32) {
        PVLogging.shared.flushLogs()
        let log = PVLogFileManager.shared.currentSessionURL
        try? HarnessOutput.copyLog(from: log, to: output)
        ILOG("DevHarness: done (status \(status)) → \(output.path)")
        if args.exitWhenDone { exit(status) }
    }

    private static func waitUntil(_ timeout: TimeInterval, _ condition: @MainActor () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: pollNanoseconds)
        }
        return condition()
    }
}
#endif
