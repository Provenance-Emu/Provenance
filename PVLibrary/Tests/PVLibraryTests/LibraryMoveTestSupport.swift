//
//  LibraryMoveTestSupport.swift
//  PVLibraryTests
//
//  Temp-directory and file helpers shared by the library move tests.
//

import Foundation
@testable import PVFileSystem

enum LibraryMoveTestSupport {
    /// A fresh, empty directory under the temp directory. Remove it with `removeTree(_:)`.
    static func makeTempDirectory(named name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name)/\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func removeTree(_ url: URL?) {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// Writes `text` to `root/relativePath`, creating intermediate directories.
    @discardableResult
    static func write(_ root: URL, _ relativePath: String, _ text: String) throws -> URL {
        try write(root, relativePath, data: Data(text.utf8))
    }

    /// Writes `bytes` copies of one byte to `root/relativePath`, creating intermediate directories.
    @discardableResult
    static func write(_ root: URL, _ relativePath: String, bytes: Int) throws -> URL {
        try write(root, relativePath, data: Data(repeating: 0x41, count: bytes))
    }

    private static func write(_ root: URL, _ relativePath: String, data: Data) throws -> URL {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
        return url
    }

    static func read(_ root: URL, _ relativePath: String) -> String? {
        try? String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }

    static func exists(_ root: URL, _ relativePath: String) -> Bool {
        FileManager.default.fileExists(atPath: root.appendingPathComponent(relativePath).path)
    }

    static func modificationDate(_ root: URL, _ relativePath: String) throws -> Date? {
        try root.appendingPathComponent(relativePath).resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    /// The planner item for an existing file: its current size and modification date.
    static func planItem(_ root: URL, _ relativePath: String) throws -> LibraryMovePlan.Item {
        let values = try root.appendingPathComponent(relativePath).resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        return LibraryMovePlan.Item(relativePath: relativePath, size: Int64(values.fileSize ?? 0), modified: values.contentModificationDate)
    }
}
