import Foundation
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
    /// Thread-safe cache storage using `OSAllocatedUnfairLock` to wrap the dictionary directly.
    /// This eliminates bare lock/unlock pairs and the associated unlock-on-early-return risks.
    private static let cacheStorage = OSAllocatedUnfairLock<[String: LibretroMetadata]>(initialState: [:])

    static func metadata(forIdentifier identifier: String) -> LibretroMetadata? {
        #if !canImport(Darwin)
        return nil
        #else
        let forceMetadata = ProcessInfo.processInfo.environment["PV_FORCE_RETRO_METADATA"] == "1"
        if DebuggerDetector.isAttached && !forceMetadata {
            DLOG("RetroArch metadata: Skipping metadata load for \(identifier) because debugger is attached")
            return nil
        }
        ILOG("RetroArch metadata: Loading metadata for core \(identifier)")

        /// Fast path: return cached entry without doing I/O
        if let cached = cacheStorage.withLock({ $0[identifier] }) {
            ILOG("RetroArch metadata: Cache hit for \(identifier) - version: \(cached.version), extensions: \(cached.validExtensions.joined(separator: ", "))")
            return cached
        }

        /// Load outside the lock so we don't block other threads during dlopen/symbol lookup
        ILOG("RetroArch metadata: Cache miss for \(identifier), loading from framework...")
        guard let metadata = loadMetadata(forIdentifier: identifier) else {
            ILOG("RetroArch metadata: Failed to load metadata for \(identifier)")
            return nil
        }

        /// Store result — concurrent first-load races are benign (last writer wins)
        cacheStorage.withLock { $0[identifier] = metadata }

        ILOG("RetroArch metadata: Successfully loaded and cached metadata for \(identifier) - version: \(metadata.version), extensions: \(metadata.validExtensions.joined(separator: ", "))")
        return metadata
        #endif
    }

    #if canImport(Darwin)
    private static func loadMetadata(forIdentifier identifier: String) -> LibretroMetadata? {
        guard let executableURL = frameworkExecutableURL(forIdentifier: identifier) else {
            DLOG("RetroArch metadata: missing framework for \(identifier)")
            return nil
        }

        ILOG("RetroArch metadata: Found framework executable at \(executableURL.path) for \(identifier)")

        guard let handle = dlopen(executableURL.path, RTLD_LOCAL | RTLD_LAZY) else {
            ELOG("RetroArch metadata: failed to dlopen \(executableURL.path)")
            return nil
        }
        defer { dlclose(handle) }
        ILOG("RetroArch metadata: Successfully dlopened framework for \(identifier)")

        typealias RetroGetSystemInfoFn = @convention(c) (UnsafeMutableRawPointer?) -> Void
        guard let symbol = dlsym(handle, "retro_get_system_info") else {
            ELOG("RetroArch metadata: retro_get_system_info missing for \(identifier)")
            return nil
        }
        ILOG("RetroArch metadata: Found retro_get_system_info symbol for \(identifier)")

        let getSystemInfo = unsafeBitCast(symbol, to: RetroGetSystemInfoFn.self)
        var info = LibretroSystemInfo(
            library_name: nil,
            library_version: nil,
            valid_extensions: nil,
            need_fullpath: false,
            block_extract: false
        )
        withUnsafeMutablePointer(to: &info) { pointer in
            getSystemInfo(UnsafeMutableRawPointer(pointer))
        }
        ILOG("RetroArch metadata: Called retro_get_system_info for \(identifier)")

        guard let versionPtr = info.library_version else {
            DLOG("RetroArch metadata: library_version nil for \(identifier)")
            return nil
        }

        let version = String(cString: versionPtr).trimmingCharacters(in: .whitespacesAndNewlines)
        let extensions: [String]
        if let validPtr = info.valid_extensions {
            extensions = String(cString: validPtr)
                .split(separator: "|")
                .map { String($0) }
        } else {
            extensions = []
        }

        ILOG("RetroArch metadata: Parsed metadata for \(identifier) - library_name: \(info.library_name.map { String(cString: $0) } ?? "nil"), version: \(version), extensions: \(extensions.isEmpty ? "none" : extensions.joined(separator: ", "))")

        return LibretroMetadata(version: version, validExtensions: extensions)
    }

    private static func frameworkExecutableURL(forIdentifier identifier: String) -> URL? {
        let fileManager = FileManager.default

        /// Extract the core name from identifier
        /// Identifier format: "corename.libretro.framework" (e.g., "2048.libretro.framework", "mgba.libretro.framework")
        /// Framework folder: "corename.libretro.framework" (e.g., "2048.libretro.framework")
        /// Executable name: "corename.libretro" (e.g., "2048.libretro")

        let coreName: String
        let frameworkFolder: String
        let executableName: String

        if identifier.hasSuffix(".libretro.framework") {
            /// Identifier is already in correct format: "2048.libretro.framework"
            frameworkFolder = identifier
            executableName = String(identifier.dropLast(".framework".count)) // "2048.libretro"
            if let range = identifier.range(of: ".libretro.framework") {
                coreName = String(identifier[..<range.lowerBound]) // "2048"
            } else {
                coreName = identifier
            }
        } else if identifier.hasSuffix(".libretro") {
            /// Identifier is "2048.libretro"
            frameworkFolder = "\(identifier).framework"
            executableName = identifier
            if let range = identifier.range(of: ".libretro") {
                coreName = String(identifier[..<range.lowerBound])
            } else {
                coreName = identifier
            }
        } else {
            /// Identifier is just "2048" - construct full names
            coreName = identifier
            executableName = "\(identifier).libretro"
            frameworkFolder = "\(identifier).libretro.framework"
        }

        ILOG("RetroArch metadata: Identifier '\(identifier)' -> coreName: '\(coreName)', frameworkFolder: '\(frameworkFolder)', executableName: '\(executableName)'")

        let searchBases: [URL?] = [
            Bundle.main.privateFrameworksURL,
            Bundle.main.bundleURL.appendingPathComponent("Frameworks", isDirectory: true),
            Bundle.main.bundleURL
        ]

        /// First try direct lookup by framework folder name
        for base in searchBases.compactMap({ $0 }) {
            let frameworkURL = base.appendingPathComponent(frameworkFolder, isDirectory: true)
            ILOG("RetroArch metadata: Checking path: \(frameworkURL.path)")

            guard fileManager.fileExists(atPath: frameworkURL.path) else {
                continue
            }

            /// Try using Bundle to get executable
            if let bundle = Bundle(url: frameworkURL),
               let executableURL = bundle.executableURL,
               fileManager.fileExists(atPath: executableURL.path) {
                ILOG("RetroArch metadata: Found framework via Bundle at \(frameworkURL.path), executable at \(executableURL.path)")
                return executableURL
            }

            /// Fallback: construct executable path directly
            let directExecutableURL = frameworkURL.appendingPathComponent(executableName)
            if fileManager.fileExists(atPath: directExecutableURL.path) {
                ILOG("RetroArch metadata: Found framework via direct path at \(frameworkURL.path), executable at \(directExecutableURL.path)")
                return directExecutableURL
            }
        }

        /// Fallback: scan Frameworks directory for matching .libretro.framework
        ILOG("RetroArch metadata: Direct lookup failed, scanning Frameworks directory for '\(coreName).libretro.framework'")
        let frameworksDir = Bundle.main.bundleURL.appendingPathComponent("Frameworks", isDirectory: true)

        guard fileManager.fileExists(atPath: frameworksDir.path) else {
            ILOG("RetroArch metadata: Frameworks directory does not exist at \(frameworksDir.path)")
            return nil
        }

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: frameworksDir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: .skipsHiddenFiles
            )

            ILOG("RetroArch metadata: Found \(contents.filter { $0.pathExtension == "framework" }.count) frameworks in Frameworks directory")

            for frameworkURL in contents where frameworkURL.pathExtension == "framework" {
                let frameworkName = frameworkURL.deletingPathExtension().lastPathComponent

                /// Match if framework name equals "corename.libretro"
                let expectedFrameworkName = "\(coreName).libretro"
                if frameworkName == expectedFrameworkName {
                    ILOG("RetroArch metadata: Found matching framework: \(frameworkName).framework")

                    /// Try using Bundle
                    if let bundle = Bundle(url: frameworkURL),
                       let executableURL = bundle.executableURL,
                       fileManager.fileExists(atPath: executableURL.path) {
                        ILOG("RetroArch metadata: Found executable via Bundle at \(executableURL.path)")
                        return executableURL
                    }

                    /// Fallback: construct executable path directly
                    let directExecutableURL = frameworkURL.appendingPathComponent(expectedFrameworkName)
                    if fileManager.fileExists(atPath: directExecutableURL.path) {
                        ILOG("RetroArch metadata: Found executable via direct path at \(directExecutableURL.path)")
                        return directExecutableURL
                    }
                }
            }
        } catch {
            ELOG("RetroArch metadata: Error scanning Frameworks directory: \(error)")
        }

        ILOG("RetroArch metadata: Framework not found for identifier '\(identifier)'")
        return nil
    }
    #endif
}

#if canImport(Darwin)
@_alignment(8)
private struct LibretroSystemInfo {
    var library_name: UnsafePointer<CChar>?
    var library_version: UnsafePointer<CChar>?
    var valid_extensions: UnsafePointer<CChar>?
    var need_fullpath: Bool
    var block_extract: Bool
}
#endif
