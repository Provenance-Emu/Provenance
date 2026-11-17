//
//  EcosystemHandoffInbox.swift
//  PVLibrary
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation

/// The receiving half of the shared drop box (see `EcosystemHandoff`): finds the
/// hand-offs a sibling app left for Provenance and puts their files in the import
/// folder, where the directory watcher imports them. File work only, no Realm;
/// `EcosystemHandoffReceiver` decides when it runs.
///
/// Where a hand-off lands depends on its shape, because the importer only reads
/// a folder in `Imports/` as one game when it holds an index file:
/// - **A set with a cue, gdi or m3u at its top:** one container folder,
///   `Imports/<sender>-<md5 prefix>/`, layout intact. The importer imports each
///   outermost index file with the files it references.
/// - **Anything else** (a lone CHD/CDI, a NAOMI zip with `{stem}/{gdrom}.chd`):
///   each top-level file goes flat into `Imports/`, exactly as the share sheet
///   delivers it. A file nested under an archive's stem is a GD-ROM companion and
///   goes to `Imports/.archive-companions/<stem>/` first, where
///   `GameImporterFileService.moveStagedArchiveCompanions` collects it when the
///   archive imports.
///
/// The listed files are first cloned into a hidden `Imports/.ecosystem-<id>/`
/// (instant on APFS; the watcher skips hidden names), then renamed into view, so
/// the watcher never sees a half-copied file. The hand-off is deleted only after
/// that: if Provenance dies midway the hand-off is still whole and the next run
/// starts over.
public enum EcosystemHandoffInbox {
    /// One complete hand-off waiting in the inbox.
    public struct Pending: Equatable, Sendable {
        public let directory: URL
        public let manifest: EcosystemHandoffManifest
    }

    /// Why a hand-off was refused. A refused hand-off stays in the inbox for its
    /// sender to clean up.
    public enum Refusal: Error, Equatable, Sendable {
        /// The manifest lists no files, or no primary file.
        case noPrimaryFile
        /// A manifest path is absolute, has `..`, an empty or hidden component.
        case unsafePath(String)
        /// Two manifest paths differ only in case.
        case duplicatePath(String)
        /// A listed file is missing under `files/`, or is not a regular file.
        case missingFile(String)
    }

    /// What `place` put in the import folder.
    public struct Placement: Equatable, Sendable {
        /// The container folder or flat files the watcher will import.
        public var imported: [URL]
        /// GD-ROM companions staged for an archive in `imported`.
        public var stagedCompanions: [URL]
    }

    /// Prefix of the hidden folder a hand-off is cloned into inside the import folder.
    static let stagingPrefix = ".ecosystem-"

