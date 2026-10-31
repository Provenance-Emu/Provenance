import Foundation

/// Classifies a completed upload using the active ROM root and installed systems' extensions.
/// Imports, BIOS, saves and files outside that root remain owned by their existing watchers.
struct PVWebUploadImportRequest: Equatable {
    let url: URL
    let systemIdentifier: String

    static func resolve(fileURL: URL, romsRoot: URL, extensionsBySystem: [String: Set<String>]) -> Self? {
        let root = romsRoot.resolvingSymlinksInPath().standardizedFileURL
        let file = fileURL.resolvingSymlinksInPath().standardizedFileURL
        let prefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard file.path.hasPrefix(prefix) else { return nil }
        let components = String(file.path.dropFirst(prefix.count)).split(separator: "/")
        guard components.count >= 2, !components.contains(where: { $0.hasPrefix(".") }),
              let system = components.first.map(String.init),
              let extensions = extensionsBySystem[system],
              extensions.contains(file.pathExtension.lowercased()) else { return nil }
        return Self(url: file, systemIdentifier: system)
    }
}
