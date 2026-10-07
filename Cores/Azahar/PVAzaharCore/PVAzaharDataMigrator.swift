import Foundation
import PVLogging

/// Moves emuThreeDS's 3DS user data (nand, sdmc, sysdata, config, cheats, shaders) from the
/// legacy root into the Azahar root. Same-volume moves are renames, so no disk is duplicated.
/// `states` is skipped on purpose: emuThreeDS save states cannot be loaded by azahar.
public struct PVAzaharDataMigrator {
    public enum Action: Equatable { case move, skipMissing, skipExists }
    public struct Plan {
        public let items: [(directory: String, action: Action)]
        public let totalBytes: Int64
        public var hasWork: Bool { items.contains { $0.action == .move } }
    }
    public enum Error: Swift.Error { case moveFailed(directory: String, underlying: Swift.Error) }

    public static let candidates = ["nand", "sdmc", "sysdata", "config", "cheats", "shaders"]
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

    public static func defaultTargetRoot() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Azahar")
    }

    public static var emuThreeCoreIsPresent: Bool { NSClassFromString(emuThreeCoreClassName) != nil }

    public var alreadyMigrated: Bool { fm.fileExists(atPath: targetRoot.appendingPathComponent(Self.markerName).path) }

    public func plan() -> Plan {
        if alreadyMigrated { return Plan(items: [], totalBytes: 0) }
        var items: [(directory: String, action: Action)] = []
        var bytes: Int64 = 0
        for dir in Self.candidates {
            let src = legacyRoot.appendingPathComponent(dir)
            let dst = targetRoot.appendingPathComponent(dir)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: src.path, isDirectory: &isDir), isDir.boolValue else {
                items.append((dir, .skipMissing))
                continue
            }
            if fm.fileExists(atPath: dst.path) {
                items.append((dir, .skipExists))
                continue
            }
            items.append((dir, .move))
            bytes += directorySize(src)
        }
        return Plan(items: items, totalBytes: bytes)
    }

    /// Moves every planned directory, then writes the marker. The marker is only written when all moves
    /// succeeded, so a failed run is retried; a source is only removed after its copy completed.
    @discardableResult
    public func apply() throws -> Plan {
        let plan = plan()
        guard plan.hasWork else { return plan }
        try fm.createDirectory(at: targetRoot, withIntermediateDirectories: true)
        for (dir, action) in plan.items where action == .move {
            let src = legacyRoot.appendingPathComponent(dir)
            let dst = targetRoot.appendingPathComponent(dir)
            do {
                try fm.moveItem(at: src, to: dst)
            } catch {
                ILOG("[PVAzahar] rename of \(dir) failed (\(error)); copying instead")
                do {
                    try fm.copyItem(at: src, to: dst)
                } catch {
                    try? fm.removeItem(at: dst) // drop the partial copy so a retry sees a clean target
                    throw Error.moveFailed(directory: dir, underlying: error)
                }
                do {
                    try fm.removeItem(at: src)
                } catch {
                    throw Error.moveFailed(directory: dir, underlying: error)
                }
            }
        }
        let marker = targetRoot.appendingPathComponent(Self.markerName)
        do {
            try Data(Date().description.utf8).write(to: marker)
        } catch {
            throw Error.moveFailed(directory: Self.markerName, underlying: error)
        }
        return plan
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
