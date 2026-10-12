//
//  SharedLibraryIndex.swift
//  PVFileSystem
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  The destination's `ROMs/` files grouped by size, with MD5s computed only on a size match, so
//  joining a shared library can recognise a ROM it already holds under another name (D15).
//  A match must sit in the same folder as the source (`ROMs/<system>/`), so a ROM is never pointed at another system's copy.
//

import Foundation
import PVHashing

struct SharedLibraryIndex {
    private let root: URL
    private let md5Provider: any MD5Provider
    /// Size → relative paths under `root`.
    private var bySize: [Int64: [String]] = [:]
    /// Relative path → MD5, filled on demand.
    private var md5s: [String: String] = [:]

    init(root: URL, folders: [String], fileManager: FileManager, md5Provider: any MD5Provider) throws {
        self.root = root
        self.md5Provider = md5Provider
        for folder in folders {
            let top = root.appendingPathComponent(folder, isDirectory: true)
            guard fileManager.fileExists(atPath: top.path),
                  let enumerator = fileManager.enumerator(at: top, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey], options: [.skipsHiddenFiles]) else { continue }
            for case let url as URL in enumerator {
                let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                guard values.isRegularFile == true, let relative = LibraryMovePlanner.relativePath(of: url, under: root) else { continue }
                bySize[Int64(values.fileSize ?? 0), default: []].append(relative)
            }
        }
    }

    /// `true` when some indexed file has this size, so the caller only hashes a source that could match.
    func hasCandidates(size: Int64) -> Bool {
        !(bySize[size] ?? []).isEmpty
    }

    /// A file of the same size and MD5 at a path other than `excluding`, in the same parent folder, or `nil`.
    mutating func match(size: Int64, md5: String, excluding relativePath: String) -> String? {
        let folder = Self.parentFolder(of: relativePath)
        for candidate in bySize[size] ?? [] where candidate != relativePath && Self.parentFolder(of: candidate) == folder {
            if md5s[candidate] == nil {
                md5s[candidate] = md5Provider.md5ForFile(at: root.appendingPathComponent(candidate), fromOffset: 0) ?? ""
            }
            if md5s[candidate] == md5 { return candidate }
        }
        return nil
    }

    private static func parentFolder(of relativePath: String) -> String {
        (relativePath as NSString).deletingLastPathComponent
    }
}
