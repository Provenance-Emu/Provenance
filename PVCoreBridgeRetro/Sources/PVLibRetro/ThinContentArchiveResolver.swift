//
//  ThinContentArchiveResolver.swift
//  PVCoreBridgeRetro
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Decides what the thin wrapper hands to `retro_load_game` when the game file
//  is a `.zip` / `.7z`.
//
//  Whether a core reads the archive itself is the same fact libretro publishes
//  as `supported_extensions` in the core's `.info` file (libretro-super) and
//  that the core reports at runtime as `retro_system_info::valid_extensions`.
//  The loaded dylib wins. A `.info` beside the dylib is used only when the
//  core reports an empty list. `block_extract` also means "do not unpack".
//
//  Otherwise, in the order RetroArch's frontend uses (`task_content.c`):
//
//  1. One ROM the core will take as a memory buffer (`need_fullpath == false`),
//     and the zip is small enough to inflate safely: pass those bytes in
//     `retro_game_info.data`. No temp file. This is the fast path.
//  2. A core that opens files through the VFS can use `archive.zip#entry`.
//     `materializeVirtualPath` turns that into one cached file.
//  3. Anything else — full path, 7z, a disc bundle (cue/gdi/m3u/ccd), or a zip
//     too big for RAM — is extracted under `extractionRoot` and reused while
//     the archive's path, size and modification date are unchanged.
//
//  A passthrough that fails `retro_load_game` is retried uncompressed once
//  when the archive also holds a file the core accepts, or when the core
//  never said what it accepts. Arcade romsets do not contain those
//  extensions, so a failed MAME/FBNeo zip is not unpacked.
//

import Foundation
import PVLogging
import PVArchiving

/// What `retro_load_game` should receive for one content path.
@objc(PVThinResolvedContent)
@objcMembers
public final class PVThinResolvedContent: NSObject {
    /// Path passed as `retro_game_info.path`. A real file, unless `data` is set,
    /// in which case it only has to end in the ROM's extension.
    public let path: String
    /// Inflated ROM bytes. Non-nil only when the core does not need a filesystem path.
    public let data: Data?
    /// The archive was handed through. A failed load should extract and try once more.
    public let retryUncompressedOnFailure: Bool

    public init(path: String, data: Data?, retryUncompressedOnFailure: Bool) {
        self.path = path
        self.data = data
        self.retryUncompressedOnFailure = retryUncompressedOnFailure
        super.init()
    }
}

@objc(PVThinContentArchiveResolver)
public final class ThinContentArchiveResolver: NSObject {

    /// Archive formats RetroArch extracts for a core that can't read them.
    static let extractableExtensions: Set<String> = ["zip", "7z"]

    /// Entry types that describe a whole game (and reference the other files in
    /// the archive), so they win over the first matching data file — and they
    /// cannot be loaded as a single memory buffer.
    static let preferredEntryExtensions = ["m3u", "cue", "gdi", "ccd"]

    /// Sidecar files that are not the game. Used only when a core reports no
    /// extensions and a failed load is being retried by unpacking.
    static let junkEntryExtensions: Set<String> = [
        "txt", "nfo", "xml", "html", "htm", "diz", "md", "pdf",
        "png", "jpg", "jpeg", "gif", "url", "ini", "cfg", "srt"
    ]

    /// Name of the file recording which archive a cache directory was extracted
    /// from, so an unchanged archive isn't extracted again on every boot.
    static let sourceStampFileName = ".pvthin-source"

    /// A zip larger than this is never pulled into RAM. Disc images take the
    /// cache path instead.
    static let memoryArchiveByteCap = 32 * 1024 * 1024

    /// Combined uncompressed size above which a zip is treated as unsafe to
    /// inflate in process (zip bomb, or simply too big for a ROM buffer).
    static let memoryUncompressedByteCap = 64 * 1024 * 1024

