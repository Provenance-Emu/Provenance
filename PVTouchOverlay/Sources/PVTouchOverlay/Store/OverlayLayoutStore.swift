import Foundation
import Combine
import PVLogging

public struct OverlayLayoutFile: Codable, Equatable, Sendable {
    public var version: Int
    public var layouts: [String: [String: GroupOverride]]
    public var games: [String: [String: [String: GroupOverride]]]
    public static let empty = OverlayLayoutFile(version: OverlayLayoutStore.currentVersion, layouts: [:], games: [:])
}

/// Persists user layout overrides: one layer per pad kind/orientation key, plus a per-game layer on top.
@MainActor
public final class OverlayLayoutStore: ObservableObject {
    nonisolated public static let currentVersion = 1
    public static let fileName = "touch_overlay_layout_v1.json"
    public static let shared: OverlayLayoutStore = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return OverlayLayoutStore(fileURL: dir.appendingPathComponent(fileName))
    }()

    @Published public private(set) var revision: Int = 0
    private let fileURL: URL
    private var file: OverlayLayoutFile

    public init(fileURL: URL) {
        self.fileURL = fileURL
        file = .empty
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? JSONDecoder().decode(OverlayLayoutFile.self, from: data),
           decoded.version == Self.currentVersion {
            file = decoded
        } else {
            WLOG("OverlayLayoutStore: ignoring \(fileURL.lastPathComponent): undecodable or version mismatch")
        }
    }

    public func overrides(for key: String, gameMD5: String?) -> OverlayLayoutOverrides {
        if let md5 = gameMD5, let groups = file.games[md5]?[key] { return OverlayLayoutOverrides(groups: groups) }
        if let groups = file.layouts[key] { return OverlayLayoutOverrides(groups: groups) }
        return .empty
    }

    /// `persist: false` still bumps `revision` but defers the disk write to `flush()`.
    public func set(_ overrides: OverlayLayoutOverrides, for key: String, gameMD5: String?, persist: Bool = true) {
        if let md5 = gameMD5 {
            file.games[md5, default: [:]][key] = overrides.groups
        } else {
            file.layouts[key] = overrides.groups
        }
        if persist { self.persist() } else { revision &+= 1 }
    }

    public func reset(key: String, gameMD5: String?) {
        if let md5 = gameMD5 {
            file.games[md5]?[key] = nil
            if file.games[md5]?.isEmpty == true { file.games[md5] = nil }
        } else {
            file.layouts[key] = nil
        }
        persist()
    }

    public func snapshot() -> OverlayLayoutFile { file }
    public func restore(_ snapshot: OverlayLayoutFile) { file = snapshot; persist() }

    /// Writes the current state to disk (after `set(..., persist: false)` calls).
    public func flush() { write() }

    private func persist() {
        revision &+= 1
        write()
    }

    private func write() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try encoder.encode(file).write(to: fileURL, options: .atomic)
        } catch {
            ELOG("OverlayLayoutStore: failed to write \(fileURL.lastPathComponent): \(error)")
        }
    }
}
