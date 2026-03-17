import Foundation
import os
import PVLogging
import PVSupport

#if canImport(Darwin)
import Darwin
#endif

struct LibretroMetadata {
    let version: String
    let validExtensions: [String]
}

enum LibretroMetadataReader {
    /// In-memory cache: identifier → metadata (cleared each launch)
    private static let cacheStorage = OSAllocatedUnfairLock<[String: LibretroMetadata]>(initialState: [:])

    // -------------------------------------------------------------------------
    // MARK: - Disk cache
    // -------------------------------------------------------------------------

    private struct DiskCacheEntry: Codable {
        let path: String
        let modificationDate: Date
        let version: String
        let validExtensions: [String]
    }

    private struct DiskCache: Codable {
        static let currentVersion = 4   // bumped: tighter name/version heuristic rejects format strings
        var version: Int = DiskCache.currentVersion
        /// keyed by core identifier
        var entries: [String: DiskCacheEntry] = [:]
    }

    /// Lazily loaded disk cache — loaded once, updated as misses are resolved.
    private static let diskCacheStorage = OSAllocatedUnfairLock<DiskCache?>(initialState: nil)

    private static var diskCacheURL: URL? {
        FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("com.provenance.libretro-metadata-cache.json")
    }

    private static func loadedDiskCache() -> DiskCache {
        diskCacheStorage.withLock { stored -> DiskCache in
            if let existing = stored { return existing }
            let loaded: DiskCache
            if let url = diskCacheURL,
               let data = try? Data(contentsOf: url),
               let decoded = try? JSONDecoder().decode(DiskCache.self, from: data),
               decoded.version == DiskCache.currentVersion {
                loaded = decoded
                DLOG("RetroArch metadata: loaded disk cache (\(decoded.entries.count) entries)")
            } else {
                loaded = DiskCache()
            }
            stored = loaded
            return loaded
        }
    }