    /// Parses a libretro `valid_extensions` / `supported_extensions` string
    /// (`"smc|sfc|swc"`).
    static func extensions(fromValidExtensions validExtensions: String?) -> Set<String> {
        guard let validExtensions else { return [] }
        return Set(validExtensions.lowercased()
            .split(separator: "|")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty })
    }

    /// The `supported_extensions` value from a libretro `.info` file, or nil
    /// when the text doesn't carry one.
    static func supportedExtensions(inInfoText text: String) -> String? {
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let parts = line.split(separator: "=", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            guard parts.count == 2, parts[0] == "supported_extensions" else { continue }
            var value = parts[1]
            if value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") {
                value = String(value.dropFirst().dropLast())
            }
            return value.isEmpty ? nil : value
        }
        return nil
    }

    /// `supported_extensions` from `<dylib name>.info` next to `corePath`.
    /// Cores are not shipped with these files; this is a fallback for a dylib
    /// that reports an empty `valid_extensions`.
    @objc(supportedExtensionsBesideDylib:)
    public static func supportedExtensions(besideDylib corePath: String?) -> String? {
        guard let corePath, !corePath.isEmpty else { return nil }
        let infoURL = URL(fileURLWithPath: corePath)
            .deletingPathExtension()
            .appendingPathExtension("info")
        guard let text = try? String(contentsOf: infoURL, encoding: .utf8) else { return nil }
        return supportedExtensions(inInfoText: text)
    }

    /// `true` when the frontend must extract `contentPath` before loading it.
    static func shouldExtract(contentPath: String, validExtensions: Set<String>, blockExtract: Bool) -> Bool {
        let ext = (contentPath as NSString).pathExtension.lowercased()
        guard extractableExtensions.contains(ext), !blockExtract else { return false }
        // An empty list means the core didn't say what it accepts; leave the
        // archive alone rather than guess. A failed load retries uncompressed.
        guard !validExtensions.isEmpty else { return false }
        return !validExtensions.contains(ext)
    }

    /// The extracted file to load: a playlist/cue sheet if there is one, else the
    /// first file (by path) the core accepts. `nil` when nothing matches.
    /// With `allowLargestFallback`, an empty acceptance list yields the largest
    /// file that isn't a readme or artwork sidecar.
    static func preferredContent(among files: [URL],
                                 validExtensions: Set<String>,
                                 allowLargestFallback: Bool = false) -> URL? {
        let visible = files.filter {
            !$0.pathComponents.contains("__MACOSX") && !$0.lastPathComponent.hasPrefix(".")
        }
        let candidates = visible
            .filter { validExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.path < $1.path }
        for ext in preferredEntryExtensions {
            if let match = candidates.first(where: { $0.pathExtension.lowercased() == ext }) {
                return match
            }
        }
        if let match = candidates.first { return match }
        guard allowLargestFallback, validExtensions.isEmpty else { return nil }
        return visible
            .filter { !junkEntryExtensions.contains($0.pathExtension.lowercased()) }
            .max { fileSize($0) < fileSize($1) }
    }

    /// Returns the path to pass to `retro_load_game`: `contentPath` itself, or the
    /// file to load from its extracted copy under `extractionRoot`. Falls back
    /// to `contentPath` when extraction fails or yields nothing the core accepts,
    /// so the core reports the load failure as it did before.
    @objc public static func resolveContentPath(_ contentPath: String,
                                                validExtensions: String?,
                                                blockExtract: Bool,
                                                extractionRoot: String) -> String {
        resolveContent(atPath: contentPath,
                       validExtensions: validExtensions,
                       infoExtensions: nil,
                       blockExtract: blockExtract,
                       needFullPath: true,
                       forceExtract: false,
                       extractionRoot: extractionRoot).path
    }

    /// Resolve `contentPath` the way the thin wrapper loads it.
    ///
    /// The core's `validExtensions` win. `infoExtensions` (from a `.info` file)
    /// is used only when the core's list is empty. `forceExtract` is the
    /// failed-load retry: unpack even if the core listed the archive extension.
    @objc(resolveContentAtPath:validExtensions:infoExtensions:blockExtract:needFullPath:forceExtract:extractionRoot:)
    public static func resolveContent(atPath contentPath: String,
                                      validExtensions: String?,
                                      infoExtensions: String?,
                                      blockExtract: Bool,
                                      needFullPath: Bool,
                                      forceExtract: Bool,
                                      extractionRoot: String) -> PVThinResolvedContent {
        let coreExtensions = extensions(fromValidExtensions: validExtensions)
        let accepted = coreExtensions.isEmpty
            ? extensions(fromValidExtensions: infoExtensions)
            : coreExtensions
        let archiveExtension = (contentPath as NSString).pathExtension.lowercased()
        guard extractableExtensions.contains(archiveExtension) else {
            return PVThinResolvedContent(path: contentPath, data: nil, retryUncompressedOnFailure: false)
        }
        guard !blockExtract else {
            return PVThinResolvedContent(path: contentPath, data: nil, retryUncompressedOnFailure: false)
        }

        let native = accepted.contains(archiveExtension)
        let names = archiveExtension == "zip"
            ? PVArchiveHelper.shared.zipEntryNames(atPath: contentPath, maxArchiveBytes: memoryArchiveByteCap)
            : []
        let inner = innerEntries(names, accepted: accepted)

        if !forceExtract && (native || accepted.isEmpty) {
            // Unknown cores, and native zip cores whose archive also holds a
            // normal ROM, get one uncompressed retry. A romset's members are
            // not in `accepted`, so those zips are not unpacked on failure.
            let retry = accepted.isEmpty || (native && !inner.isEmpty)
            return PVThinResolvedContent(path: contentPath, data: nil, retryUncompressedOnFailure: retry)
        }

        // A failed in-memory load is retried as a real file (`forceExtract`),
        // for cores that ignore `need_fullpath` and open `path` themselves.
        if !forceExtract,
           let memory = memoryContent(contentPath: contentPath,
                                      inner: inner,
                                      accepted: accepted,
                                      needFullPath: needFullPath,
                                      extractionRoot: extractionRoot) {
            return memory
        }

        let extracted = extractToCache(contentPath: contentPath,
                                       accepted: accepted,
                                       allowLargestFallback: accepted.isEmpty,
                                       extractionRoot: extractionRoot)
        return PVThinResolvedContent(path: extracted, data: nil, retryUncompressedOnFailure: false)
    }

    /// `archive.zip#entry` → a real file under `extractionRoot`, reused while
    /// the archive is unchanged. Cores that open content through the VFS can
    /// use this instead of a full unpack. Nil when `virtualPath` isn't an
    /// archive member or the entry can't be produced.
    @objc(materializeVirtualPath:extractionRoot:)
    public static func materializeVirtualPath(_ virtualPath: String, extractionRoot: String) -> String? {
        guard let hash = virtualPath.firstIndex(of: "#"), hash != virtualPath.startIndex else { return nil }
        let archivePath = String(virtualPath[..<hash])
        let entry = String(virtualPath[virtualPath.index(after: hash)...])
        guard !entry.isEmpty,
              (archivePath as NSString).pathExtension.lowercased() == "zip" else {
            return nil
        }
        let destination = cacheDirectory(for: archivePath, extractionRoot: extractionRoot)
        let output = appendingEntry(entry, to: destination)
        // Not `.pvthin-source`: that stamp means the whole archive was unpacked.
        // A one-entry cache must not make a later full extract think it is done.
        let stampURL = destination.appendingPathComponent(".pvthin-member")
        let stamp = sourceStamp(for: URL(fileURLWithPath: archivePath)).map { $0 + "\n" + entry }
        if let stamp, (try? String(contentsOf: stampURL, encoding: .utf8)) == stamp,
           FileManager.default.fileExists(atPath: output.path) {
            return output.path
        }

        if let data = PVArchiveHelper.shared.readZipEntry(entry,
                                                          atPath: archivePath,
                                                          maxArchiveBytes: memoryArchiveByteCap,
                                                          maxUncompressedBytes: memoryUncompressedByteCap) {
            return writeCached(data, to: output, stamp: stamp, stampURL: stampURL) ? output.path : nil
        }

        // Too big to inflate here: unpack the archive (cached) and use the entry.
        let extracted = extractToCache(contentPath: archivePath,
                                       accepted: [URL(fileURLWithPath: entry).pathExtension.lowercased()],
                                       allowLargestFallback: false,
                                       extractionRoot: extractionRoot)
        if extracted != archivePath, FileManager.default.fileExists(atPath: output.path) {
            return output.path
        }
        if FileManager.default.fileExists(atPath: extracted),
           URL(fileURLWithPath: extracted).lastPathComponent == URL(fileURLWithPath: entry).lastPathComponent {
            return extracted
        }
        return nil
    }

    // MARK: - Memory path

    /// One ordinary ROM in a small zip, for a core that takes a memory buffer.
    private static func memoryContent(contentPath: String,
                                      inner: [String],
                                      accepted: Set<String>,
                                      needFullPath: Bool,
                                      extractionRoot: String) -> PVThinResolvedContent? {
        guard !needFullPath, inner.count == 1, let entry = inner.first else { return nil }
        let entryExtension = URL(fileURLWithPath: entry).pathExtension.lowercased()
        guard !preferredEntryExtensions.contains(entryExtension) else { return nil }
        guard accepted.contains(entryExtension) else { return nil }
        guard let data = PVArchiveHelper.shared.readZipEntry(entry,
                                                             atPath: contentPath,
                                                             maxArchiveBytes: memoryArchiveByteCap,
                                                             maxUncompressedBytes: memoryUncompressedByteCap),
              !data.isEmpty else {
            return nil
        }
        // Path is only for the extension and the save-file name. The bytes
        // travel in `data`, so this file is not written.
        let display = appendingEntry(entry, to: cacheDirectory(for: contentPath, extractionRoot: extractionRoot))
        ILOG("ThinArchive: inflated \(URL(fileURLWithPath: entry).lastPathComponent) from \(URL(fileURLWithPath: contentPath).lastPathComponent) (\(data.count) bytes)")
        return PVThinResolvedContent(path: display.path, data: data, retryUncompressedOnFailure: true)
    }

    /// Entry names the core accepts, excluding the archive formats themselves
    /// and Finder metadata.
    private static func innerEntries(_ names: [String], accepted: Set<String>) -> [String] {
        names.filter { name in
            let url = URL(fileURLWithPath: name)
            if url.pathComponents.contains("__MACOSX") || url.lastPathComponent.hasPrefix(".") {
                return false
            }
            let ext = url.pathExtension.lowercased()
            return accepted.contains(ext) && !extractableExtensions.contains(ext)
        }
        .sorted()
    }

    // MARK: - Cache path

    private static func extractToCache(contentPath: String,
                                       accepted: Set<String>,
                                       allowLargestFallback: Bool,
                                       extractionRoot: String) -> String {
        let fm = FileManager.default
        let source = URL(fileURLWithPath: contentPath)
        let destination = cacheDirectory(for: contentPath, extractionRoot: extractionRoot)
        let stampURL = destination.appendingPathComponent(sourceStampFileName)
        let stamp = sourceStamp(for: source)

        if let stamp, (try? String(contentsOf: stampURL, encoding: .utf8)) == stamp,
           let cached = preferredContent(among: files(under: destination),
                                         validExtensions: accepted,
                                         allowLargestFallback: allowLargestFallback) {
            ILOG("ThinArchive: reusing extracted \(cached.lastPathComponent) from \(source.lastPathComponent)")
            return cached.path
        }

        try? fm.removeItem(at: destination)
        do {
            try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        } catch {
            ELOG("ThinArchive: cannot create \(destination.path): \(error.localizedDescription)")
            return contentPath
        }
        guard PVArchiveHelper.shared.extractArchive(contentPath, toDestination: destination.path, overwrite: true) else {
            ELOG("ThinArchive: extracting \(source.lastPathComponent) failed; loading the archive as-is")
            return contentPath
        }
        guard let content = preferredContent(among: files(under: destination),
                                             validExtensions: accepted,
                                             allowLargestFallback: allowLargestFallback) else {
            ELOG("ThinArchive: \(source.lastPathComponent) holds no file the core accepts; loading the archive as-is")
            return contentPath
        }
        if let stamp {
            try? stamp.write(to: stampURL, atomically: true, encoding: .utf8)
        }
        ILOG("ThinArchive: extracted \(source.lastPathComponent); loading \(content.lastPathComponent)")
        return content.path
    }

    private static func cacheDirectory(for contentPath: String, extractionRoot: String) -> URL {
        let source = URL(fileURLWithPath: contentPath)
        return URL(fileURLWithPath: extractionRoot)
            .appendingPathComponent(source.deletingPathExtension().lastPathComponent, isDirectory: true)
    }

    private static func appendingEntry(_ entry: String, to directory: URL) -> URL {
        entry.split(separator: "/").reduce(directory) { partial, part in
            let name = String(part)
            if name.isEmpty || name == "." || name == ".." { return partial }
            return partial.appendingPathComponent(name)
        }
    }

    /// Writes `data` and the archive stamp. Returns false if the file can't be created.
    private static func writeCached(_ data: Data, to output: URL, stamp: String?, stampURL: URL) -> Bool {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: output, options: .atomic)
            if let stamp {
                try? stamp.write(to: stampURL, atomically: true, encoding: .utf8)
            }
            return true
        } catch {
            ELOG("ThinArchive: cannot cache \(output.lastPathComponent): \(error.localizedDescription)")
            return false
        }
    }

    /// Identifies an archive by path, size and modification date.
    private static func sourceStamp(for url: URL) -> String? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber,
              let modified = attributes[.modificationDate] as? Date else {
            return nil
        }
        return "\(url.path)\n\(size)\n\(modified.timeIntervalSince1970)"
    }

    private static func files(under directory: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: directory,
                                                              includingPropertiesForKeys: [.isRegularFileKey]) else {
            return []
        }
        return enumerator.compactMap { $0 as? URL }
            .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
    }

    private static func fileSize(_ url: URL) -> Int {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
    }
}
