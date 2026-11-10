//
//  LogFileRouter.swift
//  PVUI
//
//  Routes a file URL handed to the app to the log viewer or the regular
//  import pipeline. The decision itself is `IncomingLogFile` in PVLogging;
//  this layer only performs the minimal I/O it asks for (#3612).
//

import Foundation
import PVLogging
import ZIPFoundation

public enum LogFileRouter {

    /// Classifies a file arriving from Files, Mail, AirDrop or a cold-launch
    /// document URL.
    ///
    /// Reads nothing for a `.log` or an unrelated extension, only the central
    /// directory of a `.zip`, and only the first `IncomingLogFile.textPrefixByteCount`
    /// bytes of a `.txt`. Call it off the main thread all the same: finding a ZIP's
    /// directory on a file provider's volume has run past the launch watchdog.
    /// A security scope is opened around the reads when the URL needs one.
    public static func classify(fileURL url: URL) -> IncomingLogFile.Kind {
        let fileExtension = url.pathExtension

        switch IncomingLogFile.inspection(for: fileExtension) {
        case .none:
            return IncomingLogFile.classify(fileExtension: fileExtension)
        case .archiveEntries:
            return IncomingLogFile.classify(fileExtension: fileExtension,
                                            archiveEntryPaths: withSecurityScope(url) { archiveEntryPaths(at: url) })
        case .textPrefix:
            return IncomingLogFile.classify(fileExtension: fileExtension,
                                            textPrefix: withSecurityScope(url) { textPrefix(at: url) })
        }
    }

    /// Every entry path in the archive, or `nil` when it cannot be opened as a ZIP.
    private static func archiveEntryPaths(at url: URL) -> [String]? {
        guard let archive = Archive(url: url, accessMode: .read) else { return nil }
        return archive.map(\.path)
    }

    /// A UTF-8 sequence is at most four bytes, so a fixed-size read can cut at
    /// most three bytes off the final character.
    private static let maxTrailingPartialUTF8Bytes = 3

    /// The first bytes of the file decoded as UTF-8, or `nil` when unreadable.
    private static func textPrefix(at url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard var bytes = try? handle.read(upToCount: IncomingLogFile.textPrefixByteCount) else { return nil }
        // The read may end mid-character; drop the partial tail rather than fail the decode.
        for _ in 0...maxTrailingPartialUTF8Bytes {
            if let text = String(bytes: bytes, encoding: .utf8) { return text }
            guard !bytes.isEmpty else { break }
            bytes.removeLast()
        }
        return nil
    }

    /// Runs `body` inside a security scope when the URL grants one.
    private static func withSecurityScope<T>(_ url: URL, _ body: () -> T) -> T {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        return body()
    }
}