    private static func persistDiskCache() {
        guard let url = diskCacheURL else { return }
        let snapshot = diskCacheStorage.withLock { $0 ?? DiskCache() }
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: url, options: .atomic)
            DLOG("RetroArch metadata: saved disk cache (\(snapshot.entries.count) entries)")
        } catch {
            WLOG("RetroArch metadata: failed to save disk cache: \(error)")
        }
    }

    // -------------------------------------------------------------------------
    // MARK: - Public API
    // -------------------------------------------------------------------------

    static func metadata(forIdentifier identifier: String) -> LibretroMetadata? {
        #if !canImport(Darwin)
        return nil
        #else
        let forceMetadata = ProcessInfo.processInfo.environment["PV_FORCE_RETRO_METADATA"] == "1"
        if DebuggerDetector.isAttached && !forceMetadata {
            DLOG("RetroArch metadata: skipping \(identifier) — debugger attached")
            return nil
        }

        // 1. In-memory cache (fastest path)
        if let hit = cacheStorage.withLock({ $0[identifier] }) {
            return hit
        }

        // 2. Resolve framework executable URL
        guard let executableURL = frameworkExecutableURL(forIdentifier: identifier) else {
            DLOG("RetroArch metadata: framework not found for \(identifier)")
            return nil
        }

        let execPath = executableURL.path
        let mtime = (try? FileManager.default.attributesOfItem(atPath: execPath))?[.modificationDate] as? Date

        // 3. Disk cache — avoids dlopen on subsequent launches
        let disk = loadedDiskCache()
        if let entry = disk.entries[identifier],
           let mtime,
           abs(entry.modificationDate.timeIntervalSince(mtime)) < 2 {
            DLOG("RetroArch metadata: disk cache hit for \(identifier)")
            let meta = LibretroMetadata(version: entry.version, validExtensions: entry.validExtensions)
            cacheStorage.withLock { $0[identifier] = meta }
            return meta
        }

        // 4. Fast-path: Mach-O string extraction (no dlopen, no code-signing penalty)
        ILOG("RetroArch metadata: probing \(identifier) via Mach-O")
        var meta = probeMachO(executableURL: executableURL)

        // 5. Slow-path: dlopen (first launch or Mach-O parse failed)
        if meta == nil {
            ILOG("RetroArch metadata: Mach-O probe failed, falling back to dlopen for \(identifier)")
            meta = probeViadlopen(executableURL: executableURL, identifier: identifier)
        }

        guard let meta else { return nil }

        // 6. Populate both caches
        cacheStorage.withLock { $0[identifier] = meta }
        diskCacheStorage.withLock { stored in
            if stored == nil { stored = DiskCache() }
            stored?.entries[identifier] = DiskCacheEntry(
                path: execPath,
                modificationDate: mtime ?? Date(),
                version: meta.version,
                validExtensions: meta.validExtensions
            )
        }
        persistDiskCache()

        ILOG("RetroArch metadata: cached '\(identifier)' v\(meta.version)")
        return meta
        #endif
    }

    // -------------------------------------------------------------------------
    // MARK: - Private helpers
    // -------------------------------------------------------------------------

    #if canImport(Darwin)

    /// Parse `__TEXT,__cstring` to extract version and extensions without dlopen.
    private static func probeMachO(executableURL: URL) -> LibretroMetadata? {
        guard let fileData = try? Data(contentsOf: executableURL, options: .mappedIfSafe) else { return nil }

        return fileData.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> LibretroMetadata? in
            guard let base = raw.baseAddress,
                  raw.count > MemoryLayout<mach_header_64>.size else { return nil }

            // Locate native-arch slice (handles fat binaries)
            var hdrOffset = 0
            let magic = base.load(as: UInt32.self)
            if magic == 0xcafebabe || magic == 0xbebafeca {
                let swap = (magic == 0xbebafeca)
                let nfat = Int(machoU32(base.advanced(by: 4), swap: swap))
                for i in 0..<nfat {
                    let aBase = base.advanced(by: 8 + i * 20)
                    guard 8 + (i + 1) * 20 <= raw.count else { break }
                    if machoU32(aBase, swap: swap) == 0x0100000c { // CPU_TYPE_ARM64
                        hdrOffset = Int(machoU32(aBase.advanced(by: 8), swap: swap))
                        break
                    }
                }
            }
            guard hdrOffset + MemoryLayout<mach_header_64>.size <= raw.count else { return nil }
            let hdr = base.advanced(by: hdrOffset).assumingMemoryBound(to: mach_header_64.self).pointee
            guard hdr.magic == MH_MAGIC_64 else { return nil }

            // Walk load commands to find __TEXT,__cstring
            var cstringStart = 0, cstringLen = 0
            var lcOff = hdrOffset + MemoryLayout<mach_header_64>.size
            outerLoop: for _ in 0..<Int(hdr.ncmds) {
                guard lcOff + MemoryLayout<load_command>.size <= raw.count else { break }
                let lc = base.advanced(by: lcOff).assumingMemoryBound(to: load_command.self).pointee
                let cmdSize = Int(lc.cmdsize)
                guard cmdSize > 0, lcOff + cmdSize <= raw.count else { break }
                if lc.cmd == UInt32(LC_SEGMENT_64),
                   cmdSize >= MemoryLayout<segment_command_64>.size {
                    let seg = base.advanced(by: lcOff).assumingMemoryBound(to: segment_command_64.self).pointee
                    if machoSegName(seg.segname) == "__TEXT" {
                        let sectBase = lcOff + MemoryLayout<segment_command_64>.size
                        for s in 0..<Int(seg.nsects) {
                            let sOff = sectBase + s * MemoryLayout<section_64>.size
                            guard sOff + MemoryLayout<section_64>.size <= raw.count else { break }
                            let sect = base.advanced(by: sOff).assumingMemoryBound(to: section_64.self).pointee
                            if machoSegName(sect.sectname) == "__cstring" {
                                cstringStart = Int(sect.offset)
                                cstringLen   = Int(sect.size)
                                break outerLoop
                            }
                        }
                        break outerLoop
                    }
                }
                lcOff += cmdSize
            }
            guard cstringLen > 0, cstringStart > 0,
                  cstringStart + cstringLen <= raw.count else { return nil }

            // Collect all C strings from __cstring
            var strings: [String] = []
            var pos = cstringStart
            let end = cstringStart + cstringLen
            while pos < end {
                let cptr = base.advanced(by: pos).assumingMemoryBound(to: CChar.self)
                var len = 0
                while pos + len < end && cptr[len] != 0 { len += 1 }
                if len > 0,
                   let s = String(bytes: UnsafeRawBufferPointer(start: UnsafeRawPointer(cptr), count: len), encoding: .utf8) {
                    strings.append(s)
                }
                pos += len + 1
            }

            // Find valid_extensions: pipe-separated short tokens like "gb|gbc|dmg"
            let extRegex = try? NSRegularExpression(pattern: #"^[a-zA-Z0-9]{1,8}(\|[a-zA-Z0-9]{1,8})+$"#)
            guard let extIdx = strings.firstIndex(where: { s in
                let r = NSRange(s.startIndex..., in: s)
                return extRegex?.firstMatch(in: s, range: r) != nil
            }) else { return nil }

            let extStr = strings[extIdx]
            let exts   = extStr.split(separator: "|").map(String.init)

            // Find library_name and library_version near the extensions string
            let lo     = max(0, extIdx - 6)
            let hi     = min(strings.count - 1, extIdx + 6)
            let window = strings[lo...hi].filter { $0 != extStr }

            // Reject strings that look like C format specifiers, file extensions,
            // file paths, or other non-name metadata that can appear in __cstring.
            let looksLikeJunk: (String) -> Bool = { s in
                s.contains("%") ||                       // printf format string ("%d.mcr", "%*lld")
                s.hasPrefix(".") ||                      // file extension (".mv", ".srm")
                s.hasPrefix("/") ||                      // file path
                s.hasPrefix("\\") ||                     // Windows path
                s.contains("\t") ||                      // tab-separated data
                s.unicodeScalars.contains(where: { $0.value < 0x20 }) // control chars
            }

            let libraryName = window.first(where: { s in
                !s.contains("|") && s.count >= 2 && s.count <= 60 &&
                !looksLikeJunk(s) &&
                s.first?.isLetter == true &&
                s.filter({ $0.isLetter }).count >= 2
            })
            guard libraryName != nil else { return nil }

            // Prefer version strings that contain at least one letter (e.g. "2.8-Vulkan bc43bce").
            // Exclude pure date strings like "2024.10.29" that appear near valid_extensions in
            // many buildbot cores — these are build dates, not library versions, and cause false
            // save-state version mismatch warnings.
            let datePattern = try? NSRegularExpression(pattern: #"^\d{4}[.\-]\d{2}[.\-]\d{2}$"#)
            let isDate: (String) -> Bool = { s in
                let r = NSRange(s.startIndex..., in: s)
                return datePattern?.firstMatch(in: s, range: r) != nil
            }
            // First pass: prefer a string with at least one letter (real version tag)
            let libVersionWithLetter = window.first(where: { s in
                s != libraryName && !isDate(s) && !looksLikeJunk(s) &&
                s.count >= 1 && s.count <= 30 &&
                s.range(of: "[A-Za-z]", options: .regularExpression) != nil
            })
            // Second pass: any non-date, non-junk short string
            let libVersion = libVersionWithLetter
                ?? window.first(where: { $0 != libraryName && !isDate($0) && !looksLikeJunk($0) && $0.count >= 1 && $0.count <= 30 })
                ?? ""

            return LibretroMetadata(version: libVersion, validExtensions: exts)
        }
    }

    private static func probeViadlopen(executableURL: URL, identifier: String) -> LibretroMetadata? {
        guard let handle = dlopen(executableURL.path, RTLD_LOCAL | RTLD_LAZY) else {
            ELOG("RetroArch metadata: dlopen failed for \(identifier): \(String(cString: dlerror()))")
            return nil
        }
        defer { dlclose(handle) }

        typealias GetSystemInfoFn = @convention(c) (UnsafeMutableRawPointer?) -> Void
        guard let sym = dlsym(handle, "retro_get_system_info") else {
            ELOG("RetroArch metadata: retro_get_system_info missing for \(identifier)")
            return nil
        }

        let getInfo = unsafeBitCast(sym, to: GetSystemInfoFn.self)
        var info = LibretroSystemInfo()
        withUnsafeMutablePointer(to: &info) { getInfo(UnsafeMutableRawPointer($0)) }

        guard let versionPtr = info.library_version else { return nil }
        let version = String(cString: versionPtr).trimmingCharacters(in: .whitespacesAndNewlines)
        let extensions: [String] = info.valid_extensions.map {
            String(cString: $0).split(separator: "|").map(String.init)
        } ?? []

        return LibretroMetadata(version: version, validExtensions: extensions)
    }

    private static func frameworkExecutableURL(forIdentifier identifier: String) -> URL? {
        let fileManager = FileManager.default

        let frameworkFolder: String
        let executableName: String
        let coreName: String

        if identifier.hasSuffix(".libretro.framework") {
            frameworkFolder  = identifier
            executableName   = String(identifier.dropLast(".framework".count))
            coreName         = String(identifier[..<(identifier.range(of: ".libretro.framework")!.lowerBound)])
        } else if identifier.hasSuffix(".libretro") {
            frameworkFolder  = "\(identifier).framework"
            executableName   = identifier
            coreName         = String(identifier[..<(identifier.range(of: ".libretro")!.lowerBound)])
        } else {
            coreName         = identifier
            executableName   = "\(identifier).libretro"
            frameworkFolder  = "\(identifier).libretro.framework"
        }

        let searchBases: [URL] = [
            Bundle.main.privateFrameworksURL,
            Bundle.main.bundleURL.appendingPathComponent("Frameworks", isDirectory: true),
        ].compactMap { $0 }

        for base in searchBases {
            let frameworkURL = base.appendingPathComponent(frameworkFolder, isDirectory: true)
            guard fileManager.fileExists(atPath: frameworkURL.path) else { continue }

            if let bundle = Bundle(url: frameworkURL),
               let exec = bundle.executableURL,
               fileManager.fileExists(atPath: exec.path) {
                return exec
            }
            let direct = frameworkURL.appendingPathComponent(executableName)
            if fileManager.fileExists(atPath: direct.path) { return direct }
        }

        // Fallback: scan Frameworks dir
        let frameworksDir = Bundle.main.bundleURL.appendingPathComponent("Frameworks", isDirectory: true)
        guard let contents = try? fileManager.contentsOfDirectory(
            at: frameworksDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        ) else { return nil }

        let expectedName = "\(coreName).libretro"
        for url in contents where url.pathExtension == "framework" {
            guard url.deletingPathExtension().lastPathComponent == expectedName else { continue }
            if let bundle = Bundle(url: url),
               let exec = bundle.executableURL,
               fileManager.fileExists(atPath: exec.path) { return exec }
            let direct = url.appendingPathComponent(expectedName)
            if fileManager.fileExists(atPath: direct.path) { return direct }
        }
        return nil
    }

    #endif
}

// ---------------------------------------------------------------------------
// MARK: - Mach-O helpers
// ---------------------------------------------------------------------------

private func machoU32(_ ptr: UnsafeRawPointer, swap: Bool) -> UInt32 {
    let v = ptr.load(as: UInt32.self)
    return swap ? v.byteSwapped : v
}

private func machoSegName<T>(_ tuple: T) -> String {
    withUnsafeBytes(of: tuple) { bytes in
        String(bytes: bytes.prefix(while: { $0 != 0 }), encoding: .utf8) ?? ""
    }
}

// ---------------------------------------------------------------------------
// MARK: - libretro_system_info mirror
// ---------------------------------------------------------------------------

#if canImport(Darwin)
@_alignment(8)
internal struct LibretroSystemInfo {
    var library_name: UnsafePointer<CChar>? = nil
    var library_version: UnsafePointer<CChar>? = nil
    var valid_extensions: UnsafePointer<CChar>? = nil
    var need_fullpath: Bool = false
    var block_extract: Bool = false
}
#endif
