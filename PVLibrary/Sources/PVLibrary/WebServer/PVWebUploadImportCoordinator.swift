import Foundation
import PVSystems

/// Coalesces simultaneous completion notifications before handing a file to the existing importer.
actor PVWebUploadImportCoordinator {
    typealias ImportFile = @Sendable (URL, SystemIdentifier) async -> Void

    private var pendingPaths: Set<String> = []
    private let importFile: ImportFile

    init(importFile: @escaping ImportFile = { url, system in
        await GameImporter.shared.addImports(forPaths: [url], targetSystem: system)
        GameImporter.shared.startProcessing()
    }) {
        self.importFile = importFile
    }

    func enqueue(_ request: PVWebUploadImportRequest) async {
        guard let system = SystemIdentifier(rawValue: request.systemIdentifier),
              pendingPaths.insert(request.url.path).inserted else { return }
        defer { pendingPaths.remove(request.url.path) }
        await importFile(request.url, system)
    }
}
