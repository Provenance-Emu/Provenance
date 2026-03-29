//
//  PVArchivingObjC.swift
//  PVArchiving
//
//  Created by Joseph Mattiello on 3/28/26.
//
//  Thin ObjC-compatible wrapper around ArchiveManager for use from
//  Objective-C code (e.g. PVRetroArchCore+Archive.m).

import Foundation
import PVLogging

/// ObjC-compatible archive extraction facade.
/// Bridges PVArchiving's Swift API to Objective-C callers.
@objc(PVArchiveHelper)
@objcMembers
public final class PVArchiveHelper: NSObject {

    /// Shared singleton.
    @objc public static let shared = PVArchiveHelper()

    private override init() {
        super.init()
    }

    // MARK: - Extraction

    /// Extract a ZIP archive to a destination directory.
    /// - Returns: `YES` on success.
    @objc public func extractZIP(_ atPath: String, toDestination: String, overwrite: Bool) -> Bool {
        let source = URL(fileURLWithPath: atPath)
        let dest = URL(fileURLWithPath: toDestination)
        do {
            if overwrite {
                let fm = FileManager.default
                if fm.fileExists(atPath: toDestination) {
                    try? fm.removeItem(at: dest)
                }
            }
            try ZipBackend.unzip(at: source, to: dest)
            return true
        } catch {
            ELOG("PVArchiveHelper: ZIP extraction failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Extract an LZH/LHA archive to a destination directory.
    /// - Returns: `YES` on success.
    @objc public func extractLZH(_ atPath: String, toDestination: String, overwrite: Bool) -> Bool {
        let source = URL(fileURLWithPath: atPath)
        let dest = URL(fileURLWithPath: toDestination)
        do {
            try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
            return syncExtract {
                for try await _ in LzhBackend().extract(at: source, to: dest, progress: { _ in }) {}
            }
        } catch {
            ELOG("PVArchiveHelper: LZH extraction failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Extract a RAR archive to a destination directory.
    /// - Returns: `YES` on success.
    @objc public func extractRAR(_ atPath: String, toDestination: String, overwrite: Bool) -> Bool {
        let source = URL(fileURLWithPath: atPath)
        let dest = URL(fileURLWithPath: toDestination)
        do {
            try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
            return syncExtract {
                for try await _ in RarBackend().extract(at: source, to: dest, progress: { _ in }) {}
            }
        } catch {
            ELOG("PVArchiveHelper: RAR extraction failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Auto-detect archive format and extract.
    /// - Returns: `YES` on success.
    @objc public func extractArchive(_ atPath: String, toDestination: String, overwrite: Bool) -> Bool {
        let source = URL(fileURLWithPath: atPath)
        let dest = URL(fileURLWithPath: toDestination)
        guard let format = ArchiveManager.shared.detectFormat(at: source) else {
            ELOG("PVArchiveHelper: unknown archive format for \(atPath)")
            return false
        }

        switch format {
        case .zip:
            return extractZIP(atPath, toDestination: toDestination, overwrite: overwrite)
        case .lzh:
            return extractLZH(atPath, toDestination: toDestination, overwrite: overwrite)
        case .rar:
            return extractRAR(atPath, toDestination: toDestination, overwrite: overwrite)
        default:
            return syncExtract {
                try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
                for try await _ in ArchiveManager.shared.extract(at: source, to: dest, format: format) {}
            }
        }
    }

    /// Check if a path refers to a supported archive file.
    @objc public func isArchive(_ atPath: String) -> Bool {
        let url = URL(fileURLWithPath: atPath)
        return ArchiveManager.shared.isArchive(at: url)
    }

    /// Check if a file extension is a supported archive format.
    @objc public static func isArchiveExtension(_ ext: String) -> Bool {
        ArchiveManager.isArchiveExtension(ext)
    }

    /// Create a ZIP archive from a directory.
    /// - Returns: `YES` on success.
    @objc public func createZIP(at destinationPath: String, fromDirectory directoryPath: String) -> Bool {
        do {
            try ArchiveManager.shared.createZipArchive(
                at: URL(fileURLWithPath: destinationPath),
                from: URL(fileURLWithPath: directoryPath)
            )
            return true
        } catch {
            ELOG("PVArchiveHelper: ZIP creation failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Private

    /// Run an async throwing closure synchronously on a GCD thread (not the cooperative pool).
    /// This avoids the deadlock risk of DispatchSemaphore + Task, which can starve
    /// the cooperative thread pool when called from the main thread.
    private func syncExtract(_ work: @escaping @Sendable () async throws -> Void) -> Bool {
        nonisolated(unsafe) var success = false
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .userInitiated).async {
            let group = DispatchGroup()
            group.enter()
            Task {
                defer { group.leave() }
                do {
                    try await work()
                    success = true
                } catch {
                    ELOG("PVArchiveHelper: extraction failed: \(error.localizedDescription)")
                }
            }
            group.wait()
            semaphore.signal()
        }
        semaphore.wait()
        return success
    }
}
