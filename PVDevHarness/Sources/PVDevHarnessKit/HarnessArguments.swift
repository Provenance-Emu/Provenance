import Foundation

/// Launch arguments of the dev harness. A normal launch has no `-PVHarnessROM` and
/// `parse(_:)` returns nil.
public struct HarnessArguments: Equatable, Sendable {
    public enum Key {
        public static let rom = "-PVHarnessROM"
        public static let core = "-PVHarnessCore"
        public static let frames = "-PVHarnessFrames"
        public static let out = "-PVHarnessOut"
        public static let exit = "-PVHarnessExit"
        static let prefix = "-PVHarness"
    }

    // Exit: only the value "0" for -PVHarnessExit keeps the app running; anything else (or absent) exits.
    public static let defaultFrames = 300
    /// Upper bound for `-PVHarnessFrames`: 10 minutes at 60 fps.
    public static let maxFrames = 36_000

    public var romPath: String
    public var coreIdentifier: String?
    public var frames: Int
    public var outputPath: String?
    public var exitWhenDone: Bool

    public init(romPath: String, coreIdentifier: String? = nil, frames: Int = defaultFrames,
                outputPath: String? = nil, exitWhenDone: Bool = true) {
        self.romPath = romPath
        self.coreIdentifier = coreIdentifier
        self.frames = frames
        self.outputPath = outputPath
        self.exitWhenDone = exitWhenDone
    }

    public static func parse(_ arguments: [String]) -> HarnessArguments? {
        func value(_ key: String) -> String? {
            guard let index = arguments.firstIndex(of: key), index + 1 < arguments.count else { return nil }
            let candidate = arguments[index + 1]
            return candidate.hasPrefix(Key.prefix) ? nil : candidate
        }
        guard let rom = value(Key.rom), !rom.isEmpty else { return nil }
        let frames = value(Key.frames).flatMap(Int.init).map { min(maxFrames, max(1, $0)) } ?? defaultFrames
        return HarnessArguments(
            romPath: rom,
            coreIdentifier: value(Key.core),
            frames: frames,
            outputPath: value(Key.out),
            exitWhenDone: value(Key.exit).map { $0 != "0" } ?? true
        )
    }

    /// Absolute paths as given; anything else relative to the app's home (its data container).
    static func resolve(_ path: String, home: URL) -> URL {
        path.hasPrefix("/") ? URL(fileURLWithPath: path) : home.appendingPathComponent(path)
    }

    public func romURL(home: URL) -> URL { Self.resolve(romPath, home: home) }

    /// `-PVHarnessOut`, else `<documents>/Harness/<yyyyMMdd-HHmmss-SSS>` (UTC, millisecond resolution
    /// so two runs in the same second get distinct directories).
    public func outputDirectory(home: URL, documents: URL, now: Date) -> URL {
        if let outputPath { return Self.resolve(outputPath, home: home) }
        return documents.appendingPathComponent("Harness", isDirectory: true)
            .appendingPathComponent(Self.timestamp(now), isDirectory: true)
    }

    public static func timestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        return formatter.string(from: date)
    }
}
