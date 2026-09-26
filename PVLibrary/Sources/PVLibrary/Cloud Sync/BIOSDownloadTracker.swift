//
//  BIOSDownloadTracker.swift
//  PVLibrary
//
//  Live status of BIOS files being fetched from CloudKit, so UI such as the
//  console BIOS list can show a download in progress or a failed attempt.
//

import Foundation

@MainActor
public final class BIOSDownloadTracker: ObservableObject {

    public enum Status: Equatable, Sendable {
        case downloading
        case failed
    }

    public static let shared = BIOSDownloadTracker()

    /// Keyed by lowercased filename. A file with no entry is idle.
    @Published public private(set) var statuses: [String: Status] = [:]

    init() {}

    public func status(for filename: String) -> Status? {
        statuses[Self.key(filename)]
    }

    public func begin(_ filename: String) {
        statuses[Self.key(filename)] = .downloading
    }

    /// A success clears the entry; the row then reads its state from the imported file.
    public func finish(_ filename: String, success: Bool) {
        statuses[Self.key(filename)] = success ? nil : .failed
    }

    private static func key(_ filename: String) -> String {
        filename.lowercased()
    }
}
