import Foundation
import PVSupport
import Combine
import PVLogging
import Perception

@Perceptible
public final class ConflictsWatcher: ObservableObject {
    public static let shared = ConflictsWatcher()

    private let conflictsPath: URL
    private var directoryWatcher: DirectoryWatcher?

    public private(set) var conflictFiles: [URL] = []

    public var hasConflicts: Bool {
        !conflictFiles.isEmpty
    }

    private init() {
        conflictsPath = URL.documentsPath.appendingPathComponent("Conflicts/", isDirectory: true)
        setupDirectoryWatcher()
        updateConflictFiles()
    }

    private func setupDirectoryWatcher() {
        directoryWatcher = DirectoryWatcher(directory: conflictsPath)

        Task {
            await watchForChanges()
        }
    }

    private func watchForChanges() async {
        guard let directoryWatcher = directoryWatcher else { return }

        for await _ in directoryWatcher.extractionStatusSequence {
            await MainActor.run {
                self.updateConflictFiles()
            }
        }
    }

    private func updateConflictFiles() {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: conflictsPath,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            conflictFiles = fileURLs.sorted { $0.lastPathComponent < $1.lastPathComponent }
        } catch {
            ELOG("Error reading conflicts directory: \(error.localizedDescription)")
            conflictFiles = []
        }
    }
}
