//
//  EcosystemHandoffStager.swift
//  PVLibrary
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation

/// The sending half of the shared drop box (see `EcosystemHandoff`): puts one
/// game's files where a sibling app will find them. Ported from iFly's
/// `EcosystemHandoffStager`. File work only; `EcosystemHandoffSender` decides
/// what to send and to whom.
///
/// Files are copied with `FileManager.copyItem`, which clones on APFS: the app
/// container and the group container sit on one volume, so a multi-gigabyte
/// disc image is staged in milliseconds and takes no extra space.
public enum EcosystemHandoffStager {
    public enum StageError: Error, Equatable {
        /// Nothing to send, or no file marked `primary`.
        case noPrimaryFile
        /// A path below `files/` is absolute, empty, has `.`, `..`, a hidden
        /// component or a backslash, or appears twice.
        case unsafePath(String)
        /// A source is missing or is not a regular file (a directory, a link).
        case notARegularFile(URL)
    }

    /// One file of the hand-off with the path it gets below `files/`.
    public struct Entry: Equatable, Sendable {
        public let source: URL
        public let relativePath: String
        public let role: String

        public init(source: URL, relativePath: String, role: String) {
            self.source = source
            self.relativePath = relativePath
            self.role = role
        }
    }

    /// Writes the hand-off for `peer` and returns its manifest. The directory
    /// appears under its final name only once every file and the manifest are
    /// in it; on any failure the staging directory is removed and nothing is left.
    @discardableResult
    public static func stage(
        _ entries: [Entry],
        to peer: String,
        from sender: String = EcosystemHandoff.ownScheme,
        title: String,
        system: String?,
        md5: String?,
        root: URL,
        id: String = UUID().uuidString,
        now: Date = Date(),
        fileManager: FileManager = .default
    ) throws -> EcosystemHandoffManifest {
        try validate(entries, fileManager: fileManager)

        let inbox = EcosystemHandoff.inbox(for: peer, root: root)
        let staging = inbox.appendingPathComponent(".\(id)\(EcosystemHandoff.stagingSuffix)", isDirectory: true)
        let filesDirectory = staging.appendingPathComponent(EcosystemHandoff.filesDirectoryName, isDirectory: true)
        try fileManager.createDirectory(at: filesDirectory, withIntermediateDirectories: true)

        do {
            var manifestFiles: [EcosystemHandoffManifest.File] = []
            for entry in entries {
                let destination = filesDirectory.appendingPathComponent(entry.relativePath)
                try fileManager.createDirectory(
                    at: destination.deletingLastPathComponent(), withIntermediateDirectories: true
                )
                try fileManager.copyItem(at: entry.source, to: destination)
                let size = (try fileManager.attributesOfItem(atPath: destination.path)[.size] as? NSNumber)?
                    .int64Value ?? 0
                manifestFiles.append(.init(path: entry.relativePath, role: entry.role, size: size))
            }
            let manifest = EcosystemHandoffManifest(
                version: EcosystemHandoff.protocolVersion,
                id: id,
                from: sender.lowercased(),
                to: peer.lowercased(),
                created: wholeSeconds(now),
                kind: EcosystemHandoff.gameKind,
                title: title,
                system: system,
                md5: md5?.lowercased(),
                files: manifestFiles
            )
            try EcosystemHandoff.encoder().encode(manifest)
                .write(to: staging.appendingPathComponent(EcosystemHandoff.manifestName), options: .atomic)
            try fileManager.moveItem(at: staging, to: inbox.appendingPathComponent(id, isDirectory: true))
            return manifest
        } catch {
            try? fileManager.removeItem(at: staging)
            throw error
        }
    }

    /// Removes what Provenance left behind in every inbox: its own hand-offs
    /// nobody picked up within `EcosystemHandoff.staleAfter`, and staging
    /// directories of sends that died (`EcosystemHandoff.stagingStaleAfter`).
    /// Other apps' hand-offs are never touched; a staging directory carries no
    /// sender, so only one old enough to be dead is removed. Returns the count.
    @discardableResult
    public static func collectGarbage(
        root: URL,
        sender: String = EcosystemHandoff.ownScheme,
        now: Date = Date(),
        fileManager: FileManager = .default
    ) -> Int {
        let handoffRoot = root.appendingPathComponent(EcosystemHandoff.handoffDirectoryName, isDirectory: true)
        guard let inboxes = try? fileManager.contentsOfDirectory(at: handoffRoot, includingPropertiesForKeys: nil)
        else { return 0 }

        var removed = 0
        for inbox in inboxes {
            guard let items = try? fileManager.contentsOfDirectory(
                at: inbox, includingPropertiesForKeys: [.contentModificationDateKey]
            ) else { continue }
            for item in items where isGarbage(item, sender: sender.lowercased(), now: now) {
                if (try? fileManager.removeItem(at: item)) != nil {
                    removed += 1
                }
            }
        }
        return removed
    }

    // MARK: - Private

    private static func isGarbage(_ item: URL, sender: String, now: Date) -> Bool {
        let name = item.lastPathComponent
        if name.hasPrefix(".") {
            guard name.hasSuffix(EcosystemHandoff.stagingSuffix) else { return false }
            let modified = (try? item.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? now
            return now.timeIntervalSince(modified) > EcosystemHandoff.stagingStaleAfter
        }
        guard let data = try? Data(contentsOf: item.appendingPathComponent(EcosystemHandoff.manifestName)),
              let manifest = try? EcosystemHandoff.decoder().decode(EcosystemHandoffManifest.self, from: data)
        else { return false }
        return manifest.from.lowercased() == sender
            && now.timeIntervalSince(manifest.created) > EcosystemHandoff.staleAfter
    }

    /// The receivers refuse what this rejects, so a bad set fails here, before
    /// anything is written.
    private static func validate(_ entries: [Entry], fileManager: FileManager) throws {
        guard entries.contains(where: { $0.role == EcosystemHandoffManifest.primaryRole }) else {
            throw StageError.noPrimaryFile
        }
        var seen = Set<String>()
        for entry in entries {
            let path = entry.relativePath
            let components = path.split(separator: "/", omittingEmptySubsequences: false)
            guard !path.hasPrefix("/"), !path.contains("\\"),
                  components.allSatisfy({ !$0.isEmpty && !$0.hasPrefix(".") }),
                  seen.insert(path.lowercased()).inserted
            else { throw StageError.unsafePath(path) }

            let values = try? entry.source.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values?.isRegularFile == true, values?.isSymbolicLink != true else {
                throw StageError.notARegularFile(entry.source)
            }
        }
    }

    /// ISO 8601 as the drop box writes it has no fractional seconds; dropping
    /// them here keeps the returned manifest equal to what a receiver decodes.
    private static func wholeSeconds(_ date: Date) -> Date {
        Date(timeIntervalSince1970: date.timeIntervalSince1970.rounded(.down))
    }
}
