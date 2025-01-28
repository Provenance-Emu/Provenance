import Foundation

/// Manages storage of DeltaSkin files
public final class DeltaSkinStorage: DeltaSkinStorageProtocol {
    public static let shared = DeltaSkinStorage()

    private let fileManager = FileManager.default

    private init() {}

    /// Get the directory where skins are stored
    public func skinsDirectory() throws -> URL {
        let appSupport = try fileManager.url(for: .applicationSupportDirectory,
                                           in: .userDomainMask,
                                           appropriateFor: nil,
                                           create: true)

        let skinsDir = appSupport.appendingPathComponent("DeltaSkins", isDirectory: true)
        if !fileManager.fileExists(atPath: skinsDir.path) {
            try fileManager.createDirectory(at: skinsDir,
                                         withIntermediateDirectories: true)
        }
        return skinsDir
    }

    public func saveSkin(_ data: Data, withIdentifier identifier: String) async throws -> URL {
        let directory = try skinsDirectory()
        let fileURL = directory.appendingPathComponent("\(identifier).deltaskin")

        try data.write(to: fileURL)
        return fileURL
    }

    public func deleteSkin(withIdentifier identifier: String) async throws {
        if let url = url(forSkinIdentifier: identifier) {
            try fileManager.removeItem(at: url)
        }
    }

    public func url(forSkinIdentifier identifier: String) -> URL? {
        guard let directory = try? skinsDirectory() else { return nil }
        let url = directory.appendingPathComponent("\(identifier).deltaskin")
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }
}