    /// Hand-offs addressed to `own` that this build understands, oldest first.
    /// Staging directories, newer versions, other kinds and other recipients are
    /// left where they are.
    public static func pending(
        root: URL,
        own: String = EcosystemHandoff.ownScheme,
        fileManager: FileManager = .default
    ) -> [Pending] {
        let inbox = EcosystemHandoff.inbox(for: own, root: root)
        guard let items = try? fileManager.contentsOfDirectory(
            at: inbox, includingPropertiesForKeys: [.isDirectoryKey]
        ) else { return [] }

        var result: [Pending] = []
        for item in items where !item.lastPathComponent.hasPrefix(".") {
            guard (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true,
                  let data = try? Data(contentsOf: item.appendingPathComponent(EcosystemHandoff.manifestName)),
                  let manifest = try? EcosystemHandoff.decoder().decode(EcosystemHandoffManifest.self, from: data),
                  manifest.version >= 1, manifest.version <= EcosystemHandoff.protocolVersion,
                  manifest.kind == EcosystemHandoff.gameKind,
                  manifest.to.lowercased() == own.lowercased()
            else { continue }
            result.append(Pending(directory: item, manifest: manifest))
        }
        return result.sorted { $0.manifest.created < $1.manifest.created }
    }

    /// Checks every manifest path before anything is copied: all or nothing.
    public static func validate(_ pending: Pending, fileManager: FileManager = .default) throws {
        let files = pending.manifest.files
        guard files.contains(where: { $0.role == EcosystemHandoffManifest.primaryRole }) else {
            throw Refusal.noPrimaryFile
        }
        let filesDirectory = filesRoot(of: pending)
        var seen = Set<String>()
        for file in files {
            guard isSafeRelativePath(file.path) else { throw Refusal.unsafePath(file.path) }
            guard seen.insert(file.path.lowercased()).inserted else { throw Refusal.duplicatePath(file.path) }
            let source = filesDirectory.appendingPathComponent(file.path)
            // A symlink (the file, or a folder on its path) could point anywhere in
            // Provenance's own container; only regular files below `files/` are taken.
            let values = try? source.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values?.isRegularFile == true, values?.isSymbolicLink != true,
                  IncomingFileReceiver.isInside(source, directory: filesDirectory) else {
                throw Refusal.missingFile(file.path)
            }
        }
    }

    /// Puts a validated hand-off's files in `importDirectory` (see the type's
    /// comment for where), then deletes the hand-off. Throws `Refusal` without
    /// touching anything, or the file error that stopped it (the hidden staging
    /// folder is removed); the hand-off stays in the inbox either way, so the next
    /// run tries again.
    @discardableResult
    public static func place(
        _ pending: Pending,
        into importDirectory: URL,
        fileManager: FileManager = .default
    ) throws -> Placement {
        try validate(pending, fileManager: fileManager)

        let staging = importDirectory.appendingPathComponent(
            stagingPrefix + pending.directory.lastPathComponent, isDirectory: true)
        try? fileManager.removeItem(at: staging)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: staging) }

        let filesDirectory = filesRoot(of: pending)
        for file in pending.manifest.files {
            let destination = staging.appendingPathComponent(file.path)
            try fileManager.createDirectory(
                at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            // Clones on APFS: the group container and the library share a volume.
            try fileManager.copyItem(at: filesDirectory.appendingPathComponent(file.path), to: destination)
        }

        let placement: Placement
        if !MultiFileSetPlacement.outermostIndexFiles(in: staging, fileManager: fileManager).isEmpty {
            let container = IncomingFileReceiver.uniqueDestination(
                importDirectory.appendingPathComponent(containerName(for: pending), isDirectory: true),
                fileManager: fileManager)
            try fileManager.moveItem(at: staging, to: container)
            placement = Placement(imported: [container], stagedCompanions: [])
        } else {
            placement = try placeFlat(pending.manifest.files, from: staging, into: importDirectory, fileManager: fileManager)
        }

        try? fileManager.removeItem(at: pending.directory)
        return placement
    }

    /// Removes hidden staging folders a run that died left in the import folder.
    public static func removeLeftoverStaging(in importDirectory: URL, fileManager: FileManager = .default) {
        guard let items = try? fileManager.contentsOfDirectory(atPath: importDirectory.path) else { return }
        for name in items where name.hasPrefix(stagingPrefix) {
            try? fileManager.removeItem(at: importDirectory.appendingPathComponent(name, isDirectory: true))
        }
    }

    /// A manifest path may only name something below `files/`: relative, forward
    /// slashes, no empty, `.`, `..` or hidden components.
    public static func isSafeRelativePath(_ path: String) -> Bool {
        guard !path.isEmpty, !path.hasPrefix("/"), !path.contains("\\"), !path.contains("\0") else {
            return false
        }
        return path.split(separator: "/", omittingEmptySubsequences: false).allSatisfy { component in
            !component.isEmpty && !component.hasPrefix(".")
        }
    }

    /// `iFly EMU-1a2b3c4d`: the sender's name and the first 8 hex digits of the md5,
    /// or of the hand-off id when the manifest carries no usable md5.
    static func containerName(for pending: Pending) -> String {
        let manifest = pending.manifest
        let sender = EcosystemApp(rawValue: manifest.from.lowercased())?.displayName
            ?? sanitized(manifest.from, fallback: "Handoff")
        let md5Tag = (manifest.md5 ?? "").prefix(8)
        let tag = md5Tag.count == 8 && md5Tag.allSatisfy(\.isHexDigit)
            ? String(md5Tag).lowercased()
            : String(sanitized(pending.directory.lastPathComponent, fallback: "game").prefix(8))
        return "\(sender)-\(tag)"
    }

