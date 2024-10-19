//
//  ArchiveExtractor.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 10/19/24.
//

package enum ArchiveType: String {
    case zip
    case sevenZip = "7z"
}

package protocol ArchiveExtractor {
    func extract(at path: URL, to destination: URL) async throws -> [URL]
}

package struct ZipExtractor: ArchiveExtractor {
    func extract(at path: URL, to destination: URL) async throws -> [URL] {
        var extractedFiles: [URL] = []

        try await withCheckedThrowingContinuation { continuation in
            SSZipArchive.unzipFile(atPath: path.path,
                                   toDestination: destination.path,
                                   overwrite: true,
                                   password: nil,
                                   progressHandler: { entry, _, entryNumber, total in
                                       if !entry.isEmpty {
                                           let url = destination.appendingPathComponent(entry)
                                           extractedFiles.append(url)
                                       }
                                   },
                                   completionHandler: { _, succeeded, error in
                                       if succeeded {
                                           continuation.resume(returning: ())
                                       } else if let error = error {
                                           continuation.resume(throwing: error)
                                       } else {
                                           continuation.resume(throwing: NSError(domain: "ZipExtractor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unknown error during ZIP extraction"]))
                                       }
                                   })
        }

        return extractedFiles
    }
}

package struct SevenZipExtractor: ArchiveExtractor {
    func extract(at path: URL, to destination: URL) async throws -> [URL] {
        var extractedFiles: [URL] = []

        let container = try Data(contentsOf: path)
        let entries = try SevenZipContainer.open(container: container)

        for item in entries where item.info.type != .directory {
            let fullPath = destination.appendingPathComponent(item.info.name)
            extractedFiles.append(fullPath)

            if let data = item.data {
                try data.write(to: fullPath, options: [.atomic, .noFileProtection])
            }
        }

        return extractedFiles
    }
}
