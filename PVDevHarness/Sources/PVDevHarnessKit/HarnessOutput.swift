import Foundation

/// What a harness run measured. `frameCountSource` is "estimated": no core exposes a public
/// frame counter, so `frames` frames are assumed to render in `frames * frameInterval` seconds.
public struct HarnessReport: Codable, Equatable, Sendable {
    public var core: String
    public var game: String
    public var frames: Int
    public var frameCountSource: String
    public var frameInterval: Double
    public var fps: Double
    public var waitedSeconds: Double
    public var elapsedSeconds: Double

    public init(core: String, game: String, frames: Int, frameCountSource: String, frameInterval: Double,
                fps: Double, waitedSeconds: Double, elapsedSeconds: Double) {
        self.core = core
        self.game = game
        self.frames = frames
        self.frameCountSource = frameCountSource
        self.frameInterval = frameInterval
        self.fps = fps
        self.waitedSeconds = waitedSeconds
        self.elapsedSeconds = elapsedSeconds
    }
}

/// The files a harness run leaves in its output directory.
public enum HarnessOutput {
    public static let screenshotFile = "screenshot.png"
    public static let framesFile = "frames.json"
    public static let logFile = "log.txt"
    public static let errorFile = "error.txt"

    /// Frame interval used when the core reports none.
    static let fallbackFrameInterval = 1.0 / 60.0

    public static func prepare(_ directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public static func writeReport(_ report: HarnessReport, to directory: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(report).write(to: directory.appendingPathComponent(framesFile), options: .atomic)
    }

    public static func writeError(_ message: String, to directory: URL) throws {
        try (message + "\n").write(to: directory.appendingPathComponent(errorFile), atomically: true, encoding: .utf8)
    }

    public static func writeScreenshot(_ png: Data, to directory: URL) throws {
        try png.write(to: directory.appendingPathComponent(screenshotFile), options: .atomic)
    }

    /// Copies the current log file; writes a one-line note when there is none.
    public static func copyLog(from source: URL?, to directory: URL) throws {
        let destination = directory.appendingPathComponent(logFile)
        try? FileManager.default.removeItem(at: destination)
        if let source, FileManager.default.fileExists(atPath: source.path) {
            try FileManager.default.copyItem(at: source, to: destination)
        } else {
            try "no log file\n".write(to: destination, atomically: true, encoding: .utf8)
        }
    }

    public static func waitSeconds(frames: Int, frameInterval: Double) -> Double {
        Double(frames) * (frameInterval > 0 ? frameInterval : fallbackFrameInterval)
    }
}