    // MARK: - Internals

    private static let maxSenderNameLength = 32

    private static func filesRoot(of pending: Pending) -> URL {
        pending.directory.appendingPathComponent(EcosystemHandoff.filesDirectoryName, isDirectory: true)
    }

    /// Letters, digits, `-` and `_` from `text`, or `fallback` when none are left.
    private static func sanitized(_ text: String, fallback: String) -> String {
        let kept = String(text.unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_"
        }.prefix(maxSenderNameLength))
        return kept.isEmpty ? fallback : kept
    }

    /// Top-level files go to the import folder under a free name; a file under an
    /// archive's stem (`ikaruga/gdl-0010.chd` next to `ikaruga.zip`) is staged as
    /// that archive's companion first; any other nested file goes flat.
    private static func placeFlat(
        _ files: [EcosystemHandoffManifest.File],
        from staging: URL,
        into importDirectory: URL,
        fileManager: FileManager
    ) throws -> Placement {
        let topLevel = files.filter { !$0.path.contains("/") }
        let nested = files.filter { $0.path.contains("/") }

        // Final names first, so a companion is staged under the stem its archive
        // will actually have.
        var destinations: [String: URL] = [:]
        var claimed = Set<String>()
        /// `name`, or `name-1.ext`, `name-2.ext`, …: the first that is neither in the
        /// import folder nor taken by another file of this hand-off.
        func freeDestination(for name: String) -> URL {
            let base = (name as NSString).deletingPathExtension
            let ext = (name as NSString).pathExtension
            var index = 0
            while true {
                let candidateName = index == 0 ? name : (ext.isEmpty ? "\(base)-\(index)" : "\(base)-\(index).\(ext)")
                let candidate = importDirectory.appendingPathComponent(candidateName, isDirectory: false)
                if !claimed.contains(candidateName.lowercased()), !fileManager.fileExists(atPath: candidate.path) {
                    claimed.insert(candidateName.lowercased())
                    return candidate
                }
                index += 1
            }
        }
        for file in topLevel {
            destinations[file.path] = freeDestination(for: file.path)
        }
        let hostStems: [String: String] = Dictionary(
            topLevel.filter { ArchiveCompanionLayout.isHost($0.path) }.map {
                (ArchiveCompanionLayout.stem(of: $0.path).lowercased(),
                 destinations[$0.path].map { $0.lastPathComponent } ?? $0.path)
            },
            uniquingKeysWith: { first, _ in first })

        var placement = Placement(imported: [], stagedCompanions: [])
        for file in nested {
            let components = file.path.split(separator: "/")
            let source = staging.appendingPathComponent(file.path)
            if components.count == 2, let archiveName = hostStems[String(components[0]).lowercased()] {
                let companionDirectory = ArchiveCompanionLayout.stagingDirectory(
                    importDirectory: importDirectory, archiveName: archiveName)
                let destination = companionDirectory.appendingPathComponent(String(components[1]))
                guard !fileManager.fileExists(atPath: destination.path) else { continue }
                try fileManager.createDirectory(at: companionDirectory, withIntermediateDirectories: true)
                try fileManager.moveItem(at: source, to: destination)
                placement.stagedCompanions.append(destination)
            } else {
                let destination = freeDestination(for: source.lastPathComponent)
                try fileManager.moveItem(at: source, to: destination)
                placement.imported.append(destination)
            }
        }
        // Archives last, after their companions are staged.
        let archivesLast = topLevel.filter { !ArchiveCompanionLayout.isHost($0.path) }
            + topLevel.filter { ArchiveCompanionLayout.isHost($0.path) }
        for file in archivesLast {
            guard let destination = destinations[file.path] else { continue }
            try fileManager.moveItem(at: staging.appendingPathComponent(file.path), to: destination)
            placement.imported.append(destination)
        }
        return placement
    }
}
