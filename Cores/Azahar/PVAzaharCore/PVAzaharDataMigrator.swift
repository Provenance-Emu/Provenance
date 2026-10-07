import Foundation
import PVLogging

/// Moves emuThreeDS's 3DS user data (nand, sdmc, sysdata, config, cheats, shaders) from the
/// legacy root into the Azahar root. Same-volume moves are renames, so no disk is duplicated.
/// `states` is skipped on purpose: emuThreeDS save states cannot be loaded by azahar.
///
/// A destination that already exists (azahar creates nand/, sdmc/ and others on its first boot) is merged:
/// every legacy entry missing at the destination is moved, directories present on both sides are merged
/// recursively, and a file present on both sides is left in place and reported as a conflict.
public struct PVAzaharDataMigrator {
    /// `.move`: the destination is absent, the whole directory moves. `.merge`: the destination exists and
    /// some legacy entries move into it. `.skipExists`: the destination exists and already has everything.
    public enum Action: Equatable { case move, merge, skipMissing, skipExists }
    public struct Plan {
        public let items: [(directory: String, action: Action)]
        public let totalBytes: Int64
        /// Legacy files left in place because the destination already has a file at that path (relative paths).
        public let conflicts: [String]
        /// Source → destination, in order; the entries `apply()` moves.
        let moves: [(source: URL, destination: URL)]
        public var hasWork: Bool { !moves.isEmpty }

        static var empty: Plan { Plan(items: [], totalBytes: 0, conflicts: [], moves: []) }
    }
    public enum Error: Swift.Error, LocalizedError {
        case moveFailed(directory: String, underlying: Swift.Error)
        public var errorDescription: String? {
            switch self {
            case let .moveFailed(directory, underlying): return "Could not move \(directory): \(underlying.localizedDescription)"
            }
        }
    }

    public static let candidates = ["nand", "sdmc", "sysdata", "config", "cheats", "shaders"]
    public static let userDirectoryName = "Azahar"
    public static let markerName = ".migrated-from-emuthree"
    private static let emuThreeCoreClassName = "PVEmuThree.PVEmuThreeCore"

    public let legacyRoot: URL
    public let targetRoot: URL
    private let fm: FileManager

    public init(legacyRoot: URL, targetRoot: URL, fileManager: FileManager = .default) {
        self.legacyRoot = legacyRoot
        self.targetRoot = targetRoot
        self.fm = fileManager
    }

    /// Where emuThreeDS keeps its data: Documents on iOS, Library/Caches on tvOS.
    public static func defaultLegacyRoot() -> URL {
        #if os(tvOS)
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        #else
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        #endif
    }

    /// Azahar's user root (`PVAzaharCore.userRootURL`): Documents/Azahar on iOS, Library/Caches/Azahar on tvOS,
    /// where Documents is not writable. Lives here so the test bundle, which compiles only this file, has it.
    public static func defaultTargetRoot() -> URL {
        #if os(tvOS)
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        #else
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        #endif
        return base.appendingPathComponent(userDirectoryName)
    }

    public static var emuThreeCoreIsPresent: Bool { NSClassFromString(emuThreeCoreClassName) != nil }

    public var alreadyMigrated: Bool { fm.fileExists(atPath: targetRoot.appendingPathComponent(Self.markerName).path) }

    public func plan() -> Plan {
        if alreadyMigrated { return .empty }
        var items: [(directory: String, action: Action)] = []
        var moves: [(source: URL, destination: URL)] = []
        var conflicts: [String] = []
        var bytes: Int64 = 0
        for dir in Self.candidates {
            let src = legacyRoot.appendingPathComponent(dir)
            let dst = targetRoot.appendingPathComponent(dir)
            guard isDirectory(src) else {
                items.append((dir, .skipMissing))
                continue
            }
            guard fm.fileExists(atPath: dst.path) else {
                items.append((dir, .move))
                moves.append((src, dst))
                bytes += directorySize(src)
                continue
            }
            let before = moves.count
            collectMerge(from: src, into: dst, relativePath: dir, moves: &moves, conflicts: &conflicts)
            for move in moves[before...] {
                bytes += isDirectory(move.source) ? directorySize(move.source) : fileSize(move.source)
            }
            items.append((dir, moves.count > before ? .merge : .skipExists))
        }
        return Plan(items: items, totalBytes: bytes, conflicts: conflicts, moves: moves)
    }

    /// Appends a move for every entry of `src` missing at `dst`, recursing into directories that exist on
    /// both sides. Anything else present on both sides is a conflict and stays where it is.
    private func collectMerge(from src: URL, into dst: URL, relativePath: String,
                              moves: inout [(source: URL, destination: URL)], conflicts: inout [String]) {
        guard isDirectory(dst) else {
            conflicts.append(relativePath)
            return
        }
        let children = (try? fm.contentsOfDirectory(atPath: src.path))?.sorted() ?? []
        for name in children {
            let child = src.appendingPathComponent(name)
            let target = dst.appendingPathComponent(name)
            let childPath = relativePath + "/" + name
            if !fm.fileExists(atPath: target.path) {
                moves.append((child, target))
            } else if isDirectory(child) {
                collectMerge(from: child, into: target, relativePath: childPath, moves: &moves, conflicts: &conflicts)
            } else {
                conflicts.append(childPath)
            }
        }
    }

    /// Moves every planned entry, then writes the marker. The marker is only written when all moves
    /// succeeded, so a failed run is retried; a source is only removed after its copy completed.
    /// Conflicting legacy files stay in the legacy root.
    @discardableResult
    public func apply() throws -> Plan {
        let plan = plan()
        guard plan.hasWork else { return plan }
        try fm.createDirectory(at: targetRoot, withIntermediateDirectories: true)
        for (src, dst) in plan.moves {
            let name = src.path.replacingOccurrences(of: legacyRoot.path + "/", with: "")
            do {
                try fm.moveItem(at: src, to: dst)
            } catch {
                ILOG("[PVAzahar] rename of \(name) failed (\(error)); copying instead")
                do {
                    try fm.copyItem(at: src, to: dst)
                } catch {
                    try? fm.removeItem(at: dst) // drop the partial copy so a retry sees a clean target
                    throw Error.moveFailed(directory: name, underlying: error)
                }
                do {
                    try fm.removeItem(at: src)
                } catch {
                    throw Error.moveFailed(directory: name, underlying: error)
                }
            }
        }
        if !plan.conflicts.isEmpty {
            ILOG("[PVAzahar] left \(plan.conflicts.count) emuThreeDS file(s) in place; Azahar already has them: \(plan.conflicts)")
        }
        let marker = targetRoot.appendingPathComponent(Self.markerName)
        do {
            try Data(Date().description.utf8).write(to: marker)
        } catch {
            throw Error.moveFailed(directory: Self.markerName, underlying: error)
        }
        return plan
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return fm.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    private func fileSize(_ url: URL) -> Int64 {
        Int64((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
    }

    private func directorySize(_ url: URL) -> Int64 {
        let keys: [URLResourceKey] = [.fileSizeKey, .isRegularFileKey]
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: keys) else { return 0 }
        var total: Int64 = 0
        for case let file as URL in enumerator {
            if let values = try? file.resourceValues(forKeys: Set(keys)), values.isRegularFile == true {
                total += Int64(values.fileSize ?? 0)
            }
        }
        return total
    }
}
